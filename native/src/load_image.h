#include <stddef.h>
#include <stdint.h>

typedef struct {
    uint8_t* pixels;
    size_t w;
    size_t h;
    size_t channels;
} image_t;

image_t load_image(const char* filename);
void free_image(image_t);
