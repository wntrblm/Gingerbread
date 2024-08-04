# Gingerbread

Gingerbread is a tool for converting vector artwork to KiCAD PCB files that lives in your browser.

See https://gingerbread.wntr.dev for more information.

## Building & Running

1. make sure you have python3 and zig (0.12.1) installed
2. build the native code in `native/` using `zig build`
3. make sure you have `jinja2` installed (`python3 -m pip install jinja2`)
4. run build.py in the root directory (`python3 build.py`)
5. this builds the site into `build/`, serve it using python `python3 -m http.server 8080 --bind 127.0.0.1 --directory ./build` and visit `http://127.0.0.1:8080/` to view the site

## License and contributing

Gingerbread is open source! Please take a chance to read the [LICENSE](LICENSE.md) file.

We welcome contributions! Please read our [Code of Conduct](CODE_OF_CONDUCT.md).
