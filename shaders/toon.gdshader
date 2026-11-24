// Toon ("ink") shading for 3D characters and props. Hard light bands, no gradients, plus an
// optional rim light (the hero's demon glow). Pair with outline.gdshader as next_pass.
// Character3D.apply_toon() sets this up from a model's own materials automatically.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float bands : hint_range(2.0, 4.0) = 3.0;     // number of light steps
uniform float shade_floor : hint_range(0.0, 1.0) = 0.35; // darkest band (ambient adds on top)
uniform vec4 rim_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.0; // 0 = no rim
uniform float rim_width : hint_range(0.05, 0.8) = 0.3;
uniform float flash : hint_range(0.0, 1.0) = 0.0;          // hit flash (Character3D.hit)

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_color.rgb * rim_strength * step(1.0 - rim_width, fres) + vec3(flash);
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float stepped = floor(ndl * bands) / (bands - 1.0);
	float lit = mix(shade_floor, 1.0, clamp(stepped, 0.0, 1.0));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
}
