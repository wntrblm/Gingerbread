import * as yak from "./yak.js";
import { LibGingerbread } from "./libgingerbread.js";
import { PreviewCanvas } from "./preview-canvas.js";
import { DropTarget } from "./dragdrop.js";

class Design {
    static mask_colors = {
        green: "rgb(0, 84, 3)",
        red: "rgb(127, 0, 0)",
        yellow: "rgb(207, 184, 0)",
        blue: "rgb(0, 28, 204)",
        white: "white",
        black: "black",
        pink: "pink",
        grey: "grey",
        orange: "orange",
        purple: "rgb(117, 0, 207)",
    };

    static silk_colors = ["white", "black", "yellow", "blue", "grey"];

    static layer_defs = [
        {
            name: "Drill",
            type: "drill",
            selector: '#Drill, #Drills, [*|label="Drills"]',
            color: "Fuchsia",
        },
        {
            name: "FSilkS",
            type: "raster",
            selector: '#FSilkS, #F\\.SilkS, [*|label="F\\.SilkS"]',
            color: "white",
            number: 3,
        },
        {
            name: "FMask",
            type: "raster",
            selector: '#FMask, #F\\.Mask, [*|label="F\\.Mask"]',
            color: "black",
            is_mask: true,
            number: 5,
        },
        {
            name: "FCu",
            type: "raster",
            selector: '#FCu, #F\\.Cu, [*|label="F\\.Cu"]',
            color: "gold",
            number: 1,
        },
        {
            name: "BCu",
            type: "raster",
            selector: '#BCu, #B\\.Cu, [*|label="B\\.Cu"]',
            color: "gold",
            number: 2,
        },
        {
            name: "BMask",
            type: "raster",
            selector: '#BMask, #B\\.Mask, [*|label="B\\.Mask"]',
            color: "black",
            is_mask: true,
            number: 6,
        },
        {
            name: "BSilkS",
            type: "raster",
            selector: '#BSilkS, #B\\.SilkS, [*|label="B\\.SilkS"]',
            color: "white",
            number: 4,
        },
        {
            name: "EdgeCuts",
            type: "vector",
            selector: '#EdgeCuts, #Edge\\.Cuts, [*|label="Edge\\.Cuts"]',
            color: "PeachPuff",
            force_color: true,
            number: 7,
        },
    ];

    constructor(canvas, svg) {
        this.cvs = canvas;
        this.svg = svg;
        this.svg_template = yak.cloneDocumentRoot(this.svg, "image/svg+xml");
        this._preview_layout = "both";
        this._mask_opacity = 0.9;
        this.determine_size();
        this.make_layers();
        this._mirror_back_layers = true;

        const resize_observer = new ResizeObserver(() => {
            this.cvs.resize_to_container();
            this.draw();
        });
        resize_observer.observe(this.cvs.elm);
    }

    determine_size() {
        const viewbox = this.svg.documentElement.viewBox.baseVal;
        this.dpi = 2540;
        this.width_pts = viewbox.width;
        this.height_pts = viewbox.height;
        this.preview_width = Math.min(this.width_pts * 0.25, 1024);
        this.raster_width = this.width_pts * 0.5;
    }

    make_layers() {
        this.layers = [];
        this.layers_by_name = {};

        for (const layer_def of Design.layer_defs) {
            const layer_doc = this.svg_template.cloneNode(true);
            const layer_elms = this.svg.querySelectorAll(layer_def.selector);

            for (const layer_elm of layer_elms) {
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
        return (this.width_pts * this.dpmm) / this.raster_width;
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

    get mask_opacity() {
        return this._mask_opacity;
    }

    set mask_opacity(val) {
        this._mask_opacity = val;
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

    get mirror_back_layers() {
        return this._mirror_back_layers;
    }

    set mirror_back_layers(val) {
        this._mirror_back_layers = val;
        this.draw();
    }

    async draw_layers(layers, side) {
        const cvs = this.cvs;

        let i = 0;
        for (const layer_name of layers) {
            const layer = this.layers_by_name[layer_name];

            if (!layer.visible) {
                continue;
            }

            if (layer.is_mask) {
                cvs.ctx.globalAlpha = this.mask_opacity;
            }

            if (this.preview_layout === "both") {
                cvs.draw_image_two_up(await layer.get_preview_bitmap(), side);
            } else if (this.preview_layout.endsWith("-spread")) {
                cvs.draw_image_n_up(await layer.get_preview_bitmap(), i, layers.length);
            } else {
                cvs.draw_image(await layer.get_preview_bitmap());
            }

            cvs.ctx.globalAlpha = 1;
            i++;
        }
    }

    async draw() {
        const cvs = this.cvs;

        cvs.clear();

        if (
            this.preview_layout === "front" ||
            this.preview_layout === "front-spread" ||
            this.preview_layout === "both"
        ) {
            await this.draw_layers(["EdgeCuts", "FCu", "FMask", "FSilkS", "Drill"], "left");
        }

        if (this.preview_layout === "back" || this.preview_layout === "back-spread" || this.preview_layout === "both") {
            await this.draw_layers(["EdgeCuts", "BCu", "BMask", "BSilkS", "Drill"], "right");
        }
    }

    toggle_layer_visibility(layer_name) {
        const layer = this.layers_by_name[layer_name];
        layer.visible = !layer.visible;
        return layer.visible;
    }

    async export(method) {
        const gingerbread = await LibGingerbread.new();
        gingerbread.onRuntimeError = (error) => {
            console.error("WASM Runtime Error:", error);
            console.error("Stack trace:", error.stack);
        };
        console.log(gingerbread);

        gingerbread.conversion_start();
        gingerbread.set_mirror_back_layers(this._mirror_back_layers);

        for (const layer of this.layers) {
            switch (layer.type) {
                case "raster": {
                    const bm = await layer.get_raster_bitmap();
                    const imgdata = await yak.ImageData_from_ImageBitmap(bm);

                    // Check that the ImageData is valid
                    const imgdata_sum = imgdata.data.reduce((a, b) => a + b, 0);

                    if (imgdata_sum === 0) {
                        console.log("Skipping layer:", layer.name, "because it has no data");
                        continue;
                    }

                    try {
                        gingerbread.conversion_add_raster_layer(layer.number, this.trace_scale_factor, imgdata);
                    } catch (error) {
                        console.log("imgdata:", imgdata);
                        console.error("WASM error in conversion_add_raster_layer:", error, {
                            layer: layer.name,
                            number: layer.number,
                            scale_factor: this.trace_scale_factor,
                        });
                        // throw error;
                    }
                    break;
                }
                case "vector": {
                    for (const path of layer.get_paths()) {
                        gingerbread.conversion_start_poly();
                        for (const pt of path) {
                            gingerbread.conversion_add_poly_point(pt[0], pt[1], layer.number, this.dpmm);
                        }
                        gingerbread.conversion_end_poly(layer.number, 1, false);
                    }
                    break;
                }
                case "drill": {
                    for (const circle of layer.get_circles()) {
                        gingerbread.conversion_add_drill(
                            circle.cx.baseVal.value,
                            circle.cy.baseVal.value,
                            circle.r.baseVal.value * 2,
                            this.dpmm,
                        );
                    }
                    break;
                }
                default: {
                    throw `Unexpected layer type ${layer.type}`;
                }
            }
        }

        console.log("Conversion finished");
        const footprint = gingerbread.conversion_finish();

        if (method === "clipboard") {
            console.log("Copying to clipboard");
            navigator.clipboard.writeText(footprint);
        } else {
            const file = new File([footprint], "design.kicad_pcb");
            yak.initiateDownload(file);
        }
    }
}

class Layer {
    constructor(design, svg, options) {
        this.design = design;
        this.svg = svg;

        this.name = options.name;
        this.number = options.number;
        this.type = options.type || "raster";
        this.force_color = options.force_color || false;
        this.is_mask = options.is_mask || false;
        this.color = options.color || "red";

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
            this.bitmap = await yak.createImageBitmap(this.svg, this.design.constructor.preview_width);
            if (this.is_mask) {
                this.bitmap = await yak.ImageBitmap_inverse_mask(
                    this.bitmap,
                    await this.design.edge_cuts.get_preview_bitmap(),
                    this.color,
                );
            }
        }
        return this.bitmap;
    }

    async get_raster_bitmap() {
        return await yak.createImageBitmap(this.svg, this.design.raster_width);
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

async function load_design_file(file) {
    if (cvs === undefined) {
        cvs = new PreviewCanvas(document.getElementById("preview-canvas"));
    }

    const svg_doc = new DOMParser().parseFromString(await file.text(), "image/svg+xml");

    design = new Design(cvs, svg_doc);

    window.dispatchEvent(new CustomEvent("designloaded", { detail: design }));
}

new DropTarget(document.querySelector("body"), async (files) => {
    console.log(files);
    const image_file = files[0];

    if (image_file.type !== "image/svg+xml") {
        console.log(`Expected svg, got ${image_file.type}`);
        return;
    }

    await load_design_file(image_file);
});

document.addEventListener("alpine:init", () => {
    Alpine.data("app", () => ({
        mask_colors: Design.mask_colors,
        silk_colors: Design.silk_colors,
        layers: Design.layer_defs.map((prop) => {
            return { name: prop.name, visible: true };
        }),
        design: false,
        current_layer: "FSilkS",
        toggle_layer_visibility(layer) {
            layer.visible = design.toggle_layer_visibility(layer.name);
            design.draw(cvs);
        },
        designloaded(e) {
            this.design = e.detail;
        },
        exporting: false,
        async export_design(method) {
            this.exporting = true;
            await this.design.export(method);
            this.exporting = "done";
            window.setTimeout(() => {
                this.exporting = false;
            }, 3000);
        },
        async load_example_design(name) {
            await load_design_file(await fetch(name));
        },
    }));
});

LibGingerbread.onRuntimeError = (error) => {
    console.error("WASM Runtime Error:", error);
    console.error("Stack trace:", error.stack);

    if (error?.message?.includes("unreachable")) {
        console.error("WASM hit unreachable code - this likely means a panic occurred");
        console.error("Last known operation:", LibGingerbread.lastOperation);
    } else if (error.message) {
        console.error("WASM error- this is probably a bug in the Gingerbread code");
    } else {
        throw new Error(`WASM execution failed: ${error.message}`);
    }
};
