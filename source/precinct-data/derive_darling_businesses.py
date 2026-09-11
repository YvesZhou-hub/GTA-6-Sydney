"""Reproduce the directory audit without inventing unmapped shop doors.

The official directory is retained verbatim. Current operator addresses override
conflicting directory cards, and every facade is projected from its OSM POI to
an actual ground-level exterior wall. Widths are conservative visual estimates.
"""
import json, math, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
directory=json.loads((ROOT/'game/assets/darling_precinct_directory.json').read_text())
city=json.loads((ROOT/'game/assets/city_map.json').read_text())
points={p['id']:p for p in city['places']}
old=json.loads((ROOT/'game/assets/darling_square_frontages.json').read_text())['shops']
existing={p['osm']:p['id'] for p in old}
existing.update({'node/10590131122':'auvers','node/9480685417':'hakatamon','node/11834192053':'chinta_ria'})
# Official directory row -> mapped branch. No city-wide fuzzy name matching.
rows={1:5783556454,2:10590131122,3:14053356759,5:12588832181,6:10689672744,9:13475274201,12:11834192053,15:7030232362,18:9805973142,19:6539605558,20:7041091585,21:10590136180,24:12528689300,25:13459500701,26:9480685417,27:12117849338,29:5783581153,33:13028462508,34:10689694170,35:14053385031,37:13483075684,38:6901321285,39:9642576281,40:10689683738,41:5783556455,42:5783072555,43:12588832180,44:13475270001,45:6901321187,47:11824294647,48:10689683737,49:11271537769,50:10590350430,51:13483086755,52:14053356760,53:14053356761,54:7704131106,56:7030291185,58:10689677826,59:12528689299,61:10689688741,62:13028462510,63:10689677631,64:13389834403,66:14053387656,67:10869993140,68:14053356762}
exchange={0,4,9,14,15,21,24,25,30,55,59,62,64,67,69}
corrections={
 29:('SW08, 51 Tumbalong Boulevard','https://holybasil.com.au/darling-square/'),
 37:('6 Steam Mill Lane','https://www.darlingsq.com/eat-drink-shop/lermont-laser-clinic/'),
 38:('Shop 2/4 Steam Mill Lane','https://lillianna.com.au/pages/contact-us'),
 66:('3/35 Tumbalong Boulevard','https://www.darlingharbour.com/offers/dine-sip-save-20-at-uliveto'),
 52:('NW01/2 Steam Mill Lane','https://puppuccino.com.au/locate-us'),
}
# Desired street-facing normals, not arbitrary nearest indoor partitions.
N=(.356,.934); S=(-.356,-.934); E=(.94,-.34); W=(-.994,.115)
config={
1:(E,7.0,'dining','red'),3:(S,4.8,'bar','green'),5:((.99,-.1),5.3,'bank','red'),6:((.978,.21),5.0,'bakery','cream'),
19:(N,4.3,'dining','red'),27:((.99,-.1),6.5,'cafe','cream'),37:(N,4.0,'clinic','white'),38:(N,3.9,'gifts','cream'),
39:((.212,-.977),6.1,'dining','red'),40:((-.994,.11),4.6,'tea','cream'),43:((-.2,-.98),6.7,'counter','gold'),44:((-.2,-.98),6.7,'dessert','ochre'),
47:((-.94,.34),5.2,'clinic','blue'),48:((.212,-.977),4.6,'optics','cream'),50:(E,8.0,'dining','ochre'),
51:(N,4.2,'toys','peach'),52:(N,3.1,'pet','cream'),53:(S,4.4,'convenience','blue'),56:(W,7.5,'cafe','green'),
58:((-.194,.981),5.6,'dining','coal'),61:((.212,-.977),4.5,'tea','green'),63:((-.194,.981),4.5,'tattoo','coal'),66:(E,7.0,'cafe','green')}

def inside(p,poly):
 hit=False
 for a,b in zip(poly,poly[1:]+poly[:1]):
  if (a[1]>p[1])!=(b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]:hit=not hit
 return hit
buildings=[]
for b in city['buildings']:
 x,z=b['center']
 if b.get('base',0)>.5 or not(-950<x<-600 and 1930<z<2180):continue
 buildings.append((b['id'],[[x+dx,z+dz] for dx,dz in b['outline']]))
def project(p,width,facing):
 candidates=[]
 for ident,poly in buildings:
  if ident=='way/614603737':continue
  for a,b in zip(poly,poly[1:]+poly[:1]):
   dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz)
   if length<width+.2:continue
   normal=[-dz/length,dx/length];middle=[(a[0]+b[0])/2,(a[1]+b[1])/2]
   if inside([middle[0]+normal[0]*.1,middle[1]+normal[1]*.1],poly):normal=[-v for v in normal]
   align=sum(a*b for a,b in zip(normal,facing))
   if align<.75:continue
   t=((p[0]-a[0])*dx+(p[1]-a[1])*dz)/length**2;inset=(width/2+.1)/length
   t=max(inset,min(1-inset,t));front=[a[0]+t*dx,a[1]+t*dz]
   outside=[front[0]+normal[0]*.6,front[1]+normal[1]*.6]
   if any(inside(outside,other) for _,other in buildings):continue
   distance=math.dist(p,front)
   if distance>18:continue
   candidates.append((distance+(1-align)*8,front,normal,ident,distance))
 if not candidates:return None
 _,front,normal,ident,distance=min(candidates,key=lambda c:c[0])
 return {'front':[round(v,4) for v in front],'normal':[round(v,6) for v in normal],'building':ident,'projection_metres':round(distance,3),'width':width}

shops=[];counts={};occupied=[]
for row,t in enumerate(directory['tenants']):
 slug=t['source'].rstrip('/').rsplit('/',1)[1]
 t['id']='darling_business_'+re.sub('[^a-z0-9]+','_',slug.lower()).strip('_')
 t['verified_scope']='Official directory entry; tenant listing does not by itself verify a precise shopfront or current occupation.'
 t['model_status']='directory_only_unresolved'
 t['location_precision']='unresolved; no fabricated exact destination'
 if row in corrections:
  t['corrected_address'],t['address_source']=corrections[row]
  t['address_note']='Operator or detailed precinct text distinguishes this branch from the conflicting directory card.'
 if row in rows:
  osm='node/'+str(rows[row]);p=points[osm]
  t['osm']=osm;t['mapped_point']=p['point'];t['osm_name']=p['tags']['name']
  if osm in existing:
   t['model_status']='existing_researched_frontage';t['model_id']=existing[osm];t['location_precision']='OSM point projected to documented street wall; see frontage references'
  elif row not in exchange:
   facing,width,style,accent=config[row]
   projection=project(p['point'],width,facing)
   if projection:
    r={**projection,'id':t['id'],'name':t['name'],'osm':osm,'poi':p['point'],'style':style,'accent':accent,'source':t['source'],'evidence':'Official precinct tenant name and OSM branch point projected to mapped exterior. Frame, display, widths and furnishing are explicitly inferred; not a photo-identical shop survey.','confidence':'Mapped street wall with inferred retail frontage','address':t.get('corrected_address',t['listed_address'])}
    shops.append(r);t['model_status']='mapped_inferred_frontage';t['location_precision']='mapped OSM branch and exterior wall; facade fittings inferred';t['frontage']=projection
   else:t['model_status']='mapped_point_only';t['location_precision']='OSM point; exterior arrival not yet proven'
 if row in exchange:
  t['model_status']='exchange_building_directory';t['location_precision']='Shared Exchange public forecourt; indoor stall/level is not a street door'
  t['building']='way/614603737'
  if row==69:
   t['model_status']='directory_conflict_unresolved';t['location_precision']='Directory retains XOPP; current Haidilao listing also present. No exact current shop assertion.'
  elif row==14:t['level']='3 (directory)'
  elif row==25:t['level']='5 (directory and OSM)'
  elif row==15:t['level']='1–2 (library operator)'
  else:t['level']='ground food hall or building only; exact counter not reconstructed'
 counts[t['model_status']]=counts.get(t['model_status'],0)+1

# Conservative front widths must not cover a retained shop's front plane.
allfronts=old+shops
for a in shops:
 overlaps=[]
 for b in allfronts:
  if a is b or a.get('building')!=b.get('building'):continue
  if sum(x*y for x,y in zip(a['normal'],b['normal']))<.99:continue
  d=math.dist(a['front'],b['front'])
  if d<(a['width']+b['width'])/2+.12:overlaps.append((b,d))
 for b,d in overlaps:
  cap=max(1.5,2*(d-.18)-b['width'])
  a['width']=min(a['width'],cap)
  next(t for t in directory['tenants'] if t['id']==a['id'])['frontage']['width']=a['width']
directory['audit_checked']='2026-09-11'
photo_details={
 'darling_business_bar_bubu':('open bar visible from street','https://www.darlingsq.com/eat-drink-shop/bar-bubu/','2025 Kera Wong photograph: yellow fluted counter, red high stools, open black lift-up glazing, cubby bottle shelving and gallery wall.'),
 'darling_business_bendigo_bank':('completed branch exterior','https://www.jodiedangarchitects.com/bendigo-bank','Dark brick plinth, curved bronze-framed glass, seven upper louvers, vertical sign and right-hand door; facade length remains an OSM-based approximation.'),
 'darling_business_thirteen_feet_tattoo':('branch exterior; supplier photograph','https://online.remondis.com.au/article/industries/simplifying-waste-management-for-tattoo-parlours/3v14nmy','Black brick, gold fascia, left-hand door, right window neon, framed flash sheets and projecting sign; abstract flash graphics are original, not copied tattoo art.'),
 'darling_business_puppuccino_pet_spa':('interior display only; exterior remains inferred','https://puppuccino.com.au/locate-us','Darling Square-labeled operator photograph: yellow/white striped partition, dark shelves, timber base and pet products. Does not establish the exterior sign or door layout.'),
 'darling_business_lillianna_gifts_and_home':('interior display only; exterior remains inferred','https://www.darlingsq.com/eat-drink-shop/lillianna-gifts-and-home/','Official banner photograph shows colour-grouped gift boxes, diffuser bottles and white shelves; does not establish exterior frame or sign.'),
}
for shop in shops:
 if shop['id'] in photo_details:
  scope,source,note=photo_details[shop['id']]
  shop.update(photo_scope=scope,photo_source=source,photo_notes=note)
  t=next(t for t in directory['tenants'] if t['id']==shop['id'])
  t.update(photo_scope=scope,photo_source=source,photo_notes=note)
directory['coverage_counts']=counts
directory['photo_detail_counts']={'new_exterior_or_open_bar':3,'new_interior_display_only':2,'other_new_inferred_frontages':18}
directory['scope_notice']='All 71 official cards retained and individually classified. Street-front reconstruction is selective; no claim of all stores being exact or accessible indoors. Food-hall and upper-level tenants use building-level arrivals. Unresolved records have no invented door.'
(ROOT/'game/assets/darling_precinct_directory.json').write_text(json.dumps(directory,ensure_ascii=False,indent=2)+'\n')
(ROOT/'game/assets/darling_precinct_frontages.json').write_text(json.dumps({'checked':'2026-09-11','scope':'Additional OSM-located, explicitly inferred frontages; original geometry and labels only.','shops':shops},ensure_ascii=False,indent=2)+'\n')
print('Coverage',counts,'new frontages',len(shops))
for s in shops:print(s['name'],s['front'],s['normal'],s['width'],s['building'])
