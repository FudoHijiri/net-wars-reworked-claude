shader_type canvas_item;
// Restrained CRT scanline + vignette overlay for the monitor screen area. Draws thin
// horizontal lines and a soft edge darkening; deliberately subtle so dialogue and UI
// text stay fully readable.

uniform float line_spacing : hint_range(2.0, 12.0) = 4.0;
uniform float line_strength : hint_range(0.0, 0.5) = 0.12;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float line = sin(FRAGCOORD.y / line_spacing) * 0.5 + 0.5;
	float scanline = 1.0 - line * line_strength;

	vec2 centered = UV - vec2(0.5);
	float vignette = smoothstep(0.75, 0.35, length(centered)) ;
	vignette = mix(1.0 - vignette_strength, 1.0, vignette);

	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - scanline) + (1.0 - vignette) * 0.5);
}
