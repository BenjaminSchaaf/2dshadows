#version 130
/*Accumulation Vertex Shader

Expects to be called on a full-screen quad in clip space.
*/

//The varying texture coordinate of every vertex.
varying vec2 texture_coordinate;

void main() {
    //convert vertex to 2d
    vec2 position = vec2(gl_Vertex);
    
    //Calculate texture coordinate for the vertex
    texture_coordinate = (position - vec2(1.0))/2.0;
    
    gl_Position = vec4(position, 0.0, 1.0);
}