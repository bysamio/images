"""Fail on new Go advisories; prove the sole module-metadata finding absent."""
import json
from pathlib import Path
import sys

def require(value, message):
    if not value:
        raise RuntimeError(message)


root = Path(sys.argv[1])
expected = sys.argv[2]
proof = json.loads((root / 'compiled-functions.json').read_text())
require(proof['binary_sha256'] == expected, 'Audit/runtime binary mismatch')
require(proof['functions_examined'] > 100 and proof['openpgp_functions'] == [], 'OpenPGP code present or incomplete ELF proof')
packages = (root / 'compiled-packages.txt').read_text().splitlines()
require(len(packages) > 100 and 'github.com/ollama/ollama' in packages, 'Incomplete compile closure')
require(not any(p.startswith('golang.org/x/crypto/openpgp') for p in packages), 'OpenPGP compile dependency present')
raw = (root / 'govulncheck.json').read_text()
decoder = json.JSONDecoder()
findings = []
configs = []
sboms = []
while raw.strip():
    item, end = decoder.raw_decode(raw.lstrip())
    raw = raw.lstrip()[end:]
    if 'config' in item:
        configs.append(item['config'])
    if 'SBOM' in item:
        sboms.append(item['SBOM'])
    if 'finding' in item:
        findings.append(item['finding'])
require(len(configs) == 1 and configs[0].get('scanner_name') == 'govulncheck'
        and configs[0].get('scanner_version') == 'v1.9.0'
        and configs[0].get('scan_level') == 'symbol' and configs[0].get('scan_mode') == 'binary'
        and len(sboms) == 1, 'Missing or incorrect native audit receipt')
for finding in findings:
    require(finding['osv'] == 'GO-2026-5932', 'New advisory requires explicit review/remediation')
    require(finding['trace'] and finding['trace'][0]['module'] == 'golang.org/x/crypto', 'Unexpected advisory scope')
    for frame in finding['trace']:
        require(not frame.get('package') or frame['package'].startswith('golang.org/x/crypto/openpgp'), 'Unexpected affected package')
print('PASS: native Go audit and exact-binary proof; deprecated OpenPGP packages/functions absent.')
