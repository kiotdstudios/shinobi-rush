shader_type canvas_item;
render_mode unshaded;
uniform float phase_index = 0.0;
uniform float strength = 1.0;
uniform bool enabled = true;
uniform vec2 frame_size = vec2(112.0, 160.0);
uniform float root_line = 116.0;
uniform float blade_height = 92.0;
uniform float amplitude = 4.5;
varying vec4 item_tint;
varying vec2 world_pixel;

void vertex() {
	item_tint = COLOR;
	world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = UV;
	if (enabled) {
		float t = phase_index / 144.0 * TAU;
		// World-space phase carries the gust across adjacent tiles coherently.
		float field = world_pixel.x * 0.007 - world_pixel.y * 0.0035;
		float y = UV.y * frame_size.y;
		float h = clamp((root_line - y) / blade_height, 0.0, 1.0);
		float bend_weight = h * h;
		float gust = 0.25 + sin(t - field);
		float follow = sin(t * 2.0 - field + y * 0.028) * 0.22;
		float filament = sin(t * 3.0 + world_pixel.x * 0.11 + y * 0.05) * 0.12;
		uv.x -= (gust + follow + filament) * amplitude * strength * bend_weight / frame_size.x;
		uv.y -= sin(t * 2.0 - field + UV.x * 7.0) * 0.7 * strength * bend_weight / frame_size.y;
	}
	COLOR = texture(TEXTURE, uv) * item_tint;
}
