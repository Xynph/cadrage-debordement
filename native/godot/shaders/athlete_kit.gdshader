shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec4 jersey_color : source_color = vec4(0.63, 0.18, 0.25, 1.0);
uniform vec4 panel_color : source_color = vec4(0.43, 0.10, 0.15, 1.0);
uniform vec4 trim_color : source_color = vec4(0.87, 0.66, 0.61, 1.0);
uniform vec4 shorts_color : source_color = vec4(0.12, 0.17, 0.20, 1.0);
uniform vec4 socks_color : source_color = vec4(0.63, 0.18, 0.25, 1.0);
uniform vec4 skin_color : source_color = vec4(0.74, 0.55, 0.43, 1.0);
uniform vec4 hair_color : source_color = vec4(0.15, 0.12, 0.10, 1.0);
void fragment() {
	// UV/UV2 portent les attributs de repos : limites attachées au mesh.
	float h = UV.x;
	float x = UV.y;
	float depth = UV2.x;
	int part = int(floor(UV2.y + 0.5));
	vec3 color = jersey_color.rgb;
	float roughness = 0.92;
	if (part == 0 || part == 1) {
		// Panneaux originaux sobres : épaules, flancs et bord de manche.
		if (h > 0.0372 && abs(x) > 0.0036) color = panel_color.rgb;
		if (abs(x) > 0.0037 && h < 0.0350) color = panel_color.rgb;
		if (abs(x) > 0.0110) color = trim_color.rgb;
		if (h > 0.0394 && abs(x) < 0.0033) color = panel_color.rgb;
		// Fin accent sternum, sans logo, sponsor, boutons ni tenue de club réel.
		if (h > 0.0345 && h < 0.0350 && depth < -0.0010 && abs(x) < 0.0035) color = trim_color.rgb;
	} else if (part == 3) {
		color = shorts_color.rgb;
		if (h < 0.0190) color = skin_color.rgb;
		if (h < 0.0106) {
			color = socks_color.rgb;
			if (h > 0.0096) color = panel_color.rgb;
			if (h > 0.00975 && h < 0.0100) color = trim_color.rgb;
		}
	} else if (part == 5) {
		color = socks_color.rgb;
	} else if (part == 2) {
		color = skin_color.rgb;
		roughness = 0.81;
	} else if (part == 6 || part == 7) {
		color = hair_color.rgb * (part == 6 ? 0.84 : 1.0);
		roughness = 0.96;
	} else if (part == 4) {
		color = vec3(0.032, 0.043, 0.048);
		roughness = 0.82;
	} else if (part == 8) {
		color = vec3(0.028, 0.027, 0.024);
	}
	ALBEDO = color;
	METALLIC = 0.0;
	ROUGHNESS = roughness;
}
