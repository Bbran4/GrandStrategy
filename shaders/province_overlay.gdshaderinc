// Province IDs are data: NEVER apply source_color, mipmaps or linear filtering.
group_uniforms provinces;
uniform bool province_overlay_enabled = false;
uniform int province_view_mode = 0;
uniform bool province_borders_enabled = true;
uniform bool province_neutral_base = false;
uniform sampler2D province_id_map : filter_nearest, repeat_disable;
uniform sampler2D territory_id_map : filter_nearest, repeat_disable;
uniform sampler2D province_color_lookup : source_color, filter_nearest, repeat_disable;
uniform sampler2D territory_color_lookup : source_color, filter_nearest, repeat_disable;
uniform sampler2D province_owner_lookup : source_color, filter_nearest, repeat_disable;
uniform sampler2D province_owner_ids : filter_nearest, repeat_disable;
uniform sampler2D province_border_distance : filter_linear, repeat_disable;
uniform vec2 province_world_size = vec2(1024.0, 512.0);
uniform vec2 province_raster_size = vec2(2048.0, 1024.0);
uniform int province_selected_id = 0;
uniform int province_hovered_id = 0;
uniform float province_fill_opacity : hint_range(0.0, 1.0) = 0.7;
group_uniforms;

int province_decode(vec3 data) {
	ivec3 bytes = ivec3(round(data * 255.0));
	return bytes.r * 65536 + bytes.g * 256 + bytes.b;
}
vec3 province_lookup_color(sampler2D lookup_map, int id) {
	return texelFetch(lookup_map, ivec2(id % 256, id / 256), 0).rgb;
}
// Water annotations are composited as unlit surface ink by the ocean shader.
vec3 province_apply_surface(vec2 world, vec3 base, bool water_surface, out float coverage) {
	coverage = 0.0;
	if (!province_overlay_enabled) { return base; }
	vec2 uv = world / province_world_size;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) { return base; }
	int province = province_decode(texture(province_id_map, uv).rgb);
	if (province == 0) { return base; }
	int territory = province_decode(texture(territory_id_map, uv).rgb);
	float land = texelFetch(province_color_lookup, ivec2(province % 256, province / 256), 0).a;
	// Never paint water IDs onto the seabed (or land IDs onto breaking waves).
	if (water_surface == (land > 0.5)) { return base; }
	float opacity = province_fill_opacity * land;
	vec3 result = province_neutral_base && land > 0.5 ? vec3(0.5) : base;
	if (province_view_mode == 1) {
		result = mix(result, province_lookup_color(province_color_lookup, province), opacity);
	} else if (province_view_mode == 2) {
		result = mix(result, province_lookup_color(territory_color_lookup, territory), opacity);
	} else if (province_view_mode == 3) {
		result = mix(result, province_lookup_color(province_owner_lookup, province), opacity);
	}
	if (province_view_mode > 0) { coverage = opacity; }
	float footprint = max(length(dFdx(uv * province_raster_size)), length(dFdy(uv * province_raster_size)));
	vec2 distances = texture(province_border_distance, uv).rg * 32.0;
	float thin = 1.0 - smoothstep(min(4.0, max(0.5, footprint * 0.4)), min(4.0, max(0.5, footprint * 0.4)) + max(0.5, footprint * 0.6), distances.r);
	float thick = 1.0 - smoothstep(min(6.0, max(1.0, footprint * 0.9)), min(6.0, max(1.0, footprint * 0.9)) + max(0.5, footprint * 0.6), distances.g);
	if (province_view_mode == 3) {
		int owner = province_decode(texelFetch(province_owner_ids, ivec2(province % 256, province / 256), 0).rgb);
		vec2 probe = min(vec2(6.0), max(vec2(1.0), fwidth(uv * province_raster_size) * 1.8)) / province_raster_size;
		float country_edge = 0.0;
		for (int i = 0; i < 4; i++) {
			vec2 offset = i == 0 ? vec2(probe.x, 0.0) : i == 1 ? vec2(-probe.x, 0.0) : i == 2 ? vec2(0.0, probe.y) : vec2(0.0, -probe.y);
			int other_province = province_decode(texture(province_id_map, uv + offset).rgb);
			int other_owner = province_decode(texelFetch(province_owner_ids, ivec2(other_province % 256, other_province / 256), 0).rgb);
			if (owner != other_owner) { country_edge = 1.0; }
		}
		thick = (1.0 - smoothstep(max(1.0, footprint), max(1.0, footprint) + max(0.5, footprint * 0.6), distances.r)) * country_edge;
	}
	if (province_borders_enabled) {
		float thin_alpha = thin * 0.65;
		float thick_alpha = thick * 0.9;
		result = mix(result, mix(vec3(0.015, 0.04, 0.07), vec3(0.09, 0.085, 0.07), land), thin_alpha);
		result = mix(result, mix(vec3(0.01, 0.025, 0.045), vec3(0.035, 0.03, 0.025), land), thick_alpha);
		coverage = 1.0 - (1.0 - coverage) * (1.0 - thin_alpha) * (1.0 - thick_alpha);
	}
	float highlight_mask = water_surface ? thin : 1.0;
	if (province == province_hovered_id && province_hovered_id != 0) {
		float hover_alpha = 0.2 * highlight_mask;
		result = mix(result, vec3(1.0), hover_alpha);
		coverage = 1.0 - (1.0 - coverage) * (1.0 - hover_alpha);
	}
	if (province == province_selected_id && province_selected_id != 0) {
		float selected_alpha = 0.25 * highlight_mask;
		result = mix(result, vec3(0.95, 0.67, 0.15), selected_alpha);
		result = mix(result, vec3(1.0, 0.72, 0.16), thin);
		coverage = 1.0 - (1.0 - coverage) * (1.0 - selected_alpha) * (1.0 - thin);
	}
	return result;
}

// Terrain overlays affect land only; the seabed stays free of political markings.
vec3 province_apply(vec2 world, vec3 base) {
	float coverage;
	return province_apply_surface(world, base, false, coverage);
}
