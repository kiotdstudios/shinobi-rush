shader_type canvas_item;
render_mode unshaded;
uniform int phase_index = 0;
uniform float root_y = 116.0;
uniform bool hanging = false;
uniform float amplitude = 1.3;
uniform float sway_length = 72.0;
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
	vec2 pixel = floor(UV * 128.0) + vec2(0.5);
	float distance_from_root = hanging ? pixel.y - root_y : root_y - pixel.y;
	float weight = clamp(distance_from_root / max(sway_length, 1.0), 0.0, 1.0);
	float phase = float(phase_index) / 96.0 * TAU;
	// Whole pixel sampling preserves the actual palette and pins the attachment/root.
	float shift = round((sin(phase) * 0.8 + sin(phase * 2.0 + pixel.y * 0.045) * 0.2) * amplitude * weight * weight);
	vec2 sample_pixel = pixel - vec2(shift, 0.0);
	if (sample_pixel.x < 0.0 || sample_pixel.x >= 128.0) { COLOR = vec4(0.0); }
	else { COLOR = texture(TEXTURE, sample_pixel / 128.0) * item_tint; }
}
