shader_type spatial;
// Original analytical particles: simulation age, no TIME or screen textures.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;
uniform bool incandescent = false;
uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_disable;
varying vec4 particle_data;
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
	particle_data=INSTANCE_CUSTOM;
	// Keep per-particle translation/scale, face camera without sharing Node poses.
	vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX=mat4(vec4(scale.x,0,0,0),vec4(0,scale.y,0,0),vec4(0,0,scale.z,0),VIEW_MATRIX*MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX=mat3(1.0);
}
void fragment() {
	vec2 p=UV*2.0-1.0;
	float angle=particle_data.x*6.283185;
	p=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*p;
	vec2 flow=p*3.8+vec2(particle_data.x*31.0, -particle_data.y*.7);
	float n=noise(flow)*.57+noise(flow*2.07+2.6)*.29+noise(flow*4.13)*.14;
	float edge=1.0-smoothstep(.40,1.00,length(p)+(n-.5)*.43);
	float holes=smoothstep(.16,.65,n);
	float density=edge*holes;
	if(incandescent) {
		float heat=clamp(n*.8+(1.0-length(p))*.5-particle_data.y*.20,0.0,1.0);
		vec3 fire=mix(vec3(.7,.07,.007),vec3(1.0,.50,.055),smoothstep(.12,.7,heat));
		fire=mix(fire,vec3(1.0,.91,.53),smoothstep(.66,.97,heat));
		ALBEDO=fire;
		EMISSION=fire*(2.5+heat*5.0)*COLOR.rgb;
		ALPHA=density*COLOR.a;
	} else {
		// Directional density gradient suggests rolling volume, not opaque balls.
		vec2 drift=vec2(noise(flow+7.1),noise(flow-3.4))*.035-.0175;
		vec4 texel=texture(cloud_texture,p*.5+.5+drift);
		float luma=dot(texel.rgb,vec3(.2126,.7152,.0722));
		float shade=.45+luma*1.08+clamp(p.y,-.5,.5)*.12;
		ALBEDO=COLOR.rgb*shade;
		ALPHA=texel.a*edge*(.65+.35*holes)*COLOR.a;
	}
}
