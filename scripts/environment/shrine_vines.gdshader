shader_type canvas_item;
uniform float motion_time = 0.0;
uniform float phase = 0.0;
uniform float top = 0.0;
uniform float bottom = 1.0;
void fragment() {
	float weight = smoothstep(top,bottom,UV.y);
	float bend = sin(motion_time*0.7853981634+phase)*1.4*weight;
	vec2 sample_uv = UV-vec2(round(bend)*TEXTURE_PIXEL_SIZE.x,0.0);
	COLOR = texture(TEXTURE,sample_uv);
}
