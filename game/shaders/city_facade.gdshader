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

void vertex() {
    is_roof = abs(NORMAL.y);
    // Every vertex of an OSM extrusion receives the same immutable ID/usage.
    facade_identity = UV2;
    facade_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
    vec2 grid = UV / vec2(bay_width,floor_height);
    vec2 cell = fract(grid);
    float window = step((1.0-glazing)*0.5,cell.x)*step(cell.x,(1.0+glazing)*0.5)*step(0.18,cell.y)*step(cell.y,0.85);
    float frame = step(0.48,cell.x)*step(cell.x,0.52);
    window *= 1.0-frame;
    float night_window = window;
    vec3 wall=wall_color.rgb;
    float mortar=step(0.94,fract(UV.y*3.2))+step(0.965,fract(UV.x*2.2+floor(UV.y*3.2)*0.5));
    wall*=1.0-clamp(mortar,0.0,1.0)*masonry*0.12;
    // High-frequency facade details fade with derivatives, avoiding distant shimmer.
    float fade=1.0-smoothstep(0.12,0.65,length(fwidth(UV)));
    window=mix(glazing*0.5,window,fade)*(1.0-step(0.6,is_roof));
    ALBEDO=mix(wall,glass_color.rgb*(0.82+0.18*cell.y),window);
    ALBEDO=mix(ALBEDO,vec3(0.33,0.36,0.36),step(0.6,is_roof));
    ROUGHNESS=mix(wall_roughness,glass_roughness,window);
    METALLIC=window*glass_metallic;
    // The epsilon also gives horizontal roof normals a defined atan(0,+eps).
    float face_index = floor((atan(facade_normal.z,facade_normal.x+0.000001)+PI)*16.0+0.5);
    float seed = floor(facade_identity.x*10000.0+0.5)+face_index*10007.0;
    float night_fade = 1.0-smoothstep(0.08,0.45,length(fwidth(grid)));
    float pane_area = max(glazing-0.04,0.0)*0.67;
    EMISSION = night_radiance(floor(grid),seed,facade_identity.y,night_window,pane_area,night_fade,city_night_amount)*(1.0-step(0.6,is_roof));
}
