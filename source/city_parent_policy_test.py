"""Offline importer policy and generated-data consistency; no fetching or saves."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from import_city import annotate_parent_geometry
checks=[]
def check(name,value):
    checks.append({'name':name,'passed':bool(value)})
    print(('PASS ' if value else 'FAIL ')+name)

def fixture(height=18,base=18,explicit_height=True,explicit_base=True,source='OSM tagged height; not independently surveyed'):
    parent={'id':'parent','height':height,'base':0,'parts':['child'],'height_source':source,'tags':{'building':'apartments'}}
    child={'id':'child','height':60,'base':base,'tags':{'building:part':'yes'}}
    if explicit_height:parent['tags']['height']=str(height)
    if explicit_base:child['tags']['min_height']=str(base)
    return [parent,child]
for label,rows,expected in [
    ('tagged podium stops exactly at raised part',fixture(),'preserve_tagged_base'),
    ('tagged lower structure below raised part',fixture(height=12),'preserve_tagged_base'),
    ('overlapping full-height parent remains suppressed',fixture(height=120),'parts_only'),
    ('one ground-level part prevents wholesale base reconstruction',fixture(base=0),'parts_only'),
    ('inferred parent height is never filled blindly',fixture(explicit_height=False),'parts_only'),
    ('inferred child minimum level is not explicit min_height',fixture(explicit_base=False),'parts_only'),
    ('OSM height explicitly marked estimate stays suppressed',fixture(source='OSM tagged estimate'),'parts_only')]:
    annotate_parent_geometry(rows);check(label,rows[0]['parent_geometry_policy']['mode']==expected)
rows=fixture();rows[0]['parts'].append('missing');annotate_parent_geometry(rows)
check('missing part prevents inferred reconstruction',rows[0]['parent_geometry_policy']['mode']=='parts_only')
data=json.loads((ROOT/'game/assets/city_map.json').read_text())
original=copy.deepcopy(data['buildings']);rebuilt=copy.deepcopy(original)
for row in rebuilt:row.pop('parent_geometry_policy',None)
annotate_parent_geometry(rebuilt)
check('all committed parent policies reproduce from source dimensions',original==rebuilt)
parent=next(b for b in original if b['id']=='way/614603732')
check('Darling Square 18 m podium is explicit and retained',parent['height']==18 and parent['base']==0 and parent['parent_geometry_policy']['mode']=='preserve_tagged_base')
kept=[b for b in original if b.get('parent_geometry_policy',{}).get('mode')=='preserve_tagged_base']
check('preserved base count is explicit and agrees with snapshot',len(kept)==21==data['counts']['tagged_parent_bases_preserved'])
check('only overlapping or unestablished parent outlines are suppressed',data['counts']['outlines_replaced_by_parts']==272 and data['counts']['parent_outlines_with_parts']==293)
(ROOT/'reports/city-parent-policy.json').write_text(json.dumps({'passed':all(c['passed'] for c in checks),'checks':checks},indent=2))
raise SystemExit(0 if all(c['passed'] for c in checks) else 1)
