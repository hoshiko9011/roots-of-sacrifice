shader_type canvas_item;
render_mode unshaded;

// Source cinematic image sampled with crisp pixels and no edge wrapping.
uniform sampler2D scene_texture : filter_nearest, repeat_disable;
// Source image width divided by height, used to calculate the cover crop.
uniform float image_aspect = 1.5;
// Current viewport width divided by height, normally 16:9 on landscape screens.
uniform float view_aspect = 1.777777;
// Elapsed animation time in seconds, advanced by the game or preview scene.
uniform float motion_time = 0.0;
// Disables all camera and environmental motion while preserving the base image.
uniform bool motion_enabled = true;

// Return a feathered mask for a softly edged axis-aligned rectangle.
float soft_box(vec2 point, vec2 center, vec2 half_size, float feather) {
	vec2 distance_to_edge = abs(point - center) - half_size;
	return 1.0 - smoothstep(-feather, feather, max(distance_to_edge.x, distance_to_edge.y));
}

// Return a feathered mask for a softly edged ellipse in UV space.
float soft_ellipse(vec2 point, vec2 center, vec2 radius, float feather) {
	float distance_to_edge = length((point - center) / radius) - 1.0;
	return 1.0 - smoothstep(-feather, feather, distance_to_edge);
}

// Crop UVs to cover the viewport without stretching the source image.
vec2 cover_uv(vec2 uv) {
	if (image_aspect > view_aspect) {
		uv.x = (uv.x - 0.5) * (view_aspect / image_aspect) + 0.5;
	} else {
		uv.y = (uv.y - 0.5) * (image_aspect / view_aspect) + 0.5;
	}
	return uv;
}

// Composite the cinematic camera move with localized environmental animation.
void fragment() {
	vec2 base_uv = cover_uv(UV);
	if (!motion_enabled) {
		COLOR = texture(scene_texture, base_uv);
	} else {
		float progress = clamp(motion_time / 12.0, 0.0, 1.0);
	// Ease a subtle 1.8% push-in toward the garden over twelve seconds.
	float eased = progress * progress * (3.0 - 2.0 * progress);
	vec2 focus = vec2(0.62, 0.56);
	vec2 camera_uv = (base_uv - focus) / (1.0 + eased * 0.018) + focus;

	// Limit leaf and flower sway to feathered regions of the foreground.
	float left_leaves = soft_box(base_uv, vec2(0.17, 0.26), vec2(0.24, 0.27), 0.055);
	float right_leaves = soft_box(base_uv, vec2(0.88, 0.50), vec2(0.16, 0.34), 0.05);
	float flowers = soft_box(base_uv, vec2(0.57, 0.83), vec2(0.38, 0.14), 0.045);
	float leaf_mask = max(max(left_leaves, right_leaves), flowers);
	vec2 wind_offset = vec2(
		sin(base_uv.y * 92.0 + motion_time * 1.15) * 0.00125 + sin(base_uv.x * 126.0 - motion_time * 0.82) * 0.0007,
		cos(base_uv.x * 88.0 + motion_time * 0.92) * 0.00065
	) * leaf_mask;

	// Drift only the cloud band horizontally to suggest slow atmospheric motion.
	float clouds = soft_box(base_uv, vec2(0.72, 0.17), vec2(0.31, 0.15), 0.045);
	vec2 cloud_offset = vec2(sin(motion_time * 0.075) * 0.0028 + sin(base_uv.y * 54.0) * 0.00035, 0.0) * clouds;

	// Apply two-dimensional ripples exclusively within the pool and fountain masks.
	float pool = soft_box(base_uv, vec2(0.67, 0.79), vec2(0.23, 0.17), 0.035);
	float fountain = soft_box(base_uv, vec2(0.60, 0.61), vec2(0.10, 0.13), 0.025);
	float water_mask = max(pool, fountain);
	vec2 water_offset = vec2(
		sin(base_uv.y * 210.0 - motion_time * 1.65) * 0.00075,
		sin(base_uv.x * 176.0 + motion_time * 1.95) * 0.00085
	) * water_mask;

	// Combine camera and parallax offsets, then clamp sampling inside the texture.
	vec2 animated_uv = clamp(camera_uv + wind_offset + cloud_offset + water_offset, vec2(0.001), vec2(0.999));
	vec3 color = texture(scene_texture, animated_uv).rgb;

	// Keep the character stable by restoring static pixels inside its body mask.
	float head = soft_ellipse(base_uv, vec2(0.305, 0.405), vec2(0.061, 0.077), 0.018);
	float body = soft_ellipse(base_uv, vec2(0.315, 0.665), vec2(0.102, 0.218), 0.022);
	float legs = soft_box(base_uv, vec2(0.315, 0.915), vec2(0.076, 0.095), 0.018);
	float arm = soft_box(base_uv, vec2(0.255, 0.705), vec2(0.043, 0.15), 0.02);
	float character_mask = max(max(head, body), max(legs, arm));
	vec3 character = texture(scene_texture, base_uv).rgb;
	color = mix(color, character, character_mask);

	// Animate the scarf independently while retaining its position on the character.
	float scarf = soft_box(base_uv, vec2(0.274, 0.485), vec2(0.083, 0.054), 0.014);
	vec2 scarf_offset = vec2(
		sin(motion_time * 1.35 + base_uv.y * 46.0) * 0.00155,
		cos(motion_time * 1.08) * 0.00075
	) * scarf;
	vec3 scarf_color = texture(scene_texture, clamp(base_uv + scarf_offset, vec2(0.001), vec2(0.999))).rgb;
	color = mix(color, scarf_color, scarf);

	// Add a restrained warm highlight ripple and output the opaque final color.
	float ripple = sin(base_uv.x * 154.0 + base_uv.y * 82.0 + motion_time * 1.75) * sin(base_uv.y * 118.0 - motion_time * 1.25);
	color += vec3(0.032, 0.019, 0.005) * ripple * pool;
	COLOR = vec4(color, 1.0);
	}
}
