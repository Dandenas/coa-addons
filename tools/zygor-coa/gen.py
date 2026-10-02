import struct, csv, json
d = open('WorldMapArea.dbc','rb').read()
_, nrec, nfld, rsize, ssize = struct.unpack_from('<4sIIII', d); base=20; strs=d[base+nrec*rsize:]
def S(o): e=strs.find(b'\0',o); return strs[o:e].decode()
dbc = {}
for i in range(nrec):
    r=d[base+i*rsize:base+(i+1)*rsize]; I=struct.unpack('<11I',r); F=struct.unpack('<11f',r)
    dbc.setdefault(S(I[3]).lower(), []).append(dict(id=I[0],map=I[1],area=I[2],name=S(I[3]),L=F[4],R=F[5],T=F[6],B=F[7]))
astro = {}   # (cont) -> {name: (w,h,xo,yo)}
for row in csv.reader(open('wms.csv')):
    if row[0]=='Z': astro.setdefault(int(row[1]),{})[row[2]] = tuple(map(float,row[3:7]))
probe = [ (int(c),int(z),f,a,n) for c,z,f,a,n in csv.reader(open('probe_zones.csv')) ]
out, missing = {}, []
for c,z,f,area,name in probe:
    if c>4: continue
    known = astro.get(c,{})
    if f in known: continue
    rows = dbc.get(f.lower())
    if not rows: missing.append((c,z,f,name,'no dbc row')); continue
    sub = rows[0]
    cx, cy = (sub['L']+sub['R'])/2, (sub['T']+sub['B'])/2
    best=None
    for pname,(pw,ph,pxo,pyo) in known.items():
        for p in dbc.get(pname.lower(),[]):
            if p['map']!=sub['map']: continue
            if p['L']>=cx>=p['R'] and p['T']>=cy>=p['B']:
                area_=(p['L']-p['R'])*(p['T']-p['B'])
                if best is None or area_<best[0]: best=(area_,pname,p,(pw,ph,pxo,pyo))
    if not best: missing.append((c,z,f,name,'no containing parent (map %d)'%sub['map'])); continue
    _,pname,p,(pw,ph,pxo,pyo)=best
    PW, PH = p['L']-p['R'], p['T']-p['B']
    SW, SH = sub['L']-sub['R'], sub['T']-sub['B']
    out[f] = dict(cont=c, parent=pname, name=name,
        width=pw*SW/PW, height=ph*SH/PH,
        xOffset=pxo+pw*(p['L']-sub['L'])/PW, yOffset=pyo+ph*(p['T']-sub['T'])/PH,
        fx=(p['L']-sub['L'])/PW, fy=(p['T']-sub['T'])/PH, scale=SW/PW)
print('generated', len(out))
for f,v in sorted(out.items(), key=lambda kv:(kv[1]['cont'],kv[0])):
    print('  c%d %-26s <- %-20s frac=(%.4f,%.4f) scale=%.4f' % (v['cont'], f, v['parent'], v['fx'], v['fy'], v['scale']))
print('unresolved', len(missing))
for m in missing: print('  ', m)
json.dump(out, open('coa_maps.json','w'), indent=1)
