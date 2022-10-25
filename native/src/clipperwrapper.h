#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    double x;
    double y;
} pointd_t;

typedef struct pathd_s pathd_t;

pathd_t* PathD_new(void);
void PathD_delete(pathd_t*);
void PathD_push_back(pathd_t*, double x, double y);
size_t PathD_size(pathd_t*);
pointd_t PathD_at(pathd_t*, size_t index);

typedef struct pathsd_s pathsd_t;

pathsd_t* PathsD_new(void);
void PathsD_delete(pathsd_t*);
void PathsD_push_back(pathsd_t*, pathd_t* path);
size_t PathsD_size(pathsd_t*);
pathd_t* PathsD_at(pathsd_t*, size_t index);

enum clip_type_e {
    CLIP_TYPE_NONE,
    CLIP_TYPE_INTERSECTION,
    CLIP_TYPE_UNION,
    CLIP_TYPE_DIFFERENCE,
    CLIP_TYPE_XOR,
};

enum fill_rule_e {
    FILL_RULE_EVEN_ODD,
    FILL_RULE_NON_ZERO,
    FILL_RULE_POSITIVE,
    FILL_RULE_NEGATIVE,
};

pathsd_t* clipper2_boolean_op(
    enum clip_type_e clip_type,
    enum fill_rule_e fill_rule,
    pathsd_t* subjects,
    pathsd_t* clips,
    int decimal_precision);

#ifdef __cplusplus
}
#endif
