import sys, glob, os
sys.path.insert(0, '.')
from mpq import MPQ
BS = chr(92)
A = os.path.join('D:' + BS, 'COA Client', 'Interface', 'AddOns')
names = []
for addon in ('Ascension_Collections', 'Ascension_AppearanceUI'):
    for root, _, files in os.walk(os.path.join(A, addon)):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), os.path.join('D:' + BS, 'COA Client'))
            names.append(rel.replace('/', BS))
arcs = sorted(set(p.lower() for p in glob.glob('D:/COA Client/Data/*.MPQ') + glob.glob('D:/COA Client/Data/*.mpq') + glob.glob('D:/COA Client/Data/enUS/*.MPQ')))
for p in arcs:
    try: m = MPQ(p)
    except Exception: continue
    hits = []
    for n in names:
        b = m.find(n)
        if b:
            try: d = m.read(n)
            except Exception: d = b''
            hits.append((n.split(BS)[-1], b[2], (b'localspecstate' in d) or (b'ASC_LOCAL' in d) or (b'AscensionLocal' in d)))
    if hits:
        print(os.path.basename(p), len(hits), 'of', len(names), 'files')
        for h in hits: print('   %-45s %8d  CoA-compat code: %s' % h)
print('checked', len(arcs), 'archives for', len(names), 'files')
