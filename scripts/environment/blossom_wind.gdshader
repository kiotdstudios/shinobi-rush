shader_type canvas_item;
render_mode unshaded;

uniform float wind_clock = 0.0;
uniform float phase_offset = 0.0;
uniform float strength = 1.0;
uniform float anchor_y = 390.0;
uniform bool wind_enabled = true;
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	if (wind_enabled) {
		// Exactly periodic 96-phase / 24 fps loop. The lower trunk, roots and
		// stone base never deform. Nearest sampling preserves source clusters.
		float t = floor(mod(wind_clock, 4.0) * 24.0) / 96.0 * TAU + phase_offset;
		float y = UV.y * 448.0;
		float height = clamp((anchor_y - 70.0 - y) / 260.0, 0.0, 1.0);
		float weight = height * height * (3.0 - 2.0 * height);
		float bend = sin(t) * 4.3;
		float flutter = sin(t * 2.0 + y * 0.032 + UV.x * 7.0) * 1.1;
		float tips = sin(t * 3.0 + UV.x * 16.0 + y * 0.018) * 0.65;
		uv.x -= (bend + flutter + tips) * weight * strength / 320.0;
		uv.y -= sin(t * 2.0 + UV.x * 8.0) * weight * 0.7 / 448.0;
	}
	COLOR = texture(TEXTURE, uv) * item_tint;
}
