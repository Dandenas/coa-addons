"""Adds each CoA sub-map's parent zone to AstrolabeCoAData.lua.
CoA turned starting areas, caves and mines into top-level areas (AreaTable parent 0), so
GetRealZoneText() reports e.g. "Northshire Valley" where the guides say "Elwynn Forest".
The stock subzone of the same name still records its real parent; use that."""
import struct
exec(open('gen2.py', encoding='utf-8').read().split("lines=['-- Generated")[0])   # builds `out`, `dbc`, `probe`

a = open('AreaTable_stock.dbc', 'rb').read()  # stock Blizzard table: CoA re-parented these areas in patch-M
_, an, af, ars, _ = struct.unpack_from('<4sIIII', a); astr = a[20 + an * ars:]
def AS(o): e = astr.find(b'\0', o); return astr[o:e].decode('utf8', 'replace')
area = {}
for i in range(an):
    I = struct.unpack_from('<%dI' % af, a, 20 + i * ars)
    area[I[0]] = dict(parent=I[2], name=AS(I[11]))
byname = {}
for aid, r in area.items(): byname.setdefault(r['name'], []).append(aid)
def top(aid):
    seen = 0
    while area.get(aid) and area[aid]['parent'] and seen < 10: aid = area[aid]['parent']; seen += 1
    return aid
row_by_area = {}
for rows in dbc.values():
    for r in rows: row_by_area.setdefault(r['area'], []).append(r)
listed = {(c, f.lower()): (z, n) for c, z, f, _, n in probe}

# Classic caves and dungeon entrances that even the stock AreaTable lists as top-level areas.
# Their zones are standard WoW geography; each is checked below to overlap its parent's rectangle.
KNOWN_PARENTS = {
    'burningbladecoven': 'durotar', 'dustwindcave': 'durotar', 'felrock': 'teldrassil',
    'shadowthreadcave': 'teldrassil', 'tideshollow': 'azuremystisle', 'wailingcavernsbarrens': 'barrens',
    'maraudonorange': 'desolace', 'deadmineswestfall': 'westfall', 'scarletmonasteryentrance': 'tirisfal',
    'twilightsrun': 'silithus',
}
parents, report = {}, []
for f, v in sorted(out.items(), key=lambda kv: (kv[1]['c'], kv[0])):
    c = v['c']; row = dbc[f][0]; name = area.get(row['area'], {}).get('name') or v['name']
    cx, cy = (row['L'] + row['R']) / 2, (row['T'] + row['B']) / 2
    cands = []
    for aid in byname.get(name, []):
        if aid == row['area'] or not area[aid]['parent']: continue
        for zr in row_by_area.get(top(aid), []):
            key = (c, zr['name'].lower())
            if key in listed and zr['name'].lower() not in out:
                inside = zr['L'] >= cx >= zr['R'] and zr['T'] >= cy >= zr['B']
                cands.append((not inside, zr['name'].lower(), listed[key][1]))
    if cands:
        cands.sort(); _, pf, pname = cands[0]
        parents.setdefault(c, {})[f] = pf
        report.append('  c%d %-26s %-24s -> %s' % (c, f, name, pname))
    elif f in KNOWN_PARENTS:
        pf = KNOWN_PARENTS[f]
        pr = dbc[pf][0]
        overlaps = pr['L'] >= row['R'] and row['L'] >= pr['R'] and pr['T'] >= row['B'] and row['T'] >= pr['B']
        assert overlaps and (c, pf) in listed, 'known parent %s does not fit %s' % (pf, f)
        parents.setdefault(c, {})[f] = pf
        report.append('  c%d %-26s %-24s -> %s (known)' % (c, f, name, listed[(c, pf)][1]))
    else:
        report.append('  c%d %-26s %-24s -> (own zone)' % (c, f, name))
print('\n'.join(report))
lines = ['', '-- Parent zone of each CoA map that the stock client treats as part of a larger zone.',
         '-- CoA made these top-level areas, so GetRealZoneText() names them instead of the zone',
         '-- the guides use. Values are map file names (lowercased), as in ZygorAstrolabeCoAZoneData.',
         'ZygorCoAZoneParents = {']
for c in sorted(parents):
    lines.append('\t[%d] = {' % c)
    for f, pf in sorted(parents[c].items()): lines.append('\t\t["%s"] = "%s",' % (f, pf))
    lines.append('\t},')
lines.append('}')
body = open('AstrolabeCoAData.lua', encoding='utf-8').read() if False else None
open('parents.lua', 'w', newline='\r\n').write('\n'.join(lines) + '\n')
print('parents:', sum(len(x) for x in parents.values()))
