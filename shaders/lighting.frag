#version 130

#define PI 3.14159265359
#define I_PI 0.31830988618

uniform sampler2D shadow_buffer;
uniform vec4 light_color;
uniform float light_linearFO;
uniform float light_quadraticFO;
uniform float light_softness;

varying vec2 relative_position;

float sample(float pos, float dist) {
    float shadow_dist = texture2D(shadow_buffer, vec2(pos, 0.0)).r;
    return step(dist, shadow_dist);
}

void main() {
    float frag_dist = length(relative_position);
    // Calculate the relative angle
    float angle = atan(relative_position.y, relative_position.x);
    // Convert to texture coordinates
    float tex_pos = angle * I_PI * 0.5 + 0.5;

    // blur
    float blur = smoothstep(0.0, 1.0, frag_dist) * light_softness / 800.0;

    float intensity = sample(tex_pos, frag_dist) * 0.16;

    intensity += sample(tex_pos - 4.0*blur, frag_dist) * 0.05;
    intensity += sample(tex_pos - 3.0*blur, frag_dist) * 0.09;
    intensity += sample(tex_pos - 2.0*blur, frag_dist) * 0.12;
    intensity += sample(tex_pos - 1.0*blur, frag_dist) * 0.15;

    intensity += sample(tex_pos + 1.0*blur, frag_dist) * 0.15;
    intensity += sample(tex_pos + 2.0*blur, frag_dist) * 0.12;
    intensity += sample(tex_pos + 3.0*blur, frag_dist) * 0.09;
    intensity += sample(tex_pos + 4.0*blur, frag_dist) * 0.05;


    // Apply shadowing
    intensity *= 1.0 - (light_linearFO * frag_dist
                        + light_quadraticFO * frag_dist * frag_dist);

    gl_FragColor = light_color * intensity;
}
