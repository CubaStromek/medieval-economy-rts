// Reconstructed vector source after a parallel filename collision on 2026-09-12.
// Reproduces the measured geometry and actual uniformly scaled person. The original
// generation input qa/sawmill-v2/ground-guide.png is deliberately never overwritten.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '../../../..');
const qa = path.join(root, 'docs/art/qa/sawmill-v2');
const g = JSON.parse(fs.readFileSync(path.join(qa, 'geometry.json')));
const human = fs.readFileSync(path.join(root, g.human.source)).toString('base64');
const hx = g.human.guide_foot[0] - g.human.source_ground_contact[0] * g.human.guide_scale;
const hy = g.human.guide_foot[1] - g.human.source_ground_contact[1] * g.human.guide_scale;
const hs = g.human.source_canvas[0] * g.human.guide_scale;
const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="800" height="800" viewBox="0 0 800 800">
<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0L10 5L0 10Z" fill="#c86621"/></marker></defs>
<rect width="800" height="800" fill="#f3f4ed"/>
<g font-family="Arial, sans-serif" fill="#21342c">
<text x="24" y="30" font-size="22" font-weight="bold">SAWMILL V2 · TECHNICAL GROUND GUIDE</text>
<text x="24" y="53" font-size="14">800 × 800 · 4 source px / world px · same 4 × 2 occupied cells</text>
<rect x="80" y="76" width="640" height="226" fill="none" stroke="#d4d7cd" stroke-width="2" stroke-dasharray="7 6"/>
<g fill="#778275" font-size="14"><text x="104" y="103">ROOF / HEIGHT MAY PROJECT ABOVE GROUND</text><text x="104" y="125">Keep complete roof and chimney inside canvas; no cropped silhouette.</text></g>
<rect x="80" y="320" width="640" height="320" fill="#e4ecdf" stroke="#367da4" stroke-width="4"/>
<path d="M284 620L700 504L564 356L148 472Z" fill="#c5dec9" stroke="#27836b" stroke-width="3"/>
<path d="M80 320H720V640H80Z M240 320V640 M400 320V640 M560 320V640 M80 480H720" fill="none" stroke="#709daf" stroke-width="1"/>
<g font-size="16" fill="#35647b"><text x="84" y="313">OCCUPIED GROUND · 160 × 80 WORLD PX</text><text x="88" y="340">NW (80,320)</text><text x="585" y="635">SE (720,640)</text></g>
<path d="M276 436.3L412 584.3" stroke="#27836b" stroke-width="2" stroke-dasharray="7 5" opacity=".8"/>
<g font-size="16" fill="#256b58"><text x="190" y="482">SMALL LEFT</text><text x="192" y="502">CLOSED ROOM</text><text x="424" y="469">LARGE RIGHT WORKSHOP</text><text x="424" y="490">Ground contacts stay in this envelope</text></g>
<path d="M284 620L700 504" fill="none" stroke="#c86621" stroke-width="5" marker-end="url(#arrow)"/>
<text x="405" y="570" font-size="14" fill="#b45a1d" transform="rotate(-15.58083 405 570)">FRONT EDGE RISES TO THE RIGHT · (416,−116)</text>
<path d="M292 618L348 602L348 640L292 640Z" fill="#d8b780" stroke="#9d6935"/>
<path d="M292 618V474L348 458V602" fill="none" stroke="#a33a9d" stroke-width="2" stroke-dasharray="5 4"/>
<path d="M320 610V640" fill="none" stroke="#a33a9d" stroke-width="2"/>
<circle cx="320" cy="640" r="6" fill="#a33a9d"/>
<rect x="240" y="640" width="160" height="160" fill="#f4e6ca" fill-opacity=".8" stroke="#c78c38" stroke-width="3" stroke-dasharray="8 5"/>
<g text-anchor="middle" fill="#8c5a27"><text x="320" y="677" font-size="18" font-weight="bold">KEEP CLEAR</text><text x="320" y="700" font-size="14">ENTRANCE (1,1)</text><text x="320" y="725" font-size="13">x240…400 / y640…800</text><text x="320" y="756" font-size="14">threshold (320,640)</text></g>
<g fill="#993690" font-size="14"><text x="84" y="686">Door leaf 35–37 world px tall</text><text x="84" y="706">Purple outline is a scale guide.</text><text x="84" y="728">Shallow step stays inside</text><text x="84" y="749">the occupied ground.</text></g>
<image x="${hx}" y="${hy}" width="${hs}" height="${hs}" xlink:href="data:image/png;base64,${human}"/>
<path d="M778 508H790 M784 508V640 M778 640H790" fill="none" stroke="#784526" stroke-width="2"/>
<g fill="#784526" font-size="13" text-anchor="end"><text x="784" y="667">33 world px</text><text x="784" y="687">132 source px</text></g>
</g></svg>`;
fs.writeFileSync(path.join(__dirname, 'ground-guide.svg'), svg);
sharp(Buffer.from(svg)).png().toFile(path.join(qa, 'ground-guide-rebuilt.png'))
  .then(() => process.stdout.write('Rebuilt technical guide; original generation-input PNG preserved.\n'));
