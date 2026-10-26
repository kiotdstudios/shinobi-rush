shader_type canvas_item;
render_mode unshaded;
uniform float motion_clock = 0.0;
uniform float phase = 0.0;
varying vec4 ribbon_tint;
void vertex() {
	ribbon_tint = COLOR;
}
void fragment() {
	// Sample one atlas cell only; sub-pixel clock drives deliberate native-pixel curls.
	vec2 cell_px = TEXTURE_PIXEL_SIZE * 128.0;
	vec2 origin = floor(UV / cell_px) * cell_px;
	vec2 local = (UV - origin) / cell_px;
	float bend = sin(local.x * 9.0 + motion_clock * 0.42 + phase)
		+ 0.45 * sin(local.x * 17.0 - motion_clock * 0.27 + phase);
	vec2 sample_uv = UV + vec2(0.0, floor(bend * 1.5) * TEXTURE_PIXEL_SIZE.y);
	sample_uv = clamp(sample_uv, origin + TEXTURE_PIXEL_SIZE * 0.5, origin + cell_px - TEXTURE_PIXEL_SIZE * 0.5);
	COLOR = ribbon_tint * texture(TEXTURE, sample_uv);
}
