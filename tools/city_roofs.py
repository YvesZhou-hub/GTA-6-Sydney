"""Roof profiles from explicit OSM shape tags; slopes remain labelled estimates."""
import math
from shapely.geometry import Polygon, LineString
from shapely.affinity import affine_transform
from shapely.ops import split
from shapely import constrained_delaunay_triangles

def add_roof(building):
    tags=building['tags']; kind=tags.get('roof:shape','flat')
    if kind not in ('gabled','hipped','pyramidal','skillion') or building.get('parts'): return
    polygon=Polygon(building['outline'],building['holes'])
    corners=list(polygon.minimum_rotated_rectangle.exterior.coords)[:4]
    edges=[(corners[(i+1)%4][0]-p[0],corners[(i+1)%4][1]-p[1]) for i,p in enumerate(corners)]
    dx,dz=max(edges,key=lambda p:math.hypot(*p)); length=math.hypot(dx,dz)
    ux,uz=dx/length,dz/length
    if tags.get('roof:orientation')=='across': ux,uz=-uz,ux
    cx,cz=polygon.minimum_rotated_rectangle.centroid.coords[0]
    local=affine_transform(polygon,[ux,uz,-uz,ux,-cx*ux-cz*uz,cx*uz-cz*ux])
    lo_u,lo_v,hi_u,hi_v=local.bounds
    hl,hw=(hi_u-lo_u)/2,(hi_v-lo_v)/2
    if min(hl,hw)<.6: return
    try: rise=float(str(tags.get('roof:height','')).removesuffix('m').strip()); measured=True
    except ValueError: rise=min(4.0,max(1.2,hw*.45)); measured=False
    rise=min(rise,(building['height']-building['base'])*.40)
    if rise<.3:return
    if 'height' not in tags and tags.get('building:levels'):
        building['height']=round(building['height']+rise,4)
        building['height_source']+=' + '+('tagged' if measured else 'assumed')+' roof rise'
    top=building['height']; base=top-rise
    def elevation(u,v):
        if kind=='gabled': factor=1-abs(v)/hw
        elif kind=='hipped': factor=min((hw-abs(v))/min(hl,hw),(hl-abs(u))/min(hl,hw))
        elif kind=='pyramidal': factor=min(1-abs(v)/hw,1-abs(u)/hl)
        else: factor=(v+hw)/(2*hw)
        return base+rise*max(0,min(1,factor))
    bound=max(hl,hw)*5
    cuts=[]
    if kind in ('gabled','hipped'):cuts.append(LineString([(-bound,0),(bound,0)]))
    if kind=='hipped':
        for slope in (-1,1):
            # Adjacent hip planes meet where |u|-|v| = hl-hw. Cutting at
            # +/-hl omitted both ridge endpoints and flattened rectangular roofs.
            for intercept in (hw-hl,hl-hw):cuts.append(LineString([(-bound,slope*-bound+intercept),(bound,slope*bound+intercept)]))
    if kind=='pyramidal':
        for side in (-1,1):cuts.append(LineString([(-hl*3,-hw*3*side),(hl*3,hw*3*side)]))
    pieces=[local]
    for cut in cuts:
        pieces=[p for part in pieces for p in split(part,cut).geoms if p.geom_type=='Polygon' and p.area>1e-8]
    def vertex(u,v,y=None):return [round(cx+ux*u-uz*v,4),round(elevation(u,v) if y is None else y,4),round(cz+uz*u+ux*v,4)]
    roof=[]
    for piece in pieces:
        for triangle in constrained_delaunay_triangles(piece).geoms:
            roof.extend(vertex(u,v) for u,v in list(triangle.exterior.coords)[:3])
        for ring in [piece.exterior,*piece.interiors]:
            coordinates=list(ring.coords)
            for a,b in zip(coordinates,coordinates[1:]):
                if local.boundary.buffer(.00001).covers(LineString([a,b])):
                    va,vb,ba,bb=vertex(*a),vertex(*b),vertex(*a,y=base),vertex(*b,y=base)
                    if max(va[1],vb[1])-base>.01:roof.extend([ba,bb,vb,ba,vb,va])
    clean=[]
    for i in range(0,len(roof),3):
        a,b,c=roof[i:i+3];u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
        cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        if sum(n*n for n in cross)>1e-10:clean.extend([a,b,c])
    building.update(wall_height=round(base,4),roof_surface=clean,
                    roof_profile_source='OSM roof shape; '+('tagged roof rise' if measured else 'rise and slope estimated from footprint'))
