#include "load_image.h"
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#include "stb_image.h"
#include <stdio.h>

image_t load_image(const char* filename) {
    int x = 0;
    int y = 0;
    int channels = 0;
    stbi_uc* image = stbi_load(filename, &x, &y, &channels, STBI_default);

    return (image_t) {
        .pixels = image,
        .w = x,
        .h = y,
        .channels = channels,
    };
}

void free_image(image_t img) {
    free(img.pixels);
}
