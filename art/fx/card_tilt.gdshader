shader_type canvas_item;
// Perspective tilt plus a moving sheen. Set as a Control's material and feed `tilt`
// (-1..1 on each axis, from the mouse over the card) via card_tilt.gd.
// `size_px` must be the control's size in pixels (card_tilt.gd keeps it updated).

uniform vec2 tilt = vec2(0.0);
uniform vec2 size_px = vec2(100.0);
uniform float max_angle = 0.23;
uniform float perspective = 0.5;
uniform float sheen_strength = 0.22;

varying vec2 v_uv;

void vertex() {
	vec2 c = (VERTEX / size_px - 0.5) * 2.0;
	float ax = tilt.y * max_angle;
	float ay = -tilt.x * max_angle;
	float z = c.x * sin(ay) - c.y * sin(ax);
	float k = 1.0 / (1.0 + z * perspective * 0.5);
	vec2 centre = size_px * 0.5;
	VERTEX = centre + (VERTEX - centre) * vec2(cos(ay), cos(ax)) * k;
	v_uv = VERTEX / size_px;
}

void fragment() {
	vec4 col = COLOR;
	float d = dot(v_uv - 0.5, normalize(vec2(1.0, -0.6))) - tilt.x * 0.35 + tilt.y * 0.2;
	float band = smoothstep(0.18, 0.0, abs(d));
	float active_amt = step(0.01, abs(tilt.x) + abs(tilt.y));
	col.rgb += band * sheen_strength * col.a * active_amt;
	COLOR = col;
}
