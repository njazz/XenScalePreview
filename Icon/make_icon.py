#!/usr/bin/env python3
"""Writes icon.svg (macOS: inset rounded square) and icon-ios.svg (full-bleed square; iOS rounds it).
The artwork is the preview's pitch wheel for 31-EDO with everything but the ring removed: 31 equal wedges, degree 0
at the top and clockwise from there, each white or black by the same rule the preview uses (black when the degree's
nearest 12-TET pitch is C#, D#, F#, G# or A#). No text, spokes, dots, outlines or accent colour: the wedges are
separated only by gaps that show the tile behind them. Render the PNGs with Icon/render.js."""
import math, os

N = 31
BLACK = {1, 3, 6, 8, 10}
black = [round(d * 1200 / N / 100) % 12 in BLACK for d in range(N)]

BODY = 824.0                       # macOS icon body inside the 1024 canvas; iOS icons fill the whole canvas
RING = 670.0                       # outer diameter of the ring on the macOS icon: ~87% of the body, centred with margins
INNER = 0.56                       # inner radius as a fraction of the outer radius (the wheel's hole)
GAP = 7.0                          # gap between wedges, in pixels of the 1024 canvas (macOS size)
WHITE, DARK = "#f6efe1", "#5b5654"

def build(mac: bool) -> str:
    k = 1.0 if mac else 1024 / BODY                   # same proportion of the visible icon on both platforms
    R, g = RING / 2 * k, GAP * k
    r = R * INNER
    cx = cy = 512.0

    def pt(a, rad):                                   # a in radians, 0 at the top, clockwise
        return cx + rad * math.sin(a), cy - rad * math.cos(a)
    wedges = []
    step = 2 * math.pi / N
    for d in range(N):
        a0, a1 = (d - 0.5) * step, (d + 0.5) * step
        o0, o1 = a0 + (g / 2) / R, a1 - (g / 2) / R   # constant-width gap: trim by g/2 at each radius
        i0, i1 = a0 + (g / 2) / r, a1 - (g / 2) / r
        p0, p1, p2, p3 = pt(o0, R), pt(o1, R), pt(i1, r), pt(i0, r)
        wedges.append(f'<path fill="{DARK if black[d] else WHITE}" d="M{p0[0]:.2f},{p0[1]:.2f}A{R:.2f},{R:.2f} 0 0 1 {p1[0]:.2f},{p1[1]:.2f}'
                      f'L{p2[0]:.2f},{p2[1]:.2f}A{r:.2f},{r:.2f} 0 0 0 {p3[0]:.2f},{p3[1]:.2f}Z"/>')
    wedges = "\n".join(wedges)

    if mac:
        body = '<rect id="body" x="100" y="100" width="824" height="824" rx="186"/>'
        shadow = ('<filter id="drop" x="-10%" y="-10%" width="120%" height="125%">'
                  '<feDropShadow dx="0" dy="14" stdDeviation="14" flood-color="#000" flood-opacity=".45"/></filter>')
        outer = '<g filter="url(#drop)"><use href="#body" fill="url(#bg)"/></g>'
    else:
        body = '<rect id="body" x="0" y="0" width="1024" height="1024"/>'
        shadow, outer = "", '<use href="#body" fill="url(#bg)"/>'

    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
<defs>
{body}
{shadow}
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#202020"/><stop offset="1" stop-color="#202030"/></linearGradient>
</defs>
{outer}
{wedges}
</svg>
'''

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    open(os.path.join(here, "icon.svg"), "w").write(build(True))
    open(os.path.join(here, "icon-ios.svg"), "w").write(build(False))
    print("wrote icon.svg, icon-ios.svg; wedges:", "".join("B" if b else "W" for b in black))
