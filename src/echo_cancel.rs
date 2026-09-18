use cpal::Sample;
use hbb_common::log;
use sonora::{
    config::{EchoCanceller, HighPassFilter, NoiseSuppression},
    AudioProcessing, Config, StreamConfig,
};
use std::{
    collections::VecDeque,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Mutex,
    },
};

const CHUNKS_PER_SECOND: u32 = 100;
// Playback no capture has consumed yet is dropped past this, so a stalled capture
// cannot hand the canceller echo that is older than its delay search window.
const MAX_QUEUED_CHUNKS: usize = 20;

static ACTIVE_CANCELLERS: AtomicUsize = AtomicUsize::new(0);
static PLAYBACK: Mutex<Playback> = Mutex::new(Playback {
    sample_rate: 0,
    samples: VecDeque::new(),
});

struct Playback {
    sample_rate: u32,
    samples: VecDeque<f32>,
}

impl Playback {
    fn max_samples(&self) -> usize {
        (self.sample_rate / CHUNKS_PER_SECOND) as usize * MAX_QUEUED_CHUNKS
    }
}

/// Records what the output callback just handed to the speaker, as the echo reference.
pub fn push_playback<T: Sample>(data: &[T], channels: usize, sample_rate: u32) {
    if ACTIVE_CANCELLERS.load(Ordering::Relaxed) == 0 || channels == 0 {
        return;
    }
    // The output callback must not wait; a skipped block only weakens cancellation briefly.
    let Ok(mut playback) = PLAYBACK.try_lock() else {
        return;
    };
    if playback.sample_rate != sample_rate {
        playback.sample_rate = sample_rate;
        playback.samples.clear();
        let max_samples = playback.max_samples();
        playback.samples.reserve(max_samples);
    }
    for frame in data.chunks_exact(channels) {
        let sum: f32 = frame
            .iter()
            .map(|sample| (*sample).to_float_sample().to_sample::<f32>())
            .sum();
        playback.samples.push_back(sum / channels as f32);
    }
    let excess = playback
        .samples
        .len()
        .saturating_sub(playback.max_samples());
    playback.samples.drain(..excess);
}

pub struct CaptureEchoCanceller {
    processor: AudioProcessing,
    channels: usize,
    frames: usize,
    capture_mono: Vec<f32>,
    capture_out: Vec<f32>,
    playback_pending: Vec<f32>,
    playback_out: Vec<f32>,
    reported_error: bool,
}

impl CaptureEchoCanceller {
    pub fn new(sample_rate: u32, channels: usize) -> Self {
        let config = Config {
            echo_canceller: Some(EchoCanceller::default()),
            noise_suppression: Some(NoiseSuppression::default()),
            high_pass_filter: Some(HighPassFilter::default()),
            ..Default::default()
        };
        let capture = StreamConfig::new(sample_rate, 1);
        let processor = AudioProcessing::builder()
            .config(config)
            .capture_config(capture)
            .render_config(capture)
            .build();
        if let Ok(mut playback) = PLAYBACK.lock() {
            playback.samples.clear();
        }
        ACTIVE_CANCELLERS.fetch_add(1, Ordering::Relaxed);
        log::info!("Voice call echo cancellation on: {sample_rate} Hz, {channels} channel(s)");
        Self {
            processor,
            channels: channels.max(1),
            frames: capture.num_frames(),
            capture_mono: Vec::with_capacity(capture.num_frames()),
            capture_out: vec![0.0; capture.num_frames()],
            playback_pending: Vec::new(),
            playback_out: Vec::new(),
            reported_error: false,
        }
    }

    /// Removes the speaker's echo from one interleaved 10 ms capture packet in place.
    pub fn process(&mut self, packet: &mut [f32]) {
        self.feed_playback();
        if packet.len() != self.frames * self.channels {
            return;
        }
        let channels = self.channels;
        self.capture_mono.clear();
        self.capture_mono.extend(
            packet
                .chunks_exact(channels)
                .map(|frame| frame.iter().sum::<f32>() / channels as f32),
        );
        let result = self.processor.process_capture_f32(
            &[self.capture_mono.as_slice()],
            &mut [self.capture_out.as_mut_slice()],
        );
        if let Err(err) = result {
            report_error(&mut self.reported_error, "capture", err);
            return;
        }
        for (frame, sample) in packet.chunks_exact_mut(channels).zip(&self.capture_out) {
            frame.fill(*sample);
        }
    }

    fn feed_playback(&mut self) {
        let sample_rate = {
            let Ok(mut playback) = PLAYBACK.lock() else {
                return;
            };
            let chunk = (playback.sample_rate / CHUNKS_PER_SECOND) as usize;
            if chunk == 0 {
                return;
            }
            let available = playback.samples.len() / chunk * chunk;
            self.playback_pending.clear();
            self.playback_pending.extend(playback.samples.drain(..available));
            playback.sample_rate
        };
        let config = StreamConfig::new(sample_rate, 1);
        self.playback_out.resize(config.num_frames(), 0.0);
        for block in self.playback_pending.chunks_exact(config.num_frames()) {
            let result = self.processor.process_render_f32_with_config(
                &[block],
                &config,
                &config,
                &mut [self.playback_out.as_mut_slice()],
            );
            if let Err(err) = result {
                report_error(&mut self.reported_error, "playback", err);
                return;
            }
        }
    }
}

fn report_error(reported: &mut bool, stream: &str, err: sonora::Error) {
    if !*reported {
        *reported = true;
        log::warn!("Echo cancellation skipped a {stream} block: {err}");
    }
}

impl Drop for CaptureEchoCanceller {
    fn drop(&mut self) {
        ACTIVE_CANCELLERS.fetch_sub(1, Ordering::Relaxed);
    }
}

/// Echo-cancels a capture packet when a canceller is running, otherwise passes it through.
pub fn process_capture(
    canceller: Option<&mut CaptureEchoCanceller>,
    mut packet: Vec<f32>,
) -> Vec<f32> {
    if let Some(canceller) = canceller {
        canceller.process(&mut packet);
    }
    packet
}
