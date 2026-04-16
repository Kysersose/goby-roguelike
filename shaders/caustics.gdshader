shader_type canvas_item;

uniform float opacity : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tint : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform float drift_speed : hint_range(0.0, 2.0) = 0.25;
uniform float scale : hint_range(1.0, 100.0) = 8.0;
uniform float band_min : hint_range(0.0, 1.0) = 0.45;
uniform float band_max : hint_range(0.0, 1.0) = 0.85;
uniform float wobble : hint_range(0.0, 3.0) = 1.6;

vec2 rot(vec2 uv, float a) {
	float c = cos(a); float s = sin(a);
	return vec2(uv.x * c + uv.y * s, -uv.x * s + uv.y * c);
}

float layer(vec2 uv, float angle, float sp, float ph, float wb) {
	float t = TIME * sp + ph;
	vec2 r = rot(uv, angle);
	float u = r.x;
	float v = r.y;
	float w1 = sin(v        + sin(u * 0.22 + t * 0.71) * wb + t);
	float w2 = sin(v * 1.27 + cos(u * 0.38 - t * 0.53) * (wb * 0.75) + t * 0.83);
	float w3 = sin(v * 0.81 + sin(u * 0.55 + t * 0.44) * (wb * 0.55) - t * 0.60);
	return ((w1 + w2 + w3) / 3.0) * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = UV * scale;

	float L1 = layer(uv, radians(18.0),  drift_speed * 1.00, 0.00, wobble);
	float L2 = layer(uv, radians(67.0),  drift_speed * 0.73, 2.09, wobble * 0.85);
	float L3 = layer(uv, radians(130.0), drift_speed * 0.55, 4.19, wobble * 0.70);
	float L4 = layer(uv, radians(195.0), drift_speed * 0.88, 1.30, wobble * 0.90);

	float caustic = (L1 + L2 + L3 + L4) * 0.25;
	caustic = pow(caustic, 1.8);
	caustic = smoothstep(band_min, band_max, caustic);

	vec2 slow = rot(UV * 2.5, radians(40.0));
	float pulse = sin(slow.x + TIME * 0.07) * sin(slow.y + TIME * 0.05);
	pulse = pulse * 0.15 + 0.85;

	COLOR = vec4(tint.rgb, caustic * opacity * pulse);
}
