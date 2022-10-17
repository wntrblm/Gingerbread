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
        return await ImageBitmap_from_Blob(image, width);
    } else {
        return await window.createImageBitmap(image);
    }
}

export async function ImageData_from_ImageBitmap(bitmap) {
    const canvas = document.createElement("canvas");
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;

    const ctx = canvas.getContext("2d");

    ctx.drawImage(bitmap, 0, 0);

    return ctx.getImageData(0, 0, canvas.width, canvas.height);
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

/* Approximates a cubic bezier curve as a series of points

    Approximates the curve by small line segments. The interval
    size, epsilon, is determined on the fly so that the distance
    between the true curve and its approximation does not exceed the
    desired accuracy delta.

    Ported from https://gitlab.com/kicad/code/kicad/-/blob/2ee65b2d83923acb71aa77ce0efab09a3f2a8f44/bitmap2component/bitmap2component.cpp#L544
*/
export function* bezier_to_points(p1, p2, p3, p4, delta = 0.25) {
    // dd = maximal value of 2nd derivative over curve - this must occur at an endpoint.
    const dd0 =
        Math.pow(p1[0] - 2 * p2[0] + p3[0], 2) +
        Math.pow(p1[1] - 2 * p2[1] + p3[1], 2);
    const dd1 =
        Math.pow(p2[0] - 2 * p3[0] + p4[0], 2) +
        Math.pow(p2[1] - 2 * p3[1] + p4[1], 2);
    const dd = 6 * Math.sqrt(Math.max(dd0, dd1));
    const e2 = 8 * delta < dd ? (8 * delta) / dd : 1;
    const interval = Math.sqrt(e2);

    for (let t = 0; t < 1; t += interval) {
        const x =
            p1[0] * Math.pow(1 - t, 3) +
            3 * p2[0] * Math.pow(1 - t, 2) * t +
            3 * p3[0] * (1 - t) * Math.pow(t, 2) +
            p4[0] * Math.pow(t, 3);
        const y =
            p1[1] * Math.pow(1 - t, 3) +
            3 * p2[1] * Math.pow(1 - t, 2) * t +
            3 * p3[1] * (1 - t) * Math.pow(t, 2) +
            p4[1] * Math.pow(t, 3);
        yield [x, y];
    }

    yield p4;
}

/* Converts an SVG path (from SVGGeometryElement.getPathData()) to a list of points
   that represent a polygonal approximation of the path. */
export function* SVGPathData_to_points(pathdata) {
    let last = [0, 0];
    for (const seg of pathdata) {
        switch (seg.type) {
            case "M":
                yield seg.values;
                last = seg.values;
                break;
            case "L":
                yield seg.values;
                last = seg.values;
                break;
            case "C":
                yield* bezier_to_points(
                    last,
                    seg.values.slice(0, 2),
                    seg.values.slice(2, 4),
                    seg.values.slice(4, 6)
                );
                last = seg.values.slice(4, 6);
                break;
            case "Z":
                // TODO: Handle multiple, discontinuous paths
                break;
            default:
                throw `Invalid path segment type ${seg.type}`;
                break;
        }
    }
}

export function* SVGGeometryElement_to_points(elm) {
    yield* SVGPathData_to_points(elm.getPathData({normalize: true}));
}
