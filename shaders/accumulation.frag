#version 130
/*Accumulation Fragment Shader

Samples texture directly to the output color buffer,
from the input color buffer.
*/

//The input buffer
uniform sampler2D color_buffer;

//This fragments texture coordinate
varying vec2 texture_coordinate;

void main() {
    //Sample from the color buffer directly.
    vec4 color = texture2D(color_buffer, texture_coordinate);
    gl_FragColor = color * color.a;
}
