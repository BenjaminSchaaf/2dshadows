import std.stdio;
import std.file;
import std.path;
import std.math;
import std.conv;
import core.time;
import std.random;

import derelict.opengl3.gl;
import derelict.glfw3.glfw3;
import gl3n.linalg;

import globjects;
import gl = globjects;

static GLFWwindow* window;

int main() {
    DerelictGLFW3.load();
    DerelictGL.load();

    if (!glfwInit()) {
        writeln("Error Initializing GLFW");
        return -1;
    }

    glfwWindowHint(GLFW_RESIZABLE, true);
    window = glfwCreateWindow(size[0], size[1], "2D Shadows Sample", null, null);
    glfwMakeContextCurrent(window);
    glfwSwapInterval(0);
    glfwSetWindowSizeCallback(window, cast(GLFWwindowsizefun)&resizeFun);

    DerelictGL.reload();

    init();
    float dt = 0;
    while (!glfwWindowShouldClose(window)) {
        auto now = glfwGetTime();

        render(dt);

        glfwSwapBuffers(window);
        glfwPollEvents();

        dt = glfwGetTime() - now;
        writeln(to!string(cast(int)(1.0 / dt)) ~ "fps ");
    }
    writeln();

    glfwTerminate();
    return 0;
}

void resizeFun(GLFWwindow* window_, int width_, int height_) {
    int width, height;
    glfwGetWindowSize(window, &width, &height);

    size = [width, height];
    color_buffer.setSize(size[0], size[1]);

    camera.scale.x = size[0]/cast(float)size[1] * 4;
}

@property
vec2 mousePos() {
    double posx, posy;
    glfwGetCursorPos(window, &posx, &posy);
    return vec2(posx / cast(float)size[0], posy / cast(float)size[1]);
}

const int SHADOWMAP_SIZE = 512;
const int SHADOWMAP_POINTS = 200;

static int[2] size = [400, 1000];

static Program geometry;
static Program accumulation;
static Program lighting;
static Program shadowing;

static Framebuffer color_buffer;
static Framebuffer shadow_buffer;

static Mesh shadow_points;
static Mesh quad;
static Mesh[] meshes;
static Camera camera;
static GameObject[] objects;
static Light[] lights;

void init() {
    geometry = new Program(new Shader("shaders/geometry.vert"),
                           new Shader("shaders/geometry.frag"));
    accumulation = new Program(new Shader("shaders/accumulation.vert"),
                               new Shader("shaders/accumulation.frag"));
    lighting = new Program(new Shader("shaders/lighting.vert"),
                           new Shader("shaders/lighting.frag"));
    shadowing = new Program(new Shader("shaders/shadowing.vert"),
                            new Shader("shaders/shadowing.frag"));

    color_buffer = new Framebuffer();
    glActiveTexture(GL_TEXTURE0 + 1); // Color buffer is 0
    color_buffer.attachColor(new Texture2D(size[0], size[1]));
    glActiveTexture(GL_TEXTURE0);
    color_buffer.attachDepth(new Texture2D(size[0], size[1], GL_DEPTH_COMPONENT, GL_FLOAT));

    shadow_buffer = new Framebuffer();
    glActiveTexture(GL_TEXTURE0 + 2); // Shadow buffer is 1
    shadow_buffer.attachDepth(new Texture2D(SHADOWMAP_SIZE, 1, GL_DEPTH_COMPONENT, GL_FLOAT));
    glActiveTexture(GL_TEXTURE0);
    Texture2D.unbind();

    gl.clearColor = vec4(0);
    glClearDepth(1);
    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glBlendFunc(GL_ONE, GL_ONE);
    glEnableClientState(GL_VERTEX_ARRAY);


    vec2[] lines = new vec2[SHADOWMAP_POINTS * 2];
    foreach (int i; 0..SHADOWMAP_POINTS) {
        float pos = i / cast(float)SHADOWMAP_POINTS;
        lines[i*2 + 0] = vec2(-1, pos);
        lines[i*2 + 1] = vec2(1, pos);
    }
    shadow_points = new Mesh(lines, GL_LINES);


    quad = new Mesh([vec2(-1, -1),
                     vec2(1,  -1),
                     vec2(1,   1),
                     vec2(-1,  1)], GL_QUADS);

    meshes ~= quad;
    meshes ~= new Mesh([vec2(-1, -1),
                        vec2(0,   1),
                        vec2(-1,  1)], GL_TRIANGLES);

    addObjects(120);
    addLights(30);

    camera = new Camera();
    camera.scale.x = size[0]/cast(float)size[1];
    camera.scale *= 4;

    // Set default
    accumulation.use();
    accumulation.uniforms["color_buffer"].set(1);
    shadowing.use();
    shadowing.uniforms["color_buffer"].set(1);
    lighting.use();
    lighting.uniforms["shadow_buffer"].set(2);

    checkError();
}

void addObjects(size_t num) {
    foreach (size_t _; 0..num) {
        auto mesh = meshes[uniform(0, meshes.length)];
        auto obj = new GameObject(mesh);
        obj.rotation = uniform(-PI, PI);
        obj.position = vec2(uniform(-5.0, 5.0), uniform(-5.0, 5.0));
        obj.scale *= uniform(0.1, 0.4);
        objects ~= obj;
    }
}

void addLights(size_t num) {
    foreach (size_t _; 0..num) {
        auto light = new Light();
        light.position = vec2(uniform(-5.0, 5.0), uniform(-5.0, 5.0));
        light.color = vec4(uniform(0.1, 0.8), uniform(0.1, 0.8),
                           uniform(0.1, 0.8), uniform(0.1, 0.8));
        light.scale *= uniform(1.0, 2.0);
        lights ~= light;
    }
}

void render(float dt) {
    geometry_pass();
    shadow_pass();

    Framebuffer.unbind();
    gl.blend = true;
    accumulation.use();

    quad.bind();
    quad.draw();
    gl.blend = false;

    glFinish();

    if (glfwGetKey(window, GLFW_KEY_UP) != GLFW_RELEASE) {
        camera.position.y += 0.2 * dt;
    } if (glfwGetKey(window, GLFW_KEY_DOWN) != GLFW_RELEASE) {
        camera.position.y -= 0.2 * dt;
    } if (glfwGetKey(window, GLFW_KEY_RIGHT) != GLFW_RELEASE) {
        camera.position.x += 0.2 * dt;
    } if (glfwGetKey(window, GLFW_KEY_LEFT) != GLFW_RELEASE) {
        camera.position.x -= 0.2 * dt;
    } if (glfwGetKey(window, GLFW_KEY_Q) != GLFW_RELEASE) {
        camera.rotation += 0.1 * dt;
    } if (glfwGetKey(window, GLFW_KEY_E) != GLFW_RELEASE) {
        camera.rotation -= 0.1 * dt;
    }
    objects[$-1].position = camera.cameraToWorld(mousePos);
}

void geometry_pass() {
    glEnable(GL_DEPTH_TEST);

    color_buffer.bind();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    geometry.use();
    geometry.uniforms["camera_matrix"].set(camera.matrix);

    foreach (GameObject obj; objects) {
        geometry.uniforms["object_matrix"].set(obj.matrix);

        obj.mesh.bind();
        obj.mesh.draw();
    }
}

void shadow_pass() {
    Framebuffer.unbind();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Set unchanging uniforms
    mat3 camera_matrix = camera.matrix;

    foreach (Light light; lights) {
        mat3 light_matrix = camera_matrix * light.matrix;

        // Render the shadows
        shadow_buffer.bind();
        glViewport(0, 0, SHADOWMAP_SIZE, 1);
        glClear(GL_DEPTH_BUFFER_BIT);

        glEnable(GL_DEPTH_TEST);

        shadowing.use();
        shadowing.uniforms["light_matrix"].set(light_matrix);
        shadow_points.bind();
        shadow_points.draw();

        // Draw the light
        Framebuffer.unbind();
        glViewport(0, 0, size[0], size[1]);
        glDisable(GL_DEPTH_TEST);
        gl.blend = true;

        lighting.use();
        lighting.uniforms["light_matrix"].set(light_matrix);
        lighting.uniforms["light_color"].set(light.color);
        lighting.uniforms["light_linearFO"].set(light.linearFO);
        lighting.uniforms["light_quadraticFO"].set(light.quadraticFO);
        lighting.uniforms["light_softness"].set(light.softness);

        quad.bind();
        quad.draw();

        gl.blend = false;
    }
}
