from pathlib import Path
status = dict(line.split(':',1) for line in Path('/proc/self/status').read_text().splitlines() if ':' in line)
assert all(int(status[key].strip(),16)==0 for key in ('CapEff','CapPrm','CapInh','CapBnd','CapAmb'))
cgroup=Path('/sys/fs/cgroup')
assert int((cgroup/'memory.max').read_text())==2816*1024**2
assert int((cgroup/'memory.swap.max').read_text())==0
quota,period=map(int,(cgroup/'cpu.max').read_text().split()); assert quota==period
assert int((cgroup/'pids.max').read_text())==128
assert int((cgroup/'memory.events').read_text().split('oom_kill ')[1].split()[0])==0
print('PASS: actual cgroup memory/swap/CPU/PID limits and zero capabilities')
