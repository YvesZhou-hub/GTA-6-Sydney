shader_type spatial;
// UVs are measured metres along each actual OSM footprint edge, not a box UV.
uniform vec4 wall_color : source_color = vec4(0.65,0.64,0.60,1.0);
uniform vec4 glass_color : source_color = vec4(0.16,0.25,0.28,1.0);
uniform float glazing = 0.65;
uniform float floor_height = 3.4;
uniform float bay_width = 2.8;
uniform float masonry = 0.0;
varying float is_roof;
void vertex() { is_roof = abs(NORMAL.y); }
void fragment() {
    vec2 cell = fract(UV / vec2(bay_width,floor_height));
    float window = step((1.0-glazing)*0.5,cell.x)*step(cell.x,(1.0+glazing)*0.5)*step(0.18,cell.y)*step(cell.y,0.85);
    float frame = step(0.48,cell.x)*step(cell.x,0.52);
    window *= 1.0-frame;
    vec3 wall=wall_color.rgb;
    float mortar=step(0.94,fract(UV.y*3.2))+step(0.965,fract(UV.x*2.2+floor(UV.y*3.2)*0.5));
    wall*=1.0-clamp(mortar,0.0,1.0)*masonry*0.12;
    // High-frequency facade details fade with derivatives, avoiding distant shimmer.
    float fade=1.0-smoothstep(0.12,0.65,length(fwidth(UV)));
    window=mix(glazing*0.5,window,fade)*(1.0-step(0.6,is_roof));
    ALBEDO=mix(wall,glass_color.rgb*(0.82+0.18*cell.y),window);
    ALBEDO=mix(ALBEDO,vec3(0.33,0.36,0.36),step(0.6,is_roof));
    ROUGHNESS=mix(0.84,0.24,window);
    METALLIC=window*0.28;
}
