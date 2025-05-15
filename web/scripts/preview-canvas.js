export class PreviewCanvas {
    constructor(canvas_elm, scale = 2) {
        this.elm = canvas_elm;
        this.ctx = this.elm.getContext("2d");
        this.dpr = window.devicePixelRatio * scale;
        this.resize_to_container();
    }

    get one_rem() {
        return Number.parseFloat(getComputedStyle(document.documentElement).fontSize);
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
        const paddingPx = padding.map((x) => x * this.one_rem);

        const dst_w = this.w - paddingPx[0] * 2;
        const dst_h = this.h - paddingPx[1] * 2;

        const { x, y, w, h } = this.calc_image_xywh(img, dst_w, dst_h);

        this.ctx.drawImage(img, x, y, w, h);
    }

    draw_image_two_up(img, side = "left", padding = [2, 2]) {
        let sign = +1;
        if (side === "left") {
            sign = -1;
        }

        const paddingPx = padding.map((x) => x * this.one_rem);

        const dst_w = this.w / 2 - paddingPx[0] * 2;
        const dst_h = this.h - paddingPx[1] * 2;

        const { x, y, w, h } = this.calc_image_xywh(img, dst_w, dst_h);

        this.ctx.drawImage(img, x + sign * (w / 2 + paddingPx[0]), y, w, h);
    }

    draw_image_n_up(img, i, n, padding = [2, 2]) {
        const paddingPx = padding.map((x) => x * this.one_rem);

        const dst_w = this.w / n - paddingPx[0] * 2;
        const dst_h = this.h - paddingPx[1] * 2;

        const { _, y, w, h } = this.calc_image_xywh(img, dst_w, dst_h);
        const n_w = w + paddingPx[0] / 2;
        const x_min = this.w / 2 - n * (n_w / 2) + paddingPx[0] / 4;

        this.ctx.drawImage(img, x_min + i * n_w, y, w, h);
    }
}
