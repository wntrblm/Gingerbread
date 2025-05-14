import WASI from "./wasi.js";

class Ptr {
    constructor(zigwasm, address, length) {
        this.zigwasm = zigwasm;
        this.address = address;
        this.byteLength = length;
    }

    free() {
        this.zigwasm.free(this.address, this.length);
        this.address = 0;
        this.byteLength = 0;
    }

    u8() {
        return new Uint8Array(this.zigwasm.memory.buffer, this.address, this.byteLength);
    }

    u32() {
        return new Uint32Array(
            this.zigwasm.memory.buffer,
            this.address,
            this.byteLength / Uint32Array.BYTES_PER_ELEMENT,
        );
    }

    str() {
        return new TextDecoder().decode(this.zigwasm.view(this.address, this.byteLength));
    }
}

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
        return new ZigWASM(wasm_inst, wasi);
    }

    get exports() {
        return this.inst.exports;
    }

    get memory() {
        return this.inst.exports.memory;
    }

    allocate(length) {
        const address = this.inst.exports.z_allocate(length);
        return new Ptr(this, address, length);
    }

    free(addr, len) {
        this.inst.exports.z_free(addr, len);
    }

    view(address, length) {
        return new DataView(this.inst.exports.memory.buffer, address, length);
    }

    return_ptr(result_address) {
        return new Ptr(this, result_address, 2 * Uint32Array.BYTES_PER_ELEMENT);
    }

    return_str(result_address) {
        return this.ptr_to_string(this.return_ptr(result_address));
    }

    ptr_to_string(resultptr) {
        const resultview = resultptr.u32();
        const ptr = new Ptr(this, resultview[0], resultview[1]);
        const str = ptr.str();
        ptr.free();
        resultptr.free();
        return str;
    }
}
