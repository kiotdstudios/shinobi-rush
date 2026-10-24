shader_type canvas_item;
uniform sampler2D current_atlas : source_color, filter_nearest, repeat_disable;
uniform float motion_time = 0.0;
uniform float native_scale = 1.0;
varying vec2 world_pixel;
void vertex() {
	world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	float frame = mod(floor(motion_time * 16.0), 16.0);
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	// Shared world coordinates keep neighboring diamonds in the same flow field.
	vec2 drift = floor(vec2(motion_time * 11.0, motion_time * 4.0));
	vec2 pixel = mod(floor(world_pixel / native_scale) - drift, vec2(128.0));
	vec2 atlas_uv = (cell * 128.0 + pixel + 0.5) / 512.0;
	vec4 water = texture(current_atlas, atlas_uv);
	COLOR = vec4(water.rgb, mask.a);
}
