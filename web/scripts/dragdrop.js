export class DropTarget {
    constructor(elm, callback) {
        this.elm = elm;
        this.callback = callback;

        elm.addEventListener(
            "dragenter",
            (e) => {
                e.preventDefault();
            },
            false,
        );

        elm.addEventListener(
            "dragover",
            (e) => {
                e.preventDefault();
                e.dataTransfer.dropEffect = "move";
            },
            false,
        );

        elm.addEventListener(
            "drop",
            async (e) => {
                e.stopPropagation();
                e.preventDefault();
                const dt = e.dataTransfer;
                const files = dt.files;
                if (files.length > 0) {
                    callback(files);
                }
            },
            false,
        );
    }
}
