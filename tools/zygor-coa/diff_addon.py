import sys, os, glob, difflib
sys.path.insert(0, '.')
from mpq import MPQ
BS = chr(92)
CLIENT = 'D:' + BS + 'COA Client'
m = MPQ('D:/COA Client/Data/patch-B.MPQ')
for addon in sys.argv[1:]:
    base = os.path.join(CLIENT, 'Interface', 'AddOns', addon)
    for root, _, files in os.walk(base):
        for f in files:
            full = os.path.join(root, f); rel = os.path.relpath(full, CLIENT)
            data = open(full, 'rb').read().replace(b'\r\n', b'\n')
            if not m.find(rel):
                print('== %s: LOOSE ONLY (%d bytes)' % (rel, len(data))); continue
            orig = m.read(rel).replace(b'\r\n', b'\n')
            if orig == data: continue
            a = orig.decode('latin-1').split('\n'); b = data.decode('latin-1').split('\n')
            d = [l for l in difflib.unified_diff(a, b, 'archive', 'loose', n=1, lineterm='')]
            print('== %s: %d diff lines' % (rel, len(d)))
            print('\n'.join(x[:160] for x in d[:40]))
