# flutter_svg

[![Build Status](https://travis-ci.org/dnfield/flutter_svg.svg?branch=master)](https://travis-ci.org/dnfield/flutter_svg)

Draw SVG and Android VectorDrawable (XML) files on a Flutter Widget.

<img src="/../master/assets/flutter_logo.svg?sanitize=true" width="200px" alt="Flutter Logo">

## Getting Started

This is a Dart-native rendering library. Issues/PRs will be raised in Flutter
and flutter/engine as necessary for features that are not good candidates for
Dart implementations (especially if they're impossible to implement without
engine support).  However, not everything that Skia can easily do needs to be
done by Skia; for example, the Path parsing logic here isn't much slower than
doing it in native, and Skia isn't always doing low level GPU accelerated work
where you might think it is (e.g. Dash Paths).

Basic usage (to create an SVG rendering widget from an asset):

```dart
final String assetName = 'assets/image.svg';
final Widget svg = new SvgImage.asset(
  assetName,
  new Size(100.0, 100.0),
);
```

See [main.dart](/../master/lib/main.dart) for a complete sample.

## TODO

This list is roughly ordered.

- [ ] Text support
- [ ] Gradient support (Linear: Mostly done, Radial: partly done)
- [ ] Dash path support
- [ ] More SVG samples to cover more complicated cases
- [ ] Display/visibility support
- [ ] Unit tests
- [ ] Inerhitance of inheritable properties (necessary? preprocess?)
- [ ] Support for minimal CSS/styles?  See also [svgcleaner](https://github.com/razrfalcon/svgcleaner)
- [ ] XLink/ref support (necessary? partially supported for gradients)
- [ ] Glyph support?
- [ ] Markers
- [ ] Filters/effects
- [ ] Android Vector Drawable support (partial so far)
- [ ] Caching of image

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

Please submit SVGs this can't render properly (e.g. that don't render here the
way they do in chrome), as long as they're not using anything "probably out of
scope" (above).