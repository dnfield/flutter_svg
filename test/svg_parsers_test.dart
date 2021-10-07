import 'dart:ui' show Color, Offset, PathFillType, Size;

import 'package:flutter_svg/parser.dart';
import 'package:flutter_svg/src/svg/parsers.dart';
import 'package:flutter_svg/src/svg/theme.dart';
import 'package:flutter_svg/src/vector_drawable.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  late SvgTheme theme;

  setUp(() {
    theme = const SvgTheme(fontSize: 14.0);
  });

  test('SVG Multiple transform parser tests', () {
    Matrix4 expected = Matrix4.identity();
    expected.translate(0.338957, 0.010104, 0);
    expected.translate(-0.5214, 0.125, 0);
    expected.translate(0.987, 0.789, 0);
    expect(
        parseTransform(
            'translate(0.338957,0.010104), translate(-0.5214,0.125),translate(0.987,0.789)'),
        expected);

    expected = Matrix4.translationValues(0.338957, 0.010104, 0);
    expected.scale(0.869768, 1.000000, 1.0);
    expect(
        parseTransform('translate(0.338957,0.010104),scale(0.869768,1.000000)'),
        expected);
  });

  test('SVG Transform parser tests', () {
    expect(() => parseTransform('invalid'), throwsStateError);
    expect(() => parseTransform('transformunsupported(0,0)'), throwsStateError);

    expect(parseTransform('skewX(60)'), Matrix4.skewX(60.0));
    expect(parseTransform('skewY(60)'), Matrix4.skewY(60.0));
    expect(parseTransform('translate(10,0.0)'),
        Matrix4.translationValues(10.0, 0.0, 0.0));
    expect(parseTransform('skewX(60)'), Matrix4.skewX(60.0));

    expect(parseTransform('scale(10)'),
        Matrix4.identity()..scale(10.0, 10.0, 1.0));
    expect(parseTransform('scale(10, 15)'),
        Matrix4.identity()..scale(10.0, 15.0, 1.0));

    expect(parseTransform('rotate(20)'), Matrix4.rotationZ(radians(20.0)));
    expect(
        parseTransform('rotate(20, 30)'),
        Matrix4.identity()
          ..translate(30.0, 30.0)
          ..rotateZ(radians(20.0))
          ..translate(-30.0, -30.0));
    expect(
        parseTransform('rotate(20, 30, 40)'),
        Matrix4.identity()
          ..translate(30.0, 40.0)
          ..rotateZ(radians(20.0))
          ..translate(-30.0, -40.0));

    expect(
        parseTransform('matrix(1.5, 2.0, 3.0, 4.0, 5.0, 6.0)'),
        Matrix4.fromList(<double>[
          1.5, 2.0, 0.0, 0.0, //
          3.0, 4.0, 0.0, 0.0,
          0.0, 0.0, 1.0, 0.0,
          5.0, 6.0, 0.0, 1.0
        ]));

    expect(
        parseTransform('matrix(1.5, 2.0, 3.0, 4.0, 5.0, 6.0 )'),
        Matrix4.fromList(<double>[
          1.5, 2.0, 0.0, 0.0, //
          3.0, 4.0, 0.0, 0.0,
          0.0, 0.0, 1.0, 0.0,
          5.0, 6.0, 0.0, 1.0
        ]));

    expect(parseTransform('rotate(20)\n\tscale(10)'),
        Matrix4.rotationZ(radians(20.0))..scale(10.0, 10.0, 1.0));
  });

  test('FillRule tests', () {
    expect(parseRawFillRule(''), PathFillType.nonZero);
    expect(parseRawFillRule(null), isNull);
    expect(parseRawFillRule('inherit'), isNull);
    expect(parseRawFillRule('nonzero'), PathFillType.nonZero);
    expect(parseRawFillRule('evenodd'), PathFillType.evenOdd);
    expect(parseRawFillRule('invalid'), PathFillType.nonZero);
  });

  test('TextAnchor tests', () {
    expect(parseTextAnchor(''), DrawableTextAnchorPosition.start);
    expect(parseTextAnchor(null), DrawableTextAnchorPosition.start);
    expect(parseTextAnchor('inherit'), isNull);
    expect(parseTextAnchor('start'), DrawableTextAnchorPosition.start);
    expect(parseTextAnchor('middle'), DrawableTextAnchorPosition.middle);
    expect(parseTextAnchor('end'), DrawableTextAnchorPosition.end);
  });

  T? find<T extends Drawable>(Drawable drawable, String id) {
    if (drawable.id == id && drawable is T) {
      return drawable;
    }

    if (drawable is DrawableParent) {
      final DrawableParent parent = drawable;
      for (Drawable item in parent.children!) {
        final Drawable? found = find<T>(item, id);

        if (found != null) {
          return found as T;
        }
      }
    }
    return null;
  }

  test('Font size parsing tests', () {
    const double fontSize = 14.0;
    expect(parseFontSize(null, fontSize: fontSize), isNull);
    expect(parseFontSize('', fontSize: fontSize), isNull);
    expect(parseFontSize('1', fontSize: fontSize), 1);
    expect(parseFontSize('  1 ', fontSize: fontSize), 1);
    expect(parseFontSize('xx-small', fontSize: fontSize), 10);
    expect(parseFontSize('x-small', fontSize: fontSize), 12);
    expect(parseFontSize('small', fontSize: fontSize), 14);
    expect(parseFontSize('medium', fontSize: fontSize), 18);
    expect(parseFontSize('large', fontSize: fontSize), 22);
    expect(parseFontSize('x-large', fontSize: fontSize), 26);
    expect(parseFontSize('xx-large', fontSize: fontSize), 32);

    expect(parseFontSize('larger', fontSize: fontSize),
        parseFontSize('large', fontSize: fontSize));
    expect(
        parseFontSize('larger',
            fontSize: fontSize,
            parentValue: parseFontSize('large', fontSize: fontSize)),
        parseFontSize('large', fontSize: fontSize)! * 1.2);
    expect(parseFontSize('smaller', fontSize: fontSize),
        parseFontSize('small', fontSize: fontSize));
    expect(
        parseFontSize('smaller',
            fontSize: fontSize,
            parentValue: parseFontSize('large', fontSize: fontSize)),
        parseFontSize('large', fontSize: fontSize)! / 1.2);

    expect(() => parseFontSize('invalid', fontSize: fontSize),
        throwsA(const TypeMatcher<StateError>()));
  });

  test('Check no child with id for svg', () async {
    final SvgParser parser = SvgParser();
    final DrawableRoot root = await parser.parse(
      '<svg id="test" viewBox="0 0 10 10"><text /></svg>',
      theme: theme,
    );
    expect(root.children.isEmpty, true);
    expect(root.id == 'test', true);
  });

  test('Check any ids', () async {
    const String svgStr =
        '''<svg id="svgRoot" xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 166 202">
    <defs>
        <linearGradient id="triangleGradient">
            <stop offset="20%" stop-color="#000000" stop-opacity=".55" />
            <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
        </linearGradient>
        <linearGradient id="rectangleGradient" x1="0%" x2="0%" y1="0%" y2="100%">
            <stop offset="20%" stop-color="#000000" stop-opacity=".15" />
            <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
        </linearGradient>
    </defs>
    <path id="path1" fill="#42A5F5" fill-opacity=".8" d="M37.7 128.9 9.8 101 100.4 10.4 156.2 10.4"/>
    <path id="path2" fill="#42A5F5" fill-opacity=".8" d="M156.2 94 100.4 94 79.5 114.9 107.4 142.8"/>
    <path id="path3" fill="#0D47A1" d="M79.5 170.7 100.4 191.6 156.2 191.6 156.2 191.6 107.4 142.8"/>
    <g id="group1" transform="matrix(0.7071, -0.7071, 0.7071, 0.7071, -77.667, 98.057)">
        <rect width="39.4" height="39.4" x="59.8" y="123.1" fill="#42A5F5" />
        <rect width="39.4" height="5.5" x="59.8" y="162.5" fill="url(#rectangleGradient)" />
    </g>
    <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#triangleGradient)" />
</svg>''';
    final SvgParser parser = SvgParser();
    final DrawableRoot root = await parser.parse(svgStr, theme: theme);

    expect(root.id == 'svgRoot', true);
    expect(find<DrawableGroup>(root, 'group1') != null, true);
    expect(find<DrawableShape>(root, 'path1') != null, true);
    expect(find<DrawableShape>(root, 'path2') != null, true);
    expect(find<DrawableShape>(root, 'path3') != null, true);
    expect(find<DrawableShape>(root, 'path4') != null, true);
  });

  test('Check No Svg id', () async {
    const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="27px" height="90px" viewBox="5 10 18 70" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <!-- Generator: Sketch 53 (72520) - https://sketchapp.com -->
    <title>svg/stick_figure</title>
    <desc>Created with Sketch.</desc>
    <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
        <g id="iPhone-8" transform="translate(-53.000000, -359.000000)" stroke="#979797">
            <g id="stick_figure" transform="translate(53.000000, 359.000000)">
                <ellipse id="Oval" fill="#D8D8D8" cx="13.5" cy="12" rx="12" ry="11.5"></ellipse>
                <path d="M13.5,24 L13.5,71.5" id="Line" stroke-linecap="square"></path>
                <path d="M13.5,71.5 L1,89.5" id="Line-1" stroke-linecap="square"></path>
                <path d="M13.5,37.5 L1,55.5" id="Line-2" stroke-linecap="square"></path>
                <path d="M26.5,71.5 L14,89.5" id="Line-3" stroke-linecap="square" transform="translate(20.000000, 80.500000) scale(-1, 1) translate(-20.000000, -80.500000) "></path>
                <path d="M26.5,37.5 L14,55.5" id="Line-2-Copy" stroke-linecap="square" transform="translate(20.000000, 46.500000) scale(-1, 1) translate(-20.000000, -46.500000) "></path>
            </g>
        </g>
    </g>
</svg>''';

    final SvgParser parser = SvgParser();
    final DrawableRoot root = await parser.parse(svgStr, theme: theme);

    expect(root.id!.isEmpty, true);
    expect(find<DrawableGroup>(root, 'Page-1') != null, true);
    expect(find<DrawableGroup>(root, 'iPhone-8') != null, true);
    expect(find<DrawableGroup>(root, 'stick_figure') != null, true);
    expect(find<DrawableShape>(root, 'Oval') != null, true);
  });

  test('Throws with unsupported elements with warnings as errors enabled',
      () async {
    const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="27px" height="90px" viewBox="5 10 18 70" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <!-- Generator: Sketch 53 (72520) - https://sketchapp.com -->
    <title>svg/stick_figure</title>
    <desc>Created with Sketch.</desc>
    <style> #Oval { fill: #D8D8D8; } </style>
    <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
        <g id="iPhone-8" transform="translate(-53.000000, -359.000000)" stroke="#979797">
            <g id="stick_figure" transform="translate(53.000000, 359.000000)">
                <ellipse id="Oval" cx="13.5" cy="12" rx="12" ry="11.5"></ellipse>
                <path d="M13.5,24 L13.5,71.5" id="Line" stroke-linecap="square"></path>
                <path d="M13.5,71.5 L1,89.5" id="Line-1" stroke-linecap="square"></path>
                <path d="M13.5,37.5 L1,55.5" id="Line-2" stroke-linecap="square"></path>
                <path d="M26.5,71.5 L14,89.5" id="Line-3" stroke-linecap="square" transform="translate(20.000000, 80.500000) scale(-1, 1) translate(-20.000000, -80.500000) "></path>
                <path d="M26.5,37.5 L14,55.5" id="Line-2-Copy" stroke-linecap="square" transform="translate(20.000000, 46.500000) scale(-1, 1) translate(-20.000000, -46.500000) "></path>
            </g>
        </g>
    </g>
</svg>''';
    final SvgParser parser = SvgParser();
    expect(
      parser.parse(svgStr, theme: theme, warningsAsErrors: true),
      throwsA(anything),
    );
  });

  test('Warns about unsupported elements by default', () async {
    const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="27px" height="90px" viewBox="5 10 18 70" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <!-- Generator: Sketch 53 (72520) - https://sketchapp.com -->
    <title>svg/stick_figure</title>
    <desc>Created with Sketch.</desc>
    <style> #Oval { fill: #D8D8D8; } </style>
    <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
        <g id="iPhone-8" transform="translate(-53.000000, -359.000000)" stroke="#979797">
            <g id="stick_figure" transform="translate(53.000000, 359.000000)">
                <ellipse id="Oval" cx="13.5" cy="12" rx="12" ry="11.5"></ellipse>
                <path d="M13.5,24 L13.5,71.5" id="Line" stroke-linecap="square"></path>
                <path d="M13.5,71.5 L1,89.5" id="Line-1" stroke-linecap="square"></path>
                <path d="M13.5,37.5 L1,55.5" id="Line-2" stroke-linecap="square"></path>
                <path d="M26.5,71.5 L14,89.5" id="Line-3" stroke-linecap="square" transform="translate(20.000000, 80.500000) scale(-1, 1) translate(-20.000000, -80.500000) "></path>
                <path d="M26.5,37.5 L14,55.5" id="Line-2-Copy" stroke-linecap="square" transform="translate(20.000000, 46.500000) scale(-1, 1) translate(-20.000000, -46.500000) "></path>
            </g>
        </g>
    </g>
</svg>''';

    final SvgParser parser = SvgParser();
    expect(await parser.parse(svgStr, theme: theme), isA<DrawableRoot>());
  });

  test('Respects whitespace attribute', () async {
    const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg viewBox="0 0 50 50" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <text id="preserve-space" xml:space="preserve"> </text>
  <text id="remove-space"> </text>
</svg>''';

    final SvgParser parser = SvgParser();
    final DrawableRoot root = await parser.parse(svgStr, theme: theme);

    expect(find<DrawableText>(root, 'preserve-space') != null, true);
    // Empty text elements get removed
    expect(find<DrawableText>(root, 'remove-space') != null, false);
  });

  group('currentColor', () {
    group('stroke', () {
      test(
          'respects currentColor from SvgTheme '
          'when no color attribute exists on the parent', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg viewBox="0 0 100 100" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
   <circle id="circle" r="25" cx="70" cy="70" stroke="currentColor" fill="none" stroke-width="5" />
</svg>''';

        const Color currentColor = Color(0xFFB0E3BE);

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: currentColor,
            fontSize: 14.0,
          ),
        );

        final DrawableShape? circle = find<DrawableShape>(root, 'circle');

        expect(circle, isNotNull);

        expect(
          circle!.style.stroke?.color,
          equals(currentColor),
        );
      });

      test(
          'respects currentColor from SvgTheme '
          'when the parent uses currentColor', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg color="currentColor" viewBox="0 0 100 100" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
  <g>
    <circle id="circle" r="25" cx="70" cy="70" stroke="currentColor" fill="none" stroke-width="5" />
  </g>
</svg>''';

        const Color currentColor = Color(0xFFB0E3BE);

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: currentColor,
            fontSize: 14.0,
          ),
        );

        final DrawableShape? circle = find<DrawableShape>(root, 'circle');

        expect(circle, isNotNull);

        expect(
          circle!.style.stroke?.color,
          equals(currentColor),
        );
      });

      test(
          'respects currentColor from the parent '
          'when the parent overrides currentColor', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg color="currentColor" viewBox="0 0 100 100" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
  <g color="#c460b7">
    <circle id="circle" r="25" cx="70" cy="70" stroke="currentColor" fill="none" stroke-width="5" />
  </g>
</svg>''';

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: Color(0xFFB0E3BE),
            fontSize: 14.0,
          ),
        );

        final DrawableShape? circle = find<DrawableShape>(root, 'circle');

        expect(circle, isNotNull);

        expect(
          circle!.style.stroke?.color,
          equals(const Color(0xffC460B7)),
        );
      });
    });

    group('fill', () {
      test(
          'respects currentColor from SvgTheme '
          'when no color attribute exists on the parent', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg viewBox="0 0 100 100" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
   <circle id="circle" r="25" cx="70" cy="70" fill="currentColor" />
</svg>''';

        const Color currentColor = Color(0xFFB0E3BE);

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: currentColor,
            fontSize: 14.0,
          ),
        );

        final DrawableShape? circle = find<DrawableShape>(root, 'circle');

        expect(circle, isNotNull);

        expect(
          circle!.style.fill?.color,
          equals(currentColor),
        );
      });

      test(
          'respects currentColor from SvgTheme '
          'when the parent uses currentColor', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg color="currentColor" viewBox="0 0 100 100" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
  <g>
    <circle id="circle" r="25" cx="70" cy="70" fill="currentColor" />
  </g>
</svg>''';

        const Color currentColor = Color(0xFFB0E3BE);

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: currentColor,
            fontSize: 14.0,
          ),
        );

        final DrawableShape? circle = find<DrawableShape>(root, 'circle');

        expect(circle, isNotNull);

        expect(
          circle!.style.fill?.color,
          equals(currentColor),
        );
      });

      test(
          'respects currentColor from the parent '
          'when the parent overrides currentColor', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg color="currentColor" viewBox="0 0 100 100" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
  <g color="#c460b7">
    <circle id="circle" r="25" cx="70" cy="70" fill="currentColor" />
  </g>
</svg>''';

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: Color(0xFFB0E3BE),
            fontSize: 14.0,
          ),
        );

        final DrawableShape? circle = find<DrawableShape>(root, 'circle');

        expect(circle, isNotNull);

        expect(
          circle!.style.fill?.color,
          equals(const Color(0xFFC460B7)),
        );
      });
    });

    group('stop-color', () {
      test(
          'respects currentColor from SvgTheme '
          'when no color attribute exists on the parent', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg viewBox="0 0 166 202" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
    <defs>
        <linearGradient id="gradient-1">
            <stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5" />
            <stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8" />
        </linearGradient>
    </defs>
    <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)" />
</svg>''';

        const Color currentColor = Color(0xFFB0E3BE);

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: currentColor,
            fontSize: 14.0,
          ),
        );

        final DrawableLinearGradient? gradient =
            root.definitions.getGradient('url(#gradient-1)');

        expect(gradient, isNotNull);

        expect(
          gradient!.colors?[0],
          equals(currentColor.withOpacity(0.5)),
        );

        expect(
          gradient.colors?[1],
          equals(currentColor.withOpacity(0.8)),
        );
      });

      test(
          'respects currentColor from SvgTheme '
          'when the parent uses currentColor', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg color="currentColor" viewBox="0 0 166 202" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
    <defs>
        <linearGradient id="gradient-1">
            <stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5" />
            <stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8" />
        </linearGradient>
    </defs>
    <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)" />
</svg>''';

        const Color currentColor = Color(0xFFB0E3BE);

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: currentColor,
            fontSize: 14.0,
          ),
        );

        final DrawableLinearGradient? gradient =
            root.definitions.getGradient('url(#gradient-1)');

        expect(gradient, isNotNull);

        expect(
          gradient!.colors?[0],
          equals(currentColor.withOpacity(0.5)),
        );

        expect(
          gradient.colors?[1],
          equals(currentColor.withOpacity(0.8)),
        );
      });

      test(
          'respects currentColor from the parent '
          'when the parent overrides currentColor', () async {
        const String svgStr = '''<?xml version="1.0" encoding="UTF-8"?>
<svg color="currentColor" viewBox="0 0 166 202" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" >
    <g color="#c460b7">
        <defs>
            <linearGradient id="gradient-1">
                <stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5" />
                <stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8" />
            </linearGradient>
        </defs>
        <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)" />
    </g>
</svg>''';

        final SvgParser parser = SvgParser();
        final DrawableRoot root = await parser.parse(
          svgStr,
          theme: const SvgTheme(
            currentColor: Color(0xFFB0E3BE),
            fontSize: 14.0,
          ),
        );

        final DrawableLinearGradient? gradient =
            root.definitions.getGradient('url(#gradient-1)');

        expect(gradient, isNotNull);

        expect(
          gradient!.colors?[0],
          equals(const Color(0xFFC460B7).withOpacity(0.5)),
        );

        expect(
          gradient.colors?[1],
          equals(const Color(0xFFC460B7).withOpacity(0.8)),
        );
      });
    });
  });

  group('calculates em units based on the font size for', () {
    test('svg (width, height)', () async {
      const String svgStr = '''
<svg width="5em" height="6em" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" />
''';

      const double fontSize = 26.0;
      final SvgParser parser = SvgParser();
      final DrawableRoot root = await parser.parse(
        svgStr,
        theme: const SvgTheme(
          fontSize: fontSize,
        ),
      );

      expect(root.viewport.width, equals(fontSize * 5));
      expect(root.viewport.height, equals(fontSize * 6));
    });

    test('use (x, y)', () async {
      const String svgStr = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle id="circle" cx="5" cy="5" r="4" stroke="blue"/>
  <use id="anotherCircle" href="#circle" x="2em" y="4em" fill="blue"/>
</svg>
''';

      const double fontSize = 26.0;
      final SvgParser parser = SvgParser();
      final DrawableRoot root = await parser.parse(
        svgStr,
        theme: const SvgTheme(
          fontSize: fontSize,
        ),
      );

      final DrawableGroup? circle = find<DrawableGroup>(root, 'anotherCircle');

      const double expectedX = fontSize * 2;
      const double expectedY = fontSize * 4;

      expect(circle, isNotNull);
      expect(
        circle!.transform,
        equals(
          (Matrix4.identity()..translate(expectedX, expectedY)).storage,
        ),
      );
    });

    test('text (x, y)', () async {
      const String svgStr = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <text id="text" x="2em" y="4em">Test</text>
</svg>
''';

      const double fontSize = 26.0;
      final SvgParser parser = SvgParser();
      final DrawableRoot root = await parser.parse(
        svgStr,
        theme: const SvgTheme(
          fontSize: fontSize,
        ),
      );

      final DrawableText? text = find<DrawableText>(root, 'text');

      const Offset expectedOffset = Offset(fontSize * 2, fontSize * 4);

      expect(text, isNotNull);
      expect(text!.offset, equals(expectedOffset));
    });

    test('radialGradient (cx, cy, r, fx, fy)', () async {
      const String svgStr = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="gradient" cx="1em" cy="2em" r="1.1em" fx="1.5em" fy="1.6em" gradientUnits="userSpaceOnUse">
      <stop offset="10%" stop-color="gold" />
      <stop offset="95%" stop-color="red" />
    </radialGradient>
  </defs>
</svg>
''';

      const double fontSize = 26.0;
      final SvgParser parser = SvgParser();
      final DrawableRoot root = await parser.parse(
        svgStr,
        theme: const SvgTheme(
          fontSize: fontSize,
        ),
      );

      final DrawableRadialGradient? gradient =
          root.definitions.getGradient('url(#gradient)');

      expect(gradient, isNotNull);

      const Offset expectedOffset = Offset(fontSize * 1, fontSize * 2);
      const double expectedRadius = fontSize * 1.1;
      const Offset expectedFocal = Offset(fontSize * 1.5, fontSize * 1.6);

      expect(gradient, isNotNull);
      expect(gradient!.center, equals(expectedOffset));
      expect(gradient.radius, equals(expectedRadius));
      expect(gradient.focal, equals(expectedFocal));
    });

    test('linearGradient (x1, y1, x2, y2)', () async {
      const String svgStr = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <linearGradient id="gradient" gradientUnits="userSpaceOnUse" x1="1em" x2="1.5em" y1="1.75em" y2="1.6em">
    <stop offset="5%"  stop-color="black" />
    <stop offset="50%" stop-color="red"   />
    <stop offset="95%" stop-color="black" />
  </linearGradient>
</svg>
''';

      const double fontSize = 26.0;
      final SvgParser parser = SvgParser();
      final DrawableRoot root = await parser.parse(
        svgStr,
        theme: const SvgTheme(
          fontSize: fontSize,
        ),
      );

      final DrawableLinearGradient? gradient =
          root.definitions.getGradient('url(#gradient)');

      expect(gradient, isNotNull);

      const Offset expectedFromOffset = Offset(fontSize * 1, fontSize * 1.75);
      const Offset expectedToOffset = Offset(fontSize * 1.5, fontSize * 1.6);

      expect(gradient, isNotNull);
      expect(gradient!.from, equals(expectedFromOffset));
      expect(gradient.to, equals(expectedToOffset));
    });

    test('image (x, y, width, height)', () async {
      const String svgStr = '''
<svg viewBox="0 0 50 50" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <image id="image" xlink:href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA
UAAAAFCAYAAACNb yblA AAAHElEQVQI12P4//8/w3 8GIAXDIBKE0DHxgljN
BAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" x="1em" y="0.5em" width="2em" height="1.5em" />
</svg>
''';

      const double fontSize = 26.0;
      final SvgParser parser = SvgParser();
      final DrawableRoot root = await parser.parse(
        svgStr,
        theme: const SvgTheme(
          fontSize: fontSize,
        ),
      );

      final DrawableRasterImage? image =
          find<DrawableRasterImage>(root, 'image');

      const Offset expectedOffset = Offset(fontSize * 1, fontSize * 0.5);
      const Size expectedSize = Size(fontSize * 2, fontSize * 1.5);

      expect(image, isNotNull);
      expect(image!.offset, equals(expectedOffset));
      expect(image.size, equals(expectedSize));
    });
  });
}
