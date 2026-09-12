"""Embed review images in the existing literal visualization fragment.

Only presentation resampling/compression; full-resolution deliverables stay intact.
Run with Pillow Python and pass the absolute path to the fragment.
"""
from pathlib import Path
from PIL import Image
import base64
import io
import json
import re
import sys

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[3]
DIRECTIONS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']

def encode(payload, mime):
    return 'data:image/' + mime + ';base64,' + base64.b64encode(payload).decode('ascii')

def main():
    fragment = Path(sys.argv[1])
    template = fragment.read_text()
    for quality in [86, 82, 78, 74]:
        data = {}
        for direction in DIRECTIONS:
            original = PROJECT / 'original_game_data/kam-reference-export/lumberjack-full-set/carry-guides-8x' / (direction + '.png')
            own = Image.open(ROOT / 'sheets' / (direction + '.png')).convert('RGB')
            assert own.size == (1792, 1088)
            buf = io.BytesIO()
            own.resize((1120, 680), Image.Resampling.LANCZOS).save(buf, 'WEBP', quality=quality, method=6)
            data[direction] = {'original': encode(original.read_bytes(), 'png'), 'own': encode(buf.getvalue(), 'webp')}
        output = re.sub(r'(<script type="application/json" data-images>).*?(</script>)', lambda m: m[1] + json.dumps(data, separators=(',', ':')) + m[2], template, flags=re.S)
        if len(output.encode()) < 1_000_000:
            fragment.write_text(output)
            print(json.dumps({'bytes': len(output.encode()), 'quality': quality, 'ownSheet': [1120,680], 'originalSheet':[1792,1088], 'directions':8}))
            return
    raise ValueError('Preview exceeds 1MB; preserve existing fragment and reduce preview resolution explicitly.')

if __name__ == '__main__':
    main()
