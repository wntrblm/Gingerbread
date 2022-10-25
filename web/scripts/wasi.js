const WASI_ESUCCESS = 0;
const WASI_STDOUT_FILENO = 1;
const WASI_STDERR_FILENO = 2;

export default class WASI {
    memory;
    buffers;

    constructor() {
        this.buffers = {
            [WASI_STDOUT_FILENO]: [],
            [WASI_STDERR_FILENO]: [],
        };
    }

    setMemory(memory) {
        this.memory = memory;
    }

    getDataView() {
        return new DataView(this.memory.buffer);
    }

    exports() {
        return {
            proc_exit() {},

            environ_get: (environ, buf) => {
                return WASI_ESUCCESS;
            },
            environ_sizes_get:  (count, buf_size) => {
                var view = getDataView();

                view.setUint32(count, 0, !0);
                view.setUint32(buf_size, 0, !0);

                return WASI_ESUCCESS;
            },

            fd_prestat_get() {},
            fd_prestat_dir_name() {},

            fd_write: (fd, iovs, iovsLen, nwritten) => {
                const view = this.getDataView();
                let written = 0;

                const buffers = Array.from({ length: iovsLen }, (_, i) => {
                    const ptr = iovs + i * 8;
                    const buf = view.getUint32(ptr, !0);
                    const bufLen = view.getUint32(ptr + 4, !0);

                    return new Uint8Array(this.memory.buffer, buf, bufLen);
                });

                // XXX: verify that this handles multiple lines correctly
                for (let iov of buffers) {
                    const newline = 10;
                    let i = 0;
                    let newlineIndex = iov.lastIndexOf(newline, i);
                    if (newlineIndex > -1) {
                        let line = "",
                            decoder = new TextDecoder();

                        for (let buffer of this.buffers[fd]) {
                            line += decoder.decode(buffer, { stream: true });
                        }

                        line += decoder.decode(iov.slice(0, newlineIndex));

                        if (fd === WASI_STDOUT_FILENO) console.log(line);
                        else if (fd === WASI_STDERR_FILENO) console.warn(line);

                        this.buffers[fd] = [iov.slice(newlineIndex + 1)];
                        i = newlineIndex + 1;
                    }

                    this.buffers[fd].push(new Uint8Array(iov.slice(i)));

                    written += iov.byteLength;
                }

                view.setUint32(nwritten, written, !0);

                return WASI_ESUCCESS;
            },

            fd_close() {},
            fd_read() {},
            fd_seek() {},

            path_open() {},
            path_rename() {},
            path_create_directory() {},
            path_remove_directory() {},
            path_unlink_file() {},

            fd_filestat_get() {},
            fd_fdstat_get: (fd, buf_ptr) => {
                return WASI_ESUCCESS;
            },

            random_get() {},

            clock_time_get() {},
        };
    }
}
