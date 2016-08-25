#version 130
#define M_PI 3.14159265359;

//The distance to the light in light space
varying float light_distance;
//The angle to the light in light space
varying float light_angle;

void main() {
    // The y of the vertex represents it's distance from the light origin in light space
    light_distance = gl_Vertex.y;

    // The x of the vertex represents the rotation, starting at -pi going to pi
    // We can calculate this here, as the only values of gl_Vertex.x will be -1 and 1
    light_angle = gl_Vertex.x * M_PI;

    // The actual vertex is on a line, not a plane. Only x value determines position
    gl_Position = vec4(gl_Vertex.x, 0.0, 0.0, 1.0);
}
