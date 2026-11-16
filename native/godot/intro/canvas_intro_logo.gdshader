shader_type canvas_item;
render_mode unshaded;

// Logo de l'écran titre (ouverture, Rugby Legacy 27, novembre 2026) : compose le master sur fond noir
// comme branding/black_key.gdshader, le révèle par un reflet doré qui balaie en diagonale, puis laisse
// passer de loin en loin un second reflet. Halo doré doux autour des lettres.
// Cible : GL Compatibility ; 9 lectures de texture par pixel, sur le seul rectangle du logo.

group_uniforms revelation;
// Position du front de révélation sur la diagonale (0 = rien, 1 = tout le logo).
uniform float reveal = 1.0;
// Position du reflet de passage (hors de 0..1 : aucun reflet).
uniform float shine = -1.0;
uniform float edge_width = 0.06;
uniform float edge_strength = 0.75;
uniform float shine_strength = 0.55;
group_uniforms halo;
uniform float glow = 0.4;
uniform float glow_radius = 0.012;
uniform vec4 gold : source_color = vec4(0.843, 0.678, 0.349, 1.0);
group_uniforms;

// Diagonale légèrement inclinée : le reflet monte de bas-gauche vers haut-droite.
const float SLANT = 0.22;

float keyed(sampler2D logo, vec2 uv) {
	vec4 s = texture(logo, uv);
	return smoothstep(0.025, 0.18, max(max(s.r, s.g), s.b)) * s.a;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// COLOR arrive déjà multiplié par la texture : seule l'opacité héritée (fondus) est reprise.
	float inherited = COLOR.a / max(source.a, 0.001);
	float alpha = smoothstep(0.025, 0.18, max(max(source.r, source.g), source.b)) * source.a;
	float diag = (UV.x * (1.0 - SLANT) + (1.0 - UV.y) * SLANT);
	float front = reveal * 1.45 - 0.2;
	float shown = smoothstep(front + 0.06, front - 0.16, diag) * smoothstep(0.0, 0.35, reveal);
	float edge = exp(-pow((diag - front) / edge_width, 2.0)) * smoothstep(0.0, 0.1, reveal) * smoothstep(1.0, 0.85, reveal);
	float pass = exp(-pow((diag - shine) / 0.045, 2.0));
	vec3 glint = mix(gold.rgb, vec3(1.0, 0.95, 0.82), 0.5);
	vec3 colour = source.rgb + glint * (edge * edge_strength + pass * shine_strength);
	// Halo : couverture moyenne autour du pixel (8 lectures), teintée d'or.
	vec2 r = vec2(glow_radius * 0.5, glow_radius);
	float around = keyed(TEXTURE, UV + vec2(r.x, 0.0)) + keyed(TEXTURE, UV - vec2(r.x, 0.0)) + keyed(TEXTURE, UV + vec2(0.0, r.y)) + keyed(TEXTURE, UV - vec2(0.0, r.y));
	around += keyed(TEXTURE, UV + r * 1.8) + keyed(TEXTURE, UV - r * 1.8) + keyed(TEXTURE, UV + vec2(r.x, -r.y) * 1.8) + keyed(TEXTURE, UV + vec2(-r.x, r.y) * 1.8);
	float halo = around / 8.0 * glow * clamp(shown + edge, 0.0, 1.0);
	float logo = alpha * clamp(shown + edge, 0.0, 1.0);
	vec3 rgb = mix(gold.rgb, colour, logo / max(logo + halo * (1.0 - logo), 0.0001));
	COLOR = vec4(rgb, (logo + halo * (1.0 - logo) * 0.5) * inherited);
}
