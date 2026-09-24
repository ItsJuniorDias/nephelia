shader_type spatial;
// Material das peças do Downtown City MegaKit [Source] (Quaternius, CC0): textura, ORM, relevo e
// um segundo relevo de quinas gastas (2º UV), com sujeira escorrendo onde a cor do vértice manda.
// Mudança do Nephelia: o relevo comprimido para celular (RGTC/ETC2 RG) só guarda x e y; o z era
// lido da textura (vinha 0 e as paredes brilhavam granuladas) e agora é calculado.
uniform sampler2D albedo : source_color;
uniform sampler2D base_normal : hint_normal;
uniform sampler2D detail_normal : hint_normal;
uniform sampler2D orm : hint_roughness_g;
uniform sampler2D wear_texture : hint_default_white;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 wear_color : source_color = vec4(0.292, 0.292, 0.292, 1.0);
uniform bool use_wear_color = true;
uniform bool use_detail_normal = true;
uniform float detail_normal_intensity : hint_range(0.0, 1.0) = 1.0;
// Relevo de -1 a 1 a partir de x e y (z sempre para fora).
vec3 unpack_normal(vec2 xy) {
    vec2 n = xy * 2.0 - 1.0;
    return vec3(n, sqrt(max(1.0 - dot(n, n), 0.0)));
}

void fragment() {
    vec3 base = texture(albedo, UV).rgb * color_tint.rgb;
    float wear_mask = texture(wear_texture, UV).r;
    float vertex_wear = (1.0 - COLOR.g) * (1.0 - COLOR.b);
    float wear_amount = wear_mask * vertex_wear;
    vec3 worn = base * wear_color.rgb;
    ALBEDO = use_wear_color ? mix(base, worn, wear_amount) : base;
    vec3 orm_tex = texture(orm, UV).rgb;
    AO = orm_tex.r;
    ROUGHNESS = orm_tex.g;
    METALLIC = orm_tex.b;
    vec3 t = unpack_normal(texture(base_normal, UV).rg);
    if (use_detail_normal) {
        vec3 u = unpack_normal(texture(detail_normal, UV2).rg);
        u = mix(vec3(0.0, 0.0, 1.0), u, detail_normal_intensity);
        u = u * vec3(-1.0, -1.0, 1.0);
        t = t + vec3(0.0, 0.0, 1.0);
        vec3 blended = t * dot(t, u) - u * t.z;
        NORMAL_MAP = normalize(blended) * 0.5 + 0.5;
    } else {
        NORMAL_MAP = t * 0.5 + 0.5;
    }
}