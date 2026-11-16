shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float gain : hint_range(1.0, 12.0) = 4.2;
uniform float noise_strength : hint_range(0.0, 0.3) = 0.06;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.07;
uniform vec3 phosphor_color : source_color = vec3(0.24, 1.0, 0.42);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 src = textureLod(screen_texture, SCREEN_UV, 0.0);
	float lum = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
	
	// Pre-amplification with Reinhard highlight compression
	float amp = lum * gain + 0.03;
	float compressed = amp / (0.82 + amp);
	
	// Dynamic high-frequency phosphor scintillation grain
	vec2 grain_uv = SCREEN_UV + vec2(sin(TIME * 64.0), cos(TIME * 48.0)) * 0.03;
	float n = (hash(grain_uv * 850.0) - 0.5) * noise_strength;
	compressed = clamp(compressed + n, 0.0, 1.0);
	
	// Subtle cathode scanlines
	float scanline = sin(SCREEN_UV.y * 640.0) * scanline_strength;
	compressed = clamp(compressed - scanline, 0.0, 1.0);
	
	// Grade to Gen-3 green phosphor with highlight rollover
	vec3 green_tint = phosphor_color * compressed;
	vec3 hot_highlight = vec3(pow(compressed, 3.2) * 0.38);
	vec3 final_rgb = green_tint + hot_highlight;
	
	COLOR = vec4(final_rgb, 1.0);
}
