#!/usr/bin/env python3
"""Validate compiled map geometry against real geographic fixtures and raw ways."""
import json
from pathlib import Path
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union

root=Path(__file__).resolve().parents[1]
data=json.loads((root/'game/assets/city_map.json').read_text())
checks=[]
def check(name, okay, detail=''):
    checks.append(dict(name=name,passed=bool(okay),detail=detail))
    print(('PASS ' if okay else 'FAIL ')+name, detail)
def project(lat,lon): return ((lon-151.2105)*92400,(-33.86-lat)*111320)
def triangles(points): return [Polygon(points[i:i+3]) for i in range(0,len(points),3)]

bad=[]
for b in data['buildings']:
    polygon=Polygon(b['outline'],b['holes'])
    roof=triangles(b['roof'])
    area=sum(t.area for t in roof)
    if not polygon.is_valid or any(t.area<1e-8 for t in roof) or abs(area-polygon.area)>max(.10,polygon.area*.0001): bad.append(b['id'])
check('all building roof triangulations preserve footprint and courtyard area',not bad,str(bad[:10]))
check('positive building vertical extent',all(b['height']>b['base'] for b in data['buildings']))
bad_roofs=[]
for b in data['buildings']:
    if 'roof_surface' not in b:continue
    surface=b['roof_surface']; projected=sum(Polygon([(p[0],p[2]) for p in surface[i:i+3]]).area for i in range(0,len(surface),3))
    area=Polygon(b['outline'],b['holes']).area
    if abs(projected-area)>max(.05,area*.0001) or any(p[1]<b['wall_height']-.001 or p[1]>b['height']+.001 for p in surface):bad_roofs.append(b['id'])
check('tagged pitched roofs preserve footprint holes and height envelope',not bad_roofs,str(bad_roofs[:10]))
flat_profiles=[b['id'] for b in data['buildings'] if b.get('roof_surface') and max(p[1] for p in b['roof_surface'])-min(p[1] for p in b['roof_surface'])<.02]
check('pitched roof triangulations retain visible ridge rise',not flat_profiles,str(flat_profiles[:10]))
check('all heights have confidence labels',all(b.get('height_source') for b in data['buildings']))
check('OSM estimated heights are never labelled surveyed',all('surveyed' not in b['height_source'] or 'not independently' in b['height_source'] for b in data['buildings']))
lookup={b['id']:b for b in data['buildings']}
check('Gateway outline does not duplicate its mapped tower parts',bool(lookup['way/335687879'].get('parts')))
check('Martin Place atrium clears the street',lookup['way/1241501338']['base']==40)
land=unary_union([tri for piece in data['land'] for tri in triangles(piece['triangles'])])
for name,lat,lon,is_land in [('Opera forecourt',-33.8568,151.2153,True),('CBD',-33.873,151.207,True),('Manly Corso',-33.7984,151.2875,True),('Sydney Cove',-33.858,151.212,False),('Harbour shipping channel',-33.856,151.24,False),('Manly Pacific beach water',-33.794,151.297,False)]:
    check(name+' land/water classification',land.covers(Point(project(lat,lon)))==is_land)
source_holes=json.loads((root/'source/map-data/metro_excavations.json').read_text())['holes']
check('metro excavation snapshot matches source',data['excavations']==source_holes)
for hole in data['excavations']:
    polygon=Polygon(hole['polygon']).buffer(-.02)
    check(hole['id']+' ground and road paving do not cover excavation',land.intersection(polygon).area<.001 and all(sum(t.intersection(polygon).area for t in triangles(r['surface_triangles']))<.001 for r in data['roads'] if 'surface_triangles' in r))
raw={str(e['id']):e for region in ('city','north','manly') for e in json.loads((root/'source/map-data'/f'{region}.json').read_text())['elements'] if e['type']=='way'}
for key in ('way/191626163','way/183246899','way/1116329930'):
    b=lookup[key]; mapped=Polygon([(b['center'][0]+p[0],b['center'][1]+p[1]) for p in b['outline']]); original=Polygon([project(p['lat'],p['lon']) for p in raw[key.split('/')[1]]['geometry']])
    check(key+' footprint agrees with source',mapped.hausdorff_distance(original)<.003)
check('underground routes are not painted on the ground',all(r['tags'].get('tunnel','no')=='no' and float(r['tags'].get('layer',0))>=0 for r in data['roads']))
report={'checks':checks,'counts':data['counts'],'snapshots':data['snapshots'],'passed':all(c['passed'] for c in checks)}
(root/'reports/city-data.json').write_text(json.dumps(report,indent=2))
raise SystemExit(0 if report['passed'] else 1)
