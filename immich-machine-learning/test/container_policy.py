import json,sys
row,=json.load(sys.stdin);h=row['HostConfig']
assert row['Config']['User']=='1000:1000'
assert row['State']['Running'] and not row['State']['OOMKilled'] and row['RestartCount']==0
assert h['ReadonlyRootfs'] and not h.get('Privileged') and not h.get('CapAdd')
assert h['Memory']==2816*1024**2
assert h['NetworkMode']=='none' and not h.get('PortBindings')
assert not h.get('Devices') and h['PidsLimit']==128
assert all(x['Destination']=='/cache' for x in row['Mounts'] if x['Type']!='tmpfs')
print('PASS: bounded non-root offline worker; no ports, OOM or restart')
