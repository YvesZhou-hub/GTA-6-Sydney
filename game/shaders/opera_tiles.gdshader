shader_type spatial;
render_mode cull_back;

// UV is measured in metres on the spherical roof, not screen coordinates.
// Original analytic ceramic tiles; no photograph or downloaded texture.
uniform vec4 white_tile : source_color = vec4(0.81, 0.82, 0.79, 1.0);
uniform vec4 cream_tile : source_color = vec4(0.75, 0.74, 0.67, 1.0);

float filtered_line(float coord, float half_width, float footprint) {
	float distance_to_edge = min(fract(coord), 1.0 - fract(coord));
	return 1.0 - smoothstep(half_width - footprint, half_width + footprint, distance_to_edge);
}

void fragment() {
	vec2 tile_uv = UV / 0.12;
	vec2 fw = max(fwidth(tile_uv), vec2(0.0001));
	float resolved_tiles = 1.0 - smoothstep(0.22, 0.85, max(fw.x, fw.y));
	float grout = max(filtered_line(tile_uv.x, 0.018, fw.x), filtered_line(tile_uv.y, 0.018, fw.y));
	float chevron = abs(fract(UV.x / 3.6) * 2.0 - 1.0) * 1.25 + UV.y / 3.6;
	float band = smoothstep(0.68 - fwidth(chevron), 0.68 + fwidth(chevron), fract(chevron));
	vec3 ceramic = mix(white_tile.rgb, cream_tile.rgb, band * 0.34 * COLOR.a);
	ALBEDO = mix(ceramic, ceramic * 0.72, grout * resolved_tiles * 0.55 * COLOR.a) * COLOR.rgb;
	ROUGHNESS = mix(0.38, 0.62, band);
	METALLIC = 0.04;
	SPECULAR = 0.38;
}
