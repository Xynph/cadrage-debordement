shader_type canvas_item;
render_mode unshaded, blend_add;

// Halo doré derrière le logo de l'écran titre (ouverture, Rugby Legacy 27, novembre 2026) : ellipse de
// lumière très douce et rayons faibles qui tournent lentement. Cible : GL Compatibility, aucune texture.

group_uniforms halo;
uniform float strength = 0.25;
uniform float time = 0.0;
uniform float rays = 0.35;
uniform vec4 colour : source_color = vec4(0.843, 0.678, 0.349, 1.0);
group_uniforms;

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float a = fract(sin(i * 12.9898) * 43758.5453);
	float b = fract(sin((i + 1.0) * 12.9898) * 43758.5453);
	return mix(a, b, f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec4 tint = COLOR;
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float body = exp(-r * r * 3.2);
	float angle = atan(p.y, p.x) / 6.2831853 + 0.5;
	float streaks = noise1(angle * 36.0 + time * 0.12) * noise1(angle * 11.0 - time * 0.07);
	float value = (body + streaks * rays * exp(-r * 2.6) * smoothstep(0.05, 0.3, r)) * strength;
	COLOR = vec4(colour.rgb * value * tint.a, 1.0);
}
