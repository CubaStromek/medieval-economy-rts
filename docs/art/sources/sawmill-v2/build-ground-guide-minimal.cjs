const fs=require('fs'), path=require('path'), sharp=require('sharp');
const out=__dirname;
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800">
<rect width="800" height="800" fill="#eeebe0"/>
<text x="32" y="38" font-family="sans-serif" font-size="22" fill="#33392d">GROUND GUIDE ONLY — 4 × 2 occupied cells</text>
<text x="32" y="67" font-family="sans-serif" font-size="16" fill="#555b48">Building, chimney and roof rise ABOVE this ground area.</text>
<text x="32" y="93" font-family="sans-serif" font-size="16" fill="#555b48">800 × 800 • 4 image px = 1 world px • do not draw these guides</text>
<rect x="80" y="320" width="640" height="320" fill="#d2d8c1" stroke="#6c7758" stroke-width="3"/>
<g stroke="#a5ad91" stroke-width="1.5"><path d="M240 320V640 M400 320V640 M560 320V640 M80 480H720"/></g>
<path d="M284 620 L700 504 L564 356 L148 472Z" fill="#b6c7a0" fill-opacity=".7" stroke="#536c42" stroke-width="4"/>
<path d="M284 620 L700 504" fill="none" stroke="#a67a26" stroke-width="6"/>
<text x="430" y="590" font-family="sans-serif" font-size="16" fill="#694a1f">FRONT: rises to right</text>
<path d="M320 610L320 640" stroke="#168f9a" stroke-width="10"/>
<rect x="240" y="640" width="160" height="160" fill="#b4e0de" stroke="#168f9a" stroke-width="3"/>
<circle cx="320" cy="640" r="8" fill="#168f9a"/>
<text x="246" y="740" font-family="sans-serif" font-size="16" fill="#185e64">CLEAR APPROACH</text>
<text x="246" y="765" font-family="sans-serif" font-size="16" fill="#185e64">Doorstep (320,640)</text>
<g stroke="#555858" stroke-width="7" fill="none" stroke-linecap="round"><circle cx="758" cy="499" r="11"/><path d="M758 511V570 M758 526L741 552 M758 526L775 552 M758 570L746 620 M758 570L770 620"/></g>
<text x="729" y="657" font-family="sans-serif" font-size="14" fill="#444">33 world px</text>
<text x="729" y="678" font-family="sans-serif" font-size="14" fill="#444">132 image px</text>
</svg>`;
fs.writeFileSync(path.join(out,'ground-guide-minimal.svg'),svg);
sharp(Buffer.from(svg)).png().toFile(path.join(out,'ground-guide-minimal.png')).then(()=>console.log('ground-guide-minimal.png'));
