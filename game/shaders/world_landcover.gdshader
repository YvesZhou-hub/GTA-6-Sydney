shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.31,0.40,0.28);
// Built-up ground reads as pavement; open ground stays grass. The mask is
// generated from the mapped building footprints at startup.
uniform sampler2D urban_mask : hint_default_black, filter_linear;
uniform vec4 mask_area = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 pavement_color : source_color = vec3(0.40,0.39,0.37);
varying vec2 ground_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float terrain_noise(vec2 p) {
    vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    vec2 i=floor(p);
    return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
void vertex() { ground_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
    float grove=terrain_noise(ground_position*0.008);
    float turf=terrain_noise(ground_position*0.045);
    float close_noise=terrain_noise(ground_position*1.5);
    vec3 dry_color=vec3(0.31,0.34,0.205);
    vec3 grass=mix(base_color,dry_color,smoothstep(0.45,0.85,grove)*0.34);
    vec3 open_ground=grass*(0.87+turf*0.20+close_noise*0.035);
    vec2 mask_uv=(ground_position-mask_area.xy)/max(mask_area.zw,vec2(1.0));
    float urban=texture(urban_mask,clamp(mask_uv,vec2(0.0),vec2(1.0))).r;
    if (mask_uv.x<0.0||mask_uv.x>1.0||mask_uv.y<0.0||mask_uv.y>1.0) urban=0.0;
    // A noisy edge keeps the change from drawing a straight line across a block.
    urban=smoothstep(0.16,0.60,urban+(close_noise-0.5)*0.14+(turf-0.5)*0.05);
    vec3 pavement=pavement_color*(0.90+close_noise*0.14+turf*0.08);
    ALBEDO=mix(open_ground,pavement,urban);
    ROUGHNESS=mix(0.98,0.90,urban);
}
