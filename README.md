# flutter_svg

[![Pub](https://img.shields.io/pub/v/flutter_svg.svg)](https://pub.dartlang.org/packages/flutter_svg) [![Build Status](https://travis-ci.org/dnfield/flutter_svg.svg?branch=master)](https://travis-ci.org/dnfield/flutter_svg) [![Coverage Status](https://coveralls.io/repos/github/dnfield/flutter_svg/badge.svg?branch=master)](https://coveralls.io/github/dnfield/flutter_svg?branch=master)

<img src="/../master/assets/flutter_logo.svg?sanitize=true" width="200px" alt="Flutter Logo which can be rendered by this package!">

Draw SVG and Android VectorDrawable (XML) files on a Flutter Widget.

## Getting Started

This is a Dart-native rendering library. Issues/PRs will be raised in Flutter
and flutter/engine as necessary for features that are not good candidates for
Dart implementations (especially if they're impossible to implement without
engine support).  However, not everything that Skia can easily do needs to be
done by Skia; for example, the Path parsing logic here isn't much slower than
doing it in native, and Skia isn't always doing low level GPU accelerated work
where you might think it is (e.g. Dash Paths).

All of the SVGs in the `assets/` folder (except the text related one(s)) now
have corresponding PNGs in the `golden/` folder that were rendered using
`flutter test tool/gen_golden.dart` and compared against their rendering output
in Chrome. Automated tests will continue to compare these to ensure code
changes do not break known-good renderings.

Basic usage (to create an SVG rendering widget from an asset):

```dart
final String assetName = 'assets/image.svg';
final Widget svg = new SvgImage.asset(
  assetName,
  new Size(100.0, 100.0),
);
```

If you'd like to render the SVG to some other canvas, you can do something like:

```dart
import 'package:flutter_svg/flutter_svg.dart' as svg;
final svg.DrawableRoot svgRoot = await svg.loadAsset('assets/image.svg');

// Optional, but probably normally desireable: scale the canvas dimensions to
// the SVG's viewbox
svgRoot.scaleCanvasToViewBox(canvas);

// Optional, but probably normally desireable: ensure the SVG isn't rendered
// outside of the viewbox bounds
svgRoot.clipCanvasToViewBox(canvas);
svgRoot.draw(canvas, size);
```

While I'm making every effort to avoid needlessly changing the API, it's not
guarnateed to be stable yet (hence the pre-1.0.0 version).

See [main.dart](/../master/example/main.dart) for a complete sample.

## Use Cases

- Your designer creates a vector asset that you want to include without converting to 5 different
  raster format resolutions.
- Your vector drawing is meant to be static and non (or maybe minimally) interactive.
- You want to load SVGs dynamically from network sources at runtime.
- You want to paint SVG data and render it to an image.

## TODO

This list is not very well ordered.  I'm mainly picking up things that seem interesting or useful,
or where I've gotten a request to fix something/example of something that's broken.

- [ ] Text support.
- [ ] Gradient support (Linear: Mostly done, Radial: partly done).
- [x] Dash path support.
- [ ] Dash path with percentage dasharray values.
- [ ] More SVG samples to cover more complicated cases (getting there - please send me samples of
      things that don't work!).
- [ ] Display/visibility support.
- [ ] Unit tests. In particular, tests that validate XML -> Drawable* structures. (Vastly improved as of 0.2.)
- [ ] Inheritance of inheritable properties (~~necessary? preprocess?~~ significant progress).
- [ ] Support for minimal CSS/styles?  See also
      [svgcleaner](https://github.com/razrfalcon/svgcleaner) (partial - style attr mostly supported).
- [ ] XLink/ref support (necessary? partially supported for gradients).
- [ ] Glyph support?
- [ ] Markers.
- [ ] Filters/effects.
- [ ] Android Vector Drawable support (partial so far).
- [ ] Caching of image.
- [ ] The XML parsing implementation is heavy for what this really needs.  I've made efforts to keep
      the API forward-reading-only compatible to eventually be able to use a SAX/XMLReader style
      parser.
- [ ] Color swapping/hue shifting/tinting of asset.

## Probably out of scope

- SMIL animations. That just seems crazy.
- Full (any?) CSS support - preprocess your SVGs (perhaps with svgcleaner to get rid of all CSS?)
- Scripting in SVGs
- Foreign elements
- Rendering properties/hints

## SVG sample attribution

SVGs in `/assets/w3samples` pulled from [W3 sample files](https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/)

SVGs in `/assets/deborah_ufw` provided by @deborah-ufw

SVGs in `/assets/simple` are pulled from trivial examples or generated to test
basic functionality - some of them come directly from the SVG 1.1 spec.

SVGs in `/assets/wikimedia` are pulled from [Wikimedia Commons](https://commons.wikimedia.org/wiki/Main_Page)

Android Drawables in `assets/android_vd` are pulled from Android Documentation and examples.

The Flutter Logo created based on the Flutter Logo Widget.

The Dart logo is from [darglang.org](https://github.com/dart-lang/site-shared/blob/master/src/_assets/images/dart/logo%2Btext/horizontal/original.svg) (c) Google

Please submit SVGs this can't render properly (e.g. that don't render here the
way they do in chrome), as long as they're not using anything "probably out of
scope" (above).
