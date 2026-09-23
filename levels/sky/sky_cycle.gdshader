// Céu da arena: degradê do alto ao horizonte (e abaixo dele), brilho do pôr do sol do lado do sol,
// disco do sol, estrelas que piscam e a lua. As cores e quantidades vêm do SkyCycle, que as muda
// conforme a partida passa (tarde -> pôr do sol -> noite). Barato: só contas por pixel do fundo.
shader_type sky;

uniform vec3 sky_top : source_color = vec3(0.25, 0.45, 0.78);
uniform vec3 sky_horizon : source_color = vec3(0.95, 0.78, 0.6);
uniform vec3 ground_horizon : source_color = vec3(0.9, 0.75, 0.62);
uniform vec3 ground_bottom : source_color = vec3(0.7, 0.7, 0.78);

// Sol (direção PARA o sol) e o clarão alaranjado em volta dele, no horizonte.
uniform vec3 sun_direction = vec3(-0.9, 0.35, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float sun_size = 0.035;
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.25);
uniform float glow_amount = 0.5;

// Estrelas (0 = nenhuma, 1 = céu estrelado) e lua (0 = invisível, 1 = cheia).
uniform float stars_amount = 0.0;
// Nebulosa: faixa de poeira colorida atravessando o céu (0 = invisível, 1 = noite cheia).
uniform float nebula_amount = 0.0;
uniform vec3 nebula_color_a : source_color = vec3(0.45, 0.2, 0.75);
uniform vec3 nebula_color_b : source_color = vec3(0.12, 0.55, 0.65);
uniform vec3 nebula_color_c : source_color = vec3(0.9, 0.35, 0.55);
// Eixo da faixa (perpendicular ao "plano" da nebulosa): inclinada, do sudoeste ao nordeste.
uniform vec3 nebula_axis = vec3(0.35, 0.55, 0.76);
// O céu estrelado (estrelas e nebulosa) gira devagar em volta de um polo inclinado, como a Terra
// girando: radianos por segundo (0,01 = um giro de 34° por minuto). A poeira muda de forma aos poucos.
uniform vec3 sky_pole = vec3(0.3, 0.8, -0.5);
uniform float sky_spin = 0.01;
uniform float dust_drift = 0.004;
uniform vec3 moon_direction = vec3(0.8, 0.3, -0.5);
uniform vec3 moon_color : source_color = vec3(0.93, 0.95, 1.0);
uniform float moon_size = 0.05;
uniform float moon_amount = 0.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Ruído suave em 3D (valor interpolado) e a soma de 4 oitavas dele (nuvens de poeira).
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float g = hash13(i + vec3(1.0, 0.0, 1.0));
	float h = hash13(i + vec3(0.0, 1.0, 1.0));
	float k = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise3(p) * amplitude;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amplitude *= 0.5;
	}
	return total;
}

// Gira `v` em volta do eixo `axis` (unitário) por `angle` radianos.
vec3 rotate_around(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// Nebulosa: faixa larga em volta do eixo, feita de poeira colorida com veios escuros. Devolve a
// cor (já com a força) e, em `.w`, quanto a faixa está ali (para pôr mais estrelas dentro dela).
vec4 nebula(vec3 dir) {
	float across = dot(dir, normalize(nebula_axis));
	float band = exp(-across * across * 9.0);
	vec3 drift = vec3(1.0, 0.6, 0.8) * TIME * dust_drift;
	float dust = fbm(dir * 3.2 + vec3(4.0, 1.0, 7.0) + drift);
	float detail = fbm(dir * 7.5 + vec3(11.0, 3.0, 5.0) - drift * 1.5);
	float lanes = smoothstep(0.42, 0.68, fbm(dir * 5.0 + vec3(2.0, 8.0, 1.0)));
	float density = band * smoothstep(0.3, 0.75, dust * 0.7 + detail * 0.45) * (1.0 - lanes * 0.75);
	float tint = fbm(dir * 2.0 + vec3(6.0, 2.0, 9.0));
	vec3 color = mix(nebula_color_a, nebula_color_b, smoothstep(0.35, 0.65, tint));
	color = mix(color, nebula_color_c, smoothstep(0.55, 0.8, detail) * 0.6);
	return vec4(color * density, band);
}

// Estrelas: o céu é dividido em células; algumas ganham um ponto de luz num lugar sorteado.
float stars(vec3 dir, float scale, float density) {
	vec3 p = dir * scale;
	vec3 id = floor(p);
	vec3 offset = hash33(id) * 0.6 + 0.2;
	float d = length(fract(p) - offset);
	float chosen = step(1.0 - density, hash13(id + 17.0));
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + hash13(id) * 3.0) + hash13(id + 5.0) * 40.0);
	return chosen * smoothstep(0.16, 0.0, d) * twinkle * (0.5 + hash13(id + 9.0));
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 color;
	if (h >= 0.0) {
		color = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), 0.45));
	} else {
		color = mix(ground_horizon, ground_bottom, pow(clamp(-h, 0.0, 1.0), 0.5));
	}

	// Clarão do pôr do sol: forte no horizonte, do lado do sol, e sobe um pouco pelo céu.
	vec3 sun_dir = normalize(sun_direction);
	float toward_sun = max(dot(normalize(vec3(dir.x, 0.0, dir.z)), normalize(vec3(sun_dir.x, 0.0, sun_dir.z))), 0.0);
	float band = exp(-abs(h - 0.02) * 7.0);
	color += glow_color * glow_amount * band * (0.25 + 0.75 * pow(toward_sun, 3.0));

	// Sol: disco com halo; afunda atrás do horizonte.
	float sun_dot = dot(dir, sun_dir);
	float above = smoothstep(-0.03, 0.01, h);
	float disc = smoothstep(cos(sun_size * 1.15), cos(sun_size), sun_dot) * above;
	color += sun_color * pow(max(sun_dot, 0.0), 300.0) * 1.5 * above;
	color = mix(color, sun_color * 1.6, disc);

	// Nebulosa e estrelas: somem perto do horizonte. Dentro da faixa da nebulosa há mais estrelas.
	// As duas giram juntas com o céu (a direção é "desgirada" antes de procurar a estrela).
	vec3 sky_dir = rotate_around(dir, normalize(sky_pole), -TIME * sky_spin);
	float star_band = 0.0;
	if (nebula_amount > 0.001) {
		vec4 cloud = nebula(sky_dir);
		color += cloud.rgb * nebula_amount * smoothstep(0.0, 0.3, h) * 0.55;
		star_band = cloud.w * nebula_amount;
	}
	if (stars_amount > 0.001) {
		float fade = smoothstep(0.02, 0.25, h) * stars_amount;
		float s = stars(sky_dir, 260.0, 0.06 + star_band * 0.08) * 0.8 + stars(sky_dir, 110.0, 0.025) * 1.2;
		color += vec3(0.9, 0.93, 1.0) * s * fade;
	}

	// Lua: disco claro com manchas, halo azulado; também afunda no horizonte.
	if (moon_amount > 0.001) {
		vec3 moon_dir = normalize(moon_direction);
		float moon_dot = dot(dir, moon_dir);
		float moon_above = smoothstep(-0.02, 0.01, h);
		float moon_disc = smoothstep(cos(moon_size * 1.08), cos(moon_size), moon_dot) * moon_above;
		// Manchas ("mares" da lua): ruído grosso no disco.
		vec3 local = (dir - moon_dir * moon_dot) / moon_size;
		float spots = hash13(floor(local * 3.0 + 7.0)) * 0.18 + hash13(floor(local * 7.0 + 3.0)) * 0.1;
		color += moon_color * pow(max(moon_dot, 0.0), 90.0) * 0.35 * moon_amount * moon_above;
		color = mix(color, moon_color * (1.0 - spots), moon_disc * moon_amount);
	}
	COLOR = color;
}
