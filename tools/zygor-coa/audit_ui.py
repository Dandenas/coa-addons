"""Compare every loose Interface\AddOns\Ascension* folder with its original in the client MPQs."""
import sys, os, glob
sys.path.insert(0, '.')
from mpq import MPQ
BS = chr(92)
CLIENT = 'D:' + BS + 'COA Client'
ADDONS = os.path.join(CLIENT, 'Interface', 'AddOns')
arcs = []
for p in sorted(set(x.lower() for x in glob.glob('D:/COA Client/Data/*.MPQ') + glob.glob('D:/COA Client/Data/*.mpq') + glob.glob('D:/COA Client/Data/enUS/*.MPQ'))):
    try: arcs.append((os.path.basename(p), MPQ(p)))
    except Exception: pass
MARKERS = (b'localspec', b'localtalent', b'localappearance', b'localvanity', b'localcharges', b'ASC_LOCAL', b'AscensionLocal', b'ASCENSION_LOCAL', b'LOCAL_MANASTORM', b'extprobe')
for addon in sorted(os.listdir(ADDONS)):
    if not addon.lower().startswith('ascension') or not os.path.isdir(os.path.join(ADDONS, addon)): continue
    same = diff = loose_only = 0; compat = set(); where = set()
    for root, _, files in os.walk(os.path.join(ADDONS, addon)):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, CLIENT)
            data = open(full, 'rb').read()
            for mk in MARKERS:
                if mk in data: compat.add(mk.decode())
            orig = None
            for name, m in arcs:
                if m.find(rel):
                    try: orig = m.read(rel); where.add(name)
                    except Exception: orig = None
            if orig is None: loose_only += 1
            elif orig.replace(b'\r\n', b'\n') == data.replace(b'\r\n', b'\n'): same += 1
            else: diff += 1
    verdict = 'IDENTICAL to archive' if diff == 0 and loose_only == 0 else ('NOT IN ARCHIVE' if same == 0 and diff == 0 else 'MODIFIED')
    print('%-38s %-20s same %3d  differ %3d  loose-only %3d  %s%s' % (addon, verdict, same, diff, loose_only,
          ('archive: ' + ','.join(sorted(where)) + '  ') if where else '', ('CoA compat: ' + ','.join(sorted(compat))) if compat else ''))
