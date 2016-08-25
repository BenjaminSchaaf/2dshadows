module globjects;

import std.file;
import std.path;
import std.stdio;

import core.exception;

import derelict.opengl3.gl;
import derelict.glfw3.glfw3;
import gl3n.linalg;

//==============================================================================
//                                Exceptions
//==============================================================================

class CompilerError : Error {
    this(Args...)(Args args) { super(args); }
}
class LinkError : Error {
    this(Args...)(Args args) { super(args); }
}

//==============================================================================
//                          Transformation Objects
//==============================================================================

class Transform {
    vec2 position = vec2(0, 0);
    float rotation = 0;
    vec2 scale = vec2(1, 1);

    @property
    mat3 matrix() {
        mat3 mat = mat3.identity;
        mat.scale(scale.x, scale.y, 1);
        mat.rotate(rotation, vec3(0, 0, 1));
        mat.translate(position.x, position.y, 1);
        return mat;
    }
}

class GameObject:Transform {
    Mesh mesh;

    this(Mesh mesh) {
        this.mesh = mesh;
    }
}

class Light:Transform {
    vec4 color = vec4(1, 1, 1, 1);
    float linearFO = 1.0;
    float quadraticFO = 0.0;
    float intensity = 1;
    float softness = 5;
}

class Camera:Transform {
    @property
    override mat3 matrix() {
        mat3 mat = mat3.identity;
        mat.translate(-position.x, -position.y, 0);
        mat.rotate(rotation, vec3(0, 0, -1));
        mat.scale(1/scale.x, 1/scale.y, 1);
        return mat;
    }

    vec2 cameraToWorld(vec2 pos) {
        // Convert screen coords to clip space
        pos.x = 2*pos.x - 1;
        pos.y = 2*pos.y - 1;
        pos = vec2(matrix.inverse * vec3(pos, 1));
        return pos;
    }
}

//==============================================================================
//                         Vertex Buffer Objects
//==============================================================================

class Mesh {
    const GLuint id;
    const GLenum type;
    private float[] data;

    this(vec2[] vertices, GLenum type = GL_TRIANGLES) {
        this.type = type;

        GLuint id;
        glGenBuffers(1, &id);
        this.id = id;

        data = new float[vertices.length * 2];
        foreach (size_t i; 0..vertices.length) {
            data[2*i + 0] = vertices[i].x;
            data[2*i + 1] = vertices[i].y;
        }

        bind();
        glBufferData(GL_ARRAY_BUFFER, float.sizeof * data.length, data.ptr, GL_STATIC_DRAW);
    }
    ~this() {
        glDeleteBuffers(1, &id);
    }

    void bind() {
        glBindBuffer(GL_ARRAY_BUFFER, id);
    }

    void draw() {
        glVertexPointer(2, GL_FLOAT, 0, null);
        glDrawArrays(type, 0, cast(int)(data.length / 2));
    }
}

//==============================================================================
//                          Framebuffer Objects
//==============================================================================

class Framebuffer {
    const GLuint id;
    private FramebufferAttachment[4] color_attachments;
    private FramebufferAttachment depth_attachment = null;

    this() {
        GLuint id;
        glGenFramebuffers(1, &id);
        this.id = id;
        bind();
    }
    ~this() {
        glDeleteFramebuffers(1, &id);
    }

    @property FramebufferAttachment color() {
        return color_attachments[0];
    }

    @property
    FramebufferAttachment[4] colors() {
        return color_attachments;
    }

    @property
    FramebufferAttachment depth() {
        return depth_attachment;
    }

    void attachColor(Texture2D texture, int point = 0) {
        attach(texture, GL_COLOR_ATTACHMENT0 + point);
        color_attachments[point] = texture;
    }
    void attachDepth(Texture2D texture) {
        attach(texture, GL_DEPTH_ATTACHMENT);
        depth_attachment = texture;
    }

    private void attach(Texture2D texture, GLenum attachment) {
        GLuint id;
        if (texture !is null) {
            texture.bind();
            id = texture.id;
        } else {
            id = 0;
        }

        glFramebufferTexture2D(GL_FRAMEBUFFER, attachment,
                               GL_TEXTURE_2D, id, 0);
    }

    void setSize(uint width, uint height) {
        // Color attachments
        foreach (FramebufferAttachment obj; color_attachments) {
            if (obj !is null) {
                obj.setSize(width, height);
            }
        }
        if (depth_attachment !is null) {
            depth_attachment.setSize(width, height);
        }
    }

    void bind() {
        glBindFramebuffer(GL_FRAMEBUFFER, id);
    }

    static void unbind() {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
}

abstract class FramebufferAttachment {
    const GLuint id;

    void bind();
    void setSize(uint width, uint height);
}

class Texture2D : FramebufferAttachment {
    const GLuint id;
    const GLenum format;
    const GLenum representation;

    this(uint width, uint height, GLenum format = GL_RGBA,
        GLenum representation = GL_UNSIGNED_BYTE, GLenum interp = GL_LINEAR) {
        GLuint id;
        glGenTextures(1, &id);
        this.id = id;
        this.format = format;
        this.representation = representation;

        bind();
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, interp);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, interp);
        setSize(width, height);
    }

    override void bind() {
        glBindTexture(GL_TEXTURE_2D, id);
    }

    static void unbind() {
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    override void setSize(uint width, uint height) {
        bind();
        glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0,
                     format, representation, cast(GLvoid*)null);
    }
}

//==============================================================================
//                          Shader Program Objects
//==============================================================================

class Shader {
    const GLuint id;
    const GLenum type;

    this(string path) {
        string ext = extension(path);
        if (ext == ".vert") {
            type = GL_VERTEX_SHADER;
        } else if (ext == ".frag") {
            type = GL_FRAGMENT_SHADER;
        } else {
            throw new Exception("Invalid file extension");
        }

        string source = cast(string)read(path);
        try {
            this(source, type);
        } catch (Exception e) {
            // Append path to error message
            e.msg = path ~ ":\n" ~ e.msg;
            throw e;
        }
    }
    this(string source, GLenum type) {
        this.type = type;
        id = glCreateShader(type);

        // Apply source
        int lengths = cast(int)source.length;
        char* csource = cast(char*)source;
        glShaderSource(id, 1, &(csource), &lengths);

        // Compile
        glCompileShader(id);

        // Get errors
        GLint error;
        glGetShaderiv(id, GL_COMPILE_STATUS, &error);
        if (error != GL_TRUE) {
            // Grab Info Log
            int info_log_length;
            glGetShaderiv(id, GL_INFO_LOG_LENGTH, &info_log_length);
            char[] info_log = new char[info_log_length];
            glGetShaderInfoLog(id, info_log_length, cast(GLint*)null, cast(GLchar*)info_log);
            throw new CompilerError("Shader Compiler Error\n" ~ cast(string)info_log);
        }
    }
    ~this() {
        glDeleteShader(id);
    }
}

class Program {
    const GLuint id;
    const int[string] attributes;
    Uniform[string] uniforms;

    this(Shader[] shaders...) {
        id = glCreateProgram();

        foreach (Shader shader; shaders) {
            glAttachShader(id, shader.id);
        }

        glLinkProgram(id);

        GLint error;
        glGetProgramiv(id, GL_LINK_STATUS, &error);
        if (error != GL_TRUE) {
            // Grab Info Log
            int info_log_length;
            glGetProgramiv(id, GL_INFO_LOG_LENGTH, &info_log_length);
            char[] info_log = new char[info_log_length];
            glGetProgramInfoLog(id, info_log_length, cast(GLint*)null, cast(GLchar*)info_log);
            throw new LinkError("Program Link Error\n" ~ cast(string)info_log);
        }

        // Grab attributes
        int[string] attributes;
        int num;
        glGetProgramiv(id, GL_ACTIVE_ATTRIBUTES, &num);
        foreach (int i; 0..num) {
            char[] name = new char[30];
            GLsizei length;
            glGetActiveAttrib(id, i, 30, &length, cast(GLint*)null,
                              cast(GLenum*)null, cast(GLchar*)name);

            // Strip other characters
            name = name[0..length];
            attributes[cast(string)name] = i;
        }
        this.attributes = attributes;

        // Grab uniforms
        glGetProgramiv(id, GL_ACTIVE_UNIFORMS, &num);
        foreach (int i; 0..num) {
            char[] name = new char[30];
            GLsizei length;
            glGetActiveUniform(id, i, 30, &length, cast(GLint*)null,
                               cast(GLenum*)null, cast(GLchar*)name);

            // Strip other characters
            name = name[0..length];
            uniforms[cast(string)name] = new Uniform(this, i);
        }
    }
    ~this() {
        glDeleteProgram(id);
    }

    void use() {
        glUseProgram(id);
    }
}

class Uniform {
    const GLint id;
    const Program program;

    this(Program program, GLint id) {
        this.program = program;
        this.id = id;
    }

    void set(T)(T v) {
        static if (is(T == float)) {
            glUniform1f(id, v);
        } else static if (is(T == int)) {
            glUniform1i(id, v);
        } else static if (is(T == vec2)) {
            glUniform2f(id, v.x, v.y);
        } else static if (is(T == vec3)) {
            glUniform3f(id, v.x, v.y, v.z);
        } else static if (is(T == vec4)) {
            glUniform4f(id, v.x, v.y, v.z, v.w);
        } else static if (is(T == quat)) {
            glUniform4f(id, v.x, v.y, v.z, v.w);
        } else static if (is(T == mat2)) {
            glUniformMatrix2fv(id, 1, GL_FALSE, v.value_ptr);
        } else static if (is(T == mat3)) {
            glUniformMatrix3fv(id, 1, GL_FALSE, v.value_ptr);
        } else static if (is(T == mat4)) {
            glUniformMatrix4fv(id, 1, GL_FALSE, v.value_ptr);
        } else static if (is(T == vec2i)) {
            glUniform2i(id, v.x, v.y);
        } else static if (is(T == vec3i)) {
            glUniform3i(id, v.x, v.y, v.z);
        } else static if (is(T == vec4i)) {
            glUniform4i(id, v.x, v.y, v.z, v.w);
        } else static if (is(T == Texture2D)) {
            glUniform1i(v.id);
        } else {
            static assert(0);
        }
    }
}

//==============================================================================
//                         Conveniance Functions
//==============================================================================

private enum ERRORS = [
    GL_INVALID_ENUM: "Invalid Enum",
    GL_INVALID_VALUE: "Invalid Value",
    GL_INVALID_OPERATION: "Invalid Operation",
    GL_INVALID_FRAMEBUFFER_OPERATION: "Invalid FBO Operation",
    GL_OUT_OF_MEMORY: "Out of Memory",
];

void checkError() {
    auto err = glGetError();
    if (err != GL_NO_ERROR) {
        throw new Exception(ERRORS[err]);
    }
}

@property
void clearColor(vec4 c) {
    glClearColor(c.r, c.g, c.b, c.a);
}
@property
vec4 clearColor() {
    float[4] c;
    glGetFloatv(GL_COLOR_CLEAR_VALUE, cast(GLfloat*)c);
    return vec4(c);
}

@property
void blend(bool t) {
    t ? glEnable(GL_BLEND) : glDisable(GL_BLEND);
}
@property
bool blend() {
    bool t;
    glGetBooleanv(GL_BLEND, cast(GLboolean*)t);
    return t;
}
