#version 130

// The color buffer to grab alpha values from
uniform sampler2D color_buffer;

uniform mat3 light_matrix;

varying float light_distance;
varying float light_angle;

void main() {
    // Get the position of the pixel relative to the light in light space
    vec2 rel_pos = vec2(cos(light_angle), sin(light_angle)) * light_distance;

    // convert light space to clip space
    vec2 clip_pos = (vec3(rel_pos, 1.0) * light_matrix).xy;
    // Transform to texture coordinates
    vec2 tex_pos = clip_pos * 0.5 + vec2(0.5);

    // Sample the alpha
    float alpha = texture2D(color_buffer, tex_pos).a;

    float shadow = 1.0 - light_distance;

    // If the alpha < 1.0, fragDepth = 1.0
    // Otherwise fragDepth = shadow
    gl_FragDepth = 1.0 - min(step(1.0, alpha), shadow);
}
