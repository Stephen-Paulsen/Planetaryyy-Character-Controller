shader_type canvas_item;

uniform vec4 crystal_color : source_color = vec4(0.06, 0.0, 0.06, 0.8);
uniform float radius : hint_range(0.0, 1.0) = 0.8;
uniform float fresnel_power : hint_range(0.1, 10.0) = 1.8;

void fragment() {
	// 1. ASPECT RATIO CORRECTION
	// If your sprite is a rectangle, UV.x - 0.5 will be "off". 
	// This math ensures the circle stays a circle and stays centered.
	vec2 ratio = vec2(1.0, 1.0);
	// Get the size of the texture/sprite
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	
	// Adjust UVs so (0,0) is the center and it handles rectangles
	vec2 centered_uv = (UV - 0.5) * (size / min(size.x, size.y));
	
	// 2. DISTANCE
	float dist = length(centered_uv);
	
	// 3. FRESNEL (CLEAR MIDDLE)
	// We normalize the distance based on the radius
	float normalized_dist = clamp(dist / radius, 0.0, 1.0);
	float fresnel = pow(normalized_dist, fresnel_power);
	
	// 4. MASK
	// Sharper edge for that "lens" or "crystal" look
	float circle_mask = 1.0 - smoothstep(radius - 0.005, radius + 0.005, dist);
	
	// 5. FINAL COLOR
	COLOR = vec4(crystal_color.rgb, crystal_color.a * fresnel * circle_mask);
}
