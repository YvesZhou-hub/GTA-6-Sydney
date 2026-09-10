shader_type spatial;
uniform vec4 masonry : source_color = vec4(0.66, 0.52, 0.37, 1.0);
uniform vec4 window_color : source_color = vec4(0.11, 0.22, 0.25, 1.0);
uniform vec2 modules = vec2(3.0, 2.0);
uniform float heritage = 1.0;
uniform float lit_windows = 0.05;

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
    float brick = step(0.96,fract(st.y*8.0)) + step(0.975,fract(st.x*4.0+floor(st.y*8.0)*0.5));
    vec3 stone = masonry.rgb * (0.91 + hash(floor(st * vec2(4.0,8.0))) * 0.10);
    stone *= 1.0 - clamp(brick,0.0,1.0) * 0.11 * heritage;
    stone = mix(stone, masonry.rgb*1.18, frame*0.35);
    vec3 glass = window_color.rgb * (0.65+h*0.6 + cell.y*0.1);
    ALBEDO = mix(stone,glass,glazing);
    ROUGHNESS = mix(0.86,0.2,glazing);
    METALLIC = glazing * 0.36;
    float lit = step(0.79,h)*lit_windows;
    EMISSION = vec3(1.0,0.67,0.34) * glazing * lit;
}
