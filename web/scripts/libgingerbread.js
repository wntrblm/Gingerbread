import { ZigWASM } from "./zigwasm.js";

export class LibGingerbread {
    static wasm_src = "./scripts/gingerbread.wasm";
    static wasm_module;

    constructor(zig) {
        this.zig = zig;
    }

    static async new() {
        if (this.wasm_module == null) {
            this.wasm_module = await ZigWASM.compile(this.wasm_src);
        }

        return new this(await ZigWASM.new(this.wasm_module));
    }

    trace(image) {
        const image_array = this.zig.allocate(image.data.byteLength);
        image_array.set(image.data);
        const result = this.zig.exports.trace(image_array.byteOffset, image.width, image.height);
        const footprint = this.zig.result_to_string(result);
        return footprint;
    }
}
