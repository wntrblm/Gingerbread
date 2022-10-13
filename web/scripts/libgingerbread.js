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

    conversion_start() {
        this.zig.exports.conversion_start();
    }

    conversion_add(image) {
        if (!this.image_array_ptr) {
            this.image_array_ptr = this.zig.allocate(image.data.byteLength);
        }

        this.image_array_ptr.u8().set(image.data);

        this.zig.exports.conversion_add(this.image_array_ptr.address, image.width, image.height);
    }

    conversion_finish() {
        this.image_array_ptr.free();
        return this.zig.return_str(this.zig.exports.conversion_finish());
    }

}
