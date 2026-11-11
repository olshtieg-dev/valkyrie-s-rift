shader_type canvas_item;
// Armored enemies: the sprite's dark outline pixels become steel plating, with
// a glint sweeping across. Pixel-exact (no filtering or scaling).

uniform vec4 steel : source_color = vec4(0.62, 0.70, 0.86, 1.0);
uniform vec4 glint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_luma = 0.22;   // pixels darker than this count as outline
uniform float band_spacing = 28.0;   // world pixels between glint bands
uniform float glint_speed = 0.7;

varying vec2 world_pos;
// fragment()'s COLOR already includes the texture, so keep the bare
// modulate/vertex color from the vertex stage to multiply with instead.
varying vec4 tint;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (c.a > 0.5 && luma < outline_luma) {
		vec2 p = floor(world_pos);
		float band = fract((p.x + p.y) / band_spacing - TIME * glint_speed);
		c.rgb = band < 0.08 ? glint.rgb : steel.rgb;
	}
	COLOR = c * tint;
}
