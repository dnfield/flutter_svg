# flutter_svg

Messing around with drawing SVGs on canvas

## Getting Started

For now, this requires the flutter/engine path_svg branch

you'll need to clone that, build it (see [instructions](https://github.com/flutter/engine/blob/master/CONTRIBUTING.md)), and then use something like

`flutter run --local-engine=android_debug_unopt_x86` (to run a build for the android emulator, for example)

## TODO

- [ ] Finalize interface for parsing SVG paths and create PR
- [ ] Find out why `canvas.drawPoints` isn't allowing me to fill the resulting shape
- [ ] Better support for transforms
- [ ] Support for minimal CSS/styles
- [ ] Unit tests
- [ ] More SVG samples to cover more complicated cases
- [ ] XLink support
- [ ] Glyph support

## SVG sample attribution

SVGs in `/assets/w3samples` pulled from [W3 sample files](https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/)

SVGs in `/assets/deborah_ufw` provided by @deborah-ufw

SVGs in `/assets/simple` are pulled from trivial examples or generated to test basic functionality