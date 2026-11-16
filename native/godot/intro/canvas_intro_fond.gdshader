shader_type canvas_item;
render_mode unshaded;

// Fond de la carte « présente » (ouverture, Rugby Legacy 27, novembre 2026) : dégradé radial vert profond
// vers l'encre du thème, quelques lumières de stade très floues qui dérivent (bokeh), vignette et grain.
// Cible : GL Compatibility, plein écran, aucune texture.

group_uniforms couleurs;
uniform vec4 centre : source_color = vec4(0.075, 0.118, 0.106, 1.0);
uniform vec4 bord : source_color = vec4(0.027, 0.039, 0.043, 1.0);
uniform vec4 lumiere : source_color = vec4(0.843, 0.678, 0.349, 1.0);
group_uniforms reglages;
uniform float screen_aspect = 1.7778;
uniform float time = 0.0;
uniform float exposure = 1.0;
uniform float bokeh = 0.5;
uniform float grain = 0.04;
group_uniforms;

// Nombre de lumières floues (constante de compilation, boucle sans lecture de texture).
const int LIGHTS = 7;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec4 tint = COLOR;
	vec2 p = (UV - 0.5) * vec2(screen_aspect, 1.0);
	float d = length(p * vec2(0.8, 1.05));
	vec3 col = mix(centre.rgb, bord.rgb, smoothstep(0.0, 0.95, d));
	// Bokeh : grands disques doux, très peu lumineux, qui glissent lentement vers la droite.
	float glow = 0.0;
	for (int i = 0; i < LIGHTS; i++) {
		float n = float(i) + 1.0;
		vec2 at = vec2(hash(n) * 2.0 - 1.0, hash(n * 3.7) * 0.9 - 0.45) * vec2(screen_aspect * 0.5, 1.0);
		at.x += time * (0.010 + 0.012 * hash(n * 5.1));
		float size = 0.06 + 0.10 * hash(n * 7.3);
		float disc = smoothstep(size, size * 0.55, length(p - at));
		glow += disc * (0.25 + 0.75 * hash(n * 9.1));
	}
	col += lumiere.rgb * glow * bokeh * 0.035;
	col *= exposure;
	float g = fract(sin(dot(UV * vec2(1931.0, 1087.0) + fract(time * 23.0) * 311.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += g * grain;
	COLOR = vec4(col, 1.0) * tint;
}
