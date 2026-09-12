shader_type spatial;
render_mode cull_disabled;

// Opaque dielectric water keeps the depth buffer and Forward+ SSR path.
// Sky/environment reflection supplies the off-screen fallback. No copied maps.
uniform vec3 deep_color : source_color = vec3(0.018, 0.145, 0.18);
uniform vec3 crest_color : source_color = vec3(0.075, 0.31, 0.33);
uniform float wave_scale : hint_range(0.0, 2.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.6;
uniform float ripple_strength : hint_range(0.0, 0.3) = 0.095;
uniform float base_roughness : hint_range(0.06, 0.45) = 0.19;
uniform float specular_strength : hint_range(0.2, 0.6) = 0.35;
uniform float tint_variation : hint_range(0.0, 0.3) = 0.12;
uniform float time_override = -1.0; // A/B only; -1 uses live TIME.
uniform vec4 dry_rect_a = vec4(0.0);
uniform vec4 dry_rect_b = vec4(0.0);
varying vec3 world_pos;
varying float camera_distance;

float clock_time() { return time_override >= 0.0 ? time_override : TIME; }

float hash_wave(vec2 p) {
    vec3 q=fract(vec3(p.xyx)*0.1031);
    q+=dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}

// Analytic derivatives of continuous quintic value noise. Unlike long sine
// trains, these gradients have no repeating parallel specular bands.
vec3 wave_noise(vec2 p) {
    vec2 cell=floor(p), f=fract(p);
    vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
    vec2 du=30.0*f*f*(f*(f-2.0)+1.0);
    float a=hash_wave(cell),b=hash_wave(cell+vec2(1,0));
    float c=hash_wave(cell+vec2(0,1)),d=hash_wave(cell+vec2(1,1));
    float k=a-b-c+d;
    return vec3(a+(b-a)*u.x+(c-a)*u.y+k*u.x*u.y,
        du.x*((b-a)+k*u.y),du.y*((c-a)+k*u.x));
}

vec2 broad_gradient(vec2 p, float t) {
    return cos(dot(p, vec2(0.073, 0.102)) + t * 0.94) * vec2(0.073, 0.102) * 0.27
         + cos(dot(p, vec2(-0.155, 0.098)) + t * 1.32) * vec2(-0.155, 0.098) * 0.13
         + cos(dot(p, vec2(0.312, 0.179)) + t * 1.83) * vec2(0.312, 0.179) * 0.055;
}

void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float t = clock_time();
    float a = dot(p.xz, vec2(0.073, 0.102)) + t * 0.94;
    float b = dot(p.xz, vec2(-0.155, 0.098)) + t * 1.32;
    float c = dot(p.xz, vec2(0.312, 0.179)) + t * 1.83;
    // Existing wave heights and world-space phase at tile seams are unchanged.
    VERTEX.y += wave_scale * (sin(a) * 0.27 + sin(b) * 0.13 + sin(c) * 0.055);
    vec2 grad = broad_gradient(p.xz,t) * wave_scale;
    NORMAL = normalize(vec3(-grad.x,1.0,-grad.y));
    world_pos = p;
    camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
    vec2 p = world_pos.xz;
    if ((p.x > dry_rect_a.x && p.y > dry_rect_a.y && p.x < dry_rect_a.z && p.y < dry_rect_a.w) ||
        (p.x > dry_rect_b.x && p.y > dry_rect_b.y && p.x < dry_rect_b.z && p.y < dry_rect_b.w)) { discard; }
    float t = clock_time();
    float broad_weight = 1.0 - smoothstep(350.0,3200.0,camera_distance);
    float detail_weight = 1.0 - smoothstep(45.0,420.0,camera_distance);
    mat2 rotate_b=mat2(vec2(0.6,0.8),vec2(-0.8,0.6));
    mat2 rotate_c=mat2(vec2(-0.8,0.6),vec2(-0.6,-0.8));
    vec2 a=p*0.75+vec2(t*0.28,-t*0.19);
    vec2 b=rotate_b*p*1.7+vec2(-t*0.22,t*0.35)+vec2(17.2,3.8);
    vec2 c=rotate_c*p*3.4+vec2(t*0.31,t*0.13)+vec2(41.6,29.3);
    // Band-limit each octave by its projected pixel footprint.
    float fa=1.0-smoothstep(0.3,1.3,length(fwidth(a)));
    float fb=1.0-smoothstep(0.3,1.3,length(fwidth(b)));
    float fc=1.0-smoothstep(0.3,1.3,length(fwidth(c)));
    vec2 ripples=wave_noise(a).yz*0.48*fa;
    ripples+=transpose(rotate_b)*wave_noise(b).yz*0.32*fb;
    ripples+=transpose(rotate_c)*wave_noise(c).yz*0.20*fc;
    vec2 grad = broad_gradient(p,t) * wave_scale * broad_weight * normal_strength;
    grad += ripples * ripple_strength * detail_weight;
    vec3 world_normal = normalize(vec3(-grad.x,1.0,-grad.y));
    NORMAL = normalize((VIEW_MATRIX * vec4(world_normal,0.0)).xyz);
    float crest = wave_noise(p*0.055+vec2(t*.015,-t*.02)).x;
    ALBEDO = mix(deep_color,crest_color,tint_variation * crest * broad_weight);
    ROUGHNESS = clamp(base_roughness + (1.0-detail_weight)*0.09 + length(grad)*0.08,0.06,0.5);
    METALLIC = 0.0;
    SPECULAR = specular_strength;
}
