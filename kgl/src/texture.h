#ifndef TEXTURE_H
#define TEXTURE_H
#ifdef _WIN32
#include <windows.h>
#endif
#include <gl/gl.h>
#include "utils.h"
#include <map>

/*
*	Class for representing textures
*	We assume 2D textures only for this, since we are loading from image files
*	TODO: add mipmaps and jpegs
*/

class Texture
{
public:
    Texture(const char *filename, bool mipmap = false);
    Texture(const Texture &other);
    virtual ~Texture();
    void bind(GLenum target = GL_TEXTURE_2D);
    void bindToImage(GLuint unit, GLenum access, GLenum format, GLuint level = 0);
    GLuint getID();
private:
    bool init(const char *filename);
    bool loadPng(const char *filename);
    bool loadJpg(const char *filename);
    void sendGL(const GLvoid *data);

    GLuint id_;
    int2 dims_;
};
#endif // TEXTURE_H
