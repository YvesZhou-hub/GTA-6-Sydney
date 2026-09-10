shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep_color : source_color = vec3(0.016, 0.145, 0.18);
uniform vec3 crest_color : source_color = vec3(0.10, 0.40, 0.43);
uniform float wave_scale = 1.0;
uniform vec4 dry_rect_a = vec4(0.0);
uniform vec4 dry_rect_b = vec4(0.0);
varying vec3 world_pos;
varying vec3 wave_normal;
varying float camera_distance;

void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float a = dot(p.xz, vec2(0.073, 0.102)) + TIME * 0.94;
    float b = dot(p.xz, vec2(-0.155, 0.098)) + TIME * 1.32;
    float c = dot(p.xz, vec2(0.312, 0.179)) + TIME * 1.83;
    VERTEX.y += wave_scale * (sin(a) * 0.27 + sin(b) * 0.13 + sin(c) * 0.055);
    vec2 grad = cos(a) * vec2(0.073, 0.102) * 0.27;
    grad += cos(b) * vec2(-0.155, 0.098) * 0.13;
    grad += cos(c) * vec2(0.312, 0.179) * 0.055;
    NORMAL = normalize(vec3(-grad.x * wave_scale, 1.0, -grad.y * wave_scale));
    world_pos = p;
    wave_normal = NORMAL;
    camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
    vec2 p = world_pos.xz;
    if ((p.x > dry_rect_a.x && p.y > dry_rect_a.y && p.x < dry_rect_a.z && p.y < dry_rect_a.w) ||
        (p.x > dry_rect_b.x && p.y > dry_rect_b.y && p.x < dry_rect_b.z && p.y < dry_rect_b.w)) { discard; }
    float a = dot(p, vec2(0.41, 0.32)) + TIME * 1.8;
    float b = dot(p, vec2(-0.59, 0.393)) + TIME * 2.4;
    float detail = sin(a + sin(b) * 0.4);
    float detail_weight = 1.0 - smoothstep(30.0, 380.0, camera_distance);
    float broad_weight = 1.0 - smoothstep(260.0, 2600.0, camera_distance);
    float wa = dot(p,vec2(0.073,0.102)) + TIME*0.94;
    float wb = dot(p,vec2(-0.155,0.098)) + TIME*1.32;
    float wc = dot(p,vec2(0.312,0.179)) + TIME*1.83;
    vec2 grad = cos(wa)*vec2(0.073,0.102)*0.27 + cos(wb)*vec2(-0.155,0.098)*0.13;
    grad += cos(wc)*vec2(0.312,0.179)*0.055;
    vec3 n = normalize(vec3(-grad.x*broad_weight,1.0,-grad.y*broad_weight) + vec3(cos(a)*0.026,0.0,cos(b)*0.023)*detail_weight);
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
    float crest = smoothstep(0.65, 1.0, sin(dot(p, vec2(0.073, 0.102)) + TIME * 0.94));
    ALBEDO = mix(deep_color, crest_color, fresnel * 0.55 + crest * 0.05*broad_weight + detail * 0.018*detail_weight);
    ROUGHNESS = mix(0.32,0.24,broad_weight) + detail * 0.015 * detail_weight;
    METALLIC = 0.18;
    SPECULAR = 0.64;
}
