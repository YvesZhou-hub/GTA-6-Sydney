#!/usr/bin/env python3
"""Package only explicitly approved public source; never sweep the workspace."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile
from release_files import public_files

root = Path(__file__).resolve().parent.parent
archive = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / 'dist/Harbourlife-source-public.zip'
archive.parent.mkdir(parents=True, exist_ok=True)
files = public_files(root)
manifest = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as output:
    for path in files:
        output.write(path, Path('harbourlife') / path.relative_to(root))
    output.writestr('harbourlife/SOURCE_MANIFEST.json', json.dumps(manifest, ensure_ascii=False, indent=2))
report = {'archive': archive.name, 'file_count': len(files), 'bytes': archive.stat().st_size,
          'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
          'scope': 'Public source, original source assets, attributed geography, tests, public evidence and notices. The playable build is a separate release asset; obtain Godot from its official release.'}
print(json.dumps(report, ensure_ascii=False, indent=2))
