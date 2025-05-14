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
async function ImageBitmap_from_Blob(blob, width = 1000, context = null) {
    const blob_url = URL.createObjectURL(blob);
    const image = await createImageElement(blob_url);

    // Workaround for firefox- it doesn't set the image dimensions for SVG
    // elements until they've been added to the DOM, so use the viewBox
    // dimensions.
    if (image.width === 0 && context instanceof XMLDocument) {
        const viewbox = context.documentElement.viewBox.baseVal;
        image.width = viewbox.width;
        image.height = viewbox.height;
    }

    ImageElement_resize(image, width);

    return await window.createImageBitmap(image, {
        resizeWidth: image.width,
        resizeHeight: image.height,
    });
}

/* Like window.createImageBitmap, but can deal with SVGs and a bunch of other
   nonsense. */
export async function createImageBitmap(image, width = 1000) {
    const context = image;
    let imageToProcess = image;

    if (imageToProcess instanceof XMLDocument) {
        imageToProcess = Blob_from_SVGDocument(imageToProcess);
    }

    if (imageToProcess instanceof Blob) {
        return await ImageBitmap_from_Blob(imageToProcess, width, context);
    }

    return await window.createImageBitmap(imageToProcess);
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
        new XMLSerializer().serializeToString(doc.documentElement.cloneNode(false)),
        type,
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
    const strokeToUse = stroke ?? fill;
    const fillToUse = fill ?? stroke;

    const invisible_values = ["none", "transparent"];

    for (const el of elm.querySelectorAll("*")) {
        const { fill: current_fill, stroke: current_stroke } = SVGElement_get_effective_fill_and_stroke(el);

        if (!invisible_values.includes(current_fill)) {
            el.style.fill = fillToUse;
            el.style.fillOpacity = "1";
        }

        if (!invisible_values.includes(current_stroke)) {
            el.style.stroke = strokeToUse;
        }
    }
}

export function SVGElement_get_effective_fill_and_stroke(elm) {
    let fill = "";
    let stroke = "";
    let e = elm;

    while (e) {
        if (fill === "" || fill === undefined || fill === null) {
            fill = e.style.fill;
        }
        if (stroke === "" || stroke === undefined || stroke === null) {
            stroke = e.style.stroke;
        }
        e = e.parentElement;
    }

    if (fill === "" || fill === undefined || fill === null) {
        fill = "black";
    }

    if (stroke === "" || stroke === undefined || stroke === null) {
        stroke = "none";
    }

    return { fill: fill, stroke: stroke };
}

/* Inverts the given ImageBitmap in a way that matches how KiCAD handles soldermask
   layers */
export async function ImageBitmap_inverse_mask(bitmap, background, color = "rgba(0, 0, 0, 1)") {
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
    const dd0 = (p1[0] - 2 * p2[0] + p3[0]) ** 2 + (p1[1] - 2 * p2[1] + p3[1]) ** 2;
    const dd1 = (p2[0] - 2 * p3[0] + p4[0]) ** 2 + (p2[1] - 2 * p3[1] + p4[1]) ** 2;
    const dd = 6 * Math.sqrt(Math.max(dd0, dd1));
    const e2 = 8 * delta < dd ? (8 * delta) / dd : 1;
    const interval = Math.sqrt(e2);

    for (let t = 0; t < 1; t += interval) {
        const x = p1[0] * (1 - t) ** 3 + 3 * p2[0] * (1 - t) ** 2 * t + 3 * p3[0] * (1 - t) * t ** 2 + p4[0] * t ** 3;
        const y = p1[1] * (1 - t) ** 3 + 3 * p2[1] * (1 - t) ** 2 * t + 3 * p3[1] * (1 - t) * t ** 2 + p4[1] * t ** 3;
        yield [x, y];
    }

    yield p4;
}

/* Splits an SVG path (from SVGGeometryElement.getPathData()) to a list of
   continuous subpaths */
export function* SVGPathData_continuous_subpaths(pathdata) {
    let subpath = [];
    for (const seg of pathdata) {
        if (seg.type === "Z") {
            yield subpath;
            subpath = [];
        } else {
            subpath.push(seg);
        }
    }
    if (subpath.length) {
        yield subpath;
    }
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
                yield* bezier_to_points(last, seg.values.slice(0, 2), seg.values.slice(2, 4), seg.values.slice(4, 6));
                last = seg.values.slice(4, 6);
                break;
            case "Z":
                console.log("discontinuity");
                // TODO: Handle multiple, discontinuous paths
                break;
            default:
                throw `Invalid path segment type ${seg.type}`;
        }
    }
}

export function* SVGGeometryElement_to_paths(elm) {
    const pathdata = elm.getPathData({ normalize: true });
    for (const subpath of SVGPathData_continuous_subpaths(pathdata)) {
        yield SVGPathData_to_points(subpath);
    }
}

export function* SVGElement_to_paths(elm) {
    if (elm.tagName === "g" || elm.tagName === "svg") {
        for (const child of elm.children) {
            yield* SVGElement_to_paths(child);
        }
    } else {
        yield* SVGGeometryElement_to_paths(elm);
    }
}

/*
    Basic helper to initiate a download of a given File using the browser.
    Useful for generating files client side for the user to download.
*/
export function initiateDownload(file) {
    let name;
    let url;

    if (file instanceof File) {
        url = URL.createObjectURL(file);
        name ??= file.name;
    } else {
        url = file.href;
        name ??= basename(url);
    }

    const anchor = document.createElement("a");

    anchor.href = url;
    anchor.download = name;
    anchor.target = "_blank";
    anchor.click();

    if (file instanceof File) {
        URL.revokeObjectURL(url);
    }
}
