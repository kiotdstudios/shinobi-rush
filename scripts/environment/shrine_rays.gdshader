shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float motion_time = 0.0;
void fragment() {
	float x = UV.x;
	float streaks = pow(max(0.0,sin(x*43.0+sin(motion_time*0.21)*0.4)),12.0);
	float soft = pow(max(0.0,sin(x*3.14159265)),2.0);
	float fade = sin(clamp(UV.y,0.0,1.0)*3.14159265);
	float breath = 0.75+0.25*sin(motion_time*0.37);
	COLOR = vec4(0.56,0.69,0.92,(0.035+streaks*0.065)*soft*fade*breath);
}
