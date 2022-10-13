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

    conversion_start() {
        this.zig.exports.conversion_start();
    }

    conversion_add(layer, image) {
        if (!this.image_array_ptr) {
            this.image_array_ptr = this.zig.allocate(image.data.byteLength);
        }

        this.image_array_ptr.u8().set(image.data);

        this.zig.exports.conversion_add(layer, this.image_array_ptr.address, image.width, image.height);
    }

    conversion_finish() {
        this.image_array_ptr.free();
        return this.zig.return_str(this.zig.exports.conversion_finish());
    }

}
