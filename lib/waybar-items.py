#!/usr/bin/env python3
import json, os, re, sys

path = sys.argv[1]
wm = os.environ.get('IBR_WM', 'sway')
zones = [os.environ.get(k, '').split() for k in ('IBR_L', 'IBR_M', 'IBR_R')]

mod = {}
with open(os.environ['IBR_MODMAP']) as fh:
    for line in fh:
        f = line.rstrip('\n').split('\t')
        if len(f) == 4 and f[0] == 'waybar':
            mod[(f[1], f[2])] = f[3]

def name(item):
    return mod.get((item, wm)) or mod.get((item, '*'))

cfg = json.loads(re.sub(r'^\s*//.*$', '', open(path).read(), flags=re.M))
picked = [[n for n in (name(i) for i in z) if n and n in cfg] for z in zones]
cfg['modules-left'], cfg['modules-center'], cfg['modules-right'] = picked

keep = set(sum(picked, []))
for k in [k for k in cfg if '/' in k or '#' in k]:
    if k not in keep and not k.startswith('layer'):
        cfg.pop(k, None)

open(path, 'w').write(json.dumps(cfg, indent='\t') + '\n')
