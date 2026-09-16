import math
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

RED = "#E2463B"
GRAY = "#5E5F61"
FONT = "/Users/abdullah/Library/Fonts/Montserrat-VariableFont_wght.ttf"

AVENIR = "/System/Library/Fonts/Avenir Next.ttc"

def load_font(face):
    if isinstance(face, int):
        return TTFont(AVENIR, fontNumber=face)
    return instancer.instantiateVariableFont(TTFont(FONT), {"wght": face[1]})

def text_path(text, face, x, baseline, size, tracking=0.0):
    f = load_font(face)
    gs, cmap, hmtx = f.getGlyphSet(), f.getBestCmap(), f["hmtx"]
    s = size / f["head"].unitsPerEm
    pen = SVGPathPen(gs)
    cx = x
    for ch in text:
        g = cmap[ord(ch)]
        gs[g].draw(TransformPen(pen, (s, 0, 0, -s, cx, baseline)))
        cx += hmtx[g][0] * s + tracking
    return pen.getCommands(), cx

def arc(cx, cy, r, a0, a1):
    p = lambda a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    (x0, y0), (x1, y1) = p(a0), p(a1)
    large = 1 if (a1 - a0) > 180 else 0
    return f"M{x0:.2f},{y0:.2f} A{r},{r} 0 {large} 1 {x1:.2f},{y1:.2f}"

def ellipse(cx, cy, rx, ry):
    return (f"M{cx-rx},{cy} a{rx},{ry} 0 1 0 {2*rx},0 a{rx},{ry} 0 1 0 {-2*rx},0 Z")

# "g": bowl ring + stem + hook
gcx, gcy = 40.5, 89
g_bowl = ellipse(gcx, gcy, 39.5, 36) + " " + ellipse(gcx, gcy, 24, 24)
g_stem = "M64.5,54.5 H80 V117 H64.5 Z"
hy, orx, ory, irx, iry, cut = 117, 39.5, 35, 24, 23, 126
ox = gcx - orx * math.sqrt(1 - ((cut - hy) / ory) ** 2)
ix = gcx - irx * math.sqrt(1 - ((cut - hy) / iry) ** 2)
g_hook = (f"M{gcx+orx},{hy} A{orx},{ory} 0 0 1 {ox:.2f},{cut} L{ix:.2f},{cut} "
          f"A{irx},{iry} 0 0 0 {gcx+irx},{hy} Z")

# "o"
ocx, ocy = 129.5, 90.5
o_ring = ellipse(ocx, ocy, 38.5, 37.5) + " " + ellipse(ocx, ocy, 22.5, 25)

arcs = [(67, 222, 408), (67, 127, 139), (63, 316, 352), (54.5, 20, 78), (54.5, 108, 152),
        (54.5, 228, 272), (47.5, 232, 452), (43.5, 106, 264)]
arc_paths = " ".join(arc(ocx, ocy, r, a0, a1) for r, a0, a1 in arcs)

SOL_SIZE = 12.5
tech, tech_end = text_path("tech", ("m", 380), 89.5, 175, 46.4, tracking=-2.6)
erp, erp_end = text_path("ERP", 2, 5.5, 175, 18.5, tracking=-1.3)
sol, _ = text_path("Solutions", 5, erp_end + 2.8, 175, SOL_SIZE, tracking=-0.5)

print("sol end", round(_, 1))

def svg(bg=None):
    rect = f'<rect x="-8" y="-4" width="206" height="206" fill="{bg}"/>' if bg else ""
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-8 -4 206 206" width="2048" height="2048">
{rect}
<path d="{arc_paths}" fill="none" stroke="{RED}" stroke-width="1" stroke-linecap="round" opacity="0.85"/>
<path d="{g_bowl}" fill="{RED}" fill-rule="evenodd"/>
<path d="{g_stem} {g_hook}" fill="{RED}"/>
<path d="{o_ring}" fill="{RED}" fill-rule="evenodd"/>
<path d="{tech}" fill="{RED}"/>
<path d="{erp}" fill="{GRAY}"/>
<path d="{sol}" fill="{GRAY}"/>
</svg>'''

open("gotech-logo.svg", "w").write(svg())
open("gotech-logo-white.svg", "w").write(svg("#FFFFFF"))
print("tech ends at", round(tech_end, 1), "ERP ends at", round(erp_end, 1))

def doc(view, size, body):
    w, h = size
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" width="{w}" height="{h}">{body}</svg>'

def mark(arcs_on=True, gray=GRAY, text=True):
    parts = []
    if arcs_on:
        parts.append(f'<path d="{arc_paths}" fill="none" stroke="{RED}" stroke-width="1" stroke-linecap="round" opacity="0.85"/>')
    parts += [f'<path d="{g_bowl}" fill="{RED}" fill-rule="evenodd"/>',
              f'<path d="{g_stem} {g_hook}" fill="{RED}"/>',
              f'<path d="{o_ring}" fill="{RED}" fill-rule="evenodd"/>']
    if text:
        parts += [f'<path d="{tech}" fill="{RED}"/>', f'<path d="{erp}" fill="{gray}"/>', f'<path d="{sol}" fill="{gray}"/>']
    return "".join(parts)

# tight logos for the in-app header (max 300x60 -> render 3x height)
tight = "0 18 200 160"
open("logo_light.svg", "w").write(doc(tight, (750, 600), mark()))
open("logo_dark.svg", "w").write(doc(tight, (750, 600), mark(gray="#D0D1D3")))
# app icon: white rounded tile + "go" mark
tile = '<rect x="-12" y="-19" width="220" height="220" rx="44" fill="#FFFFFF"/>'
open("icon_arcs.svg", "w").write(doc("-12 -19 220 220", (1024, 1024), tile + mark(text=False)))
tile_small = '<rect x="-15.5" y="-0.5" width="200" height="200" rx="38" fill="#FFFFFF"/>'
open("icon_plain.svg", "w").write(doc("-15.5 -0.5 200 200", (1024, 1024), tile_small + mark(arcs_on=False, text=False)))
