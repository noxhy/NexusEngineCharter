shader_type canvas_item;

uniform float columns = 64.0;
uniform float rows = 36.0;
uniform float border_width = 0.05;
uniform vec4 border_color : source_color;


void fragment() {
    vec2 grid = fract(vec2(UV.x * columns, UV.y * rows));
	vec2 bottom_left = step(vec2(border_width), grid);
	vec2 top_right = step(vec2(border_width), 1.0 - grid);
	COLOR = border_color - (bottom_left.x * bottom_left.y * top_right.x * top_right.y);
}