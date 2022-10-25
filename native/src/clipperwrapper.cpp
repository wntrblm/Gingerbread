#include "clipper.h"
#include "clipperwrapper.h"
#include <cstdio>

using namespace Clipper2Lib;

extern "C" {

    pathd_t* PathD_new(void) {
        return reinterpret_cast<pathd_t*>(new PathD());
    }
    void PathD_delete(pathd_t* self) {
        delete reinterpret_cast<PathD*>(self);
    }
    void PathD_push_back(pathd_t* self, double x, double y) {
        reinterpret_cast<PathD*>(self)->push_back(PointD(x, y));
    }
    size_t PathD_size(pathd_t* self) {
        return reinterpret_cast<PathD*>(self)->size();
    }
    pointd_t PathD_at(pathd_t* self, size_t index) {
        auto selfp = reinterpret_cast<PathD*>(self);
        auto pt = selfp->at(index);
        return (pointd_t){.x = pt.x, .y = pt.y};
    }

    pathsd_t* PathsD_new(void) {
        return reinterpret_cast<pathsd_t*>(new PathsD());
    }
    void PathsD_delete(pathsd_t* self) {
        delete reinterpret_cast<PathsD*>(self);
    }
    void PathsD_push_back(pathsd_t* self, pathd_t* path) {
        reinterpret_cast<PathsD*>(self)->push_back(*reinterpret_cast<PathD*>(path));
    }
    size_t PathsD_size(pathsd_t* self) {
        return reinterpret_cast<PathsD*>(self)->size();
    };
    pathd_t* PathsD_at(pathsd_t* self, size_t index) {
        auto selfp = reinterpret_cast<PathsD*>(self);
        auto item = &selfp->at(index);
        return reinterpret_cast<pathd_t*>(item);
    }

    pathsd_t* clipper2_boolean_op(
        enum clip_type_e clip_type,
        enum fill_rule_e fill_rule,
        pathsd_t* subjects,
        pathsd_t* clips,
        int decimal_precision) {

            PathsD subjects_ = *reinterpret_cast<PathsD*>(subjects);
            PathsD clips_ = *reinterpret_cast<PathsD*>(clips);

            auto clip_type_ = ClipType::None;
            switch (clip_type) {
                case CLIP_TYPE_NONE:
                    clip_type_ = ClipType::None;
                    break;
                case CLIP_TYPE_INTERSECTION:
                    clip_type_ = ClipType::Intersection;
                    break;
                case CLIP_TYPE_UNION:
                    clip_type_ = ClipType::Union;
                    break;
                case CLIP_TYPE_DIFFERENCE:
                    clip_type_ = ClipType::Difference;
                    break;
                case CLIP_TYPE_XOR:
                    clip_type_ = ClipType::Xor;
                    break;
            }

            auto fill_rule_ = FillRule::EvenOdd;
            switch(fill_rule) {
                case FILL_RULE_EVEN_ODD:
                    fill_rule_ = FillRule::EvenOdd;
                    break;
                case FILL_RULE_NON_ZERO:
                    fill_rule_ = FillRule::NonZero;
                    break;
                case FILL_RULE_NEGATIVE:
                    fill_rule_ = FillRule::Negative;
                    break;
                case FILL_RULE_POSITIVE:
                    fill_rule_ = FillRule::Positive;
                    break;
            }

            auto solution = BooleanOp(
                clip_type_,
                fill_rule_,
                subjects_,
                clips_,
                decimal_precision);

            auto result = new PathsD(solution);

            return reinterpret_cast<pathsd_t*>(result);
    }
}
