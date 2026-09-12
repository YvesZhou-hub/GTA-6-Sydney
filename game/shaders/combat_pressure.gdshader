shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;
uniform vec4 tint : source_color = vec4(.73,.65,.49,.24);
void fragment() {
	vec2 p=UV*2.0-1.0;
	float r=length(p);
	float angular=atan(p.y,p.x);
	float broken=.64+.36*sin(angular*13.0+sin(angular*7.0));
	float band=smoothstep(.65,.85,r)*(1.0-smoothstep(.88,1.0,r));
	ALBEDO=tint.rgb;
	ALPHA=band*broken*tint.a;
}
