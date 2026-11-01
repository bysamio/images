import importlib.metadata as metadata
import sys
expected = sorted(line.strip() for line in sys.stdin if line.strip())
actual = sorted(d.metadata['Name'].lower().replace('_', '-') + '==' + d.version for d in metadata.distributions())
assert actual == expected, 'Runtime inventory differs from reviewed audit input'
assert len({line.split('==')[0] for line in actual}) == len(actual)
print('PASS: complete audited runtime inventory; no stale package copies')
