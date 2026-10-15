shader_type canvas_item;

uniform vec4 crystal_color : source_color = vec4(0.06, 0.0, 0.06, 0.8);
// Controls the thickness of the border line
uniform float border_thickness : hint_range(0.0, 0.5) = 0.05;
// Controls how blurry/soft the glow is
uniform float softness : hint_range(0.01, 1.0) = 0.05;

group_uniforms Center_Window;
uniform float center_width = 0.4;
uniform float center_height = 0.3;

group_uniforms Side_Windows;
uniform float side_width = 0.15;
uniform float side_height = 0.2;
uniform float side_spacing = 0.6;
uniform float side_warp = 0.3;

void fragment() {
	// 1. ASPECT RATIO CORRECTION
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 centered_uv = (UV - 0.5) * (size / min(size.x, size.y));
	
	// 2. CENTER WINDOW SDF
	vec2 ctr_d = abs(centered_uv) - vec2(center_width, center_height);
	float ctr_dist = length(max(ctr_d, 0.0)) + min(max(ctr_d.x, ctr_d.y), 0.0);
	
	// 3. WARPED SIDE WINDOWS SDF
	float side_center_x = side_spacing * 0.5;
	float local_side_x = abs(centered_uv.x) - side_center_x;
	float warp_factor = 1.0 - (local_side_x * side_warp);
	float dynamic_height = side_height * warp_factor;
	
	vec2 side_d = abs(vec2(local_side_x, centered_uv.y)) - vec2(side_width, dynamic_height);
	float side_dist = length(max(side_d, 0.0)) + min(max(side_d.x, side_d.y), 0.0);
	
	// 4. COMBINE SHAPES (Union)
	float final_dist = min(ctr_dist, side_dist);
	
	// 5. THE BORDER LOGIC FIX
	// We only want to see color when final_dist is GREATER than 0 (outside)
	// but LESS than our thickness.
	
	// This creates a mask that is 0.0 inside the window and 1.0 outside
	float outer_mask = smoothstep(-softness, softness, final_dist);
	
	// This creates a falloff so it fades out as it gets further away
	float limit_mask = 1.0 - smoothstep(border_thickness - softness, border_thickness, final_dist);
	
	// Final visibility: Only show the "crust" outside the window
	float border_mask = outer_mask * limit_mask;
	
	// 6. FINAL COLOR
	COLOR = vec4(crystal_color.rgb, crystal_color.a * border_mask);
}
