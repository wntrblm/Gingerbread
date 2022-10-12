import WASI from "./wasi.js";

export class ZigWASM {
    constructor(wasm_inst, wasi) {
        this.inst = wasm_inst;
        this.wasi = wasi;
    }

    static async compile(src) {
        return await WebAssembly.compileStreaming(fetch(src));
    }

    static async new(wasm_module) {
        const wasi = new WASI();
        const wasm_inst = await WebAssembly.instantiate(wasm_module, {
            wasi_snapshot_preview1: wasi.exports(),
            env: {},
        });
        wasi.setMemory(wasm_inst.exports.memory);
        return new this(wasm_inst, wasi);
    }

    get exports() {
        return this.inst.exports;
    }

    get memory() {
        return this.inst.exports.memory;
    }

    allocate(length) {
        const arrayptr = this.inst.exports.z_allocate(length);
        const array = new Uint8Array(
            this.inst.exports.memory.buffer,
            arrayptr,
            length
        );
        return array;
    }

    free(addr, len) {
        this.inst.exports.z_free(addr, len);
    }

    view(address, length) {
        return new DataView(this.inst.exports.memory.buffer, address, length);
    }

    result_to_string(resultptr) {
        const view = this.view(resultptr, 2 * 4);
        const addr = view.getUint32(0, true);
        const len = view.getUint32(4, true);
        const str = new TextDecoder().decode(this.view(addr, len));
        // free the result and string from zig. This isn't strictly necessary, I guess?
        this.free(resultptr, 2 * 4);
        this.free(addr, len);
        return str;
    }
}
