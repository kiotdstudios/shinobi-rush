shader_type canvas_item;
render_mode unshaded;
uniform vec4 chakra_color : source_color = vec4(0.08, 0.5, 1.0, 1.0);
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float light = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = mix(chakra_color.rgb * 0.18, chakra_color.rgb, smoothstep(0.03, 0.65, light));
	color = mix(color, vec3(1.0), smoothstep(0.65, 0.98, light));
	COLOR = vec4(color, src.a * chakra_color.a) * item_tint;
}
