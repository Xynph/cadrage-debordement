shader_type spatial;
// Contour sombre du ballon (lot 5, 16 novembre 2026) : coque retournée, d'une épaisseur
// constante à l'écran (en pixels), pour détacher le ballon de la pelouse et des maillots
// clairs à la distance de la caméra TV. Aucun repère au sol : le ballon seul est souligné.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 couleur : source_color = vec4(0.07, 0.10, 0.11, 1.0);
uniform float epaisseur_px = 1.6;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 normale = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 sens = (PROJECTION_MATRIX * vec4(normale, 0.0)).xy;
	if (length(sens) > 0.0001) {
		clip.xy += normalize(sens) * epaisseur_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = couleur.rgb;
}
