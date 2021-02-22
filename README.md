# flutter_svg

[![Pub](https://img.shields.io/pub/v/flutter_svg.svg)](https://pub.dartlang.org/packages/flutter_svg) [![Build Status](https://travis-ci.org/dnfield/flutter_svg.svg?branch=master)](https://travis-ci.org/dnfield/flutter_svg) [![Coverage Status](https://coveralls.io/repos/github/dnfield/flutter_svg/badge.svg?branch=master)](https://coveralls.io/github/dnfield/flutter_svg?branch=master)

<!-- markdownlint-disable MD033 -->
<img src="https://raw.githubusercontent.com/dnfield/flutter_svg/7d374d7107561cbd906d7c0ca26fef02cc01e7c8/example/assets/flutter_logo.svg?sanitize=true" width="200px" alt="Flutter Logo which can be rendered by this package!">
<!-- markdownlint-enable MD033 -->

Draw SVG (and _some_ Android VectorDrawable (XML)) files on a Flutter Widget.

## Getting Started

This is a Dart-native rendering library. Issues/PRs will be raised in Flutter
and flutter/engine as necessary for features that are not good candidates for
Dart implementations (especially if they're impossible to implement without
engine support). However, not everything that Skia can easily do needs to be
done by Skia; for example, the Path parsing logic here isn't much slower than
doing it in native, and Skia isn't always doing low level GPU accelerated work
where you might think it is (e.g. Dash Paths).

All of the SVGs in the `assets/` folder (except the text related one(s)) now
have corresponding PNGs in the `golden/` folder that were rendered using
`flutter test tool/gen_golden.dart` and compared against their rendering output
in Chrome. Automated tests will continue to compare these to ensure code changes
do not break known-good renderings.

Basic usage (to create an SVG rendering widget from an asset):

```dart
final String assetName = 'assets/image.svg';
final Widget svg = SvgPicture.asset(
  assetName,
  semanticsLabel: 'Acme Logo'
);
```

You can color/tint the image like so:

```dart
final String assetName = 'assets/up_arrow.svg';
final Widget svgIcon = SvgPicture.asset(
  assetName,
  color: Colors.red,
  semanticsLabel: 'A red up arrow'
);
```

The default placeholder is an empty box (`LimitedBox`) - although if a `height`
or `width` is specified on the `SvgPicture`, a `SizedBox` will be used instead
(which ensures better layout experience). There is currently no way to show an
Error visually, however errors will get properly logged to the console in debug
mode.

You can also specify a placeholder widget. The placeholder will display during
parsing/loading (normally only relevant for network access).

```dart
// Will print error messages to the console.
final String assetName = 'assets/image_that_does_not_exist.svg';
final Widget svg = SvgPicture.asset(
  assetName,
);

final Widget networkSvg = SvgPicture.network(
  'https://site-that-takes-a-while.com/image.svg',
  semanticsLabel: 'A shark?!',
  placeholderBuilder: (BuildContext context) => Container(
      padding: const EdgeInsets.all(30.0),
      child: const CircularProgressIndicator()),
);
```

If you'd like to render the SVG to some other canvas, you can do something like:

```dart
import 'package:flutter_svg/flutter_svg.dart';
final String rawSvg = '''<svg viewBox="...">...</svg>''';
final DrawableRoot svgRoot = await svg.fromSvgString(rawSvg, rawSvg);

// If you only want the final Picture output, just use
final Picture picture = svgRoot.toPicture();

// Otherwise, if you want to draw it to a canvas:
// Optional, but probably normally desirable: scale the canvas dimensions to
// the SVG's viewbox
svgRoot.scaleCanvasToViewBox(canvas);

// Optional, but probably normally desireable: ensure the SVG isn't rendered
// outside of the viewbox bounds
svgRoot.clipCanvasToViewBox(canvas);
svgRoot.draw(canvas, size);
```

The `SvgPicture` helps to automate this logic, and it provides some convenience
wrappers for getting assets from multiple sources and caching the resultant
`Picture`. _It does not render the data to an `Image` at any point_; you
certainly can do that in Flutter, but you then lose some of the benefit of
having a vector format to begin with.

While I'm making every effort to avoid needlessly changing the API, it's not
guarnateed to be stable yet (hence the pre-1.0.0 version). To date, the biggest
change is deprecating the `SvgImage` widgets in favor of `SvgPicture` - it
became very confusing to maintain that name, as `Picture`s are the underlying
mechanism for rendering rather than `Image`s.

See [main.dart](/../master/example/lib/main.dart) for a complete sample.

## Check SVG compatibility

As not all SVG features are supported by this library (see below), sometimes we have to dynamically
check if an SVG contains any unsupported features resulting in broken images.
You might also want to throw errors in tests, but only warn about them at runtime.
This can be done by using the snippet below:

```dart
final SvgParser parser = SvgParser();
try {
  parser.parse(svgString, warningsAsErrors: true);
  print('SVG is supported');
} catch (e) {
  print('SVG contains unsupported features');
}
```

> Note:
> The library currently only detects unsupported elements (like the `<style>`-tag), but not unsupported attributes.

## Use Cases

- Your designer creates a vector asset that you want to include without
  converting to 5 different raster format resolutions.
- Your vector drawing is meant to be static and non (or maybe minimally)
  interactive.
- You want to load SVGs dynamically from network sources at runtime.
- You want to paint SVG data and render it to an image.

## TODO

This list is not very well ordered. I'm mainly picking up things that seem
interesting or useful, or where I've gotten a request to fix something/example
of something that's broken.

- Support Radial gradients that use percentages in the offsets.
- Dash path with percentage dasharray values (need good examples).
- Markers.
- Filters/effects (will require upstream engine changes, but doable).
- Android Vector Drawable support beyond PoC - I'm willing to put more time into
  this if there's actually demand, but it doesn't come up often.

## Out of scope/non-goals

- SMIL animations. That just seems crazy. I think it'll be possible to animate
  the SVG but probably in a more Flutter driven way.
- Interactivity/events in SVG.
- Any CSS support - preprocess your SVGs (perhaps with [usvg](https://github.com/RazrFalcon/resvg/tree/master/usvg) or [scour](https://github.com/scour-project/scour) to get rid of all CSS?).
- Scripting in SVGs
- Foreign elements
- Rendering properties/hints

## Recommended Adobe Illustrator SVG Configuration
- In Styling: choose Presentation Attributes instead of Inline CSS because CSS is not fully supported.
- In Images: choose Embded not Linked to other file to get a single svg with no dependency to other files.
- In Objects IDs: choose layer names to add every layer name to svg tags or you can use minimal,it is optional.
![Export configuration](https://user-images.githubusercontent.com/2842459/62599914-91de9c00-b8fe-11e9-8fb7-4af57d5100f7.png)
## SVG sample attribution

SVGs in `/assets/w3samples` pulled from [W3 sample files](https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/)

SVGs in `/assets/deborah_ufw` provided by @deborah-ufw

SVGs in `/assets/simple` are pulled from trivial examples or generated to test
basic functionality - some of them come directly from the SVG 1.1 spec. Some
have also come or been adapted from issues raised in this repository.

SVGs in `/assets/wikimedia` are pulled from [Wikimedia Commons](https://commons.wikimedia.org/wiki/Main_Page)

Android Drawables in `/assets/android_vd` are pulled from Android Documentation
and examples.

The Flutter Logo created based on the Flutter Logo Widget © Google.

The Dart logo is from
[dartlang.org](https://github.com/dart-lang/site-shared/blob/master/src/_assets/images/dart/logo%2Btext/horizontal/original.svg)
© Google

SVGs in `/assets/noto-emoji` are from [Google i18n noto-emoji](https://github.com/googlei18n/noto-emoji),
licensed under the Apache license.

Please submit SVGs this can't render properly (e.g. that don't render here the
way they do in chrome), as long as they're not using anything "probably out of
scope" (above).

## Alternatives

- [Rive](https://rive.app/) supports importing SVGs and animating vector graphics.
- [FlutterShapeMaker](https://fluttershapemaker.com) supports converting SVGs to [CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html) widgets.
