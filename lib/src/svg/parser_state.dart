import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml_events.dart' hide parseEvents;

import '../svg/theme.dart';
import '../utilities/errors.dart';
import '../utilities/numbers.dart';
import '../utilities/xml.dart';
import '../vector_drawable.dart';
import 'parsers.dart';

final Set<String> _unhandledElements = <String>{'title', 'desc'};

typedef _ParseFunc = Future<void>? Function(SvgParserState parserState,
    Map<String, String> attributes, bool warningsAsErrors);
typedef _PathFunc = Path? Function(
    SvgParserState parserState, Map<String, String> attributes);

final RegExp _trimPattern = RegExp(r'[\r|\n|\t]');

const Map<String, _ParseFunc> _svgElementParsers = <String, _ParseFunc>{
  'svg': _Elements.svg,
  'g': _Elements.g,
  'a': _Elements.g, // treat as group
  'use': _Elements.use,
  'symbol': _Elements.symbol,
  'mask': _Elements.symbol, // treat as symbol
  'radialGradient': _Elements.radialGradient,
  'linearGradient': _Elements.linearGradient,
  'clipPath': _Elements.clipPath,
  'image': _Elements.image,
  'text': _Elements.text,
};

const Map<String, _PathFunc> _svgPathFuncs = <String, _PathFunc>{
  'circle': _Paths.circle,
  'path': _Paths.path,
  'rect': _Paths.rect,
  'polygon': _Paths.polygon,
  'polyline': _Paths.polyline,
  'ellipse': _Paths.ellipse,
  'line': _Paths.line,
};

Offset _parseCurrentOffset(SvgParserState parserState,
    Map<String, String> attributes, Offset? lastOffset) {
  final String? x = getAttribute(attributes, 'x', def: null);
  final String? y = getAttribute(attributes, 'y', def: null);

  return Offset(
    x != null
        ? parserState.parseDoubleWithUnits(x)!
        : parserState.parseDoubleWithUnits(
              getAttribute(attributes, 'dx', def: '0'),
            )! +
            (lastOffset?.dx ?? 0),
    y != null
        ? parserState.parseDoubleWithUnits(y)!
        : parserState.parseDoubleWithUnits(
              getAttribute(attributes, 'dy', def: '0'),
            )! +
            (lastOffset?.dy ?? 0),
  );
}

class _TextInfo {
  const _TextInfo(
    this.style,
    this.offset,
    this.transform,
  );

  final DrawableStyle style;
  final Offset offset;
  final Matrix4? transform;

  @override
  String toString() => '$runtimeType{$offset, $style, $transform}';
}

// ignore: avoid_classes_with_only_static_members
class _Elements {
  static Future<void>? svg(SvgParserState parserState,
      Map<String, String> attributes, bool warningsAsErrors) async {
    final DrawableViewport? viewBox = parserState.parseViewBox(attributes);

    final String? id = getAttribute(attributes, 'id', def: '');

    final Color? color = parserState.parseColor(
      getAttribute(attributes, 'color', def: null),
      currentColor: parserState.theme.currentColor,
    );

    // TODO(dnfield): Support nested SVG elements. https://github.com/dnfield/flutter_svg/issues/132
    if (parserState._root != null) {
      const String errorMessage = 'Unsupported nested <svg> element.';
      if (warningsAsErrors) {
        throw UnsupportedError(errorMessage);
      }
      FlutterError.reportError(FlutterErrorDetails(
        exception: UnsupportedError(errorMessage),
        informationCollector: () => <DiagnosticsNode>[
          ErrorDescription(
              'The root <svg> element contained an unsupported nested SVG element.'),
          if (parserState._key != null) ErrorDescription(''),
          if (parserState._key != null)
            DiagnosticsProperty<String>('Picture key', parserState._key),
        ],
        library: 'SVG',
        context: ErrorDescription('in _Element.svg'),
      ));
      parserState._processing.add(parserState._currentStartElement);
      final DrawableStyle style = await parserState.parseStyle(
          viewBox!.viewBoxRect, null, attributes,
          currentColor: color);
      parserState._parentDrawables.addLast(
        _SvgGroupTuple(
          'svg',
          DrawableGroup(
            id,
            <Drawable>[],
            style,
            color: color,
          ),
        ),
      );
    }
    parserState._root = DrawableRoot(
      id,
      viewBox!,
      <Drawable>[],
      parserState._definitions,
      await parserState.parseStyle(viewBox.viewBoxRect, null, attributes,
          currentColor: color),
      color: color,
      compatibilityTester: parserState._compatibilityTester,
    );
    parserState.addGroup(
        parserState._currentStartElement!, parserState._root, id ?? '');
    parserState._completeProcessing(id, parserState._currentStartElement);
    return;
  }

  static Future<void> g(SvgParserState parserState,
      Map<String, String> attributes, bool warningsAsErrors) async {
    if (parserState._currentStartElement?.isSelfClosing == true) {
      return;
    }
    final DrawableParent parent = parserState.currentGroup!;
    final Color? color = parserState.parseColor(
            getAttribute(attributes, 'color', def: null),
            currentColor: parent.color ?? parserState.theme.currentColor) ??
        parent.color;
    final String? id = getAttribute(attributes, 'id', def: '');
    final XmlStartElementEvent currentElement =
        parserState._currentStartElement!;
    parserState._processing.add(currentElement);

    final DrawableStyle style = await parserState.parseStyle(
        parserState.rootBounds, parent.style, attributes,
        currentColor: color);
    final DrawableGroup group = DrawableGroup(
      id,
      <Drawable>[],
      style,
      transform: parseTransform(getAttribute(attributes, 'transform'))?.storage,
      color: color,
    );
    parent.children!.add(group);
    parserState.addGroup(currentElement, group, id ?? '');
    parserState._completeProcessing(id, currentElement);
  }

  static Future<void>? symbol(SvgParserState parserState,
      Map<String, String> attributes, bool warningsAsErrors) async {
    final DrawableParent parent = parserState.currentGroup!;
    final Color? color = parserState.parseColor(
            getAttribute(attributes, 'color', def: null),
            currentColor: parent.color ?? parserState.theme.currentColor) ??
        parent.color;
    final String? id = getAttribute(attributes, 'id', def: '');
    final XmlStartElementEvent currentElement =
        parserState._currentStartElement!;
    parserState._processing.add(currentElement);
    final DrawableGroup group = DrawableGroup(
      id,
      <Drawable>[],
      await parserState.parseStyle(
        parserState.rootBounds,
        parent.style,
        attributes,
        currentColor: color,
      ),
      transform: parseTransform(getAttribute(attributes, 'transform'))?.storage,
      color: color,
    );
    parserState.addGroup(currentElement, group, id ?? '');
  }

  static Future<void>? use(SvgParserState parserState,
      Map<String, String> attributes, bool warningsAsErrors) async {
    final DrawableParent? parent = parserState.currentGroup;
    final String xlinkHref = getHrefAttribute(attributes)!;
    if (xlinkHref.isEmpty) {
      return;
    }

    final Matrix4 transform =
        parseTransform(getAttribute(attributes, 'transform')) ??
            Matrix4.identity();
    transform.translate(
      parserState.parseDoubleWithUnits(
        getAttribute(attributes, 'x', def: '0'),
      ),
      parserState.parseDoubleWithUnits(
        getAttribute(attributes, 'y', def: '0'),
      )!,
    );

    final String id = getAttribute(attributes, 'id') ?? '';
    final XmlStartElementEvent currentElement =
        parserState._currentStartElement!;
    parserState._processing.add(currentElement);
    parserState
        .parseStyle(
      parserState.rootBounds,
      parent!.style,
      attributes,
      currentColor: parent.color,
    )
        .then((DrawableStyle style) async {
      final DrawableStyleable ref =
          await parserState._getDrawable(xlinkHref, currentElement);
      final DrawableGroup group = DrawableGroup(
        id,
        <Drawable>[ref.mergeStyle(style)],
        style,
        transform: transform.storage,
      );
      parserState.checkForIri(group, id);
      parent.children!.add(group);
      parserState._completeProcessing(id, currentElement);
    });
  }

  static void parseStops(
    SvgParserState parserState,
    List<Color> colors,
    List<double> offsets,
  ) {
    final DrawableParent parent = parserState.currentGroup!;

    for (XmlEvent event in parserState._readSubtree()) {
      if (event is XmlEndElementEvent) {
        continue;
      }
      if (event is XmlStartElementEvent) {
        final Map<String, String> attributes =
            event.attributes.toAttributeMap();
        final String rawOpacity = getAttribute(
          attributes,
          'stop-opacity',
          def: '1',
        )!;
        final Color stopColor = parserState.parseColor(
                getAttribute(attributes, 'stop-color'),
                currentColor: parent.color ?? parserState.theme.currentColor) ??
            parent.color ??
            colorBlack;
        colors.add(stopColor.withOpacity(parseDouble(rawOpacity)!));

        final String rawOffset = getAttribute(
          attributes,
          'offset',
          def: '0%',
        )!;
        offsets.add(parseDecimalOrPercentage(rawOffset));
      }
    }
    return;
  }

  static Future<void> radialGradient(
    SvgParserState parserState,
    Map<String, String> attributes,
    bool warningsAsErrors,
  ) async {
    final String? gradientUnits = getAttribute(
      attributes,
      'gradientUnits',
      def: null,
    );
    bool isObjectBoundingBox = gradientUnits != 'userSpaceOnUse';

    final String? rawCx = getAttribute(attributes, 'cx', def: '50%');
    final String? rawCy = getAttribute(attributes, 'cy', def: '50%');
    final String? rawR = getAttribute(attributes, 'r', def: '50%');
    final String? rawFx = getAttribute(attributes, 'fx', def: rawCx);
    final String? rawFy = getAttribute(attributes, 'fy', def: rawCy);
    final TileMode spreadMethod = parserState.parseTileMode(attributes);
    final String? id = getAttribute(attributes, 'id');
    final String iri = parserState.buildUrlIri(id ?? '');
    final Matrix4? originalTransform = parseTransform(
      getAttribute(attributes, 'gradientTransform', def: null),
    );

    final List<double> offsets = <double>[];
    final List<Color> colors = <Color>[];

    final XmlStartElementEvent currentElement =
        parserState._currentStartElement!;
    if (parserState._currentStartElement!.isSelfClosing) {
      parserState._processing.add(currentElement);
      final String? href = getHrefAttribute(attributes);
      final DrawableGradient ref =
          await parserState._getGradient(href ?? '', currentElement);
      if (gradientUnits == null) {
        isObjectBoundingBox =
            ref.unitMode == GradientUnitMode.objectBoundingBox;
      }
      colors.addAll(ref.colors!);
      offsets.addAll(ref.offsets!);
    } else {
      parseStops(parserState, colors, offsets);
    }

    late double cx, cy, r, fx, fy;
    if (isObjectBoundingBox) {
      cx = parseDecimalOrPercentage(rawCx!);
      cy = parseDecimalOrPercentage(rawCy!);
      r = parseDecimalOrPercentage(rawR!);
      fx = parseDecimalOrPercentage(rawFx!);
      fy = parseDecimalOrPercentage(rawFy!);
    } else {
      cx = isPercentage(rawCx!)
          ? parsePercentage(rawCx) * parserState.rootBounds.width +
              parserState.rootBounds.left
          : parserState.parseDoubleWithUnits(rawCx)!;
      cy = isPercentage(rawCy!)
          ? parsePercentage(rawCy) * parserState.rootBounds.height +
              parserState.rootBounds.top
          : parserState.parseDoubleWithUnits(rawCy)!;
      r = isPercentage(rawR!)
          ? parsePercentage(rawR) *
              ((parserState.rootBounds.height + parserState.rootBounds.width) /
                  2)
          : parserState.parseDoubleWithUnits(rawR)!;
      fx = isPercentage(rawFx!)
          ? parsePercentage(rawFx) * parserState.rootBounds.width +
              parserState.rootBounds.left
          : parserState.parseDoubleWithUnits(rawFx)!;
      fy = isPercentage(rawFy!)
          ? parsePercentage(rawFy) * parserState.rootBounds.height +
              parserState.rootBounds.top
          : parserState.parseDoubleWithUnits(rawFy)!;
    }

    parserState._definitions.addGradient(
      iri,
      DrawableRadialGradient(
        center: Offset(cx, cy),
        radius: r,
        focal: (fx != cx || fy != cy) ? Offset(fx, fy) : Offset(cx, cy),
        focalRadius: 0.0,
        colors: colors,
        offsets: offsets,
        unitMode: isObjectBoundingBox
            ? GradientUnitMode.objectBoundingBox
            : GradientUnitMode.userSpaceOnUse,
        spreadMethod: spreadMethod,
        transform: originalTransform?.storage,
      ),
    );
    parserState._markUnkownDefinitionComplete(iri);
    parserState._completeProcessing(id, currentElement);
  }

  static Future<void> linearGradient(
    SvgParserState parserState,
    Map<String, String> attributes,
    bool warningsAsErrors,
  ) async {
    final String? gradientUnits = getAttribute(attributes, 'gradientUnits');
    bool isObjectBoundingBox = gradientUnits != 'userSpaceOnUse';

    final String x1 = getAttribute(attributes, 'x1', def: '0%')!;
    final String x2 = getAttribute(attributes, 'x2', def: '100%')!;
    final String y1 = getAttribute(attributes, 'y1', def: '0%')!;
    final String y2 = getAttribute(attributes, 'y2', def: '0%')!;
    final String? id = getAttribute(attributes, 'id');
    final String iri = parserState.buildUrlIri(id ?? '');
    final Matrix4? originalTransform = parseTransform(
      getAttribute(attributes, 'gradientTransform'),
    );
    final TileMode spreadMethod = parserState.parseTileMode(attributes);

    final List<Color> colors = <Color>[];
    final List<double> offsets = <double>[];
    final XmlStartElementEvent currentElement =
        parserState._currentStartElement!;
    if (parserState._currentStartElement!.isSelfClosing) {
      parserState._processing.add(currentElement);
      final String? href = getHrefAttribute(attributes);
      final DrawableGradient ref = await parserState._getGradient(
          href ?? '', parserState._currentStartElement!);
      if (gradientUnits == null) {
        isObjectBoundingBox =
            ref.unitMode == GradientUnitMode.objectBoundingBox;
      }
      colors.addAll(ref.colors!);
      offsets.addAll(ref.offsets!);
    } else {
      parseStops(parserState, colors, offsets);
    }

    Offset fromOffset, toOffset;
    if (isObjectBoundingBox) {
      fromOffset = Offset(
        parseDecimalOrPercentage(x1),
        parseDecimalOrPercentage(y1),
      );
      toOffset = Offset(
        parseDecimalOrPercentage(x2),
        parseDecimalOrPercentage(y2),
      );
    } else {
      fromOffset = Offset(
        isPercentage(x1)
            ? parsePercentage(x1) * parserState.rootBounds.width +
                parserState.rootBounds.left
            : parserState.parseDoubleWithUnits(x1)!,
        isPercentage(y1)
            ? parsePercentage(y1) * parserState.rootBounds.height +
                parserState.rootBounds.top
            : parserState.parseDoubleWithUnits(y1)!,
      );

      toOffset = Offset(
        isPercentage(x2)
            ? parsePercentage(x2) * parserState.rootBounds.width +
                parserState.rootBounds.left
            : parserState.parseDoubleWithUnits(x2)!,
        isPercentage(y2)
            ? parsePercentage(y2) * parserState.rootBounds.height +
                parserState.rootBounds.top
            : parserState.parseDoubleWithUnits(y2)!,
      );
    }
    parserState._definitions.addGradient(
      iri,
      DrawableLinearGradient(
        from: fromOffset,
        to: toOffset,
        colors: colors,
        offsets: offsets,
        spreadMethod: spreadMethod,
        unitMode: isObjectBoundingBox
            ? GradientUnitMode.objectBoundingBox
            : GradientUnitMode.userSpaceOnUse,
        transform: originalTransform?.storage,
      ),
    );
    parserState._markUnkownDefinitionComplete(iri);
    parserState._completeProcessing(id, currentElement);
  }

  static Future<void> clipPath(SvgParserState parserState,
      Map<String, String> attributes, bool warningsAsErrors) async {
    final String id =
        parserState.buildUrlIri(getAttribute(attributes, 'id') ?? '');

    final List<Path> paths = <Path>[];
    Path? currentPath;
    for (XmlEvent event in parserState._readSubtree()) {
      if (event is XmlEndElementEvent) {
        continue;
      }
      if (event is XmlStartElementEvent) {
        final _PathFunc? pathFn = _svgPathFuncs[event.name];
        final Map<String, String> attributes =
            event.attributes.toAttributeMap();

        if (pathFn != null) {
          final Path nextPath = parserState.applyTransformIfNeeded(
              pathFn(parserState, attributes), attributes)!;
          nextPath.fillType =
              parserState.parseFillRule(attributes, 'clip-rule')!;
          if (currentPath != null &&
              nextPath.fillType != currentPath.fillType) {
            currentPath = nextPath;
            paths.add(currentPath);
          } else if (currentPath == null) {
            currentPath = nextPath;
            paths.add(currentPath);
          } else {
            currentPath.addPath(nextPath, Offset.zero);
          }
        } else if (event.name == 'use') {
          final String xlinkHref = getHrefAttribute(attributes) ?? '';
          final DrawableStyleable? definitionDrawable =
              await parserState._getDrawable(xlinkHref, event);

          void extractPathsFromDrawable(Drawable? target) {
            if (target is DrawableShape) {
              paths.add(target.path);
            } else if (target is DrawableGroup) {
              target.children!.forEach(extractPathsFromDrawable);
            }
          }

          extractPathsFromDrawable(definitionDrawable);
        } else {
          final String errorMessage =
              'Unsupported clipPath child ${event.name}';
          if (warningsAsErrors) {
            throw UnsupportedError(errorMessage);
          }
          FlutterError.reportError(FlutterErrorDetails(
            exception: UnsupportedError(errorMessage),
            informationCollector: () => <DiagnosticsNode>[
              ErrorDescription(
                  'The <clipPath> element contained an unsupported child ${event.name}'),
              if (parserState._key != null) ErrorDescription(''),
              if (parserState._key != null)
                DiagnosticsProperty<String>('Picture key', parserState._key),
            ],
            library: 'SVG',
            context: ErrorDescription('in _Element.clipPath'),
          ));
        }
      }
    }
    parserState._definitions.addClipPath(id, paths);
    parserState._markUnkownDefinitionComplete(id);
  }

  static Future<void> image(SvgParserState parserState,
      Map<String, String> attributes, bool warningsAsErrors) async {
    final String? href = getHrefAttribute(attributes);
    if (href == null) {
      return;
    }
    final Offset offset = Offset(
      parserState.parseDoubleWithUnits(
        getAttribute(attributes, 'x', def: '0'),
      )!,
      parserState.parseDoubleWithUnits(
        getAttribute(attributes, 'y', def: '0'),
      )!,
    );
    final Image image = await resolveImage(href);
    final Size size = Size(
      parserState.parseDoubleWithUnits(
              getAttribute(attributes, 'width', def: null)) ??
          image.width.toDouble(),
      parserState.parseDoubleWithUnits(
              getAttribute(attributes, 'height', def: null)) ??
          image.height.toDouble(),
    );
    final DrawableParent parent = parserState._parentDrawables.last.drawable!;
    final DrawableStyle? parentStyle = parent.style;
    final DrawableParent group = parserState.currentGroup!;
    final String? id = getAttribute(attributes, 'id');
    final Float64List? transform =
        parseTransform(getAttribute(attributes, 'transform'))?.storage;
    final XmlStartElementEvent? currentElement =
        parserState._currentStartElement;
    parserState._processing.add(currentElement);

    parserState
        .parseStyle(parserState.rootBounds, parentStyle, attributes,
            currentColor: parent.color)
        .then((DrawableStyle style) {
      final DrawableRasterImage drawable = DrawableRasterImage(
        id,
        image,
        offset,
        style,
        size: size,
        transform: transform,
      );
      parserState.checkForIri(drawable, id ?? '');
      group.children!.add(drawable);
      parserState._completeProcessing(id, currentElement);
    });
  }

  static Future<void> text(
    SvgParserState parserState,
    Map<String, String> attributes,
    bool warningsAsErrors,
  ) async {
    assert(parserState.currentGroup != null);
    if (parserState._currentStartElement!.isSelfClosing) {
      return;
    }

    // <text>, <tspan> -> Collect styles
    // <tref> TBD - looks like Inkscape supports it, but no browser does.
    // XmlNodeType.TEXT/CDATA -> DrawableText
    // Track the style(s) and offset(s) for <text> and <tspan> elements
    final Queue<_TextInfo> textInfos = ListQueue<_TextInfo>();
    double lastTextWidth = 0;

    void _processText(String value, Map<String, String> attributes) {
      if (value.isEmpty) {
        return;
      }
      assert(textInfos.isNotEmpty);
      final _TextInfo lastTextInfo = textInfos.last;
      final Paragraph fill = createParagraph(
        value,
        lastTextInfo.style,
        lastTextInfo.style.fill,
      );
      final Paragraph stroke = createParagraph(
        value,
        lastTextInfo.style,
        DrawablePaint.isEmpty(lastTextInfo.style.stroke)
            ? transparentStroke
            : lastTextInfo.style.stroke,
      );
      parserState.currentGroup!.children!.add(
        DrawableText(
          getAttribute(attributes, 'id', def: ''),
          fill,
          stroke,
          lastTextInfo.offset,
          lastTextInfo.style.textStyle!.anchor ??
              DrawableTextAnchorPosition.start,
          transform: lastTextInfo.transform?.storage,
        ),
      );
      lastTextWidth = fill.maxIntrinsicWidth;
    }

    Future<void> _processStartElement(
        XmlStartElementEvent event, Map<String, String> attributes) async {
      _TextInfo? lastTextInfo;
      if (textInfos.isNotEmpty) {
        lastTextInfo = textInfos.last;
      }
      final Offset currentOffset = _parseCurrentOffset(
        parserState,
        attributes,
        lastTextInfo?.offset.translate(lastTextWidth, 0),
      );
      Matrix4? transform =
          parseTransform(getAttribute(attributes, 'transform'));
      if (lastTextInfo?.transform != null) {
        if (transform == null) {
          transform = lastTextInfo!.transform;
        } else {
          transform = lastTextInfo!.transform!.multiplied(transform);
        }
      }

      final DrawableStyle? parentStyle =
          lastTextInfo?.style ?? parserState.currentGroup!.style;

      textInfos.add(_TextInfo(
        await parserState.parseStyle(
          parserState.rootBounds,
          parentStyle,
          attributes,
        ),
        currentOffset,
        transform,
      ));
      if (event.isSelfClosing) {
        textInfos.removeLast();
      }
    }

    await _processStartElement(parserState._currentStartElement!, attributes);

    for (XmlEvent event in parserState._readSubtree()) {
      if (event is XmlCDATAEvent) {
        _processText(event.text.trim(), attributes);
      } else if (event is XmlTextEvent) {
        final String? space = getAttribute(attributes, 'space', def: null);
        if (space != 'preserve') {
          _processText(event.text.trim(), attributes);
        } else {
          _processText(event.text.replaceAll(_trimPattern, ''), attributes);
        }
      }
      if (event is XmlStartElementEvent) {
        await _processStartElement(event, attributes);
      } else if (event is XmlEndElementEvent) {
        textInfos.removeLast();
      }
    }
  }
}

// ignore: avoid_classes_with_only_static_members
class _Paths {
  static Path circle(
      SvgParserState parserState, Map<String, String> attributes) {
    final double cx = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'cx', def: '0'),
    )!;
    final double cy = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'cy', def: '0'),
    )!;
    final double r = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'r', def: '0'),
    )!;
    final Rect oval = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    return Path()..addOval(oval);
  }

  static Path path(SvgParserState parserState, Map<String, String> attributes) {
    final String d = getAttribute(attributes, 'd', def: '')!;
    return parseSvgPathData(d);
  }

  static Path rect(SvgParserState parserState, Map<String, String> attributes) {
    final double x = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'x', def: '0'),
    )!;
    final double y = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'y', def: '0'),
    )!;
    final double w = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'width', def: '0'),
    )!;
    final double h = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'height', def: '0'),
    )!;
    final Rect rect = Rect.fromLTWH(x, y, w, h);
    String? rxRaw = getAttribute(attributes, 'rx', def: null);
    String? ryRaw = getAttribute(attributes, 'ry', def: null);
    rxRaw ??= ryRaw;
    ryRaw ??= rxRaw;

    if (rxRaw != null && rxRaw != '') {
      final double rx = parserState.parseDoubleWithUnits(rxRaw)!;
      final double ry = parserState.parseDoubleWithUnits(ryRaw)!;

      return Path()..addRRect(RRect.fromRectXY(rect, rx, ry));
    }

    return Path()..addRect(rect);
  }

  static Path? polygon(
      SvgParserState parserState, Map<String, String> attributes) {
    return parsePathFromPoints(parserState, attributes, true);
  }

  static Path? polyline(
      SvgParserState parserState, Map<String, String> attributes) {
    return parsePathFromPoints(parserState, attributes, false);
  }

  static Path? parsePathFromPoints(
      SvgParserState parserState, Map<String, String> attributes, bool close) {
    final String points = getAttribute(attributes, 'points', def: '')!;
    if (points == '') {
      return null;
    }
    final String path = 'M$points${close ? 'z' : ''}';

    return parseSvgPathData(path);
  }

  static Path ellipse(
      SvgParserState parserState, Map<String, String> attributes) {
    final double cx = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'cx', def: '0'),
    )!;
    final double cy = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'cy', def: '0'),
    )!;
    final double rx = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'rx', def: '0'),
    )!;
    final double ry = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'ry', def: '0'),
    )!;

    final Rect r = Rect.fromLTWH(cx - rx, cy - ry, rx * 2, ry * 2);
    return Path()..addOval(r);
  }

  static Path line(SvgParserState parserState, Map<String, String> attributes) {
    final double x1 = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'x1', def: '0'),
    )!;
    final double x2 = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'x2', def: '0'),
    )!;
    final double y1 = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'y1', def: '0'),
    )!;
    final double y2 = parserState.parseDoubleWithUnits(
      getAttribute(attributes, 'y2', def: '0'),
    )!;

    return Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
  }
}

class _SvgGroupTuple {
  _SvgGroupTuple(this.name, this.drawable);

  final String name;
  final DrawableParent? drawable;
}

class _SvgCompatibilityTester extends CacheCompatibilityTester {
  bool usesCurrentColor = false;
  bool usesFontSize = false;

  @override
  bool isCompatible(Object oldData, Object newData) {
    if (oldData is! SvgTheme || newData is! SvgTheme) {
      return true;
    }
    if (usesCurrentColor && oldData.currentColor != newData.currentColor) {
      return false;
    }
    if (usesFontSize && oldData.fontSize != newData.fontSize) {
      return false;
    }
    return true;
  }
}

/// The implementation of [SvgParser].
///
/// Maintains state while pushing an [XmlPushReader] through the SVG tree.
class SvgParserState {
  /// Creates a new [SvgParserState].
  SvgParserState(
    Iterable<XmlEvent> events,
    this.theme,
    this._key,
    this._warningsAsErrors,
  ) : _eventIterator = events.iterator;

  _SvgCompatibilityTester _compatibilityTester = _SvgCompatibilityTester();

  /// The theme used when parsing SVG elements.
  final SvgTheme theme;
  final Iterator<XmlEvent> _eventIterator;
  final String? _key;
  final bool _warningsAsErrors;
  final DrawableDefinitionServer _definitions = DrawableDefinitionServer();
  final Map<String, Completer<void>> _unknownDefinitions =
      <String, Completer<void>>{};
  final Map<String, List<XmlStartElementEvent?>> _waitingForDefinitions =
      <String, List<XmlStartElementEvent?>>{};
  final Set<XmlStartElementEvent?> _processing = <XmlStartElementEvent?>{};
  final Queue<_SvgGroupTuple> _parentDrawables = ListQueue<_SvgGroupTuple>(10);
  Completer<void>? _drawingCompleter;
  DrawableRoot? _root;
  XmlStartElementEvent? _currentStartElement;

  /// The current depth of the reader in the XML hierarchy.
  int depth = 0;

  void _discardSubtree() {
    final int subtreeStartDepth = depth;
    while (_eventIterator.moveNext()) {
      final XmlEvent event = _eventIterator.current;
      if (event is XmlStartElementEvent && !event.isSelfClosing) {
        depth += 1;
      } else if (event is XmlEndElementEvent) {
        depth -= 1;
        assert(depth >= 0);
      }
      _currentStartElement = null;
      if (depth < subtreeStartDepth) {
        return;
      }
    }
  }

  Iterable<XmlEvent> _readSubtree() sync* {
    final int subtreeStartDepth = depth;
    while (_eventIterator.moveNext()) {
      final XmlEvent event = _eventIterator.current;
      bool isSelfClosing = false;
      if (event is XmlStartElementEvent) {
        final Map<String, String> attributeMap =
            event.attributes.toAttributeMap();
        if (getAttribute(attributeMap, 'display') == 'none' ||
            getAttribute(attributeMap, 'visibility') == 'hidden') {
          print('SVG Warning: Discarding:\n\n  $event\n\n'
              'and any children it has since it is not visible.\n'
              'If that element is meant to be visible, the `display` or '
              '`visibility` attributes should be removed.\n'
              'If that element is not meant to be visible, it would be better '
              'to remove it from the SVG file.');
          if (!event.isSelfClosing) {
            depth += 1;
            _discardSubtree();
          }
          continue;
        }
        _currentStartElement = event;
        depth += 1;
        isSelfClosing = event.isSelfClosing;
      }
      yield event;

      if (isSelfClosing || event is XmlEndElementEvent) {
        depth -= 1;
        assert(depth >= 0);
        _currentStartElement = null;
      }
      if (depth < subtreeStartDepth) {
        return;
      }
    }
  }

  /// Drive the [XmlTextReader] to EOF and produce a [DrawableRoot].
  Future<DrawableRoot> parse() async {
    _compatibilityTester = _SvgCompatibilityTester();
    for (XmlEvent event in _readSubtree()) {
      if (event is XmlStartElementEvent) {
        final Map<String, String> attributes =
            event.attributes.toAttributeMap();
        if (startElement(event, attributes)) {
          continue;
        }
        final _ParseFunc? parseFunc = _svgElementParsers[event.name];
        await parseFunc?.call(this, attributes, _warningsAsErrors);
        if (parseFunc == null) {
          if (!event.isSelfClosing) {
            _discardSubtree();
          }
          assert(() {
            unhandledElement(event);
            return true;
          }());
        }
      } else if (event is XmlEndElementEvent) {
        endElement(event);
      }
    }
    if (_processing.isNotEmpty) {
      _drawingCompleter = Completer<void>();
      await _drawingCompleter!.future;
      for (final String href in _unknownDefinitions.keys) {
        reportMissingDef(_key, href, 'parse');
      }
    }
    if (_root == null) {
      throw StateError('Invalid SVG data');
    }
    return _root!;
  }

  /// The current group, if any, in the [Drawable] heirarchy.
  DrawableParent? get currentGroup {
    assert(_parentDrawables.isNotEmpty);
    return _parentDrawables.last.drawable;
  }

  /// The root bounds of the drawable.
  Rect get rootBounds {
    assert(_root != null, 'Cannot get rootBounds with null root');
    return _root!.viewport.viewBoxRect;
  }

  /// Whether this [DrawableStyleable] belongs in the [DrawableDefinitions] or not.
  bool checkForIri(DrawableStyleable? drawable, String id) {
    final String iri = buildUrlIri(id);
    if (iri != emptyUrlIri) {
      _definitions.addDrawable(iri, drawable!);
      _markUnkownDefinitionComplete(_buildHref(id));
      return true;
    }
    return false;
  }

  /// Appends a group to the collection.
  void addGroup(
      XmlStartElementEvent event, DrawableParent? drawable, String id) {
    _parentDrawables.addLast(_SvgGroupTuple(event.name, drawable));
    checkForIri(drawable, id);
  }

  /// Appends a [DrawableShape] to the [currentGroup].
  bool addShape(XmlStartElementEvent event, Map<String, String> attributes) {
    final _PathFunc? pathFunc = _svgPathFuncs[event.name];
    if (pathFunc == null) {
      return false;
    }

    final DrawableParent parent = _parentDrawables.last.drawable!;
    final DrawableStyle? parentStyle = parent.style;
    final Path path = pathFunc(this, attributes)!;
    final Float64List? transform =
        parseTransform(getAttribute(attributes, 'transform'))?.storage;
    final String id = getAttribute(attributes, 'id', def: '') ?? '';
    final XmlStartElementEvent? currentElement = _currentStartElement;
    _processing.add(currentElement);
    parseStyle(
      path.getBounds(),
      parentStyle,
      attributes,
      defaultFillColor: colorBlack,
      currentColor: parent.color,
    ).then((DrawableStyle style) {
      final DrawableStyleable drawable = DrawableShape(
        id,
        path,
        style,
        transform: transform,
      );
      checkForIri(drawable, id);
      parent.children!.add(drawable);
      _completeProcessing(id, currentElement);
    });
    return true;
  }

  /// Potentially handles a starting element.
  bool startElement(
      XmlStartElementEvent event, Map<String, String> attributes) {
    if (event.name == 'defs') {
      if (!event.isSelfClosing) {
        addGroup(
          event,
          DrawableGroup(
            '__defs__${event.hashCode}',
            <Drawable>[],
            null,
            color: currentGroup?.color,
            transform: currentGroup?.transform,
          ),
          getAttribute(attributes, 'id') ?? '',
        );
        return true;
      }
    }
    return addShape(event, attributes);
  }

  /// Handles the end of an XML element.
  void endElement(XmlEndElementEvent event) {
    if (event.name == _parentDrawables.last.name) {
      _parentDrawables.removeLast();
    }
  }

  /// Prints an error for unhandled elements.
  ///
  /// Will only print an error once for unhandled/unexpected elements, except for
  /// `<style/>`, `<title/>`, and `<desc/>` elements.
  void unhandledElement(XmlStartElementEvent event) {
    final String errorMessage =
        'unhandled element ${event.name}; Picture key: $_key';
    if (_warningsAsErrors) {
      // Throw error instead of log warning.
      throw UnimplementedError(errorMessage);
    }
    if (event.name == 'style') {
      FlutterError.reportError(FlutterErrorDetails(
        exception: UnimplementedError(
            'The <style> element is not implemented in this library.'),
        informationCollector: () => <DiagnosticsNode>[
          ErrorDescription(
              'Style elements are not supported by this library and the requested SVG may not '
              'render as intended.'),
          ErrorHint(
              'If possible, ensure the SVG uses inline styles and/or attributes (which are '
              'supported), or use a preprocessing utility such as svgcleaner to inline the '
              'styles for you.'),
          ErrorDescription(''),
          DiagnosticsProperty<String>('Picture key', _key),
        ],
        library: 'SVG',
        context: ErrorDescription('in parseSvgElement'),
      ));
    } else if (_unhandledElements.add(event.name)) {
      print(errorMessage);
    }
  }

  /// The number of pixels per CSS inch.
  static const int kCssPixelsPerInch = 96;

  /// The number of points per CSS inch.
  static const int kCssPointsPerInch = 72;

  /// The multiplicand to convert from CSS points to pixels.
  static const double kPointsToPixelFactor =
      kCssPixelsPerInch / kCssPointsPerInch;

  /// Parses a `rawDouble` `String` to a `double`
  /// taking into account absolute and relative units
  /// (`px`, `em` or `ex`).
  ///
  /// Passing an `em` value will calculate the result
  /// relative to the provided [fontSize]:
  /// 1 em = 1 * `fontSize`.
  ///
  /// Passing an `ex` value will calculate the result
  /// relative to the provided [xHeight]:
  /// 1 ex = 1 * `xHeight`.
  ///
  /// The `rawDouble` might include a unit which is
  /// stripped off when parsed to a `double`.
  ///
  /// Passing `null` will return `null`.
  double? parseDoubleWithUnits(
    String? rawDouble, {
    bool tryParse = false,
  }) {
    if (rawDouble == null) {
      return null;
    }

    double unit = 1.0;
    // 1 rem unit is equal to the root font size.
    // 1 em unit is equal to the current font size.
    // 1 ex unit is equal to the current x-height.
    if (rawDouble.contains('pt')) {
      unit = kPointsToPixelFactor;
    } else if (rawDouble.contains('rem')) {
      _compatibilityTester.usesFontSize = true;
      unit = theme.fontSize;
    } else if (rawDouble.contains('em')) {
      _compatibilityTester.usesFontSize = true;
      unit = theme.fontSize;
    } else if (rawDouble.contains('ex')) {
      _compatibilityTester.usesFontSize = true;
      unit = theme.xHeight;
    }

    final double? value = parseDouble(
      rawDouble,
      tryParse: tryParse,
    );

    return value != null ? value * unit : null;
  }

  static final Map<String, double> _kTextSizeMap = <String, double>{
    'xx-small': 10,
    'x-small': 12,
    'small': 14,
    'medium': 18,
    'large': 22,
    'x-large': 26,
    'xx-large': 32,
  };

  /// Parses a `font-size` attribute.
  double? parseFontSize(
    String? raw, {
    double? parentValue,
  }) {
    if (raw == null || raw == '') {
      return null;
    }

    double? ret = parseDoubleWithUnits(
      raw,
      tryParse: true,
    );
    if (ret != null) {
      return ret;
    }

    raw = raw.toLowerCase().trim();
    ret = _kTextSizeMap[raw];
    if (ret != null) {
      return ret;
    }

    if (raw == 'larger') {
      if (parentValue == null) {
        return _kTextSizeMap['large'];
      }
      return parentValue * 1.2;
    }

    if (raw == 'smaller') {
      if (parentValue == null) {
        return _kTextSizeMap['small'];
      }
      return parentValue / 1.2;
    }

    throw StateError('Could not parse font-size: $raw');
  }

  double _parseRawWidthHeight(String raw) {
    if (raw == '100%' || raw == '') {
      return double.infinity;
    }
    assert(() {
      final RegExp notDigits = RegExp(r'[^\d\.]');
      if (!raw.endsWith('px') &&
          !raw.endsWith('em') &&
          !raw.endsWith('ex') &&
          raw.contains(notDigits)) {
        print(
            'Warning: Flutter SVG only supports the following formats for `width` and `height` on the SVG root:\n'
            '  width="100%"\n'
            '  width="100em"\n'
            '  width="100ex"\n'
            '  width="100px"\n'
            '  width="100" (where the number will be treated as pixels).\n'
            'The supplied value ($raw) will be discarded and treated as if it had not been specified.');
      }
      return true;
    }());
    return parseDoubleWithUnits(raw, tryParse: true) ?? double.infinity;
  }

  /// Parses an SVG @viewBox attribute (e.g. 0 0 100 100) to a [Rect].
  ///
  /// The [nullOk] parameter controls whether this function should throw if there is no
  /// viewBox or width/height parameters.
  ///
  /// The [respectWidthHeight] parameter specifies whether `width` and `height` attributes
  /// on the root SVG element should be treated in accordance with the specification.
  DrawableViewport? parseViewBox(Map<String, String> attributes,
      {bool nullOk = false}) {
    final String viewBox = getAttribute(attributes, 'viewBox')!;
    final String rawWidth = getAttribute(attributes, 'width')!;
    final String rawHeight = getAttribute(attributes, 'height')!;

    if (viewBox == '' && rawWidth == '' && rawHeight == '') {
      if (nullOk) {
        return null;
      }
      throw StateError('SVG did not specify dimensions\n\n'
          'The SVG library looks for a `viewBox` or `width` and `height` attribute '
          'to determine the viewport boundary of the SVG.  Note that these attributes, '
          'as with all SVG attributes, are case sensitive.\n'
          'During processing, the following attributes were found:\n'
          '  $attributes');
    }

    final double width = _parseRawWidthHeight(rawWidth);

    final double height = _parseRawWidthHeight(rawHeight);

    if (viewBox == '') {
      return DrawableViewport(
        Size(width, height),
        Size(width, height),
      );
    }

    final List<String> parts = viewBox.split(RegExp(r'[ ,]+'));
    if (parts.length < 4) {
      throw StateError('viewBox element must be 4 elements long');
    }

    return DrawableViewport(
      Size(width, height),
      Size(
        parseDouble(parts[2])!,
        parseDouble(parts[3])!,
      ),
      viewBoxOffset: Offset(
        -parseDouble(parts[0])!,
        -parseDouble(parts[1])!,
      ),
    );
  }

  /// Builds an IRI in the form of `'url(#id)'`.
  String buildUrlIri(String id) => 'url(#$id)';

  String _buildHref(String? id) => '#$id';

  /// An empty IRI.
  static const String emptyUrlIri = DrawableDefinitionServer.emptyUrlIri;

  /// Parses an @stroke-dasharray attribute into a [CircularIntervalList].
  ///
  /// Does not currently support percentages.
  CircularIntervalList<double>? parseDashArray(Map<String, String> attributes) {
    final String? rawDashArray = getAttribute(attributes, 'stroke-dasharray');
    if (rawDashArray == '') {
      return null;
    } else if (rawDashArray == 'none') {
      return DrawableStyle.emptyDashArray;
    }

    final List<String> parts = rawDashArray!.split(RegExp(r'[ ,]+'));
    final List<double> doubles = <double>[];
    bool atLeastOneNonZeroDash = false;
    for (final String part in parts) {
      final double dashOffset = parseDoubleWithUnits(part)!;
      if (dashOffset != 0) {
        atLeastOneNonZeroDash = true;
      }
      doubles.add(dashOffset);
    }
    if (doubles.isEmpty || !atLeastOneNonZeroDash) {
      return null;
    }
    return CircularIntervalList<double>(doubles);
  }

  /// Parses a @stroke-dashoffset into a [DashOffset].
  DashOffset? parseDashOffset(Map<String, String> attributes) {
    final String? rawDashOffset = getAttribute(attributes, 'stroke-dashoffset');
    if (rawDashOffset == '') {
      return null;
    }

    if (rawDashOffset!.endsWith('%')) {
      return DashOffset.percentage(parsePercentage(rawDashOffset));
    } else {
      return DashOffset.absolute(parseDoubleWithUnits(rawDashOffset)!);
    }
  }

  /// Parses a `spreadMethod` attribute into a [TileMode].
  TileMode parseTileMode(Map<String, String> attributes) {
    final String? spreadMethod =
        getAttribute(attributes, 'spreadMethod', def: 'pad');
    switch (spreadMethod) {
      case 'pad':
        return TileMode.clamp;
      case 'repeat':
        return TileMode.repeated;
      case 'reflect':
        return TileMode.mirror;
      default:
        return TileMode.clamp;
    }
  }

  /// Parses an @opacity value into a [double], clamped between 0..1.
  double? parseOpacity(Map<String, String> attributes) {
    final String? rawOpacity = getAttribute(attributes, 'opacity', def: null);
    if (rawOpacity != null) {
      return parseDouble(rawOpacity)!.clamp(0.0, 1.0).toDouble();
    }
    return null;
  }

  Future<DrawablePaint> _getDefinitionPaint(
    String? key,
    PaintingStyle paintingStyle,
    String iri,
    DrawableDefinitionServer definitions,
    Rect bounds,
    XmlStartElementEvent? event, {
    double? opacity,
  }) async =>
      DrawablePaint(
        paintingStyle,
        shader: await _getShader(iri, bounds, event),
        color: opacity != null ? Color.fromRGBO(255, 255, 255, opacity) : null,
      );

  /// Parses a @stroke attribute into a [Paint].
  Future<DrawablePaint?> parseStroke(
    Rect bounds,
    DrawablePaint? parentStroke,
    Color? currentColor,
    XmlStartElementEvent? event,
    Map<String, String> attributes,
  ) async {
    final String? rawStroke = getAttribute(attributes, 'stroke', def: null);
    final String? rawStrokeOpacity = getAttribute(
      attributes,
      'stroke-opacity',
      def: '1.0',
    );
    final String? rawOpacity = getAttribute(attributes, 'opacity');
    double opacity = parseDouble(rawStrokeOpacity)!.clamp(0.0, 1.0).toDouble();
    if (rawOpacity != '') {
      opacity *= parseDouble(rawOpacity)!.clamp(0.0, 1.0);
    }

    final String? rawStrokeCap =
        getAttribute(attributes, 'stroke-linecap', def: null);
    final String? rawLineJoin =
        getAttribute(attributes, 'stroke-linejoin', def: null);
    final String? rawMiterLimit =
        getAttribute(attributes, 'stroke-miterlimit', def: null);
    final String? rawStrokeWidth =
        getAttribute(attributes, 'stroke-width', def: null);

    final String? anyStrokeAttribute = rawStroke ??
        rawStrokeCap ??
        rawLineJoin ??
        rawMiterLimit ??
        rawStrokeWidth;
    if (anyStrokeAttribute == null && DrawablePaint.isEmpty(parentStroke)) {
      return null;
    } else if (rawStroke == 'none') {
      return DrawablePaint.empty;
    }

    DrawablePaint? definitionPaint;
    Color? strokeColor;
    if (rawStroke?.startsWith('url') == true) {
      definitionPaint = await _getDefinitionPaint(
        _key,
        PaintingStyle.stroke,
        rawStroke!,
        _definitions,
        bounds,
        event,
        opacity: opacity,
      );
      strokeColor = definitionPaint.color;
    } else {
      strokeColor = parseColor(rawStroke, currentColor: currentColor);
    }

    final DrawablePaint paint = DrawablePaint(
      PaintingStyle.stroke,
      color: (strokeColor ??
              currentColor ??
              parentStroke?.color ??
              definitionPaint?.color)
          ?.withOpacity(opacity),
      strokeCap: StrokeCap.values.firstWhere(
        (StrokeCap sc) => sc.toString() == 'StrokeCap.$rawStrokeCap',
        orElse: () =>
            parentStroke?.strokeCap ??
            definitionPaint?.strokeCap ??
            StrokeCap.butt,
      ),
      strokeJoin: StrokeJoin.values.firstWhere(
        (StrokeJoin sj) => sj.toString() == 'StrokeJoin.$rawLineJoin',
        orElse: () =>
            parentStroke?.strokeJoin ??
            definitionPaint?.strokeJoin ??
            StrokeJoin.miter,
      ),
      strokeMiterLimit: parseDouble(rawMiterLimit) ??
          parentStroke?.strokeMiterLimit ??
          definitionPaint?.strokeMiterLimit ??
          4.0,
      strokeWidth: parseDoubleWithUnits(rawStrokeWidth) ??
          parentStroke?.strokeWidth ??
          definitionPaint?.strokeWidth ??
          1.0,
    );

    return DrawablePaint.merge(definitionPaint, paint);
  }

  /// Parses a `fill` attribute.
  Future<DrawablePaint?> parseFill(
    Rect bounds,
    DrawablePaint? parentFill,
    Color? defaultFillColor,
    Color? currentColor,
    XmlStartElementEvent? event,
    Map<String, String> attributes,
  ) async {
    final String rawFill = getAttribute(attributes, 'fill', def: '')!;
    final String? rawFillOpacity =
        getAttribute(attributes, 'fill-opacity', def: '1.0');
    final String? rawOpacity = getAttribute(attributes, 'opacity', def: '');
    double opacity = parseDouble(rawFillOpacity)!.clamp(0.0, 1.0).toDouble();
    if (rawOpacity != '') {
      opacity *= parseDouble(rawOpacity)!.clamp(0.0, 1.0);
    }

    if (rawFill.startsWith('url')) {
      return _getDefinitionPaint(
        _key,
        PaintingStyle.fill,
        rawFill,
        _definitions,
        bounds,
        event,
        opacity: opacity,
      );
    }

    final Color? fillColor = _determineFillColor(
      parentFill?.color,
      rawFill,
      opacity,
      rawOpacity != '' || rawFillOpacity != '',
      defaultFillColor,
      currentColor,
    );

    if (rawFill == '' &&
        (fillColor == null || parentFill == DrawablePaint.empty)) {
      return null;
    }
    if (rawFill == 'none') {
      return DrawablePaint.empty;
    }

    return DrawablePaint(
      PaintingStyle.fill,
      color: fillColor,
    );
  }

  Color? _determineFillColor(
    Color? parentFillColor,
    String rawFill,
    double opacity,
    bool explicitOpacity,
    Color? defaultFillColor,
    Color? currentColor,
  ) {
    final Color? color = parseColor(rawFill, currentColor: currentColor) ??
        parentFillColor ??
        defaultFillColor;

    if (explicitOpacity && color != null) {
      return color.withOpacity(opacity);
    }

    return color;
  }

  /// Parses a `fill-rule` attribute into a [PathFillType].
  PathFillType? parseFillRule(
    Map<String, String> attributes, [
    String attr = 'fill-rule',
    String? def = 'nonzero',
  ]) {
    final String? rawFillRule = getAttribute(attributes, attr, def: def);
    return parseRawFillRule(rawFillRule);
  }

  /// Applies a transform to a path if the [attributes] contain a `transform`.
  Path? applyTransformIfNeeded(Path? path, Map<String, String> attributes) {
    final Matrix4? transform =
        parseTransform(getAttribute(attributes, 'transform', def: null));

    if (transform != null) {
      return path!.transform(transform.storage);
    } else {
      return path;
    }
  }

  /// Parses a `clipPath` element into a list of [Path]s.
  Future<List<Path>?> parseClipPath(
      Map<String, String> attributes, XmlStartElementEvent? event) async {
    final String? rawClipAttribute = getAttribute(attributes, 'clip-path');
    if (rawClipAttribute?.isNotEmpty == true) {
      return _getClipPath(rawClipAttribute!, event);
    }
    return null;
  }

  static const Map<String, BlendMode> _blendModes = <String, BlendMode>{
    'multiply': BlendMode.multiply,
    'screen': BlendMode.screen,
    'overlay': BlendMode.overlay,
    'darken': BlendMode.darken,
    'lighten': BlendMode.lighten,
    'color-dodge': BlendMode.colorDodge,
    'color-burn': BlendMode.colorBurn,
    'hard-light': BlendMode.hardLight,
    'soft-light': BlendMode.softLight,
    'difference': BlendMode.difference,
    'exclusion': BlendMode.exclusion,
    'hue': BlendMode.hue,
    'saturation': BlendMode.saturation,
    'color': BlendMode.color,
    'luminosity': BlendMode.luminosity,
  };

  /// Lookup the mask if the attribute is present.
  Future<DrawableStyleable?> parseMask(
      XmlStartElementEvent? event, Map<String, String> attributes) async {
    final String? rawMaskAttribute = getAttribute(attributes, 'mask');
    if (rawMaskAttribute != '') {
      return _getDrawable(rawMaskAttribute!, event);
    }
    return null;
  }

  /// Parses a `font-weight` attribute value into a [FontWeight].
  FontWeight? parseFontWeight(String? fontWeight) {
    if (fontWeight == null) {
      return null;
    }
    switch (fontWeight) {
      case '100':
        return FontWeight.w100;
      case '200':
        return FontWeight.w200;
      case '300':
        return FontWeight.w300;
      case 'normal':
      case '400':
        return FontWeight.w400;
      case '500':
        return FontWeight.w500;
      case '600':
        return FontWeight.w600;
      case 'bold':
      case '700':
        return FontWeight.w700;
      case '800':
        return FontWeight.w800;
      case '900':
        return FontWeight.w900;
    }
    throw UnsupportedError('Attribute value for font-weight="$fontWeight"'
        ' is not supported');
  }

  /// Parses a `font-style` attribute value into a [FontStyle].
  FontStyle? parseFontStyle(String? fontStyle) {
    if (fontStyle == null) {
      return null;
    }
    switch (fontStyle) {
      case 'normal':
        return FontStyle.normal;
      case 'italic':
      case 'oblique':
        return FontStyle.italic;
    }
    throw UnsupportedError('Attribute value for font-style="$fontStyle"'
        ' is not supported');
  }

  /// Parses a `text-decoration` attribute value into a [TextDecoration].
  TextDecoration? parseTextDecoration(String? textDecoration) {
    if (textDecoration == null) {
      return null;
    }
    switch (textDecoration) {
      case 'none':
        return TextDecoration.none;
      case 'underline':
        return TextDecoration.underline;
      case 'overline':
        return TextDecoration.overline;
      case 'line-through':
        return TextDecoration.lineThrough;
    }
    throw UnsupportedError(
        'Attribute value for text-decoration="$textDecoration"'
        ' is not supported');
  }

  /// Parses a `text-decoration-style` attribute value into a [TextDecorationStyle].
  TextDecorationStyle? parseTextDecorationStyle(String? textDecorationStyle) {
    if (textDecorationStyle == null) {
      return null;
    }
    switch (textDecorationStyle) {
      case 'solid':
        return TextDecorationStyle.solid;
      case 'dashed':
        return TextDecorationStyle.dashed;
      case 'dotted':
        return TextDecorationStyle.dotted;
      case 'double':
        return TextDecorationStyle.double;
      case 'wavy':
        return TextDecorationStyle.wavy;
    }
    throw UnsupportedError(
        'Attribute value for text-decoration-style="$textDecorationStyle"'
        ' is not supported');
  }

  /// Parses style attributes or @style attribute.
  ///
  /// Remember that @style attribute takes precedence.
  Future<DrawableStyle> parseStyle(
    Rect bounds,
    DrawableStyle? parentStyle,
    Map<String, String> attributes, {
    Color? defaultFillColor,
    Color? currentColor,
  }) async {
    final XmlStartElementEvent? event = _currentStartElement;
    return DrawableStyle.mergeAndBlend(
      parentStyle,
      stroke: await parseStroke(
          bounds, parentStyle?.stroke, currentColor, event, attributes),
      dashArray: parseDashArray(attributes),
      dashOffset: parseDashOffset(attributes),
      fill: await parseFill(bounds, parentStyle?.fill, defaultFillColor,
          currentColor, event, attributes),
      pathFillType: parseFillRule(
        attributes,
        'fill-rule',
        parentStyle != null ? null : 'nonzero',
      ),
      groupOpacity: parseOpacity(attributes),
      mask: await parseMask(event, attributes),
      clipPath: await parseClipPath(attributes, event),
      textStyle: DrawableTextStyle(
        fontFamily: getAttribute(attributes, 'font-family'),
        fontSize: parseFontSize(getAttribute(attributes, 'font-size'),
            parentValue: parentStyle?.textStyle?.fontSize),
        fontWeight: parseFontWeight(
          getAttribute(attributes, 'font-weight', def: null),
        ),
        fontStyle: parseFontStyle(
          getAttribute(attributes, 'font-style', def: null),
        ),
        anchor: parseTextAnchor(
          getAttribute(attributes, 'text-anchor', def: 'inherit'),
        ),
        decoration: parseTextDecoration(
          getAttribute(attributes, 'text-decoration', def: null),
        ),
        decorationColor: parseColor(
          getAttribute(attributes, 'text-decoration-color', def: null),
          currentColor: currentColor,
        ),
        decorationStyle: parseTextDecorationStyle(
          getAttribute(attributes, 'text-decoration-style', def: null),
        ),
      ),
      blendMode: _blendModes[getAttribute(attributes, 'mix-blend-mode')!],
    );
  }

  /// Converts a SVG Color String (either a # prefixed color string or a named color) to a [Color].
  Color? parseColor(String? colorString, {Color? currentColor}) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }

    if (colorString == 'none') {
      return null;
    }

    if (colorString.toLowerCase() == 'currentcolor') {
      _compatibilityTester.usesCurrentColor = true;
      return currentColor ?? theme.currentColor;
    }

    // handle hex colors e.g. #fff or #ffffff.  This supports #RRGGBBAA
    if (colorString[0] == '#') {
      if (colorString.length == 4) {
        final String r = colorString[1];
        final String g = colorString[2];
        final String b = colorString[3];
        colorString = '#$r$r$g$g$b$b';
      }
      int color = int.parse(colorString.substring(1), radix: 16);

      if (colorString.length == 7) {
        return Color(color |= 0xFF000000);
      }

      if (colorString.length == 9) {
        return Color(color);
      }
    }

    // handle rgba() colors e.g. rgba(255, 255, 255, 1.0)
    if (colorString.toLowerCase().startsWith('rgba')) {
      final List<String> rawColorElements = colorString
          .substring(colorString.indexOf('(') + 1, colorString.indexOf(')'))
          .split(',')
          .map((String rawColor) => rawColor.trim())
          .toList();

      final double opacity = parseDouble(rawColorElements.removeLast())!;

      final List<int> rgb = rawColorElements
          .map((String rawColor) => int.parse(rawColor))
          .toList();

      return Color.fromRGBO(rgb[0], rgb[1], rgb[2], opacity);
    }

    // Conversion code from: https://github.com/MichaelFenwick/Color, thanks :)
    if (colorString.toLowerCase().startsWith('hsl')) {
      final List<int> values = colorString
          .substring(colorString.indexOf('(') + 1, colorString.indexOf(')'))
          .split(',')
          .map((String rawColor) {
        rawColor = rawColor.trim();

        if (rawColor.endsWith('%')) {
          rawColor = rawColor.substring(0, rawColor.length - 1);
        }

        if (rawColor.contains('.')) {
          return (parseDouble(rawColor)! * 2.55).round();
        }

        return int.parse(rawColor);
      }).toList();
      final double hue = values[0] / 360 % 1;
      final double saturation = values[1] / 100;
      final double luminance = values[2] / 100;
      final int alpha = values.length > 3 ? values[3] : 255;
      List<double> rgb = <double>[0, 0, 0];

      if (hue < 1 / 6) {
        rgb[0] = 1;
        rgb[1] = hue * 6;
      } else if (hue < 2 / 6) {
        rgb[0] = 2 - hue * 6;
        rgb[1] = 1;
      } else if (hue < 3 / 6) {
        rgb[1] = 1;
        rgb[2] = hue * 6 - 2;
      } else if (hue < 4 / 6) {
        rgb[1] = 4 - hue * 6;
        rgb[2] = 1;
      } else if (hue < 5 / 6) {
        rgb[0] = hue * 6 - 4;
        rgb[2] = 1;
      } else {
        rgb[0] = 1;
        rgb[2] = 6 - hue * 6;
      }

      rgb = rgb
          .map((double val) => val + (1 - saturation) * (0.5 - val))
          .toList();

      if (luminance < 0.5) {
        rgb = rgb.map((double val) => luminance * 2 * val).toList();
      } else {
        rgb = rgb
            .map((double val) => luminance * 2 * (1 - val) + 2 * val - 1)
            .toList();
      }

      rgb = rgb.map((double val) => val * 255).toList();

      return Color.fromARGB(
          alpha, rgb[0].round(), rgb[1].round(), rgb[2].round());
    }

    // handle rgb() colors e.g. rgb(255, 255, 255)
    if (colorString.toLowerCase().startsWith('rgb')) {
      final List<int> rgb = colorString
          .substring(colorString.indexOf('(') + 1, colorString.indexOf(')'))
          .split(',')
          .map((String rawColor) {
        rawColor = rawColor.trim();
        if (rawColor.endsWith('%')) {
          rawColor = rawColor.substring(0, rawColor.length - 1);
          return (parseDouble(rawColor)! * 2.55).round();
        }
        return int.parse(rawColor);
      }).toList();

      // rgba() isn't really in the spec, but Firefox supported it at one point so why not.
      final int a = rgb.length > 3 ? rgb[3] : 255;
      return Color.fromARGB(a, rgb[0], rgb[1], rgb[2]);
    }

    // handle named colors ('red', 'green', etc.).
    final Color? namedColor = _namedColors[colorString];
    if (namedColor != null) {
      return namedColor;
    }

    throw StateError('Could not parse "$colorString" as a color.');
  }

  void _completeProcessing(String? id, XmlStartElementEvent? currentElement) {
    _processing.remove(currentElement);
    if (_processing.isEmpty &&
        !_unknownDefinitions.keys.contains(_buildHref(id)) &&
        _drawingCompleter != null) {
      // TODO(ikbendewilliam): remove Implicit check if _drawingCompleter != null
      _drawingCompleter!.complete();
    }
  }

  Future<DrawableStyleable> _getDrawable(
      String xlinkHref, XmlStartElementEvent? event) async {
    DrawableStyleable? ref = _definitions.getDrawable('url($xlinkHref)');
    if (ref == null) {
      await _waitForRef(xlinkHref, event);
      ref = _definitions.getDrawable('url($xlinkHref)');
    }
    return ref!;
  }

  Future<List<Path>> _getClipPath(
      String rawClipAttribute, XmlStartElementEvent? event) async {
    List<Path>? ref = _definitions.getClipPath(rawClipAttribute);
    if (ref == null) {
      await _waitForRef(rawClipAttribute, event);
      ref = _definitions.getClipPath(rawClipAttribute);
    }
    return ref!;
  }

  Future<DrawableGradient> _getGradient(
      String xlinkHref, XmlStartElementEvent event) async {
    DrawableGradient? ref =
        _definitions.getGradient<DrawableGradient>(xlinkHref);
    if (ref == null) {
      await _waitForRef(xlinkHref, event);
      ref = _definitions.getGradient(xlinkHref);
    }
    return ref!;
  }

  Future<Shader> _getShader(
      String xlinkHref, Rect bounds, XmlStartElementEvent? event) async {
    Shader? ref = _definitions.getShader(xlinkHref, bounds);
    if (ref == null) {
      await _waitForRef(xlinkHref, event);
      ref = _definitions.getShader(xlinkHref, bounds);
    }
    return ref!;
  }

  Future<void> _waitForRef(String ref, XmlStartElementEvent? event) async {
    _unknownDefinitions[ref] ??= Completer<void>();
    final Completer<void> completer = _unknownDefinitions[ref]!;
    final bool isInProcessing = _processing.contains(event);
    if (isInProcessing) {
      _waitingForDefinitions[ref] ??= <XmlStartElementEvent?>[];
      _waitingForDefinitions[ref]!.add(event);
      _processing.remove(event);
    }
    // No other elements are being processed if _drawingCompleter is null.
    // This will result in reportMissingDef being calles for each element that is missing a definition.
    if (_processing.isEmpty) {
      _drawingCompleter?.complete();
    }
    await completer.future;
    _unknownDefinitions.remove(ref);
  }

  void _markUnkownDefinitionComplete(String iri) {
    _waitingForDefinitions[iri]?.forEach(_processing.add);
    _waitingForDefinitions.remove(iri);
    _unknownDefinitions[iri]?.complete();
  }
}

/// The color black, with full opacity.
const Color colorBlack = Color(0xFF000000);

// https://www.w3.org/TR/SVG11/types.html#ColorKeywords
const Map<String, Color> _namedColors = <String, Color>{
  'aliceblue': Color.fromARGB(255, 240, 248, 255),
  'antiquewhite': Color.fromARGB(255, 250, 235, 215),
  'aqua': Color.fromARGB(255, 0, 255, 255),
  'aquamarine': Color.fromARGB(255, 127, 255, 212),
  'azure': Color.fromARGB(255, 240, 255, 255),
  'beige': Color.fromARGB(255, 245, 245, 220),
  'bisque': Color.fromARGB(255, 255, 228, 196),
  'black': Color.fromARGB(255, 0, 0, 0),
  'blanchedalmond': Color.fromARGB(255, 255, 235, 205),
  'blue': Color.fromARGB(255, 0, 0, 255),
  'blueviolet': Color.fromARGB(255, 138, 43, 226),
  'brown': Color.fromARGB(255, 165, 42, 42),
  'burlywood': Color.fromARGB(255, 222, 184, 135),
  'cadetblue': Color.fromARGB(255, 95, 158, 160),
  'chartreuse': Color.fromARGB(255, 127, 255, 0),
  'chocolate': Color.fromARGB(255, 210, 105, 30),
  'coral': Color.fromARGB(255, 255, 127, 80),
  'cornflowerblue': Color.fromARGB(255, 100, 149, 237),
  'cornsilk': Color.fromARGB(255, 255, 248, 220),
  'crimson': Color.fromARGB(255, 220, 20, 60),
  'cyan': Color.fromARGB(255, 0, 255, 255),
  'darkblue': Color.fromARGB(255, 0, 0, 139),
  'darkcyan': Color.fromARGB(255, 0, 139, 139),
  'darkgoldenrod': Color.fromARGB(255, 184, 134, 11),
  'darkgray': Color.fromARGB(255, 169, 169, 169),
  'darkgreen': Color.fromARGB(255, 0, 100, 0),
  'darkgrey': Color.fromARGB(255, 169, 169, 169),
  'darkkhaki': Color.fromARGB(255, 189, 183, 107),
  'darkmagenta': Color.fromARGB(255, 139, 0, 139),
  'darkolivegreen': Color.fromARGB(255, 85, 107, 47),
  'darkorange': Color.fromARGB(255, 255, 140, 0),
  'darkorchid': Color.fromARGB(255, 153, 50, 204),
  'darkred': Color.fromARGB(255, 139, 0, 0),
  'darksalmon': Color.fromARGB(255, 233, 150, 122),
  'darkseagreen': Color.fromARGB(255, 143, 188, 143),
  'darkslateblue': Color.fromARGB(255, 72, 61, 139),
  'darkslategray': Color.fromARGB(255, 47, 79, 79),
  'darkslategrey': Color.fromARGB(255, 47, 79, 79),
  'darkturquoise': Color.fromARGB(255, 0, 206, 209),
  'darkviolet': Color.fromARGB(255, 148, 0, 211),
  'deeppink': Color.fromARGB(255, 255, 20, 147),
  'deepskyblue': Color.fromARGB(255, 0, 191, 255),
  'dimgray': Color.fromARGB(255, 105, 105, 105),
  'dimgrey': Color.fromARGB(255, 105, 105, 105),
  'dodgerblue': Color.fromARGB(255, 30, 144, 255),
  'firebrick': Color.fromARGB(255, 178, 34, 34),
  'floralwhite': Color.fromARGB(255, 255, 250, 240),
  'forestgreen': Color.fromARGB(255, 34, 139, 34),
  'fuchsia': Color.fromARGB(255, 255, 0, 255),
  'gainsboro': Color.fromARGB(255, 220, 220, 220),
  'ghostwhite': Color.fromARGB(255, 248, 248, 255),
  'gold': Color.fromARGB(255, 255, 215, 0),
  'goldenrod': Color.fromARGB(255, 218, 165, 32),
  'gray': Color.fromARGB(255, 128, 128, 128),
  'grey': Color.fromARGB(255, 128, 128, 128),
  'green': Color.fromARGB(255, 0, 128, 0),
  'greenyellow': Color.fromARGB(255, 173, 255, 47),
  'honeydew': Color.fromARGB(255, 240, 255, 240),
  'hotpink': Color.fromARGB(255, 255, 105, 180),
  'indianred': Color.fromARGB(255, 205, 92, 92),
  'indigo': Color.fromARGB(255, 75, 0, 130),
  'ivory': Color.fromARGB(255, 255, 255, 240),
  'khaki': Color.fromARGB(255, 240, 230, 140),
  'lavender': Color.fromARGB(255, 230, 230, 250),
  'lavenderblush': Color.fromARGB(255, 255, 240, 245),
  'lawngreen': Color.fromARGB(255, 124, 252, 0),
  'lemonchiffon': Color.fromARGB(255, 255, 250, 205),
  'lightblue': Color.fromARGB(255, 173, 216, 230),
  'lightcoral': Color.fromARGB(255, 240, 128, 128),
  'lightcyan': Color.fromARGB(255, 224, 255, 255),
  'lightgoldenrodyellow': Color.fromARGB(255, 250, 250, 210),
  'lightgray': Color.fromARGB(255, 211, 211, 211),
  'lightgreen': Color.fromARGB(255, 144, 238, 144),
  'lightgrey': Color.fromARGB(255, 211, 211, 211),
  'lightpink': Color.fromARGB(255, 255, 182, 193),
  'lightsalmon': Color.fromARGB(255, 255, 160, 122),
  'lightseagreen': Color.fromARGB(255, 32, 178, 170),
  'lightskyblue': Color.fromARGB(255, 135, 206, 250),
  'lightslategray': Color.fromARGB(255, 119, 136, 153),
  'lightslategrey': Color.fromARGB(255, 119, 136, 153),
  'lightsteelblue': Color.fromARGB(255, 176, 196, 222),
  'lightyellow': Color.fromARGB(255, 255, 255, 224),
  'lime': Color.fromARGB(255, 0, 255, 0),
  'limegreen': Color.fromARGB(255, 50, 205, 50),
  'linen': Color.fromARGB(255, 250, 240, 230),
  'magenta': Color.fromARGB(255, 255, 0, 255),
  'maroon': Color.fromARGB(255, 128, 0, 0),
  'mediumaquamarine': Color.fromARGB(255, 102, 205, 170),
  'mediumblue': Color.fromARGB(255, 0, 0, 205),
  'mediumorchid': Color.fromARGB(255, 186, 85, 211),
  'mediumpurple': Color.fromARGB(255, 147, 112, 219),
  'mediumseagreen': Color.fromARGB(255, 60, 179, 113),
  'mediumslateblue': Color.fromARGB(255, 123, 104, 238),
  'mediumspringgreen': Color.fromARGB(255, 0, 250, 154),
  'mediumturquoise': Color.fromARGB(255, 72, 209, 204),
  'mediumvioletred': Color.fromARGB(255, 199, 21, 133),
  'midnightblue': Color.fromARGB(255, 25, 25, 112),
  'mintcream': Color.fromARGB(255, 245, 255, 250),
  'mistyrose': Color.fromARGB(255, 255, 228, 225),
  'moccasin': Color.fromARGB(255, 255, 228, 181),
  'navajowhite': Color.fromARGB(255, 255, 222, 173),
  'navy': Color.fromARGB(255, 0, 0, 128),
  'oldlace': Color.fromARGB(255, 253, 245, 230),
  'olive': Color.fromARGB(255, 128, 128, 0),
  'olivedrab': Color.fromARGB(255, 107, 142, 35),
  'orange': Color.fromARGB(255, 255, 165, 0),
  'orangered': Color.fromARGB(255, 255, 69, 0),
  'orchid': Color.fromARGB(255, 218, 112, 214),
  'palegoldenrod': Color.fromARGB(255, 238, 232, 170),
  'palegreen': Color.fromARGB(255, 152, 251, 152),
  'paleturquoise': Color.fromARGB(255, 175, 238, 238),
  'palevioletred': Color.fromARGB(255, 219, 112, 147),
  'papayawhip': Color.fromARGB(255, 255, 239, 213),
  'peachpuff': Color.fromARGB(255, 255, 218, 185),
  'peru': Color.fromARGB(255, 205, 133, 63),
  'pink': Color.fromARGB(255, 255, 192, 203),
  'plum': Color.fromARGB(255, 221, 160, 221),
  'powderblue': Color.fromARGB(255, 176, 224, 230),
  'purple': Color.fromARGB(255, 128, 0, 128),
  'red': Color.fromARGB(255, 255, 0, 0),
  'rosybrown': Color.fromARGB(255, 188, 143, 143),
  'royalblue': Color.fromARGB(255, 65, 105, 225),
  'saddlebrown': Color.fromARGB(255, 139, 69, 19),
  'salmon': Color.fromARGB(255, 250, 128, 114),
  'sandybrown': Color.fromARGB(255, 244, 164, 96),
  'seagreen': Color.fromARGB(255, 46, 139, 87),
  'seashell': Color.fromARGB(255, 255, 245, 238),
  'sienna': Color.fromARGB(255, 160, 82, 45),
  'silver': Color.fromARGB(255, 192, 192, 192),
  'skyblue': Color.fromARGB(255, 135, 206, 235),
  'slateblue': Color.fromARGB(255, 106, 90, 205),
  'slategray': Color.fromARGB(255, 112, 128, 144),
  'slategrey': Color.fromARGB(255, 112, 128, 144),
  'snow': Color.fromARGB(255, 255, 250, 250),
  'springgreen': Color.fromARGB(255, 0, 255, 127),
  'steelblue': Color.fromARGB(255, 70, 130, 180),
  'tan': Color.fromARGB(255, 210, 180, 140),
  'teal': Color.fromARGB(255, 0, 128, 128),
  'thistle': Color.fromARGB(255, 216, 191, 216),
  'tomato': Color.fromARGB(255, 255, 99, 71),
  'transparent': Color.fromARGB(0, 255, 255, 255),
  'turquoise': Color.fromARGB(255, 64, 224, 208),
  'violet': Color.fromARGB(255, 238, 130, 238),
  'wheat': Color.fromARGB(255, 245, 222, 179),
  'white': Color.fromARGB(255, 255, 255, 255),
  'whitesmoke': Color.fromARGB(255, 245, 245, 245),
  'yellow': Color.fromARGB(255, 255, 255, 0),
  'yellowgreen': Color.fromARGB(255, 154, 205, 50),
};
