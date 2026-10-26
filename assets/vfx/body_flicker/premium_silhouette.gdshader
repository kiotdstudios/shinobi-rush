shader_type canvas_item;
render_mode unshaded;
uniform bool streak = false;
uniform float flash = 0.0;
uniform float spread = 1.0;
uniform bool smear = false;
uniform float whiten = 0.55;
uniform vec2 heading = vec2(1.0,0.0);
varying vec4 sprite_color;
void vertex() { sprite_color = COLOR; }
void fragment() {
 vec2 uv = UV;
 float stripe = mod(floor(dot(UV / TEXTURE_PIXEL_SIZE, vec2(-heading.y,heading.x))), 6.0);
 if (smear) uv += heading * TEXTURE_PIXEL_SIZE * (4.0 + stripe * 1.4) * spread;
 vec4 source = texture(TEXTURE,uv);
 float luma = dot(source.rgb,vec3(0.299,0.587,0.114));
 vec3 cold = mix(vec3(0.35,0.43,0.52), vec3(0.94,0.98,1.0),floor(luma*3.0)/3.0);
 if(streak) cold=mix(vec3(0.66,0.78,0.9),vec3(0.96,0.99,1.0),luma);
 cold=mix(cold,vec3(0.96,0.99,1.0),flash);
 COLOR = vec4(mix(source.rgb,cold,streak ? 1.0 : whiten),source.a) * sprite_color;
 if(smear && stripe>1.0) COLOR.a=0.0;
}
