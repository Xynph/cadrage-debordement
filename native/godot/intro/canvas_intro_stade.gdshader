shader_type canvas_item;
render_mode unshaded;

// Plan « stade » de l'ouverture (compatible GL Compatibility) : illustration du stade en 2,5D.
// Mouvement de caméra lent (zoom + panoramique) avec parallaxe par carte de profondeur, brume qui dérive,
// halo et faisceaux du projecteur, poussière dans la lumière, étalonnage chaud/froid, vignette et grain.
// Toutes les intensités viennent d'intro.json (carte_stade.gd) ; aucune n'est fixée ici.
// Cible : rendu GL Compatibility, plein écran ; 4 lectures de profondeur + 4 lectures d'image par pixel.
// Auteur : ouverture du jeu, novembre 2026 (Rugby Legacy 27).

group_uniforms images;
uniform sampler2D image : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform sampler2D glow_map : source_color, filter_linear, repeat_disable;
uniform sampler2D blur_map : source_color, filter_linear, repeat_disable;
uniform float image_aspect = 1.7768;
uniform float screen_aspect = 1.7778;
uniform float time = 0.0;
group_uniforms camera;
// Caméra : avancement 0..1 (déjà lissé), zoom et point visé (UV de l'image) au début et à la fin.
uniform float progress = 0.0;
uniform float zoom_from = 1.06;
uniform float zoom_to = 1.16;
uniform vec2 focus_from = vec2(0.47, 0.52);
uniform vec2 focus_to = vec2(0.56, 0.47);
uniform float parallax = 0.012;
uniform float parallax_pivot = 0.34;
group_uniforms lumiere;
// Lumière et atmosphère.
uniform vec2 light_uv = vec2(0.5269, 0.3422);
uniform vec4 light_color : source_color = vec4(1.0, 0.80, 0.52, 1.0);
uniform float bloom = 0.9;
uniform float halo = 0.55;
uniform float beams = 0.35;
uniform float haze = 0.45;
uniform float dust = 0.8;
uniform float clarity = 0.18;
group_uniforms finition;
// Étalonnage et finition.
uniform float exposure = 1.0;
uniform float blur = 0.0;
uniform float warmth = 0.5;
uniform float vignette = 0.55;
uniform float grain = 0.045;
uniform float letterbox = 0.0;
uniform vec4 ink : source_color = vec4(0.043, 0.063, 0.071, 1.0);
group_uniforms;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return total;
}

// Poussière et insectes : un point doux par cellule, dérive lente, scintillement ; clairsemé.
float motes(vec2 p, float scale, float t, float seed) {
	vec2 q = p * scale;
	q += vec2(sin(t * 0.21 + seed) * 0.6 + t * 0.10, -t * (0.18 + seed * 0.05));
	vec2 cell = floor(q);
	vec2 h = hash22(cell + seed * 13.0);
	vec2 wander = vec2(sin(t * (0.7 + h.y) + h.x * 6.28), cos(t * (0.6 + h.x) + h.y * 6.28)) * 0.18;
	vec2 at = 0.25 + 0.5 * h + wander;
	float d = length(fract(q) - at);
	float twinkle = 0.55 + 0.45 * sin(t * (1.3 + 2.0 * h.y) + h.x * 40.0);
	return smoothstep(0.09, 0.0, d) * twinkle * step(0.72, h.x);
}

void fragment() {
	// Couleur d'entrée = modulate hérité (fondus des cartes) : réappliquée en sortie.
	vec4 tint = COLOR;
	vec2 uv = UV;
	vec2 cover = screen_aspect > image_aspect ? vec2(1.0, image_aspect / screen_aspect) : vec2(screen_aspect / image_aspect, 1.0);
	float k = clamp(progress, 0.0, 1.0);
	float zoom = mix(zoom_from, zoom_to, k);
	vec2 focus = mix(focus_from, focus_to, k);
	vec2 base = focus + (uv - 0.5) * cover / zoom;
	// Parallaxe : la caméra glisse vers la droite ; le premier plan défile plus vite que les montagnes.
	vec2 shift = vec2(mix(-1.0, 1.0, k), mix(0.35, -0.35, k)) * parallax;
	// Recherche du point source par itérations successives (déroulées : pas de lecture de texture en boucle).
	vec2 src = base + shift * (texture(depth_map, clamp(base, 0.0, 1.0)).r - parallax_pivot);
	src = base + shift * (texture(depth_map, clamp(src, 0.0, 1.0)).r - parallax_pivot);
	src = base + shift * (texture(depth_map, clamp(src, 0.0, 1.0)).r - parallax_pivot);
	src = base + shift * (texture(depth_map, clamp(src, 0.0, 1.0)).r - parallax_pivot);
	src = clamp(src, vec2(0.001), vec2(0.999));

	vec3 sharp = texture(image, src).rgb;
	vec3 soft = texture(blur_map, src).rgb;
	vec3 col = sharp + (sharp - soft) * clarity;
	col = mix(max(col, vec3(0.0)), soft, blur);

	// Lumière du projecteur, dans l'espace de l'image : elle suit la caméra et la parallaxe.
	vec2 dl = (src - light_uv) * vec2(image_aspect, 1.0);
	float r = length(dl);
	float flicker = 0.96 + 0.04 * noise(vec2(time * 7.0, 3.0));
	vec3 lc = light_color.rgb;
	col += texture(glow_map, src).rgb * bloom * flicker * (1.0 - 0.6 * blur);
	float core = exp(-r * r / 0.00035);
	float wide = exp(-r * 7.5);
	float streak = exp(-abs(dl.y) * 260.0) * exp(-abs(dl.x) * 4.5);
	col += lc * ((core * 0.8 + streak * 0.3) * (1.0 - blur) + wide * 0.16) * halo * flicker;
	// Faisceaux : rayons qui partent du projecteur vers la pelouse, modulés par la brume.
	float angle = atan(dl.x, dl.y);
	float cone = smoothstep(1.45, 0.25, abs(angle - 0.55)) * step(0.0, dl.y + 0.02);
	float rays = pow(noise(vec2(angle * 9.0 + time * 0.04, 1.7)), 2.2) + 0.35 * noise(vec2(angle * 31.0 - time * 0.07, 5.3));
	float beam = rays * cone * exp(-r * 2.4) * smoothstep(0.0, 0.05, r);

	// Brume : deux nappes qui dérivent lentement, au ras de la pelouse et à flanc de montagne.
	vec2 hp = src * vec2(image_aspect, 1.0);
	float ground_band = smoothstep(0.50, 0.62, src.y) * (1.0 - smoothstep(0.66, 0.86, src.y));
	float slope_band = smoothstep(0.18, 0.32, src.y) * (1.0 - smoothstep(0.42, 0.58, src.y));
	float mist_low = fbm(hp * vec2(2.2, 7.0) + vec2(time * 0.045, 0.0));
	float mist_high = fbm(hp * vec2(1.6, 4.0) + vec2(-time * 0.025, time * 0.006) + 7.0);
	float mist = smoothstep(0.35, 0.85, mist_low) * ground_band + smoothstep(0.42, 0.9, mist_high) * slope_band * 0.7;
	vec3 mist_color = mix(vec3(0.52, 0.60, 0.60), lc, clamp(wide * 1.6 + beam * 0.6, 0.0, 1.0));
	vec3 atmosphere = mist_color * mist * haze * 0.42 + lc * beam * beams * (0.55 + 0.9 * mist);
	col = col + atmosphere * (1.0 - clamp(col, 0.0, 1.0)) * (1.0 - 0.7 * blur);

	// Poussière dans la lumière.
	float light_mask = clamp(exp(-r * 13.0) * 1.6 + beam * 1.6, 0.0, 1.0);
	float specks = motes(hp, 70.0, time, 0.0) + 0.7 * motes(hp, 120.0, time * 0.8, 1.0) + 0.5 * motes(hp, 42.0, time * 1.1, 2.0);
	col += lc * specks * light_mask * dust * (1.0 - blur);

	// Étalonnage : ombres froides vert-bleu, hautes lumières chaudes, noirs relevés vers l'encre du thème.
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	vec3 cool = col * vec3(0.90, 1.0, 1.04) + vec3(0.0, 0.012, 0.016);
	vec3 warm = col * vec3(1.07, 1.0, 0.88);
	col = mix(col, mix(cool, warm, smoothstep(0.12, 0.7, lum)), warmth);
	col = mix(vec3(lum), col, 0.92);
	col *= exposure;
	// Épaule douce : les hautes lumières gardent leur teinte chaude au lieu de virer au blanc.
	vec3 over = max(col - 0.72, vec3(0.0));
	col = min(col, vec3(0.72)) + 0.28 * (1.0 - exp(-over / 0.28));

	// Vignette, grain filmique, bandes cinéma.
	vec2 v = (uv - 0.5) * vec2(screen_aspect / 1.7778 * 1.0, 1.0);
	float vig = smoothstep(0.95, 0.28, length(v * vec2(0.92, 1.08)));
	col *= mix(1.0, vig, vignette);
	col = ink.rgb * (1.0 - clamp(col, 0.0, 1.0)) * 0.55 + col;
	float g = hash12(uv * vec2(1931.0, 1087.0) + fract(time * 23.0) * 311.0) - 0.5;
	col += g * grain * (0.35 + 0.65 * (1.0 - abs(lum - 0.4) * 1.6));
	float bars = smoothstep(letterbox, letterbox + 0.002, uv.y) * smoothstep(letterbox, letterbox + 0.002, 1.0 - uv.y);
	col = mix(ink.rgb * 0.6, col, bars);
	COLOR = vec4(col, 1.0) * tint;
}
