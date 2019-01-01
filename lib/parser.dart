import 'dart:async';
import 'dart:collection';
import 'dart:convert' hide Codec;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart'
    show XmlPushReader, XmlPushReaderNodeType, XmlAttribute;

import 'src/svg/colors.dart';
import 'src/svg/parsers.dart';
import 'src/svg/xml_parsers.dart';
import 'src/svg_parser.dart';
import 'src/utilities/http.dart';
import 'src/utilities/xml.dart';
import 'src/vector_drawable.dart';

final Set<String> _unhandledElements = Set<String>();

typedef _ParseFunc = Future<void> Function(_SvgParserState parserState);
typedef _PathFunc = Path Function(List<XmlAttribute> attributes);

const Map<String, _ParseFunc> _parsers = <String, _ParseFunc>{
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

const Map<String, _PathFunc> _pathFuncs = <String, _PathFunc>{
  'circle': _Paths.circle,
  'path': _Paths.path,
  'rect': _Paths.rect,
  'polygon': _Paths.polygon,
  'polyline': _Paths.polyline,
  'ellipse': _Paths.ellipse,
  'line': _Paths.line,
};

double _parseDecimalOrPercentage(String val, {double multiplier = 1.0}) {
  if (_isPercentage(val)) {
    return _parsePercentage(val, multiplier: multiplier);
  } else {
    return double.parse(val);
  }
}

double _parsePercentage(String val, {double multiplier = 1.0}) {
  return double.parse(val.substring(0, val.length - 1)) / 100 * multiplier;
}

bool _isPercentage(String val) => val.endsWith('%');

class _Elements {
  static Future<void> svg(_SvgParserState parserState) {
    final DrawableViewport viewBox = parseViewBox(parserState.attributes);

    parserState.root = DrawableRoot(
      viewBox,
      <Drawable>[],
      parserState.definitions,
      _parseStyle(parserState.attributes, parserState.definitions,
          viewBox.viewBoxRect, null),
    );
    parserState.addGroup(parserState.root);
    return null;
  }

  static Future<void> g(_SvgParserState parserState) {
    final DrawableParent parent = parserState.currentGroup;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[],
      _parseStyle(
        parserState.attributes,
        parserState.definitions,
        parserState.rootBounds,
        parent.style,
        needsTransform: true,
      ),
    );
    if (!parserState.inDefs) {
      parent.children.add(group);
    }
    parserState.addGroup(group);
    return null;
  }

  static Future<void> symbol(_SvgParserState parserState) {
    final DrawableParent parent = parserState.currentGroup;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[],
      _parseStyle(
        parserState.attributes,
        parserState.definitions,
        null,
        parent.style,
        needsTransform: true,
      ),
    );
    parserState.addGroup(group);
    return null;
  }

  static Future<void> use(_SvgParserState parserState) {
    final String xlinkHref = getHrefAttribute(parserState.attributes);
    final DrawableStyle style = _parseStyle(
      parserState.attributes,
      parserState.definitions,
      parserState.rootBounds,
      null,
    );
    final Matrix4 transform = Matrix4.identity()
      ..translate(
        double.parse(getAttribute(parserState.attributes, 'x', def: '0')),
        double.parse(getAttribute(parserState.attributes, 'y', def: '0')),
      );
    final DrawableStyleable ref =
        parserState.definitions.getDrawable('url($xlinkHref)');
    final DrawableParent parent = parserState.currentGroup;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[ref.mergeStyle(style)],
      DrawableStyle(transform: transform.storage),
    );
    parent.children.add(group);
    return null;
  }

  static Future<void> parseStops(
      XmlPushReader reader, List<Color> colors, List<double> offsets) {
    final int depth = reader.depth;

    while (reader.read() && depth < reader.depth) {
      final String rawOpacity = getAttribute(
        reader.attributes,
        'stop-opacity',
        def: '1',
      );
      colors.add(parseColor(getAttribute(reader.attributes, 'stop-color'))
          .withOpacity(double.parse(rawOpacity)));

      final String rawOffset = getAttribute(
        reader.attributes,
        'offset',
        def: '0%',
      );
      offsets.add(_parseDecimalOrPercentage(rawOffset));
    }
    return null;
  }

  static Future<void> radialGradient(_SvgParserState parserState) {
    final String gradientUnits = getAttribute(
        parserState.attributes, 'gradientUnits',
        def: 'objectBoundingBox');
    final bool isObjectBoundingBox = gradientUnits == 'objectBoundingBox';

    final String rawCx = getAttribute(parserState.attributes, 'cx', def: '50%');
    final String rawCy = getAttribute(parserState.attributes, 'cy', def: '50%');
    final String rawR = getAttribute(parserState.attributes, 'r', def: '50%');
    final String rawFx = getAttribute(parserState.attributes, 'fx', def: rawCx);
    final String rawFy = getAttribute(parserState.attributes, 'fy', def: rawCy);
    final TileMode spreadMethod = parseTileMode(parserState.attributes);
    final String id = buildUrlIri(parserState.attributes);
    final Matrix4 originalTransform = parseTransform(
      getAttribute(parserState.attributes, 'gradientTransform', def: null),
    );

    final List<double> offsets = <double>[];
    final List<Color> colors = <Color>[];
    parseStops(parserState.reader, colors, offsets);

    final Rect rootBounds = Rect.fromLTRB(
      parserState.rootBounds.left,
      parserState.rootBounds.top,
      parserState.rootBounds.right,
      parserState.rootBounds.bottom,
    );

    final PaintServer shaderFunc = (Rect bounds) {
      double cx, cy, r, fx, fy;
      Matrix4 transform = originalTransform?.clone() ?? Matrix4.identity();

      if (isObjectBoundingBox) {
        final Matrix4 scale =
            affineMatrix(bounds.width, 0.0, 0.0, bounds.height, 0.0, 0.0);
        final Matrix4 translate =
            affineMatrix(1.0, 0.0, 0.0, 1.0, bounds.left, bounds.top);
        transform = translate.multiplied(scale)..multiply(transform);

        cx = _parseDecimalOrPercentage(rawCx);
        cy = _parseDecimalOrPercentage(rawCy);
        r = _parseDecimalOrPercentage(rawR);
        fx = _parseDecimalOrPercentage(rawFx);
        fy = _parseDecimalOrPercentage(rawFy);
      } else {
        cx = _isPercentage(rawCx)
            ? _parsePercentage(rawCx) * rootBounds.width + rootBounds.left
            : double.parse(rawCx);
        cy = _isPercentage(rawCy)
            ? _parsePercentage(rawCy) * rootBounds.height + rootBounds.top
            : double.parse(rawCy);
        r = _isPercentage(rawR)
            ? _parsePercentage(rawR) *
                ((rootBounds.height + rootBounds.width) / 2)
            : double.parse(rawR);
        fx = _isPercentage(rawFx)
            ? _parsePercentage(rawFx) * rootBounds.width + rootBounds.left
            : double.parse(rawFx);
        fy = _isPercentage(rawFy)
            ? _parsePercentage(rawFy) * rootBounds.height + rootBounds.top
            : double.parse(rawFy);
      }

      final Offset center = Offset(cx, cy);
      final Offset focal =
          (fx != cx || fy != cy) ? Offset(fx, fy) : Offset(cx, cy);

      return Gradient.radial(
        center,
        r,
        colors,
        offsets,
        spreadMethod,
        transform?.storage,
        focal,
        0.0,
      );
    };

    parserState.definitions.addPaintServer(
      id,
      shaderFunc,
    );
    return null;
  }

  static Future<void> linearGradient(_SvgParserState parserState) {
    final String gradientUnits = getAttribute(
        parserState.attributes, 'gradientUnits',
        def: 'objectBoundingBox');
    final bool isObjectBoundingBox = gradientUnits == 'objectBoundingBox';

    final String x1 = getAttribute(parserState.attributes, 'x1', def: '0%');
    final String x2 = getAttribute(parserState.attributes, 'x2', def: '100%');
    final String y1 = getAttribute(parserState.attributes, 'y1', def: '0%');
    final String y2 = getAttribute(parserState.attributes, 'y2', def: '0%');
    final String id = buildUrlIri(parserState.attributes);
    final Matrix4 originalTransform = parseTransform(
      getAttribute(parserState.attributes, 'gradientTransform', def: null),
    );
    final TileMode spreadMethod = parseTileMode(parserState.attributes);

    final List<Color> colors = <Color>[];
    final List<double> offsets = <double>[];
    parseStops(parserState.reader, colors, offsets);
    final Rect rootBounds = Rect.fromLTRB(
      parserState.rootBounds.left,
      parserState.rootBounds.top,
      parserState.rootBounds.right,
      parserState.rootBounds.bottom,
    );

    final PaintServer shaderFunc = (Rect bounds) {
      Vector3 from, to;
      Matrix4 transform = originalTransform?.clone() ?? Matrix4.identity();

      if (isObjectBoundingBox) {
        final Matrix4 scale =
            affineMatrix(bounds.width, 0.0, 0.0, bounds.height, 0.0, 0.0);
        final Matrix4 translate =
            affineMatrix(1.0, 0.0, 0.0, 1.0, bounds.left, bounds.top);
        transform = translate.multiplied(scale)..multiply(transform);

        final Offset fromOffset = Offset(
          _parseDecimalOrPercentage(x1),
          _parseDecimalOrPercentage(y1),
        );
        final Offset toOffset = Offset(
          _parseDecimalOrPercentage(x2),
          _parseDecimalOrPercentage(y2),
        );

        from = Vector3(
          fromOffset.dx,
          fromOffset.dy,
          0.0,
        );
        to = Vector3(
          toOffset.dx,
          toOffset.dy,
          0.0,
        );
      } else {
        final Offset fromOffset = Offset(
          _isPercentage(x1)
              ? _parsePercentage(x1) * rootBounds.width + rootBounds.left
              : double.parse(x1),
          _isPercentage(y1)
              ? _parsePercentage(y1) * rootBounds.height + rootBounds.top
              : double.parse(y1),
        );

        final Offset toOffset = Offset(
          _isPercentage(x2)
              ? _parsePercentage(x2) * rootBounds.width + rootBounds.left
              : double.parse(x2),
          _isPercentage(y2)
              ? _parsePercentage(y2) * rootBounds.height + rootBounds.top
              : double.parse(y2),
        );

        from = Vector3(fromOffset.dx, fromOffset.dy, 0.0);
        to = Vector3(toOffset.dx, toOffset.dy, 0.0);
      }

      if (transform != null) {
        from = transform.transform3(from);
        to = transform.transform3(to);
      }

      return Gradient.linear(
        Offset(from.x, from.y),
        Offset(to.x, to.y),
        colors,
        offsets,
        spreadMethod,
      );
    };

    parserState.definitions.addPaintServer(
      id,
      shaderFunc,
    );
    return null;
  }

  static Future<void> clipPath(_SvgParserState parserState) {
    final String id = buildUrlIri(parserState.attributes);

    final List<Path> paths = <Path>[];
    Path currentPath;
    final int depth = parserState.reader.depth;
    while (parserState.reader.read() && depth < parserState.reader.depth) {
      final _PathFunc pathFn = _pathFuncs[parserState.reader.name.local];
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
      } else if (parserState.reader.name.local == 'use') {
        final String xlinkHref = getHrefAttribute(parserState.attributes);
        final DrawableStyleable definitionDrawable =
            parserState.definitions.getDrawable('url($xlinkHref)');

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
              'Unsupported clipPath child ${parserState.reader.name.local}'),
          informationCollector: (StringBuffer buff) {
            buff.writeln(
                'The <clipPath> element contained an unsupported child ${parserState.reader.name.local}');
            if (parserState.key != null) {
              buff.writeln();
              buff.writeln('Picture key: ${parserState.key}');
            }
          },
          library: 'SVG',
          context: 'in _Element.clipPath',
        ));
      }
    }
    parserState.definitions.addClipPath(id, paths);
    return null;
  }

  static Future<void> image(_SvgParserState parserState) async {
    final String href = getHrefAttribute(parserState.attributes);
    final Offset offset = Offset(
      double.parse(getAttribute(parserState.attributes, 'x', def: '0')),
      double.parse(getAttribute(parserState.attributes, 'y', def: '0')),
    );
    final Size size = Size(
      double.parse(getAttribute(parserState.attributes, 'width', def: '0')),
      double.parse(getAttribute(parserState.attributes, 'height', def: '0')),
    );
    final Image image = await _resolveImage(href);
    parserState.currentGroup.children.add(
      DrawableRasterImage(image, offset, size: size),
    );
  }

  static Future<void> text(_SvgParserState parserState) async {
    final Offset offset = Offset(
        double.parse(getAttribute(parserState.attributes, 'x', def: '0')),
        double.parse(getAttribute(parserState.attributes, 'y', def: '0')));
    final DrawableStyle style = _parseStyle(
      parserState.attributes,
      parserState.definitions,
      parserState.rootBounds,
      parserState.currentGroup.style,
    );

    final ParagraphBuilder fill = ParagraphBuilder(ParagraphStyle());
    final ParagraphBuilder stroke = ParagraphBuilder(ParagraphStyle());

    final DrawableTextAnchorPosition textAnchor = parseTextAnchor(
      getAttribute(parserState.attributes, 'text-anchor', def: 'start'),
    );

    final int depth = parserState.reader.depth;
    DrawableStyle childStyle = style;
    while (parserState.reader.read() && depth <= parserState.reader.depth) {
      switch (parserState.reader.nodeType) {
        case XmlPushReaderNodeType.CDATA:
        case XmlPushReaderNodeType.TEXT:
          _appendParagraphs(fill, stroke, parserState.reader.value, childStyle);
          break;
        case XmlPushReaderNodeType.ELEMENT:
          childStyle = _parseStyle(parserState.attributes,
              parserState.definitions, parserState.rootBounds, childStyle);
          fill.pop();
          stroke.pop();
          break;
        default:
          break;
      }
    }

    parserState.currentGroup.children.add(DrawableText(
      _finishParagraph(fill),
      _finishParagraph(stroke),
      offset,
      textAnchor,
    ));
  }
}

class _Paths {
  static Path circle(List<XmlAttribute> attributes) {
    final double cx = double.parse(getAttribute(attributes, 'cx', def: '0'));
    final double cy = double.parse(getAttribute(attributes, 'cy', def: '0'));
    final double r = double.parse(getAttribute(attributes, 'r', def: '0'));
    final Rect oval = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    return Path()..addOval(oval);
  }

  static Path path(List<XmlAttribute> attributes) {
    final String d = getAttribute(attributes, 'd');
    return parseSvgPathData(d);
  }

  static Path rect(List<XmlAttribute> attributes) {
    final double x = double.parse(getAttribute(attributes, 'x', def: '0'));
    final double y = double.parse(getAttribute(attributes, 'y', def: '0'));
    final double w = double.parse(getAttribute(attributes, 'width', def: '0'));
    final double h = double.parse(getAttribute(attributes, 'height', def: '0'));
    final Rect rect = Rect.fromLTWH(x, y, w, h);
    String rxRaw = getAttribute(attributes, 'rx', def: null);
    String ryRaw = getAttribute(attributes, 'ry', def: null);
    rxRaw ??= ryRaw;
    ryRaw ??= rxRaw;

    if (rxRaw != null && rxRaw != '') {
      final double rx = double.parse(rxRaw);
      final double ry = double.parse(ryRaw);

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
    final double cx = double.parse(getAttribute(attributes, 'cx', def: '0'));
    final double cy = double.parse(getAttribute(attributes, 'cy', def: '0'));
    final double rx = double.parse(getAttribute(attributes, 'rx', def: '0'));
    final double ry = double.parse(getAttribute(attributes, 'ry', def: '0'));

    final Rect r = Rect.fromLTWH(cx - rx, cy - ry, rx * 2, ry * 2);
    return Path()..addOval(r);
  }

  static Path line(List<XmlAttribute> attributes) {
    final double x1 = double.parse(getAttribute(attributes, 'x1', def: '0'));
    final double x2 = double.parse(getAttribute(attributes, 'x2', def: '0'));
    final double y1 = double.parse(getAttribute(attributes, 'y1', def: '0'));
    final double y2 = double.parse(getAttribute(attributes, 'y2', def: '0'));

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

class _SvgParserState {
  _SvgParserState(this.reader, this.key) : assert(reader != null);

  final XmlPushReader reader;
  final String key;
  final DrawableDefinitionServer definitions = DrawableDefinitionServer();
  final Queue<_SvgGroupTuple> parentDrawables = ListQueue<_SvgGroupTuple>(10);
  DrawableRoot root;
  bool inDefs = false;

  List<XmlAttribute> get attributes => reader.attributes;

  DrawableParent get currentGroup => parentDrawables.last.drawable;

  Rect get rootBounds {
    assert(root != null, 'Cannot get rootBounds with null root');
    assert(root.viewport != null);
    return root.viewport.viewBoxRect;
  }

  bool checkForIri(DrawableStyleable drawable) {
    final String iri = buildUrlIri(attributes);
    if (iri != emptyUrlIri) {
      definitions.addDrawable(iri, drawable);
      return true;
    }
    return false;
  }

  void addGroup(DrawableParent drawable) {
    parentDrawables.addLast(_SvgGroupTuple(reader.name.local, drawable));
    checkForIri(drawable);
  }

  bool addShape() {
    final _PathFunc pathFunc = _pathFuncs[reader.name.local];
    if (pathFunc == null) {
      return false;
    }

    final DrawableParent parent = parentDrawables.last.drawable;
    final DrawableStyle parentStyle = parent.style;
    final Path path = pathFunc(attributes);
    final DrawableStyleable drawable = DrawableSvgShape(
      path,
      _parseStyle(
        attributes,
        definitions,
        path.getBounds(),
        parentStyle,
      ),
      parseTransform(getAttribute(attributes, 'transform')),
    );
    final bool isIri = checkForIri(drawable);
    if (!inDefs || !isIri) {
      parent.children.add(drawable);
    }
    return true;
  }

  bool startElement() {
    if (reader.name.local == 'defs') {
      inDefs = true;
      return true;
    }
    return addShape();
  }

  void endElement() {
    if (reader.name.local == parentDrawables.last.name) {
      parentDrawables.removeLast();
    }
    if (reader.name.local == 'defs') {
      inDefs = false;
    }
  }

  void unhandledElement() {
    if (reader.name.local == 'style') {
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
          buff.writeln('Picture key: $key');
        },
        library: 'SVG',
        context: 'in parseSvgElement',
      ));
    } else if (_unhandledElements.add(reader.name.local)) {
      print('unhandled element ${reader.name.local}; Picture key: $key');
    }
  }
}

class SvgParser {
  _SvgParserState _state;

  Future<DrawableRoot> parse(String str, {String key}) async {
    _state = _SvgParserState(XmlPushReader(str), key);
    while (_state.reader.read()) {
      switch (_state.reader.nodeType) {
        case XmlPushReaderNodeType.ELEMENT:
          if (_state.startElement()) {
            continue;
          }
          final _ParseFunc parseFunc = _parsers[_state.reader.name.local];
          await parseFunc?.call(_state);
          assert(() {
            if (parseFunc == null) {
              _state.unhandledElement();
            }
            return true;
          }());
          break;
        case XmlPushReaderNodeType.END_ELEMENT:
          _state.endElement();
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
    }
    return _state.root;
  }
}

Future<Image> _resolveImage(String href) async {
  if (href == null || href == '') {
    return null;
  }

  final Function decodeImage = (Uint8List bytes) async {
    final Codec codec = await instantiateImageCodec(bytes);
    final FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  };

  if (href.startsWith('http')) {
    final Uint8List bytes = await httpGet(href);
    return decodeImage(bytes);
  }

  if (href.startsWith('data:')) {
    final int commaLocation = href.indexOf(',') + 1;
    final Uint8List bytes = base64.decode(href.substring(commaLocation));
    return decodeImage(bytes);
  }

  throw UnsupportedError('Could not resolve image href: $href');
}

const DrawablePaint _transparentStroke =
    DrawablePaint(PaintingStyle.stroke, color: Color(0x0));
void _appendParagraphs(ParagraphBuilder fill, ParagraphBuilder stroke,
    String text, DrawableStyle style) {
  fill
    ..pushStyle(
        style.textStyle.toFlutterTextStyle(foregroundOverride: style.fill))
    ..addText(text);

  stroke
    ..pushStyle(style.textStyle.toFlutterTextStyle(
        foregroundOverride:
            style.stroke == null ? _transparentStroke : style.stroke))
    ..addText(text);
}

final ParagraphConstraints _infiniteParagraphConstraints =
    ParagraphConstraints(width: double.infinity);

Paragraph _finishParagraph(ParagraphBuilder paragraphBuilder) {
  final Paragraph paragraph = paragraphBuilder.build();
  paragraph.layout(_infiniteParagraphConstraints);
  return paragraph;
}

/// Parses style attributes or @style attribute.
///
/// Remember that @style attribute takes precedence.
DrawableStyle _parseStyle(
  List<XmlAttribute> attributes,
  DrawableDefinitionServer definitions,
  Rect bounds,
  DrawableStyle parentStyle, {
  bool needsTransform = false,
}) {
  final Matrix4 transform = needsTransform
      ? parseTransform(getAttribute(attributes, 'transform'))
      : null;

  return DrawableStyle.mergeAndBlend(
    parentStyle,
    transform: transform?.storage,
    stroke: parseStroke(attributes, bounds, definitions, parentStyle?.stroke),
    dashArray: parseDashArray(attributes),
    dashOffset: parseDashOffset(attributes),
    fill: parseFill(attributes, bounds, definitions, parentStyle?.fill),
    pathFillType: parseFillRule(
      attributes,
      'fill-rule',
      parentStyle != null ? null : 'nonzero',
    ),
    groupOpacity: parseOpacity(attributes),
    clipPath: parseClipPath(attributes, definitions),
    textStyle: DrawableTextStyle(
      fontFamily: getAttribute(attributes, 'font-family'),
      fontSize: parseFontSize(getAttribute(attributes, 'font-size'),
          parentValue: parentStyle?.textStyle?.fontSize),
      height: -1.0,
    ),
  );
}
