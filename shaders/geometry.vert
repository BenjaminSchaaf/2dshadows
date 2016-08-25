#version 130

uniform mat3 camera_matrix;
uniform mat3 object_matrix;

void main() {
    vec2 position = (vec3(gl_Vertex.xy, 1.0) * object_matrix * camera_matrix).xy;

    gl_Position = vec4(position, 0.0, 1.0);
}
