#version 130

uniform mat3 light_matrix;

varying vec2 relative_position;

void main() {
    // Grab the relative position
    relative_position = gl_Vertex.xy;

    // Get vertex coordinate in clip space
    vec2 vertex_position = (vec3(relative_position, 1.0) * light_matrix).xy;
    gl_Position = vec4(vertex_position, 0.0, 1.0);
}
