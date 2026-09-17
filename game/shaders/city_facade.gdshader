shader_type spatial;
global uniform float city_night_amount;
// UVs are measured metres along each actual OSM footprint edge, not a box UV.
uniform vec4 wall_color : source_color = vec4(0.65,0.64,0.60,1.0);
uniform vec4 glass_color : source_color = vec4(0.16,0.25,0.28,1.0);
uniform float glazing = 0.65;
uniform float floor_height = 3.4;
uniform float bay_width = 2.8;
uniform float masonry = 0.0;
uniform float glass_roughness : hint_range(0.0, 1.0) = 0.24;
uniform float glass_metallic : hint_range(0.0, 1.0) = 0.28;
uniform float wall_roughness : hint_range(0.0, 1.0) = 0.84;
// Mapped building heights are measured from their own ground, so UV.y below this
// value is the street-level storey.
uniform float storefront_height = 4.2;
varying float is_roof;
varying flat vec2 facade_identity;
varying flat vec3 facade_normal;
// NIGHT_FUNCTIONS_BEGIN
// Integer arithmetic makes the occupied windows independent of TIME, camera,
// frame rate and material instance IDs. Float output uses exactly 24 hash bits.
uint night_hash(uint value) {
    value ^= value >> 16u;
    value *= 0x7feb352du;
    value ^= value >> 15u;
    value *= 0x846ca68bu;
    return value ^ (value >> 16u);
}
float night_random(vec2 cell_index, float seed, uint stream) {
    uint key = uint(int(seed));
    key ^= uint(int(cell_index.x))*0x9e3779b9u;
    key ^= uint(int(cell_index.y))*0x85ebca6bu;
    return float(night_hash(key ^ stream) & 0x00ffffffu)/16777216.0;
}
float night_density(float usage) {
    return usage < 0.5 ? 0.38 : (usage < 1.5 ? 0.64 : 0.24);
}
float night_warm_fraction(float usage) {
    return usage < 0.5 ? 0.35 : (usage < 1.5 ? 0.85 : 0.60);
}
vec3 night_radiance(vec2 cell_index, float seed, float usage, float pane, float pane_area, float detail_fade, float amount) {
    float density = night_density(usage);
    float floor_density = density+(night_random(vec2(0.0,cell_index.y),seed,101u)-0.5)*0.16;
    float occupied = step(1.0-floor_density,night_random(cell_index,seed,211u));
    float warm_fraction = night_warm_fraction(usage);
    float warm = step(night_random(cell_index,seed,307u),warm_fraction);
    vec3 cool_tint = vec3(0.74,0.84,1.0);
    vec3 warm_tint = vec3(1.0,0.72,0.43);
    vec3 tint = mix(cool_tint,warm_tint,warm);
    float intensity = 0.82+0.36*night_random(cell_index,seed,401u);
    vec3 resolved = tint*intensity*occupied*pane;
    // Average colour and occupancy together: never leave random sub-pixel
    // hash values in the far field or make a whole wall as bright as a pane.
    vec3 averaged = mix(cool_tint,warm_tint,warm_fraction)*density*pane_area;
    return mix(averaged,resolved,clamp(detail_fade,0.0,1.0))*clamp(amount,0.0,1.0)*0.42;
}
// NIGHT_FUNCTIONS_END

// Stable per-building and per-pane variation. Pure arithmetic keyed by the OSM
// identity and facade position, like the night functions above.
float facade_hash(vec2 p) {
    p = fract(p * vec2(0.1031, 0.1030));
    p += dot(p, p.yx + 33.33);
    return fract((p.x + p.y) * p.x);
}
float facade_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(facade_hash(i), facade_hash(i + vec2(1.0, 0.0)), u.x),
               mix(facade_hash(i + vec2(0.0, 1.0)), facade_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
const vec3 SIGN_COLORS[6] = vec3[6](vec3(0.12,0.21,0.18), vec3(0.33,0.13,0.11), vec3(0.12,0.15,0.24), vec3(0.13,0.13,0.14), vec3(0.62,0.58,0.49), vec3(0.42,0.31,0.16));

void vertex() {
    is_roof = abs(NORMAL.y);
    // Every vertex of an OSM extrusion receives the same immutable ID/usage.
    facade_identity = UV2;
    facade_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
    float building = facade_identity.x;
    float residential = step(0.5,facade_identity.y)*(1.0-step(1.5,facade_identity.y));
    float industrial = step(1.5,facade_identity.y);
    float commercial = 1.0-residential-industrial;
    float curtain = step(0.8,glazing);
    float roof_mask = step(0.6,is_roof);
    vec2 grid = UV / vec2(bay_width,floor_height);
    vec2 cell = fract(grid);
    float window = step((1.0-glazing)*0.5,cell.x)*step(cell.x,(1.0+glazing)*0.5)*step(0.18,cell.y)*step(cell.y,0.85);
    float frame = step(0.48,cell.x)*step(cell.x,0.52);
    window *= 1.0-frame;
    // The street-level storey gets shopfronts, a plinth or roller doors instead of the office grid.
    float street = (1.0-step(storefront_height,UV.y))*(1.0-roof_mask);
    window *= 1.0-street;
    float night_window = window;
    vec3 wall=wall_color.rgb;
    // A stable tone per building keeps neighbouring blocks of one style from looking cloned.
    float tone = facade_hash(vec2(building*9973.0, 17.0));
    wall *= 0.9+tone*0.2;
    wall = mix(wall, wall*vec3(1.06,1.0,0.92), step(0.55,facade_hash(vec2(building*7919.0,3.0)))*0.8);
    float mortar=step(0.94,fract(UV.y*3.2))+step(0.965,fract(UV.x*2.2+floor(UV.y*3.2)*0.5));
    wall*=1.0-clamp(mortar,0.0,1.0)*masonry*0.12;
    // High-frequency facade details fade with derivatives, avoiding distant shimmer.
    float fade=1.0-smoothstep(0.12,0.65,length(fwidth(UV)));
    // Floor slabs read as bands on masonry and dark spandrel panels on curtain walls.
    float slab = (1.0-step(0.12,cell.y))*(1.0-street);
    wall = mix(wall, wall*mix(0.9,0.5,curtain), slab*fade*0.85);
    // Sills catch light under each masonry window.
    float sill = step(0.145,cell.y)*step(cell.y,0.18)*step((1.0-glazing)*0.5-0.03,cell.x)*step(cell.x,(1.0+glazing)*0.5+0.03)*(1.0-curtain)*(1.0-street);
    wall *= 1.0+sill*0.16*fade;
    // Weathering: a darker plinth and faint rain streaks.
    float plinth = 1.0-smoothstep(0.0,2.6,UV.y);
    float streaks = facade_noise(vec2(UV.x*1.7, UV.y*0.18+building*40.0));
    wall *= (1.0-plinth*0.18)*(1.0-streaks*0.08*fade*(1.0-curtain));
    window=mix(glazing*0.5,window,fade)*(1.0-step(0.6,is_roof));
    ALBEDO=mix(wall,glass_color.rgb*(0.82+0.18*cell.y),window);
    // Close windows: rooms vary between dark and bright, some panes have blinds,
    // and masonry reveals shade the pane edges.
    vec2 cell_id = floor(grid);
    float pane = facade_hash(cell_id+vec2(building*131.0, building*577.0));
    vec2 inside = vec2((cell.x-(1.0-glazing)*0.5)/max(glazing,0.01), (cell.y-0.18)/0.67);
    float blind = step(0.7,pane)*step(0.75-0.5*fract(pane*13.7),inside.y);
    vec3 pane_color = ALBEDO*(0.7+0.55*fract(pane*7.31));
    pane_color = mix(pane_color, vec3(0.64,0.62,0.57), blind*0.55);
    float edge = min(min(inside.x,1.0-inside.x)*glazing*bay_width, min(inside.y,1.0-inside.y)*0.67*floor_height);
    pane_color *= 1.0-(1.0-smoothstep(0.0,0.16,edge))*0.42*(1.0-curtain);
    float close_window = step(0.5,window)*fade;
    ALBEDO = mix(ALBEDO, pane_color, close_window);
    // Street storey.
    float shop_x = fract(UV.x/4.6);
    float shop_id = floor(UV.x/4.6);
    float shop_glass = step(0.07,shop_x)*step(shop_x,0.93)*step(0.45,UV.y)*step(UV.y,3.2);
    float sign_band = step(3.4,UV.y)*step(UV.y,3.95)*step(0.03,shop_x)*step(shop_x,0.97);
    float shop_seed = facade_hash(vec2(building*311.0, shop_id));
    vec3 sign_color = mix(wall*0.62, SIGN_COLORS[int(floor(fract(shop_seed*17.0)*5.999))], step(0.3,shop_seed));
    // Mullions split each bay; a transom sits above the door height.
    float mullion = 1.0-step(0.03,abs(fract(shop_x*2.0+0.5)-0.5)*0.5*4.6);
    float transom = step(2.55,UV.y)*step(UV.y,2.65);
    float bars = clamp(mullion+transom,0.0,1.0)*shop_glass;
    // Warm shop interiors, brighter towards eye level, vary from shop to shop.
    float lit = 0.35+0.65*fract(shop_seed*5.3);
    vec3 interior = mix(vec3(0.06,0.07,0.07), vec3(0.46,0.40,0.31)*lit, smoothstep(3.1,0.9,UV.y)*0.75);
    interior = mix(interior, glass_color.rgb*0.9, 0.25);
    vec3 shop = mix(wall*0.52, interior, shop_glass);
    shop = mix(shop, vec3(0.1,0.1,0.1), bars*fade);
    // Sign bands carry a faint lettering strip of varying length.
    float lettering = step(3.58,UV.y)*step(UV.y,3.77)*step(0.2+0.2*fract(shop_seed*31.0),shop_x)*step(shop_x,0.8-0.2*fract(shop_seed*47.0));
    shop = mix(shop, sign_color, sign_band);
    shop = mix(shop, mix(sign_color*1.9+0.08, vec3(0.9,0.88,0.82), 0.5), sign_band*lettering*step(0.3,shop_seed)*fade*0.7);
    float door_x = fract(UV.x/8.5);
    vec3 home = mix(wall*0.8, vec3(0.2,0.16,0.13), step(0.42,door_x)*step(door_x,0.56)*step(UV.y,2.3));
    float roller_x = fract(UV.x/6.2);
    float roller = step(0.08,roller_x)*step(roller_x,0.92)*step(UV.y,3.6);
    vec3 works = mix(wall*0.78, vec3(0.5,0.52,0.52)*(0.88+0.12*step(0.5,fract(UV.y*5.0))), roller);
    vec3 street_color = shop*commercial + home*residential + works*industrial;
    ALBEDO = mix(ALBEDO, street_color, street*mix(0.55,1.0,fade));
    // Roofs vary between membrane, gravel and concrete with a little surface noise.
    vec3 roof_color = mix(vec3(0.33,0.36,0.36), vec3(0.47,0.46,0.43), tone);
    roof_color = mix(roof_color, vec3(0.2,0.22,0.23), step(0.72,facade_hash(vec2(building*53.0,9.0))));
    roof_color *= 0.9+0.2*facade_noise(UV*6.0)*fade;
    ALBEDO=mix(ALBEDO,roof_color,roof_mask);
    ROUGHNESS=mix(wall_roughness,glass_roughness*(0.75+0.5*fract(pane*3.1)),window);
    ROUGHNESS=mix(ROUGHNESS,0.16,street*commercial*shop_glass);
    METALLIC=window*glass_metallic+street*commercial*shop_glass*0.22;
    // Glass reflects more sky at grazing angles.
    float fresnel = pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),5.0);
    SPECULAR = 0.5+0.5*fresnel*max(window, street*commercial*shop_glass);
    // The epsilon also gives horizontal roof normals a defined atan(0,+eps).
    float face_index = floor((atan(facade_normal.z,facade_normal.x+0.000001)+PI)*16.0+0.5);
    float seed = floor(facade_identity.x*10000.0+0.5)+face_index*10007.0;
    float night_fade = 1.0-smoothstep(0.08,0.45,length(fwidth(grid)));
    float pane_area = max(glazing-0.04,0.0)*0.67;
    EMISSION = night_radiance(floor(grid),seed,facade_identity.y,night_window,pane_area,night_fade,city_night_amount)*(1.0-step(0.6,is_roof));
    // Most shops stay lit after dark, with their sign bands glowing faintly.
    float shop_open = step(0.45,facade_hash(vec2(building*97.0, shop_id+5.0)));
    float night = clamp(city_night_amount,0.0,1.0);
    float shop_glow = (0.08+0.16*fract(shop_seed*9.1))*smoothstep(3.2,0.6,UV.y)*(1.0-bars);
    EMISSION += (vec3(1.0,0.8,0.56)*shop_glass*shop_open*shop_glow + sign_color*sign_band*0.18)*street*commercial*night*mix(0.35,1.0,fade);
}
