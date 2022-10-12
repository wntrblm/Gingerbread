/* Converts an SVGDocument to a Blob. */
function Blob_from_SVGDocument(svg_doc) {
    return new Blob([new XMLSerializer().serializeToString(svg_doc)], {
        type: "image/svg+xml",
    });
}

/* Creates an <img> element with the given source, returning a promise that
   resolves when the image has loaded. */
export async function createImageElement(src) {
    const elm = document.createElement("img");
    const load = new Promise((resolve) => {
        elm.addEventListener("load", () => {
            resolve(elm);
        });
    });

    elm.src = src;

    return await load;
}

/* Resizes an image with the given width or height (or both), preserving aspect
   ratio. */
function ImageElement_resize(img, width, height) {
    const aspect_ratio = img.height / img.width;

    if (width && height) {
        img.width = width;
        img.height = height;
    } else if (width) {
        img.width = width;
        img.height = Math.floor(img.width * aspect_ratio);
    } else if (height) {
        img.height = height;
        img.width = Math.floor(img.height / aspect_ratio);
    }
}

/* Creates an ImageBitmap from a Blob */
async function ImageBitmap_from_Blob(blob, width = 1000) {
    const blob_url = URL.createObjectURL(blob);
    const image = await createImageElement(blob_url);

    ImageElement_resize(image, width);

    return await window.createImageBitmap(image, {
        resizeWidth: image.width,
        resizeHeight: image.height,
    });
}

/* Like window.createImageBitmap, but can deal with SVGs and a bunch of other
   nonsense. */
export async function createImageBitmap(image, width = 1000) {
    if (image instanceof XMLDocument) {
        image = Blob_from_SVGDocument(image);
    }

    if (image instanceof Blob) {
        return await ImageBitmap_from_Blob(image, 1000);
    } else {
        return await window.createImageBitmap(image);
    }
}

/* Creates a copy of a Document, but with just the documentElement. */
export function cloneDocumentRoot(doc, type) {
    return new DOMParser().parseFromString(
        new XMLSerializer().serializeToString(
            doc.documentElement.cloneNode(false)
        ),
        type
    );
}

/* Clones and transplants the given element into the destination document. */
export function transplantElement(elm, dst, deep = true) {
    const imported_elm = dst.importNode(elm, deep);
    dst.documentElement.appendChild(imported_elm);
}

export function SVGElement_color(elm, stroke, fill) {
    for (const el of elm.querySelectorAll("*")) {
        el.style.fill = fill;
        el.style.stroke = stroke;
        el.style.fillOpacity = "1";
    }
}

/* Recolors all SVG elements in a given <g> element (or any other element, really)
   Recolor specifically means that it doesn't *add* color, it only modifies existing
   colors. */
export function SVGElement_recolor(elm, stroke = undefined, fill = undefined) {
    if (stroke === undefined) {
        stroke = fill;
    }
    if (fill === undefined) {
        fill = stroke;
    }

    for (const el of elm.querySelectorAll("*")) {
        if (el.style.fill) {
            el.style.fill = fill;
        } else if (el.style.stroke) {
            el.style.stroke = stroke;
        } else {
            el.style.fill = fill;
        }

        el.style.fillOpacity = "1";
    }
}

/* Inverts the given ImageBitmap in a way that matches how KiCAD handles soldermask
   layers */
export async function ImageBitmap_inverse_mask(
    bitmap,
    background,
    color = "rgba(0, 0, 0, 1)"
) {
    const canvas = document.createElement("canvas");
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;

    const ctx = canvas.getContext("2d");

    ctx.fillStyle = color;
    ctx.fillRect(0, 0, canvas.width, canvas.height);


    ctx.globalCompositeOperation = "destination-in";

    ctx.drawImage(background, 0, 0);

    ctx.globalCompositeOperation = "destination-out";

    ctx.drawImage(bitmap, 0, 0);

    const result = await window.createImageBitmap(canvas);

    bitmap.close();

    return result;
}
