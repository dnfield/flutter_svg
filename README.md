# flutter_svg

Messing around with drawing SVGs on canvas

## Getting Started

~~~For now, this requires the flutter/engine path_svg branch~~~

After some testing and discussion, I've implemented Chromium's path parsing
logic in Dart. It probably has some room for improvement and definitely needs
more tests. Surprisingly (at least to me), the Skia C++ parsing implementation
wasn't notably faster than just feeing in Path commands.  If the Dart
implementation here isn't fast enough (or can't be made fast enough), you
should look at preprocessing your SVGs into Dart code. I have dreams of making
an intermediate format (or perhaps just coopting [usvg](https://github.com/razrfalcon/usvg)
to do this).

## TODO

- [ ] ~~~Finalize interface for parsing SVG paths and create PR~~~
- [ ] ~~~Find out why `canvas.drawPoints` isn't allowing me to fill the resulting shape~~~
- [x] Better support for transforms
- [ ] Support for minimal CSS/styles?  See also [svgcleaner](https://github.com/razrfalcon/svgcleaner)
- [ ] Unit tests
- [ ] More SVG samples to cover more complicated cases
- [ ] XLink/ref support?
- [ ] Glyph support?
- [ ] Text support

## Probably out of scope

- SMIL animations. That just seems crazy.
- Full (any?) CSS support - preprocess your SVGs (perhaps with svgcleaner to get rid of all CSS?)
- Scripting in SVGs
- Foreign elements

## SVG sample attribution

SVGs in `/assets/w3samples` pulled from [W3 sample files](https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/)

SVGs in `/assets/deborah_ufw` provided by @deborah-ufw

SVGs in `/assets/simple` are pulled from trivial examples or generated to test
basic functionality

Please submit SVGs this can't render properly (e.g. that don't render here the
way they do in chrome), as long as they're not using anything "probably out of
scope" (above).