shader_type spatial;
global uniform float city_night_amount;
uniform vec4 masonry : source_color = vec4(0.66, 0.52, 0.37, 1.0);
uniform vec4 window_color : source_color = vec4(0.11, 0.22, 0.25, 1.0);
uniform vec2 modules = vec2(3.0, 2.0);
uniform float heritage = 1.0;
uniform float lit_windows = 0.05;
uniform float glass_roughness : hint_range(0.0, 1.0) = 0.20;
uniform float glass_metallic : hint_range(0.0, 1.0) = 0.36;
uniform float wall_roughness : hint_range(0.0, 1.0) = 0.86;
varying float is_roof;

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

void vertex() { is_roof = abs(NORMAL.y); }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    vec2 st = UV * modules;
    vec2 cell = fract(st);
    vec2 ix = floor(st);
    float h = hash(ix);
    float wx = mix(0.09, 0.24, heritage);
    float wy = mix(0.08, 0.18, heritage);
    float glazing = step(wx, cell.x) * step(cell.x, 1.0-wx) * step(wy, cell.y) * step(cell.y, 0.82);
    float frame = step(wx-0.045, cell.x) * step(cell.x, 1.045-wx) * step(wy-0.04, cell.y) * step(cell.y,0.855);
    float mullion = 1.0-step(0.018, abs(cell.x-0.5));
    float transom = 1.0-step(0.015, abs(cell.y-0.52));
    glazing *= 1.0 - max(mullion,transom);
    float night_window = glazing;
    float brick = step(0.96,fract(st.y*8.0)) + step(0.975,fract(st.x*4.0+floor(st.y*8.0)*0.5));
    vec3 stone = masonry.rgb * (0.91 + hash(floor(st * vec2(4.0,8.0))) * 0.10);
    stone *= 1.0 - clamp(brick,0.0,1.0) * 0.11 * heritage;
    stone = mix(stone, masonry.rgb*1.18, frame*0.35);
    vec3 glass = window_color.rgb * (0.65+h*0.6 + cell.y*0.1);
    // Keep the authored close appearance; average sub-pixel details at distance.
    float detail_fade = 1.0-smoothstep(0.08,0.45,length(fwidth(st)));
    float pane_area = max(1.0-2.0*wx-0.036,0.0)*max(0.82-wy-0.030,0.0);
    ALBEDO = mix(mix(masonry.rgb*0.99,window_color.rgb, pane_area),mix(stone,glass,glazing),detail_fade);
    glazing = mix(pane_area,glazing,detail_fade);
    ROUGHNESS = mix(wall_roughness,glass_roughness,glazing);
    METALLIC = glazing * glass_metallic;
    // Legacy box facades have no OSM ID UV2. This style/module seed survives
    // batching unchanged; identical legacy materials intentionally repeat.
    float seed = floor(dot(masonry.rgb,vec3(997.0,619.0,283.0))*100.0)+floor(modules.x)*197.0+floor(modules.y)*389.0;
    float usage = mix(0.0,2.0,step(0.5,heritage));
    // Default .05 is neutral; legacy values may dim, never amplify the glass.
    EMISSION = night_radiance(floor(st),seed,usage,night_window,pane_area,detail_fade,city_night_amount)*clamp(lit_windows/0.05,0.0,1.0)*(1.0-step(0.6,is_roof));
}
