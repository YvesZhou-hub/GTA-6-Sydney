#!/usr/bin/env python3
"""Fetch attributed OSM snapshots, then compile meter-space city geometry.

Use tools/map-runtime/bin/python tools/import_city.py --fetch, after installing
shapely. The committed snapshots make subsequent imports offline/reproducible.
No imagery, authentication, OSM contributor accounts or edit history is stored.
"""
import argparse
import json
import time
import math
import re
import urllib.parse
import urllib.request
from pathlib import Path
from city_roofs import add_roof

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'source/map-data'
REGIONS = {'city': (-33.892, 151.195, -33.846, 151.223),
           'north': (-33.848, 151.196, -33.833, 151.233),
           'manly': (-33.806, 151.276, -33.780, 151.301)}
COAST_BOUNDS = (-33.895, 151.18, -33.770, 151.31)
ATTRIBUTION = '© OpenStreetMap contributors · ODbL-1.0'

def fetch(name, query):
    target = DATA / (name + '.json')
    if target.exists():
        return
    failures = []
    for server in ['https://overpass-api.de/api/interpreter',
                   'https://overpass.kumi.systems/api/interpreter']:
        try:
            req = urllib.request.Request(server, data=urllib.parse.urlencode({'data': query}).encode(),
                  headers={'User-Agent': 'Harbourlife/0.1.1 (open-source Sydney game; YvesZhou-hub/harbourlife)'})
            with urllib.request.urlopen(req, timeout=150) as response:
                raw = json.load(response)
            if 'remark' in raw:
                raise RuntimeError(raw['remark'])
            raw['source_endpoint'] = server
            raw['query'] = query
            target.write_text(json.dumps(raw, ensure_ascii=False, separators=(',', ':')))
            print(name, len(raw['elements']), 'elements', target.stat().st_size, 'bytes', flush=True)
            return
        except Exception as exc:
            failures.append(str(exc))
    raise RuntimeError(name + ': ' + '; '.join(failures))

def fetch_all():
    DATA.mkdir(exist_ok=True)
    for name, bounds in REGIONS.items():
        box = ','.join(map(str, bounds))
        query = '[out:json][timeout:120];(' + ''.join(
            f'{kind}[{selector}]({box});' for kind, selector in [
                ('way','building'),('way','"building:part"'),('way','highway'),
                ('way','railway'),('way','"natural"="beach"'),('way','leisure'),
                ('node','shop'),('node','amenity'),('node','railway'),
                ('node','"public_transport"'),('node','tourism')]) + ');out geom;'
        fetch(name, query)
    fetch('coast', '[out:json][timeout:120];way["natural"="coastline"](' +
          ','.join(map(str, COAST_BOUNDS)) + ');out geom;')
    fetch('harbour_water','[out:json][timeout:90];rel(id:1252425,15522136);out geom;')
    fetch('trees','[out:json][timeout:90];('+''.join('node["natural"="tree"]('+','.join(map(str,b))+');' for b in REGIONS.values())+');out;')
    fetch('building_relations','[out:json][timeout:90];('+''.join('rel["building"]["name"]('+','.join(map(str,b))+');' for b in REGIONS.values())+');out geom;')

def project(point):
    return [round((point['lon'] - 151.2105) * 92400, 3),
            round((-33.86 - point['lat']) * 111320, 3)]

def number(value, default=0.0):
    match = re.match(r'^\s*(-?[0-9.]+)', str(value))
    return float(match[1]) if match else default

def annotate_parent_geometry(buildings):
    """Keep explicitly mapped bases only when their height cannot overlap a part.

    A mere 2D parent/part relation is not enough: many mapped podiums have their
    own height while every upper part starts at that height. Unknown/inferred
    dimensions retain the conservative outline-only policy.
    """
    by_id = {b['id']: b for b in buildings}
    for building in buildings:
        ids = building.get('parts', [])
        if not ids:
            continue
        parts = [by_id[key] for key in ids if key in by_id]
        policy = {'mode': 'parts_only', 'reason': 'Parent outline replaced by mapped parts; no explicit non-overlapping base established.'}
        tagged_height = number(building.get('tags', {}).get('height'), -1)
        explicit_parent = (tagged_height > building.get('base', 0)
                           and abs(tagged_height - building['height']) < .001
                           and building.get('height_source') == 'OSM tagged height; not independently surveyed')
        explicit_parts = len(parts) == len(ids) and all(
            'min_height' in part.get('tags', {})
            and abs(number(part['tags']['min_height'], -1) - part['base']) < .001
            for part in parts)
        if explicit_parent and explicit_parts and parts:
            minimum_base = min(part['base'] for part in parts)
            if tagged_height <= minimum_base + .001:
                policy = {'mode': 'preserve_tagged_base',
                          'parent_height_m': tagged_height,
                          'lowest_part_base_m': minimum_base,
                          'reason': 'Explicit OSM height is at or below every mapped part explicit min_height; the parent is a separate lower volume.'}
        building['parent_geometry_policy'] = policy

def compile_map():
    from shapely.geometry import Polygon, LineString, Point, box
    from shapely.ops import polygonize, unary_union
    from shapely import constrained_delaunay_triangles
    from shapely.strtree import STRtree
    out = {'version': 1, 'attribution': ATTRIBUTION,
           'license_url': 'https://opendatacommons.org/licenses/odbl/1-0/',
           'origin': {'lat': -33.86, 'lon': 151.2105, 'meters_per_degree_lon': 92400, 'meters_per_degree_lat': 111320},
           'snapshots': {}, 'buildings': [], 'roads': [], 'places': [], 'beaches': [], 'parks': [], 'trees': [], 'land': [],
           'limits': 'OSM footprints and centerlines; tagged heights or explicitly inferred floor heights. Flat game terrain. Generic unverified facades are not photographic replicas.'}
    seen = set()
    relation_elements=[]
    relation_members=set()
    relation_path=DATA/'building_relations.json'
    if relation_path.exists():
        for el in json.loads(relation_path.read_text())['elements']:
            shapes={}
            for role in ('outer','inner'):
                members=[LineString([project(p) for p in member['geometry']]) for member in el['members']
                         if member.get('role')==role and len(member.get('geometry',[]))>1]
                shapes[role]=unary_union(list(polygonize(unary_union(members))))
            shape=shapes['outer'].difference(shapes['inner'])
            if shape.geom_type=='Polygon':
                relation_elements.append(dict(el,compiled_polygon=shape))
                relation_members.update('way/'+str(m['ref']) for m in el['members'] if m.get('type')=='way')
    for name, bounds in REGIONS.items():
        raw = json.loads((DATA / (name+'.json')).read_text())
        out['snapshots'][name] = raw.get('osm3s', {}).get('timestamp_osm_base')
        for element in raw['elements']+(relation_elements if name=='city' else []):
            key = element['type'] + '/' + str(element['id'])
            if key in seen:
                continue
            seen.add(key)
            if key in relation_members: continue
            tags = element.get('tags', {})
            common = {'id': key, 'region': name, 'tags': tags}
            if element['type'] == 'node':
                if tags.get('name') and any(k in tags for k in ('shop','amenity','railway','public_transport','tourism')):
                    out['places'].append(dict(common, point=project(element)))
                continue
            pts = list(map(list,element['compiled_polygon'].exterior.coords)) if 'compiled_polygon' in element else [project(p) for p in element.get('geometry', [])]
            if len(pts) < 2:
                continue
            if 'building' in tags or 'building:part' in tags:
                if len(pts) < 4 or pts[0] != pts[-1] or tags.get('building') in ('no','construction','ruins'):
                    continue
                poly = element.get('compiled_polygon',Polygon(pts))
                if not poly.is_valid:
                    poly = poly.buffer(0)
                if poly.geom_type != 'Polygon' or poly.area < 8:
                    continue
                center = poly.centroid
                if 'compiled_polygon' in element:
                    lat, lon = -33.86-center.y/111320, 151.2105+center.x/92400
                    common['region']=next((r for r,(s,w,n,e) in REGIONS.items() if s<=lat<=n and w<=lon<=e),name)
                levels = number(tags.get('building:levels'), 0)
                inferred = 'height' not in tags
                kind = tags.get('building', tags.get('building:part', 'yes'))
                height = number(tags.get('height'), levels * (3.65 if kind in ('commercial','office','retail') else 3.15))
                if height <= 0:
                    height = {'house':7.0,'detached':7.0,'terrace':9.0,'apartments':12.0,'garage':3.2,'garages':3.2,'shed':3.0,'church':16.0,'retail':8.0,'commercial':14.0}.get(kind,8.0)
                base = number(tags.get('min_height'), number(tags.get('building:min_level'),0)*3.4)
                if kind=='roof' and not base:
                    if inferred and not levels: height=4.5
                    base=max(0.0,height-0.3)
                # The 40m northern atrium is modelled separately by MetroEntrances.
                if key=='way/1241501338': base=40.0
                if base >= height:
                    continue
                outline = [[round(x-center.x,3),round(y-center.y,3)] for x,y in poly.exterior.coords][:-1]
                roof = []
                for tri in constrained_delaunay_triangles(poly).geoms:
                    roof.extend([[round(x-center.x,3),round(y-center.y,3)] for x,y in list(tri.exterior.coords)[:3]])
                out['buildings'].append(dict(common, center=[round(center.x,3),round(center.y,3)], outline=outline,
                     holes=[[[round(x-center.x,3),round(y-center.y,3)] for x,y in ring.coords][:-1] for ring in poly.interiors],
                     roof=roof, height=round(height,2), base=base,
                     height_source=('OSM tagged estimate' if 'estimat' in (str(tags.get('source:height',''))+' '+str(tags.get('note',''))).lower() else 'OSM tagged height; not independently surveyed') if not inferred else 'OSM levels × assumed floor height' if levels else 'inferred; no height/levels in OSM'))
            elif 'highway' in tags or 'railway' in tags:
                if tags.get('tunnel','no') != 'no' or number(tags.get('layer')) < 0 or tags.get('highway') in ('construction','proposed'):
                    continue
                out['roads'].append(dict(common, points=pts))
            elif len(pts)>3 and pts[0]==pts[-1]:
                if tags.get('natural')=='beach': out['beaches'].append(dict(common, points=pts[:-1]))
                elif tags.get('leisure') in ('park','garden','playground'): out['parks'].append(dict(common, points=pts[:-1]))
    # S3DB: an outline with mapped building:part geometry belongs on the 2D
    # map, but must not become a second solid tower enclosing all its parts.
    parts=[b for b in out['buildings'] if 'building:part' in b['tags']]
    part_shapes=[Polygon([(b['center'][0]+p[0],b['center'][1]+p[1]) for p in b['outline']]) for b in parts]
    tree=STRtree(part_shapes)
    for building in out['buildings']:
        if 'building' not in building['tags'] or 'building:part' in building['tags']: continue
        shape=Polygon([(building['center'][0]+p[0],building['center'][1]+p[1]) for p in building['outline']]).buffer(0)
        contained=[parts[i]['id'] for i in tree.query(shape) if shape.buffer(.4).covers(part_shapes[i].representative_point()) and shape.intersection(part_shapes[i]).area>part_shapes[i].area*.90]
        if contained: building['parts']=contained
    annotate_parent_geometry(out['buildings'])
    for building in out['buildings']: add_roof(building)
    if (DATA/'trees.json').exists():
        out['trees']=[{'id':'node/'+str(e['id']),'point':project(e),'tags':e.get('tags',{})}
                      for e in json.loads((DATA/'trees.json').read_text())['elements']]
    # OSM coastline ways are directed with land on their geographic left.
    # Polygonize the clipped coast with its outer rectangle; retain that side,
    # including islands. This does not draw a false land bridge across the harbour.
    raw = json.loads((DATA/'coast.json').read_text())
    s,w,n,e = COAST_BOUNDS
    low, high = project({'lat':n,'lon':w}), project({'lat':s,'lon':e})
    boundary = box(low[0],low[1],high[0],high[1])
    lines, left_samples = [], []
    for el in raw['elements']:
        pts = [project(p) for p in el['geometry']]
        lines.append(LineString(pts).intersection(boundary))
        for a,b in zip(pts,pts[1:]):
            dx,dz = b[0]-a[0],b[1]-a[1]
            length = math.hypot(dx,dz)
            if length > 1:
                left_samples.append(Point((a[0]+b[0])/2+dz/length*.3,(a[1]+b[1])/2-dx/length*.3))
    polygons = list(polygonize(unary_union(lines+[boundary.boundary])))
    land_shapes = [p for p in polygons if any(p.contains(s) for s in left_samples)]
    land = unary_union(land_shapes)
    # Inside the harbour OSM uses water multipolygons, not natural=coastline.
    water_raw=json.loads((DATA/'harbour_water.json').read_text())
    for relation in water_raw['elements']:
        rings={}
        for role in ('outer','inner'):
            members=[LineString([project(p) for p in m['geometry']]) for m in relation['members']
                     if m.get('role')==role and len(m.get('geometry',[]))>1]
            rings[role]=unary_union(list(polygonize(unary_union(members))))
        water=rings['outer'].difference(rings['inner'])
        land=land.difference(water)
    excavations=json.loads((DATA/'metro_excavations.json').read_text())['holes']
    holes=unary_union([Polygon(h['polygon']) for h in excavations])
    land=land.difference(holes)
    out['excavations']=excavations
    def flat_triangles(shape):
        triangles=[]
        for part in ([shape] if shape.geom_type=='Polygon' else shape.geoms):
            if part.geom_type!='Polygon': continue
            for tri in constrained_delaunay_triangles(part).geoms:
                triangles.extend([[round(x,3),round(y,3)] for x,y in list(tri.exterior.coords)[:3]])
        return triangles
    widths={'motorway':13,'trunk':12,'primary':10.5,'secondary':10,'tertiary':9,'residential':7,'unclassified':7,'service':4,'living_street':5.5,'pedestrian':9,'footway':2,'path':2,'cycleway':2.8,'steps':2}
    for road in out['roads']:
        tags=road['tags']; kind=tags.get('highway')
        if kind not in widths: continue
        width=number(tags.get('width'),widths[kind])
        if 'width' not in tags and number(tags.get('lanes')) and kind in ('primary','secondary','tertiary','trunk','motorway'): width=number(tags['lanes'])*3.15
        surface=LineString(road['points']).buffer(width/2,cap_style=2,join_style=2)
        if surface.intersects(holes): road['surface_triangles']=flat_triangles(surface.difference(holes))
    for area in out['parks']+out['beaches']:
        surface=Polygon(area['points']).buffer(0)
        if surface.intersects(holes): area['surface_triangles']=flat_triangles(surface.difference(holes))
    for polygon in ([land] if land.geom_type=='Polygon' else land.geoms):
        triangles=[]
        for tri in constrained_delaunay_triangles(polygon).geoms:
            triangles.extend([[round(x,3),round(y,3)] for x,y in list(tri.exterior.coords)[:3]])
        out['land'].append({'outline':list(map(list,list(polygon.exterior.coords)[:-1])), 'triangles':triangles})
    # Independently check known land/water anchors before publishing the snapshot.
    for label, lat, lon, expected in [('Opera',-33.8568,151.2153,True),('CBD',-33.873,151.207,True),
             ('Manly Corso',-33.7984,151.2875,True),('Sydney Cove',-33.858,151.212,False),
             ('Harbour shipping channel',-33.856,151.24,False),('Manly ocean',-33.794,151.297,False)]:
        assert land.contains(Point(project({'lat':lat,'lon':lon}))) == expected, label
    out['counts'] = {k:len(out[k]) for k in ['buildings','roads','places','beaches','parks','trees','land']}
    out['counts']['buildings_with_height']=sum(b['height_source'].startswith('OSM tagged') for b in out['buildings'])
    out['counts']['tagged_height_estimates']=sum(b['height_source']=='OSM tagged estimate' for b in out['buildings'])
    out['counts']['parent_outlines_with_parts']=sum(bool(b.get('parts')) for b in out['buildings'])
    out['counts']['tagged_parent_bases_preserved']=sum(b.get('parent_geometry_policy',{}).get('mode')=='preserve_tagged_base' for b in out['buildings'])
    out['counts']['outlines_replaced_by_parts']=out['counts']['parent_outlines_with_parts']-out['counts']['tagged_parent_bases_preserved']
    out['counts']['tagged_pitched_roofs']=sum(bool(b.get('roof_surface')) for b in out['buildings'])
    out['counts']['buildings_with_levels']=sum(b['height_source'].startswith('OSM levels') for b in out['buildings'])
    target=ROOT/'game/assets/city_map.json'
    temporary=target.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(out,ensure_ascii=False,separators=(',',':')))
    temporary.replace(target)
    print('Compiled',out['counts'],target.stat().st_size,'bytes',flush=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fetch', action='store_true')
    args = parser.parse_args()
    if args.fetch:
        fetch_all()
    compile_map()

if __name__ == '__main__':
    main()
