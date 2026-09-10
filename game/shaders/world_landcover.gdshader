shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.31,0.40,0.28);
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
    ALBEDO=grass*(0.87+turf*0.20+close_noise*0.035);
    ROUGHNESS=0.98;
}
