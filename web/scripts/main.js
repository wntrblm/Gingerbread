import * as yak from "./yak.js";
import { LibGingerbread } from "./libgingerbread.js";

class PreviewCanvas {
    constructor(canvas_elm, scale = 2) {
        this.elm = canvas_elm;
        this.ctx = this.elm.getContext("2d");
        this.dpr = window.devicePixelRatio * scale;
        this.resize_to_container();
    }

    resize_to_container() {
        this.elm.width = 0;
        this.elm.height = 0;
        this.w = this.elm.clientWidth;
        this.h = this.elm.clientHeight;
        this.elm.width = Math.floor(this.w * this.dpr);
        this.elm.height = Math.floor(this.h * this.dpr);
        this.ctx.scale(this.dpr, this.dpr);
    }

    clear() {
        this.ctx.clearRect(0, 0, this.w, this.h);
    }

    calc_image_xywh(img, dst_w, dst_h) {
        const src_w = img.width;
        const src_h = img.height;

        const scale_w = dst_w / src_w;
        let w = src_w * scale_w;
        let h = src_h * scale_w;

        if (h > dst_h) {
            const scale_h = dst_h / src_h;
            w = src_w * scale_h;
            h = src_h * scale_h;
        }

        const x = this.w / 2 - w / 2;
        const y = this.h / 2 - h / 2;

        return { x: x, y: y, w: w, h: h };
    }

    draw_image(img, padding = [2, 2]) {
        const one_rem = parseFloat(
            getComputedStyle(document.documentElement).fontSize
        );
        padding = padding.map((x) => x * one_rem);

        const dst_w = this.w - padding[0] * 2;
        const dst_h = this.h - padding[1] * 2;

        const { x, y, w, h } = this.calc_image_xywh(img, dst_w, dst_h);

        this.ctx.drawImage(img, x, y, w, h);
    }

    draw_image_two_up(img, side = "left", padding = [2, 2]) {
        let sign = +1;
        if (side == "left") {
            sign = -1;
        }

        const one_rem = parseFloat(
            getComputedStyle(document.documentElement).fontSize
        );
        padding = padding.map((x) => x * one_rem);

        const dst_w = this.w / 2 - padding[0] * 2;
        const dst_h = this.h - padding[1] * 2;

        const { x, y, w, h } = this.calc_image_xywh(img, dst_w, dst_h);

        this.ctx.drawImage(img, x + sign * (w / 2 + padding[0]), y, w, h);
    }
}

class Design {
    static mask_colors = [
        "green",
        "red",
        "yellow",
        "blue",
        "white",
        "black",
        "pink",
        "grey",
        "orange",
        "purple",
    ];

    static silk_colors = ["white", "black", "yellow", "blue", "grey"];

    static layer_props = [
        { name: "Drill", type: "drill", color: "MediumVioletRed" },
        { name: "FSilkS", type: "raster", color: "white", number: 3 },
        {
            name: "FMask",
            type: "raster",
            color: "blue",
            is_mask: true,
            number: 5,
        },
        { name: "FCu", type: "raster", color: "gold", number: 1 },
        { name: "BCu", type: "raster", color: "gold", number: 2 },
        {
            name: "BMask",
            type: "raster",
            color: "blue",
            is_mask: true,
            number: 6,
        },
        { name: "BSilkS", type: "raster", color: "white", number: 4 },
        {
            name: "EdgeCuts",
            type: "vector",
            color: "PeachPuff",
            force_color: true,
            number: 7,
        },
    ];

    static preview_width = 500;
    static raster_width = 2000;

    constructor(canvas, svg) {
        this.cvs = canvas;
        this.svg = svg;
        this.svg_template = yak.cloneDocumentRoot(this.svg, "image/svg+xml");
        this._preview_layout = "both";
        this.determine_size();
        this.make_layers();
    }

    determine_size() {
        const viewbox = this.svg.documentElement.viewBox.baseVal;
        this.dpi = 2540;
        this.width_pts = viewbox.width;
        this.height_pts = viewbox.height;
    }

    make_layers() {
        this.layers = [];
        this.layers_by_name = {};

        for (const layer_def of Design.layer_props) {
            const layer_doc = this.svg_template.cloneNode(true);
            const layer_elm = this.svg.getElementById(layer_def.name);

            if (layer_elm) {
                yak.transplantElement(layer_elm, layer_doc);
            }

            const layer = new Layer(this, layer_doc, layer_def);

            this.layers.push(layer);
            this.layers_by_name[layer_def.name] = layer;
        }
    }

    get dpmm() {
        return 25.4 / this.dpi;
    }

    set dpmm(val) {
        this.dpi = (25.4 / val).toFixed(1);
    }

    get trace_scale_factor() {
        return (this.width_pts * this.dpmm) / this.constructor.raster_width;
    }

    get width_mm() {
        return (this.width_pts * this.dpmm).toFixed(2);
    }

    set width_mm(val) {
        this.dpmm = val / this.width_pts;
    }

    get height_mm() {
        return (this.height_pts * this.dpmm).toFixed(2);
    }

    set height_mm(val) {
        this.dpmm = val / this.height_pts;
    }

    get edge_cuts() {
        return this.layers_by_name["EdgeCuts"];
    }

    get mask_color() {
        return this.layers_by_name["FMask"].color;
    }

    set mask_color(val) {
        this.layers_by_name["FMask"].color = val;
        this.layers_by_name["BMask"].color = val;
        this.draw();
    }

    get silk_color() {
        return this.layers_by_name["FSilkS"].color;
    }

    set silk_color(val) {
        this.layers_by_name["FSilkS"].color = val;
        this.layers_by_name["BSilkS"].color = val;
        this.draw();
    }

    get preview_layout() {
        return this._preview_layout;
    }

    set preview_layout(val) {
        this._preview_layout = val;
        this.draw();
    }

    async draw_layers(layers, side) {
        for (const layer_name of layers) {
            const layer = this.layers_by_name[layer_name];

            if (!layer.visible) {
                continue;
            }

            // TODO: Move into layer itself.
            if (layer.name.endsWith("Mask")) {
                cvs.ctx.globalAlpha = 0.8;
            }

            if (this.preview_layout === "both") {
                cvs.draw_image_two_up(await layer.get_preview_bitmap(), side);
            } else {
                cvs.draw_image(await layer.get_preview_bitmap());
            }

            cvs.ctx.globalAlpha = 1;
        }
    }

    async draw() {
        const cvs = this.cvs;

        cvs.clear();

        if (this.preview_layout === "front" || this.preview_layout === "both") {
            await this.draw_layers(
                ["EdgeCuts", "FCu", "FMask", "FSilkS", "Drill"],
                "left"
            );
        }

        if (this.preview_layout === "back" || this.preview_layout === "both") {
            await this.draw_layers(
                ["EdgeCuts", "BCu", "BMask", "BSilkS", "Drill"],
                "right"
            );
        }
    }

    toggle_layer_visibility(layer_name) {
        const layer = this.layers_by_name[layer_name];
        layer.visible = !layer.visible;
        return layer.visible;
    }

    async export() {
        const gingerbread = await LibGingerbread.new();
        console.log(gingerbread);

        gingerbread.conversion_start();

        for (const layer of this.layers) {
            switch (layer.type) {
                case "raster":
                    const bm = await layer.get_raster_bitmap();
                    const imgdata = await yak.ImageData_from_ImageBitmap(bm);
                    gingerbread.conversion_add_raster_layer(
                        layer.number,
                        this.trace_scale_factor,
                        imgdata
                    );
                    break;
                case "vector":
                    for (const path of layer.get_paths()) {
                        gingerbread.conversion_start_poly();
                        for (const pt of path) {
                            gingerbread.conversion_add_poly_point(
                                pt[0],
                                pt[1],
                                this.dpmm
                            );
                        }
                        gingerbread.conversion_end_poly(layer.number, 1, false);
                    }
                    break;
                case "drill":
                    for (const circle of layer.get_circles()) {
                        gingerbread.conversion_add_drill(
                            circle.cx.baseVal.value,
                            circle.cy.baseVal.value,
                            circle.r.baseVal.value * 2,
                            this.dpmm
                        );
                    }
                    break;
                default:
                    throw `Unexpected layer type ${layer.type}`;
            }
        }

        const footprint = gingerbread.conversion_finish();
        navigator.clipboard.writeText(footprint);
    }
}

class Layer {
    constructor(design, svg, options) {
        this.design = design;
        this.svg = svg;

        this.name = options.name;
        this.type = options.type;
        this.force_color = options.force_color;
        this.is_mask = options.is_mask;
        this.color = options.color;
        this.number = options.number;

        this.visible = true;
    }

    get color() {
        return this._color;
    }

    set color(val) {
        this._color = val;

        if (this.force_color) {
            yak.SVGElement_color(this.svg, this._color, this._color);
        } else {
            yak.SVGElement_recolor(this.svg, this._color, this._color);
        }

        if (this.bitmap) {
            this.bitmap.close();
            this.bitmap = null;
        }
    }

    async get_preview_bitmap() {
        if (!this.bitmap) {
            this.bitmap = await yak.createImageBitmap(
                this.svg,
                this.design.constructor.preview_width
            );
            if (this.is_mask) {
                this.bitmap = await yak.ImageBitmap_inverse_mask(
                    this.bitmap,
                    await this.design.edge_cuts.get_preview_bitmap(),
                    this.color
                );
            }
        }
        return this.bitmap;
    }

    async get_raster_bitmap() {
        return await yak.createImageBitmap(
            this.svg,
            this.design.constructor.raster_width
        );
    }

    *get_paths() {
        yield* yak.SVGElement_to_paths(this.svg.documentElement);
    }

    get_circles() {
        return this.svg.documentElement.querySelectorAll("circle");
    }
}

let cvs = undefined;
let design = undefined;

async function get_example_svg(cvs) {
    const svg_string = await (await fetch("/examples/example-s2m.svg")).text();
    const svg = new DOMParser().parseFromString(svg_string, "image/svg+xml");
    return new Design(cvs, svg);
}

(async function () {
    cvs = new PreviewCanvas(document.getElementById("preview-canvas"));

    window.addEventListener("resize", () => {
        cvs.resize_to_container();
        design.draw();
    });

    design = await get_example_svg(cvs);
    design.draw();

    window.dispatchEvent(new CustomEvent("designloaded", { detail: design }));
})();

document.addEventListener("alpine:init", () => {
    Alpine.data("app", () => ({
        mask_colors: Design.mask_colors,
        silk_colors: Design.silk_colors,
        layers: Design.layer_props.map((prop) => {
            return { name: prop.name, visible: true };
        }),
        design: {},
        current_layer: "FSilkS",
        toggle_layer_visibility(layer) {
            layer.visible = design.toggle_layer_visibility(layer.name);
            design.draw(cvs);
        },
        designloaded(e) {
            this.design = e.detail;
        },
    }));
});
