import statistics as st
exec(open('gen.py').read().split("out, missing")[0])
# 1. per (continent, DBC map) linear transform continent = b - a*world, from inlier zones
groups={}
for c,zones in astro.items():
    for name,(w,h,xo,yo) in zones.items():
        for p in dbc.get(name.lower(),[]):
            PW,PH=p['L']-p['R'],p['T']-p['B']
            if PW<=0 or PH<=0: continue
            groups.setdefault((c,p['map']),[]).append(dict(name=name,ax=w/PW,ay=h/PH,bx=xo+(w/PW)*p['L'],by=yo+(h/PH)*p['T'],p=p))
T={}
for k,v in groups.items():
    mbx,mby=st.median(r['bx'] for r in v),st.median(r['by'] for r in v)
    good=[r for r in v if abs(r['bx']-mbx)<=10 and abs(r['by']-mby)<=10 and abs(r['ax']-1)<0.01 and abs(r['ay']-1)<0.01]
    if good:
        T[k]=dict(ax=st.median(r['ax'] for r in good),ay=st.median(r['ay'] for r in good),bx=st.median(r['bx'] for r in good),by=st.median(r['by'] for r in good),zones=good)
def inside(p,x,y): return p['L']>=x>=p['R'] and p['T']>=y>=p['B']
out,missing,notes={},[],[]
for c,z,f,area,name in probe:
    if c>4: continue
    rows=dbc.get(f.lower())
    exact=f in astro.get(c,{})
    if exact: continue
    if not rows: missing.append((c,f,name,'no DBC row')); continue
    s=rows[0]; SW,SH=s['L']-s['R'],s['T']-s['B']
    if SW<=0 or SH<=0: missing.append((c,f,name,'inverted DBC rect')); continue
    cx,cy=(s['L']+s['R'])/2,(s['T']+s['B'])/2
    key=None
    if (c,s['map']) in T and any(inside(r['p'],cx,cy) for r in T[(c,s['map'])]['zones']): key=(c,s['map'])
    else:
        for k,t in T.items():
            if k[0]==c and s['map'] in (0,1) and k[1]==530 and any(inside(r['p'],cx,cy) for r in t['zones']): key=k; notes.append('%s: DBC map %d, placed with map %d (contained)'%(f,s['map'],k[1])); break
        if not key and (c,s['map']) in T: key=(c,s['map']); notes.append('%s: no containing zone, placed with continent map %d transform'%(f,s['map']))
    if not key: missing.append((c,f,name,'map %d not on continent'%s['map'])); continue
    t=T[key]
    out[f.lower()]=dict(c=c,name=name,width=t['ax']*SW,height=t['ay']*SH,xOffset=t['bx']-t['ax']*s['L'],yOffset=t['by']-t['ay']*s['T'])
# compare generated vs existing case-insensitive hand data
for f,v in out.items():
    for n,(w,h,xo,yo) in astro[v['c']].items():
        if n.lower()==f:
            notes.append('%-22s vs existing %-20s dx=%.1f dy=%.1f dw=%.1f dh=%.1f'%(f,n,v['xOffset']-xo,v['yOffset']-yo,v['width']-w,v['height']-h))
print('generated',len(out)); print('\n'.join(notes)); print('unresolved:'); [print('  ',m) for m in missing]
lines=['-- Generated from this client\'s DBFilesClient\WorldMapArea.dbc (patch-M.MPQ) for the Conquest of Azeroth client.',
 '-- Astrolabe zone sizes/offsets for map files the stock data lacks, keyed by lowercased map file name.',
 '-- Only consulted when the client lists a map file that Astrolabe has no entry for.',
 'ZygorAstrolabeCoAZoneData = {']
for c in (1,2,3,4):
    items=sorted((f,v) for f,v in out.items() if v['c']==c)
    if not items: continue
    lines.append('\t[%d] = {'%c)
    for f,v in items:
        lines.append('\t\t["%s"] = { width = %.3f, height = %.3f, xOffset = %.3f, yOffset = %.3f }, -- %s'%(f,v['width'],v['height'],v['xOffset'],v['yOffset'],v['name']))
    lines.append('\t},')
lines.append('}')
open('AstrolabeCoAData.lua','w',newline='\r\n').write('\n'.join(lines)+'\n')
