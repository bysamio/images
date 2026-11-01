"""Real offline HTTP vectors from an immutable default CLIP model."""
import io
import json
import math
from pathlib import Path
import time
import urllib.error
import urllib.request
from PIL import Image

base = 'http://127.0.0.1:3003'
for attempt in range(120):
    try:
        assert urllib.request.urlopen(base + '/ping', timeout=3).read() == b'pong'
        break
    except (OSError, AssertionError): time.sleep(1)
else: raise AssertionError('ML did not become ready')

def predict(kind, payload):
    boundary = 'bysam-public-synthetic-fixture'
    entries = json.dumps({'clip': {kind: {'modelName': 'ViT-B-32__openai'}}})
    body = f'--{boundary}\r\nContent-Disposition: form-data; name="entries"\r\n\r\n{entries}\r\n'.encode()
    if kind == 'visual':
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="synthetic.jpg"\r\nContent-Type: image/jpeg\r\n\r\n'.encode() + payload + b'\r\n'
    else:
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="text"\r\n\r\n{payload}\r\n'.encode()
    body += f'--{boundary}--\r\n'.encode()
    request = urllib.request.Request(base + '/predict', body, {'Content-Type': 'multipart/form-data; boundary=' + boundary})
    result = json.load(urllib.request.urlopen(request, timeout=240))
    vector = json.loads(result['clip'])
    assert isinstance(vector, list) and len(vector) == 512
    assert all(math.isfinite(x) for x in vector) and sum(x*x for x in vector) > 0
    return vector

def workers():
    rows = {}
    for path in Path('/proc').glob('[0-9]*/status'):
        try:
            pid = int(path.parent.name)
            status = dict(line.split(':', 1) for line in path.read_text().splitlines() if ':' in line)
            rows[pid] = (int(status['PPid']), (path.parent / 'cmdline').read_bytes())
        except (FileNotFoundError, ProcessLookupError): pass
    return {pid for pid, (parent, command) in rows.items()
            if b'gunicorn' in command and b'gunicorn' in rows.get(parent, (0, b''))[1]}

image = io.BytesIO(); Image.new('RGB', (256, 256), 'red').save(image, 'JPEG')
first = predict('visual', image.getvalue()); text = predict('textual', 'a red image')
assert first != text
before = workers(); assert len(before) == 1
try:
    urllib.request.urlopen(urllib.request.Request(base + '/predict', b''), timeout=10)
    raise AssertionError('Malformed request accepted')
except urllib.error.HTTPError as error: assert error.code in (400, 422)
# Idle shutdown clears the worker's model cache after TTL. A fresh request must
# load both models from the same read-only cache, with networking still disabled.
time.sleep(75)
assert len(workers()) == 1 and workers() != before, "Idle worker was not unloaded"
assert predict('visual', image.getvalue()) == first
assert predict('textual', 'a red image') == text
print('PASS: offline HTTP visual/text vectors, malformed input and idle reload')
