shader_type spatial;
// Sala atrás da janela ("interior falso", interior mapping): a janela é um plano, mas mostra uma
// sala em perspectiva, com cortina. Baseado no M_FakeInterior do Downtown City MegaKit [Source]
// (Quaternius, CC0), com três mudanças para o Nephelia:
//   - sorteio POR JANELA: o CityKit junta o prédio inteiro numa malha só (a posição do objeto,
//     usada pelo original, seria a mesma para todas); cada janela traz o seu sorteio na cor do
//     vértice (r = acesa ou não, g = qual sala acesa, b = qual cortina);
//   - brilho à noite: as salas acesas brilham conforme `night` (o SkyCycle muda junto com os postes);
//   - vidro sem transparência (caro no celular): a superfície é lisa (reflete o céu) e escurecida
//     pelo `glass_tint`, como o vidro espelhado do pacote.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D lit_interior_1 : source_color, filter_linear_mipmap;
uniform sampler2D lit_interior_2 : source_color, filter_linear_mipmap;
uniform sampler2D dark_interior : source_color, filter_linear_mipmap;
uniform sampler2D curtain_texture : source_color, hint_default_black, filter_linear_mipmap;
// Fundo da sala (0 = raso, 1 = muito fundo).
uniform float depth : hint_range(0.0, 0.95) = 0.6;
// Fração das janelas acesas e, das acesas, a que usa a segunda sala.
uniform float percentage_lit : hint_range(0.0, 1.0) = 0.45;
uniform float percentage_variations : hint_range(0.0, 1.0) = 0.5;
uniform float light_intensity : hint_range(0.0, 3.0) = 1.0;
// 0 = dia, 1 = noite (salas acesas brilhando).
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float night_glow : hint_range(0.0, 8.0) = 2.0;
// Cor da luz das salas à noite (lâmpada incandescente, como os postes; as texturas de sala são
// brancas, de luz fria).
uniform vec3 night_tint : source_color = vec3(1.0, 0.72, 0.42);
uniform vec3 glass_tint : source_color = vec3(0.23, 0.23, 0.23);
uniform float glass_mix : hint_range(0.0, 1.0) = 0.22;

varying vec3 tangent_view;
varying vec3 window_seed;

void vertex() {
	vec3 camera_local = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_vertex = VERTEX - camera_local;
	vec3 binormal = normalize(cross(TANGENT, NORMAL));
	tangent_view = vec3(dot(to_vertex, TANGENT), dot(to_vertex, binormal), dot(to_vertex, NORMAL));
	window_seed = COLOR.rgb;
}

void fragment() {
	// Raio da câmera dentro de uma caixa (a sala) atrás do plano da janela.
	float depth_scale = 1.0 / (1.0 - depth) - 1.0;
	vec3 pos = vec3(UV * 2.0 - 1.0, -1.0);
	vec3 ray = tangent_view;
	ray.z *= -depth_scale;
	vec3 inverse_ray = 1.0 / ray;
	vec3 k = abs(inverse_ray) - pos * inverse_ray;
	pos += min(min(k.x, k.y), k.z) * ray;
	float interp = pos.z * 0.5 + 0.5;
	float real_z = clamp(interp, 0.0, 1.0) / depth_scale + 1.0;
	interp = (1.0 - 1.0 / real_z) * (depth_scale + 1.0);
	vec2 room_uv = pos.xy * mix(1.0, depth, interp) * 0.5 + 0.5;

	float lit = step(1.0 - percentage_lit, window_seed.r);
	float variant = step(1.0 - percentage_variations, window_seed.g);
	vec3 lit_room = mix(texture(lit_interior_1, room_uv).rgb, texture(lit_interior_2, room_uv).rgb, variant)
			* light_intensity;
	vec3 room = mix(texture(dark_interior, room_uv).rgb, lit_room, lit);
	// Cortinas: 4 tipos num atlas 2 x 2.
	float curtain_index = min(floor(window_seed.b * 4.0), 3.0);
	vec2 curtain_uv = UV * 0.5 + vec2(mod(curtain_index, 2.0), floor(curtain_index / 2.0)) * 0.5;
	vec4 curtain = texture(curtain_texture, curtain_uv);
	vec3 color = mix(room, curtain.rgb, curtain.a);

	ALBEDO = mix(color, glass_tint, glass_mix);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	EMISSION = color * night_tint * lit * night * night_glow * (1.0 - glass_mix);
}
