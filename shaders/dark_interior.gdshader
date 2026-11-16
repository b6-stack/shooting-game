shader_type spatial;
render_mode ambient_light_disabled, cull_back;

uniform vec4 albedo_color : source_color = vec4(0.22, 0.23, 0.25, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;

void fragment() {
	vec4 col = albedo_color;
	if (use_texture) {
		col *= texture(albedo_texture, UV);
	}
	ALBEDO = col.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
