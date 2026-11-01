"""Fetch only the six manifest-bound public CLIP inputs; no inference or secrets."""
import hashlib
import json
import os
from pathlib import Path
import urllib.parse
import urllib.request


def fetch(manifest, target):
    assert set(manifest) == {'repository', 'revision', 'files'}
    assert manifest['repository'] == 'immich-app/ViT-B-32__openai'
    assert manifest['revision'] == 'a857c8de2c07bbcfa6646adfcf31b798845afa1e'
    assert set(manifest['files']) == {'config.json', 'textual/model.onnx', 'textual/tokenizer.json',
                                    'textual/tokenizer_config.json', 'visual/model.onnx', 'visual/preprocess_cfg.json'}
    for name, row in sorted(manifest['files'].items()):
        path = target / name; path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            assert path.is_file() and not path.is_symlink()
        else:
            url = 'https://huggingface.co/' + manifest['repository'] + '/resolve/' + manifest['revision'] + '/' + name
            # Hugging Face redirects large public blobs to its signed HTTPS CDN.
            with urllib.request.urlopen(url, timeout=120) as source, path.open('xb') as output:
                assert urllib.parse.urlsplit(source.url).scheme == 'https'
                length = 0
                while chunk := source.read(1024 * 1024):
                    length += len(chunk); assert length <= row['size']; output.write(chunk)
                output.flush(); os.fsync(output.fileno())
        checksum = hashlib.sha256()
        with path.open('rb') as source:
            while chunk := source.read(1024 * 1024): checksum.update(chunk)
        assert path.stat().st_size == row['size'] and checksum.hexdigest() == row['sha256']
    print('PASS: all six pinned public CLIP inputs authenticated')


if __name__ == '__main__':
    import sys
    fetch(json.loads(Path(sys.argv[1]).read_text()), Path(sys.argv[2]))
