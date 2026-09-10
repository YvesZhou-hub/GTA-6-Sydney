"""Map OSM shop points onto the exterior ground-level wall facing their named lane.

All coordinates are in the game's geographic metre frame; facade widths are
visual estimates (except Matcha-Ya's documented 4.5 m frontage), not a survey.
Run from the repository root after refreshing city_map.json.
"""
import json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
snapshot = json.loads((ROOT / 'game/assets/city_map.json').read_text())
NORTH = [0.356, 0.934]
SOUTH = [-0.356, -0.934]
SHOPS = [
    dict(id='edition', name='Edition Roasters', osm='node/7041091585', width=7.0, facing=[-0.935,0.355], street='Darling Drive / Steam Mill Lane', address='60 Darling Drive', style='edition', directory='edition-coffee-roasters', source='https://editionroasters.com/', photo='https://sydneytales.com/edition-coffee-roasters/', evidence='photo_details', notes='Dark grey panel pier, restrained small lettering, tall glazing and long slatted timber bench. Exterior photo June 2024.'),
    dict(id='matcha', name='Matcha-Ya', osm='node/5783072555', width=4.5, facing=NORTH, street='Steam Mill Lane', address='10 Steam Mill Lane', style='matcha', directory='matchaya', source='https://matchaya.com.au/', photo='https://betterfutureawards.com/syd19/project.asp?ID=18744', evidence='photo_details', notes='Documented 4.5 m facade. Black folding frame, low black awning, left fixed glazing/right entrance, green hexagonal tiles and zigzag interior light.'),
    dict(id='nakano', name='Nakano Darling', osm='node/11271537769', width=6.2, facing=NORTH, street='Steam Mill Lane', address='14 Steam Mill Lane', style='nakano', directory='nakano-darling', source='https://nakanodarling.com.au/contact-us', photo='https://nakanodarling.com.au/about', evidence='photo_details', notes='Dark horizontal roller/slat face, narrow entry, timber bench, hanging warm lanterns. Yellow noren is corroborated by the venue-linked Time Out review.'),
    dict(id='pork_roll', name='Marrickville Pork Roll', osm='node/5783556455', width=3.6, facing=NORTH, street='Steam Mill Lane', address='16 Steam Mill Lane', style='pork_roll', directory='marrickville-pork-roll', source='https://www.darlingharbour.com/eat-drink/marrickville-pork-roll', photo='https://www.kuki.au/', evidence='partial_photo', notes='Neighbour visible at the left of KUKI official 2024 photograph: black brick, small illuminated badge, red interior. Official precinct confirms a small counter and neon tiger; no Illawarra Road awning copied.'),
    dict(id='kuki', name='KUKI', osm='node/13028462508', width=4.6, facing=NORTH, street='Steam Mill Lane', address='9/18 Steam Mill Lane', style='kuki', directory='kuki', source='https://www.kuki.au/', photo='https://incostudio.co/projects/kuki-softserve-and-cookies', evidence='photo_details', notes='Two asymmetric apertures, peach order canopy, square KU/KI blade, cream lightbox, pink stone counter, timber counter base. Yusuke Oba March 2024 photography.'),
    dict(id='kwang', name='Kwang Jang Pocha', osm='node/14053385031', width=7.0, facing=SOUTH, street='Steam Mill Lane', address='Steam Mill Lane', style='kwang', directory='kwang-jang-pocha', source='https://www.darlingsq.com/eat-drink-shop/kwang-jang-pocha/', photo='https://www.darlingsq.com/eat-drink-shop/kwang-jang-pocha/', evidence='photo_details', notes='Official night photo: dark glazed facade, red vertical lettering, cream canopy, colourful plastic stools and flags.'),
    dict(id='wingboy', name='Wingboy', osm='node/14053356762', width=7.2, facing=SOUTH, street='Steam Mill Lane', address='7 Steam Mill Lane', style='wingboy', directory='wingboy', source='https://wingboy.com.au/', photo='https://www.opentable.com.au/r/wingboy-darling-square-haymarket', evidence='photo_details', notes='Merchant listing exterior: dark green vertical wainscot, timber sill, large dark-framed glass, white sign and red neon. Exterior menu board remains beside the door.'),
    dict(id='holy_basil', name='Holy Basil', osm='node/5783581153', width=8.0, facing=SOUTH, street='Steam Mill Lane / Tumbalong Boulevard', address='SW.08, 51 Tumbalong Boulevard', style='holy_basil', directory='holybasil', source='https://holybasil.com.au/darling-square/', photo='https://www.notquitenigella.com/2023/05/23/holy-basil-darling-square/', evidence='partial_photo', notes='Open alfresco shop edge, warm metal trim and purple seating reference the photographed Darling Square venue. Exact street glazing subdivisions are inferred.'),
    dict(id='messina', name='Gelato Messina', osm='node/6901321187', width=10.0, facing=[0.197,-0.980], street='Little Hay Street', address='Shop 02, 3 Little Hay Street', style='messina', directory='gelato-messina', source='https://gelatomessina.com/pages/stores', photo='https://madebytait.com.au/stories/gelato-messina/', evidence='photo_details', notes='Actual Darling Square supplier photography: tall transom with white MESSINA letters, timber ceiling, folding glazed doors, yellow/white striped parasols, white wire chairs and timber planters.'),
    dict(id='kurtosh', name='Kürtősh', osm='node/10689694170', width=5.6, facing=[-0.995,0.100], street='Nicolle Walk', address='Shop 1, 16 Nicolle Walk', style='kurtosh', directory='kurtosh', source='https://kurtosh.com.au/locations/', photo='', evidence='location_verified', notes='Official branch/address and OSM point verified; exterior is an explicitly inferred glazed bakery frontage with timber pastry display and ochre ceramic details. No claim of photographed facade replication.'),
    dict(id='dopa', name='DOPA Donburi', osm='node/9805973142', width=7.8, facing=[-0.197,0.980], street='Little Hay Street', address='Shop 5/6, 2 Little Hay Street', style='dopa', directory='', source='https://www.darlingharbour.com/eat-drink/dopa-by-devon', photo='https://concreteplayground.com/sydney/restaurants/dopa-don-and-milk-bar', evidence='photo_details', notes='Jasper Avenue Darling Square photo: narrow glazed door left, dark bronze divider with vertical gold DOPA lettering, broad right glazing, red tiled counter and pale furniture.'),
    dict(id='shortstop', name='Shortstop Coffee & Donuts', osm='node/7704131106', width=4.2, facing=[0.197,-0.980], street='Little Hay Street', address='15 Little Hay Street', style='shortstop', directory='shortstop-coffee-donuts', source='https://www.short-stop.com.au/', photo='https://www.sydney.com/destinations/sydney/sydney-city/chinatown-and-haymarket/food-and-drink/shortstop-coffee-and-donuts-darling-square', evidence='photo_details', notes='Darling Square tourism image confirms round navy SHORT/STOP projecting blade. Nick De Lorenzo Darling Square 2019 exterior photo confirms narrow left entry, timber jambs and right display, tall transom, blue tables and striped side panels. Approximate width 4.2m; supplied photo showing street number 19 excluded as unproven branch.'),
]

def inside(point, polygon):
    x,y=point; hit=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>y)!=(b[1]>y) and x < (b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]: hit=not hit
    return hit

buildings=[]
for item in snapshot['buildings']:
    cx,cy=item['center']
    if item.get('base',0)>0.5 or not (-950<cx<-600 and 1930<cy<2170): continue
    buildings.append((item['id'],[[cx+x,cy+y] for x,y in item['outline']]))

points={p['id']:p['point'] for p in snapshot['places']}
for shop in SHOPS:
    poi=points[shop['osm']]; candidates=[]
    for ident,poly in buildings:
        for a,b in zip(poly,poly[1:]+poly[:1]):
            dx,dy=b[0]-a[0],b[1]-a[1]; length=math.hypot(dx,dy)
            if length<shop['width']+0.2: continue
            normal=[-dy/length,dx/length]
            midpoint=[(a[0]+b[0])/2,(a[1]+b[1])/2]
            if inside([midpoint[0]+normal[0]*0.1,midpoint[1]+normal[1]*0.1],poly): normal=[-n for n in normal]
            alignment=sum(x*y for x,y in zip(normal,shop['facing']))
            if alignment<0.8: continue
            t=((poi[0]-a[0])*dx+(poi[1]-a[1])*dy)/length**2
            inset=(shop['width']/2+0.1)/length
            t=max(inset,min(1-inset,t))
            p=[a[0]+t*dx,a[1]+t*dy]
            outside=[p[0]+normal[0]*0.4,p[1]+normal[1]*0.4]
            if any(inside(outside,other) for _,other in buildings): continue
            distance=math.dist(p,poi)
            if distance>16: continue
            candidates.append((distance+(1-alignment)*8,p,normal,ident))
    if not candidates: raise RuntimeError(f'No exterior wall found for {shop["id"]}')
    distance,p,normal,ident=min(candidates,key=lambda c:c[0])
    shop.update(poi=poi,front=[round(v,4) for v in p],normal=[round(v,6) for v in normal],building=ident,projection_metres=round(math.dist(p,poi),3))
    print(shop['id'],shop['front'],shop['normal'],shop['projection_metres'],ident)

output={'checked':'2026-09-10','origin':snapshot['origin'],'shops':SHOPS,'scope':'Original game frontage reconstruction; OSM coordinates, photographed details where stated, inferred non-surveyed dimensions. No downloaded photo textures.'}
(ROOT/'game/assets/darling_square_frontages.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
