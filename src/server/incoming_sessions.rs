// Authorized incoming sessions as the home screen shows them: who, since when, and since when in a voice call.
// Kept by the process that serves connections; the UI process reads it over IPC (`Data::IncomingSessions`).
use std::{
    collections::BTreeMap,
    sync::Mutex,
    time::{SystemTime, UNIX_EPOCH},
};

struct IncomingSession {
    peer_id: String,
    name: String,
    conn_type: i32,
    since_ms: i64,
    voice_call_since_ms: Option<i64>,
}

static SESSIONS: Mutex<BTreeMap<i32, IncomingSession>> = Mutex::new(BTreeMap::new());

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or_default()
}

pub fn add(conn_id: i32, peer_id: &str, name: &str, conn_type: i32) {
    SESSIONS.lock().unwrap().insert(
        conn_id,
        IncomingSession {
            peer_id: peer_id.to_owned(),
            name: name.to_owned(),
            conn_type,
            since_ms: now_ms(),
            voice_call_since_ms: None,
        },
    );
}

pub fn set_voice_call(conn_id: i32, on: bool) {
    if let Some(session) = SESSIONS.lock().unwrap().get_mut(&conn_id) {
        session.voice_call_since_ms = if on {
            session.voice_call_since_ms.or(Some(now_ms()))
        } else {
            None
        };
    }
}

pub fn remove(conn_id: i32) {
    SESSIONS.lock().unwrap().remove(&conn_id);
}

pub fn to_json() -> String {
    let sessions: Vec<_> = SESSIONS
        .lock()
        .unwrap()
        .values()
        .map(|s| {
            serde_json::json!({
                "peer_id": s.peer_id,
                "name": s.name,
                "conn_type": s.conn_type,
                "since_ms": s.since_ms,
                "voice_call_since_ms": s.voice_call_since_ms,
            })
        })
        .collect();
    serde_json::Value::Array(sessions).to_string()
}
