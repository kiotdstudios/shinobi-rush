shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float strength = 1.0;
uniform bool wind_on = true;
uniform bool heat_on = true;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	float t = floor(mod(clock, 4.0) * 24.0) / 96.0 * TAU;
	float y = UV.y * 448.0;
	float height = clamp((346.0 - y) / 280.0, 0.0, 1.0);
	float weight = height * height * (3.0 - 2.0 * height);
	if (wind_on) {
		float bend = sin(t + phase) * 3.8;
		float flutter = sin(t * 2.0 + phase + y * 0.032 + UV.x * 9.0) * 1.0;
		uv.x -= (bend + flutter) * weight * strength / 320.0;
		uv.y -= sin(t * 2.0 + phase + UV.x * 8.0) * weight * 0.6 / 448.0;
	}
	vec4 source = texture(TEXTURE, uv);
	// Only existing molten source pixels pulse. Cold bark is never recolored.
	if (heat_on && source.r > source.g * 1.7 && source.r > 0.25 && y > 266.0) {
		float wave = 0.5 + 0.5 * sin(t + phase + y * 0.012);
		float pulse = floor(wave * 7.0 + 0.5) / 7.0;
		source.rgb *= 0.58 + pulse * 0.70;
	}
	COLOR = source * tint;
}
