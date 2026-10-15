shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

uniform sampler2D hud_texture : filter_linear; 
uniform float hud_fov_h = 100.0;
uniform float hud_fov_v = 80.0;

uniform vec2 hud_scale = vec2(0.5, 0.1); 
uniform vec2 hud_offset = vec2(0.5, 0.1); 

group_uniforms Center_Window;
uniform float center_width : hint_range(0.1, 2.0) = 0.751;
uniform float center_height : hint_range(0.1, 2.0) = 1.15;
uniform float center_softness : hint_range(0.1, 10.0) = 10.0;

group_uniforms Side_Windows;
uniform float side_width : hint_range(0.1, 1.0) = 0.296;
uniform float side_height : hint_range(0.1, 1.0) = 0.895;
uniform float window_spacing : hint_range(0.5, 3.0) = 2.1;
uniform float side_softness : hint_range(0.1, 10.0) = 10.0;
// Higher values make the inside edges TALLER than the outside edges
uniform float side_warp : hint_range(-2.0, 2.0) = 0.95;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(local_pos);
	
	float h_angle = atan(n.x, -n.z); 
	float v_angle = asin(n.y);

	vec2 hud_pos = vec2(
		degrees(h_angle) / (hud_fov_h * 0.5),
		degrees(v_angle) / (hud_fov_v * 0.5)
	);
	
	// --- Center Window ---
	float ctr_dist = max(abs(hud_pos.x) / center_width, abs(hud_pos.y) / center_height);
	float ctr_mask = pow(clamp(ctr_dist, 0.0, 1.0), center_softness);
	
	// --- Warped Side Windows ---
	// 1. Find the local X coordinate for the side windows
	float side_center_x = window_spacing * 0.5;
	float local_side_x = abs(hud_pos.x) - side_center_x;
	
	// 2. Calculate the Warp Factor
	// This looks at how far we are from the center of the side window.
	// Negative local_side_x means we are on the "inside" edge.
	float warp_factor = 1.0 - (local_side_x * side_warp);
	
	// 3. Apply Warp to the height
	// We divide the Y position by a modified height to "squash" or "stretch" it
	float dynamic_height = side_height * warp_factor;
	
	float side_dist = max(abs(local_side_x) / side_width, abs(hud_pos.y) / dynamic_height);
	float side_mask = pow(clamp(side_dist, 0.0, 1.0), side_softness);
	
	// --- Final Composition ---
	float final_window_mask = ctr_mask * side_mask;

	vec2 hud_uv = (hud_pos * hud_scale) + hud_offset;
	hud_uv.y = 1.0 - hud_uv.y; 

	vec4 helmet_base = vec4(0.0, 0.0, 0.0, 0.98); 
	float final_base_alpha = helmet_base.a * final_window_mask;

	if (hud_uv.x >= 0.0 && hud_uv.x <= 1.0 && hud_uv.y >= 0.0 && hud_uv.y <= 1.0) {
		vec4 tex_color = texture(hud_texture, hud_uv);
		ALBEDO = mix(helmet_base.rgb, tex_color.rgb, tex_color.a);
		ALPHA = max(final_base_alpha, tex_color.a);
	} else {
		ALBEDO = helmet_base.rgb;
		ALPHA = final_base_alpha;
	}
}
