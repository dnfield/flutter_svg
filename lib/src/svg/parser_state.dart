import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';

import '../utilities/errors.dart';
import '../utilities/numbers.dart';
import '../utilities/xml.dart';
import '../vector_drawable.dart';
import 'colors.dart';
import 'parsers.dart';
import 'xml_parsers.dart';

final Set<String> _unhandledElements = Set<String>();

typedef _ParseFunc = Future<void> Function(SvgParserState parserState, XmlElement element);
typedef _PathFunc = Path Function(List<XmlAttribute> attributes);

const Map<String, _ParseFunc> _svgElementParsers = <String, _ParseFunc>{
  'svg': _Elements.svg,
  'g': _Elements.g,
  'a': _Elements.g, // treat as group
  'use': _Elements.use,
  'symbol': _Elements.symbol,
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

Offset _parseCurrentOffset(XmlElement element, Offset lastOffset) {
  final String x = getAttribute(element.attributes, 'x', def: null);
  final String y = getAttribute(element.attributes, 'y', def: null);

  return Offset(
    x != null
        ? parseDouble(x)
        : parseDouble(getAttribute(element.attributes, 'dx', def: '0')) +
            (lastOffset?.dx ?? 0),
    y != null
        ? parseDouble(y)
        : parseDouble(getAttribute(element.attributes, 'dy', def: '0')) +
            (lastOffset?.dy ?? 0),
  );
}

class _TextInfo {
  const _TextInfo(
    this.style,
    this.offset,
  );
  final DrawableStyle style;
  final Offset offset;

  @override
  String toString() => '$runtimeType{$offset, $style}';
}

class _Elements {
  static Future<void> svg(SvgParserState parserState, XmlElement element) {
    final DrawableViewport viewBox = parseViewBox(element.attributes);

    parserState._root = DrawableRoot(
      viewBox,
      <Drawable>[],
      parserState._definitions,
      parseStyle(element.attributes, parserState._definitions,
          viewBox.viewBoxRect, null),
    );
    parserState.addGroup(parserState._root, element);
    return null;
  }

  static Future<void> g(SvgParserState parserState, XmlElement element) {
    final DrawableParent parent = parserState.currentGroup;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[],
      parseStyle(
        element.attributes,
        parserState._definitions,
        parserState.rootBounds,
        parent.style,
        needsTransform: true,
      ),
    );
    if (!parserState._inDefs) {
      parent.children.add(group);
    }
    parserState.addGroup(group, element);
    return null;
  }

  static Future<void> symbol(SvgParserState parserState, XmlElement element) {
    final DrawableParent parent = parserState.currentGroup;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[],
      parseStyle(
        element.attributes,
        parserState._definitions,
        null,
        parent.style,
        needsTransform: true,
      ),
    );
    parserState.addGroup(group, element);
    return null;
  }

  static Future<void> use(SvgParserState parserState, XmlElement element) {
    final String xlinkHref = getHrefAttribute(element.attributes);
    final DrawableStyle style = parseStyle(
      element.attributes,
      parserState._definitions,
      parserState.rootBounds,
      null,
    );
    final Matrix4 transform = Matrix4.identity()
      ..translate(
        parseDouble(_attribute(element, 'x', def: '0')),
        parseDouble(_attribute(element, 'y', def: '0')),
      );
    final DrawableStyleable ref =
        parserState._definitions.getDrawable('url($xlinkHref)');
    final DrawableParent parent = parserState.currentGroup;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[ref.mergeStyle(style)],
      DrawableStyle(transform: transform.storage),
    );
    parent.children.add(group);
    return null;
  }

  static Future<void> parseStops(
     XmlElement element, List<Color> colors, List<double> offsets) {
    for (XmlNode node in element.children) {
      if (node is XmlElement) {
        final String rawOpacity = getAttribute(
          node.attributes,
          'stop-opacity',
          def: '1',
        );
        colors.add(parseColor(getAttribute(node.attributes, 'stop-color'))
            .withOpacity(parseDouble(rawOpacity)));

        final String rawOffset = getAttribute(
          node.attributes,
          'offset',
          def: '0%',
        );
        offsets.add(parseDecimalOrPercentage(rawOffset));
      }
    }

    /*while (reader.read() && depth <= reader.depth) {
      if (reader.nodeType == XmlPushReaderNodeType.END_ELEMENT) {
        continue;
      }
      final String rawOpacity = getAttribute(
        reader.attributes,
        'stop-opacity',
        def: '1',
      );
      colors.add(parseColor(getAttribute(reader.attributes, 'stop-color'))
          .withOpacity(parseDouble(rawOpacity)));

      final String rawOffset = getAttribute(
        reader.attributes,
        'offset',
        def: '0%',
      );
      offsets.add(parseDecimalOrPercentage(rawOffset));
    }*/
    return null;
  }

  static Future<void> radialGradient(SvgParserState parserState, XmlElement element) {
    final String gradientUnits = getAttribute(
        element.attributes, 'gradientUnits',
        def: 'objectBoundingBox');
    final bool isObjectBoundingBox = gradientUnits == 'objectBoundingBox';

    final String rawCx = _attribute(element, 'cx', def: '50%');
    final String rawCy = _attribute(element, 'cy', def: '50%');
    final String rawR = _attribute(element, 'r', def: '50%');
    final String rawFx = _attribute(element, 'fx', def: rawCx);
    final String rawFy = _attribute(element, 'fy', def: rawCy);
    final TileMode spreadMethod = parseTileMode(element.attributes);
    final String id = buildUrlIri(element.attributes);
    final Matrix4 originalTransform = parseTransform(
      _attribute(element, 'gradientTransform', def: null),
    );

    final List<double> offsets = <double>[];
    final List<Color> colors = <Color>[];

    if (element.children.isEmpty) {
      final String href = getHrefAttribute(element.attributes);
      final DrawableGradient ref =
          parserState._definitions.getGradient<DrawableGradient>('url($href)');
      if (ref == null) {
        reportMissingDef(href, 'radialGradient');
      } else {
        colors.addAll(ref.colors);
        offsets.addAll(ref.offsets);
      }
    } else {
      parseStops(element, colors, offsets);
    }

    double cx, cy, r, fx, fy;
    if (isObjectBoundingBox) {
      cx = parseDecimalOrPercentage(rawCx);
      cy = parseDecimalOrPercentage(rawCy);
      r = parseDecimalOrPercentage(rawR);
      fx = parseDecimalOrPercentage(rawFx);
      fy = parseDecimalOrPercentage(rawFy);
    } else {
      cx = isPercentage(rawCx)
          ? parsePercentage(rawCx) * parserState.rootBounds.width +
              parserState.rootBounds.left
          : parseDouble(rawCx);
      cy = isPercentage(rawCy)
          ? parsePercentage(rawCy) * parserState.rootBounds.height +
              parserState.rootBounds.top
          : parseDouble(rawCy);
      r = isPercentage(rawR)
          ? parsePercentage(rawR) *
              ((parserState.rootBounds.height + parserState.rootBounds.width) /
                  2)
          : parseDouble(rawR);
      fx = isPercentage(rawFx)
          ? parsePercentage(rawFx) * parserState.rootBounds.width +
              parserState.rootBounds.left
          : parseDouble(rawFx);
      fy = isPercentage(rawFy)
          ? parsePercentage(rawFy) * parserState.rootBounds.height +
              parserState.rootBounds.top
          : parseDouble(rawFy);
    }

    parserState._definitions.addGradient(
      id,
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
    return null;
  }

  static Future<void> linearGradient(SvgParserState parserState, XmlElement element) {
    final String gradientUnits = getAttribute(
        element.attributes, 'gradientUnits',
        def: 'objectBoundingBox');
    final bool isObjectBoundingBox = gradientUnits == 'objectBoundingBox';

    final String x1 = _attribute(element, 'x1', def: '0%');
    final String x2 = _attribute(element, 'x2', def: '100%');
    final String y1 = _attribute(element, 'y1', def: '0%');
    final String y2 = _attribute(element, 'y2', def: '0%');
    final String id = buildUrlIri(element.attributes);
    final Matrix4 originalTransform = parseTransform(
      _attribute(element, 'gradientTransform', def: null),
    );
    final TileMode spreadMethod = parseTileMode(element.attributes);

    final List<Color> colors = <Color>[];
    final List<double> offsets = <double>[];
    if (element.children.isEmpty) {
      final String href = getHrefAttribute(element.attributes);
      final DrawableGradient ref =
          parserState._definitions.getGradient<DrawableGradient>('url($href)');
      if (ref == null) {
        reportMissingDef(href, 'linearGradient');
      } else {
        colors.addAll(ref.colors);
        offsets.addAll(ref.offsets);
      }
    } else {
      parseStops(element, colors, offsets);
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
            : parseDouble(x1),
        isPercentage(y1)
            ? parsePercentage(y1) * parserState.rootBounds.height +
                parserState.rootBounds.top
            : parseDouble(y1),
      );

      toOffset = Offset(
        isPercentage(x2)
            ? parsePercentage(x2) * parserState.rootBounds.width +
                parserState.rootBounds.left
            : parseDouble(x2),
        isPercentage(y2)
            ? parsePercentage(y2) * parserState.rootBounds.height +
                parserState.rootBounds.top
            : parseDouble(y2),
      );
    }

    parserState._definitions.addGradient(
      id,
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

    return null;
  }

  static Future<void> clipPath(SvgParserState parserState, XmlElement element) {
    final String id = buildUrlIri(element.attributes);

    final List<Path> paths = <Path>[];
    Path currentPath;
    for (XmlNode node in element.children) {
      if (node is XmlElement) {
        final _PathFunc pathFn = _svgPathFuncs[node.name.local];
        if (pathFn != null) {
          final Path nextPath = applyTransformIfNeeded(
            pathFn(node.attributes),
            node.attributes,
          );
          nextPath.fillType =
              parseFillRule(node.attributes, 'clip-rule');
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
        } else if (element.name.local == 'use') {
          final String xlinkHref = getHrefAttribute(node.attributes);
          final DrawableStyleable definitionDrawable =
          parserState._definitions.getDrawable('url($xlinkHref)');

          void extractPathsFromDrawable(Drawable target) {
            if (target is DrawableShape) {
              paths.add(target.path);
            } else if (target is DrawableGroup) {
              target.children.forEach(extractPathsFromDrawable);
            }
          }

          extractPathsFromDrawable(definitionDrawable);
        } else {
          FlutterError.reportError(FlutterErrorDetails(
            exception: UnsupportedError(
                'Unsupported clipPath child ${element.name.local}'),
            informationCollector: (StringBuffer buff) {
              buff.writeln(
                  'The <clipPath> element contained an unsupported child ${element
                      .name.local}');
              if (parserState._key != null) {
                buff.writeln();
                buff.writeln('Picture key: ${parserState._key}');
              }
            },
            library: 'SVG',
            context: 'in _Element.clipPath',
          ));
        }
      }
    }
    parserState._definitions.addClipPath(id, paths);

    /*while (parserState._document.read() && depth <= parserState._document.depth) {
      if (parserState._document.nodeType == XmlPushReaderNodeType.END_ELEMENT) {
        continue;
      }
      final _PathFunc pathFn = _svgPathFuncs[element.name.local];
      if (pathFn != null) {
        final Path nextPath = applyTransformIfNeeded(
          pathFn(parserState.attributes),
          parserState.attributes,
        );
        nextPath.fillType = parseFillRule(parserState.attributes, 'clip-rule');
        if (currentPath != null && nextPath.fillType != currentPath.fillType) {
          currentPath = nextPath;
          paths.add(currentPath);
        } else if (currentPath == null) {
          currentPath = nextPath;
          paths.add(currentPath);
        } else {
          currentPath.addPath(nextPath, Offset.zero);
        }
      } else if (element.name.local == 'use') {
        final String xlinkHref = getHrefAttribute(parserState.attributes);
        final DrawableStyleable definitionDrawable =
            parserState._definitions.getDrawable('url($xlinkHref)');

        void extractPathsFromDrawable(Drawable target) {
          if (target is DrawableShape) {
            paths.add(target.path);
          } else if (target is DrawableGroup) {
            target.children.forEach(extractPathsFromDrawable);
          }
        }

        extractPathsFromDrawable(definitionDrawable);
      } else {
        FlutterError.reportError(FlutterErrorDetails(
          exception: UnsupportedError(
              'Unsupported clipPath child ${element.name.local}'),
          informationCollector: (StringBuffer buff) {
            buff.writeln(
                'The <clipPath> element contained an unsupported child ${element.name.local}');
            if (parserState._key != null) {
              buff.writeln();
              buff.writeln('Picture key: ${parserState._key}');
            }
          },
          library: 'SVG',
          context: 'in _Element.clipPath',
        ));
      }
    }
    parserState._definitions.addClipPath(id, paths);*/
    return null;
  }

  static Future<void> image(SvgParserState parserState, XmlElement element) async {
    final String href = getHrefAttribute(element.attributes);
    final Offset offset = Offset(
      parseDouble(_attribute(element, 'x', def: '0')),
      parseDouble(_attribute(element, 'y', def: '0')),
    );
    final Size size = Size(
      parseDouble(_attribute(element, 'width', def: '0')),
      parseDouble(_attribute(element, 'height', def: '0')),
    );
    final Image image = await resolveImage(href);
    parserState.currentGroup.children.add(
      DrawableRasterImage(image, offset, size: size),
    );
  }

  static Future<void> text(SvgParserState parserState, XmlElement element) async {
    assert(parserState != null);
    assert(parserState.currentGroup != null);
    // <text>, <tspan> -> Collect styles
    // <tref> TBD - looks like Inkscape supports it, but no browser does.
    // XmlPushReaderNodeType.TEXT/CDATA -> DrawableText
    // Track the style(s) and offset(s) for <text> and <tspan> elements
    final Queue<_TextInfo> textInfos = ListQueue<_TextInfo>();
    double lastTextWidth = 0;
    for (XmlNode node in element.children) {
      if (node is XmlCDATA || node is XmlText) {
        final String value = node.text.trim();
        if (value.isEmpty) {
          continue;
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
        parserState.currentGroup.children.add(DrawableText(
          fill,
          stroke,
          lastTextInfo.offset,
          lastTextInfo.style.textStyle.anchor ??
              DrawableTextAnchorPosition.start,
          transform: lastTextInfo.style.transform,
        ));
        lastTextWidth = fill.maxIntrinsicWidth;
      } else if (node is XmlElement) {
        _TextInfo lastTextInfo;
        if (textInfos.isNotEmpty) {
          lastTextInfo = textInfos.last;
        }
        final Offset currentOffset = _parseCurrentOffset(
            element, lastTextInfo?.offset?.translate(lastTextWidth, 0));
        textInfos.add(_TextInfo(
          parseStyle(
            element.attributes,
            parserState._definitions,
            parserState.rootBounds,
            lastTextInfo?.style ?? parserState.currentGroup.style,
            needsTransform: true,
          ),
          currentOffset,
        ));
      }
    }


    /*do {
      switch (parserState._document.nodeType) {
        case XmlPushReaderNodeType.CDATA:
        case XmlPushReaderNodeType.TEXT:
          final String value = parserState._document.value.trim();
          if (value.isEmpty) {
            continue;
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
          parserState.currentGroup.children.add(DrawableText(
            fill,
            stroke,
            lastTextInfo.offset,
            lastTextInfo.style.textStyle.anchor ??
                DrawableTextAnchorPosition.start,
            transform: lastTextInfo.style.transform,
          ));
          lastTextWidth = fill.maxIntrinsicWidth;
          break;*//*
        case XmlPushReaderNodeType.ELEMENT:
          _TextInfo lastTextInfo;
          if (textInfos.isNotEmpty) {
            lastTextInfo = textInfos.last;
          }
          final Offset currentOffset = _parseCurrentOffset(
              parserState, lastTextInfo?.offset?.translate(lastTextWidth, 0));
          textInfos.add(_TextInfo(
            parseStyle(
              parserState.attributes,
              parserState._definitions,
              parserState.rootBounds,
              lastTextInfo?.style ?? parserState.currentGroup.style,
              needsTransform: true,
            ),
            currentOffset,
          ));
          break;
        case XmlPushReaderNodeType.END_ELEMENT:
          textInfos.removeLast();
          break;
        default:
          break;
      }
    } while (parserState._document.read() && depth <= parserState._document.depth);*/
  }
}

class _Paths {
  static Path circle(List<XmlAttribute> attributes) {
    final double cx = parseDouble(getAttribute(attributes, 'cx', def: '0'));
    final double cy = parseDouble(getAttribute(attributes, 'cy', def: '0'));
    final double r = parseDouble(getAttribute(attributes, 'r', def: '0'));
    final Rect oval = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    return Path()..addOval(oval);
  }

  static Path path(List<XmlAttribute> attributes) {
    final String d = getAttribute(attributes, 'd');
    return parseSvgPathData(d);
  }

  static Path rect(List<XmlAttribute> attributes) {
    final double x = parseDouble(getAttribute(attributes, 'x', def: '0'));
    final double y = parseDouble(getAttribute(attributes, 'y', def: '0'));
    final double w = parseDouble(getAttribute(attributes, 'width', def: '0'));
    final double h = parseDouble(getAttribute(attributes, 'height', def: '0'));
    final Rect rect = Rect.fromLTWH(x, y, w, h);
    String rxRaw = getAttribute(attributes, 'rx', def: null);
    String ryRaw = getAttribute(attributes, 'ry', def: null);
    rxRaw ??= ryRaw;
    ryRaw ??= rxRaw;

    if (rxRaw != null && rxRaw != '') {
      final double rx = parseDouble(rxRaw);
      final double ry = parseDouble(ryRaw);

      return Path()..addRRect(RRect.fromRectXY(rect, rx, ry));
    }

    return Path()..addRect(rect);
  }

  static Path polygon(List<XmlAttribute> attributes) {
    return parsePathFromPoints(attributes, true);
  }

  static Path polyline(List<XmlAttribute> attributes) {
    return parsePathFromPoints(attributes, false);
  }

  static Path parsePathFromPoints(List<XmlAttribute> attributes, bool close) {
    final String points = getAttribute(attributes, 'points');
    if (points == '') {
      return null;
    }
    final String path = 'M$points${close ? 'z' : ''}';

    return parseSvgPathData(path);
  }

  static Path ellipse(List<XmlAttribute> attributes) {
    final double cx = parseDouble(getAttribute(attributes, 'cx', def: '0'));
    final double cy = parseDouble(getAttribute(attributes, 'cy', def: '0'));
    final double rx = parseDouble(getAttribute(attributes, 'rx', def: '0'));
    final double ry = parseDouble(getAttribute(attributes, 'ry', def: '0'));

    final Rect r = Rect.fromLTWH(cx - rx, cy - ry, rx * 2, ry * 2);
    return Path()..addOval(r);
  }

  static Path line(List<XmlAttribute> attributes) {
    final double x1 = parseDouble(getAttribute(attributes, 'x1', def: '0'));
    final double x2 = parseDouble(getAttribute(attributes, 'x2', def: '0'));
    final double y1 = parseDouble(getAttribute(attributes, 'y1', def: '0'));
    final double y2 = parseDouble(getAttribute(attributes, 'y2', def: '0'));

    return Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
  }
}

class _SvgGroupTuple {
  _SvgGroupTuple(this.name, this.drawable);

  final String name;
  final DrawableParent drawable;
}

String _attribute(XmlElement element, String name, {String def, String namespace}) =>
    getAttribute(element.attributes, name, def: def, namespace: namespace);

/// The implementation of [SvgParser].
///
/// Maintains state while pushing an [XmlPushReader] through the SVG tree.
class SvgParserState {
  /// Creates a new [SvgParserState].
  SvgParserState(this._document, this._key) : assert(_document != null);

  final XmlDocument _document;
  final String _key;
  final DrawableDefinitionServer _definitions = DrawableDefinitionServer();
  final Queue<_SvgGroupTuple> _parentDrawables = ListQueue<_SvgGroupTuple>(10);
  DrawableRoot _root;
  bool _inDefs = false;

  /// Drive the [XmlTextReader] to EOF and produce a [DrawableRoot].
  Future<DrawableRoot> parse() async {
    final XmlElement rootElement = _document.rootElement;

    final _ParseFunc parseFunc = _svgElementParsers[rootElement.name.local];
    await parseFunc?.call(this, rootElement);
    assert(() {
      if (parseFunc == null) {
        unhandledElement(rootElement);
      }
      return true;
    }());
    //return _root;

    /*while (_document.read()) {
      switch (_document.nodeType) {
        case XmlPushReaderNodeType.ELEMENT:
          if (startElement()) {
            continue;
          }
          final _ParseFunc parseFunc = _svgElementParsers[_document.name.local];
          await parseFunc?.call(this);
          assert(() {
            if (parseFunc == null) {
              unhandledElement();
            }
            return true;
          }());
          break;
        case XmlPushReaderNodeType.END_ELEMENT:
          endElement();
          break;
        // comments, doctype, and process instructions are ignored.
        case XmlPushReaderNodeType.COMMENT:
        case XmlPushReaderNodeType.DOCUMENT_TYPE:
        case XmlPushReaderNodeType.PROCESSING:
        // CDATA and TEXT are handled by the `<text>` parser
        case XmlPushReaderNodeType.TEXT:
        case XmlPushReaderNodeType.CDATA:
          break;
      }
    }*/
    return _root;
  }

  /// The XML Attributes of the current node in the tree.
  //List<XmlAttribute> get attributes => _document.attributes;

  /// Gets the attribute for the current position of the parser.
  //String attribute(String name, {String def, String namespace}) =>
  //    getAttribute(attributes, name, def: def, namespace: namespace);

  /// The current group, if any, in the [Drawable] heirarchy.
  DrawableParent get currentGroup {
    assert(_parentDrawables != null);
    assert(_parentDrawables.isNotEmpty);
    return _parentDrawables.last.drawable;
  }

  /// The root bounds of the drawable.
  Rect get rootBounds {
    assert(_root != null, 'Cannot get rootBounds with null root');
    assert(_root.viewport != null);
    return _root.viewport.viewBoxRect;
  }

  /// Whether this [DrawableStyleable] belongs in the [DrawableDefinitions] or not.
  bool checkForIri(DrawableStyleable drawable, XmlElement element) {
    final String iri = buildUrlIri(element.attributes);
    if (iri != emptyUrlIri) {
      _definitions.addDrawable(iri, drawable);
      return true;
    }
    return false;
  }

  /// Appends a group to the collection.
  void addGroup(DrawableParent drawable, XmlElement element) {
    _parentDrawables.addLast(_SvgGroupTuple(element.name.local, drawable));
    checkForIri(drawable, element);
  }

  /// Appends a [DrawableShape] to the [currentGroup].
  bool addShape(XmlElement element) {
    final _PathFunc pathFunc = _svgPathFuncs[element.name.local];
    if (pathFunc == null) {
      return false;
    }

    final DrawableParent parent = _parentDrawables.last.drawable;
    final DrawableStyle parentStyle = parent.style;
    final Path path = pathFunc(element.attributes);
    final DrawableStyleable drawable = DrawableShape(
      path,
      parseStyle(
        element.attributes,
        _definitions,
        path.getBounds(),
        parentStyle,
      ),
      transform: parseTransform(getAttribute(element.attributes, 'transform'))?.storage,
    );
    final bool isIri = checkForIri(drawable, element);
    if (!_inDefs || !isIri) {
      parent.children.add(drawable);
    }
    return true;
  }
/*
  /// Potentially handles a starting element.
  bool startElement() {
    if (_document.name.local == 'defs') {
      // we won't get a call to `endElement()` if we're in a '<defs/>'
      _inDefs = !_document.isEmptyElement;
      return true;
    }
    return addShape();
  }*/
/*
  /// Handles the end of an XML element.
  void endElement() {
    if (_document.name.local == _parentDrawables.last.name) {
      _parentDrawables.removeLast();
    }
    if (_document.name.local == 'defs') {
      _inDefs = false;
    }
  }*/

  /// Prints an error for unhandled elements.
  ///
  /// Will only print an error once for unhandled/unexpected elements, except for
  /// `<style/>` elements.
  void unhandledElement(XmlElement element) {
    if (element.name.local == 'style') {
      FlutterError.reportError(FlutterErrorDetails(
        exception: UnimplementedError(
            'The <style> element is not implemented in this library.'),
        informationCollector: (StringBuffer buff) {
          buff.writeln(
              'Style elements are not supported by this library and the requested SVG may not '
              'render as intended.\n'
              'If possible, ensure the SVG uses inline styles and/or attributes (which are '
              'supported), or use a preprocessing utility such as svgcleaner to inline the '
              'styles for you.');
          buff.writeln();
          buff.writeln('Picture key: $_key');
        },
        library: 'SVG',
        context: 'in parseSvgElement',
      ));
    } else if (_unhandledElements.add(element.name.local)) {
      print('unhandled element ${element.name.local}; Picture key: $_key');
    }
  }
}
