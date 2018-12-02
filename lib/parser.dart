import 'dart:collection';
import 'dart:ui';

import 'package:flutter_svg/src/svg/colors.dart';
import 'package:flutter_svg/src/svg/parsers.dart';
import 'package:flutter_svg/src/svg/xml_parsers.dart';
import 'package:flutter_svg/src/svg_parser.dart';
import 'package:flutter_svg/src/utilities/xml.dart';
import 'package:flutter_svg/src/vector_drawable.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart'
    show XmlPushReader, XmlPushReaderNodeType, XmlAttribute;

final Set<String> _groupNames = Set<String>.from(
  <String>[
    'svg',
    'g',
    'text',
    'symbol',
    'a',
  ],
);

typedef _ParseFunc = void Function(_SvgParserState parserState);
typedef _PathFunc = Path Function(List<XmlAttribute> attributes);

const Map<String, _ParseFunc> _parsers = <String, _ParseFunc>{
  'svg': _GroupElements.svg,
  'g': _GroupElements.g,
  'a': _GroupElements.g, // treat as group
  'use': _GroupElements.use,
  'symbol': _GroupElements.symbol,
  'radialGradient': _Elements.radialGradient,
  'linearGradient': _Elements.linearGradient,
  'clipPath': _Elements.clipPath,
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

void _checkForIri(DrawableStyleable drawable, _SvgParserState parserState) {
  final String iri = buildUrlIri(parserState.attributes);
  if (iri != emptyUrlIri) {
    parserState.definitions.addDrawable(iri, drawable);
  }
}

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

class _GroupElements {
  static void svg(_SvgParserState parserState) {
    final DrawableViewport viewBox = parseViewBox(parserState.attributes);

    parserState.root = DrawableRoot(
      viewBox,
      <Drawable>[],
      parserState.definitions,
      parseStyle(parserState.attributes, parserState.definitions,
          viewBox.viewBoxRect, null),
    );
    parserState.parentDrawables.add(parserState.root);
  }

  static void g(_SvgParserState parserState) {
    final DrawableParent parent = parserState.parentDrawables.last;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[],
      parseStyle(
        parserState.attributes,
        parserState.definitions,
        null,
        parent.style,
        needsTransform: true,
      ),
    );
    parent.children.add(group);
    parserState.parentDrawables.add(group);
    _checkForIri(group, parserState);
  }

  static void symbol(_SvgParserState parserState) {
    print(parserState.attributes);
    final DrawableParent parent = parserState.parentDrawables.last;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[],
      parseStyle(
        parserState.attributes,
        parserState.definitions,
        null,
        parent.style,
        needsTransform: true,
      ),
    );
    parserState.parentDrawables.add(group);
    _checkForIri(group, parserState);
  }

  static void use(_SvgParserState parserState) {
    final String xlinkHref = getHrefAttribute(parserState.attributes);
    final DrawableStyle style = parseStyle(
      parserState.attributes,
      parserState.definitions,
      parserState.root.viewport.viewBoxRect,
      null,
    );
    final Matrix4 transform = Matrix4.identity()
      ..translate(
        double.parse(getAttribute(parserState.attributes, 'x', def: '0')),
        double.parse(getAttribute(parserState.attributes, 'y', def: '0')),
      );
    final DrawableStyleable ref =
        parserState.definitions.getDrawable('url($xlinkHref)');
    final DrawableParent parent = parserState.parentDrawables.last;
    final DrawableGroup group = DrawableGroup(
      <Drawable>[ref.mergeStyle(style)],
      DrawableStyle(transform: transform.storage),
    );
    parent.children.add(group);
  }
}

class _Elements {
  static void parseStops(
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
  }

  static void radialGradient(_SvgParserState parserState) {
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

    final Rect rootBounds = parserState.root.viewport.viewBoxRect;

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
  }

  static void linearGradient(_SvgParserState parserState) {
    final String gradientUnits = getAttribute(
        parserState.attributes, 'gradientUnits',
        def: 'objectBoundingBox');
    final bool isObjectBoundingBox = gradientUnits == 'objectBoundingBox';

    final String x1 = getAttribute(parserState.attributes, 'x1', def: '0%');
    final String x2 = getAttribute(parserState.attributes, 'x2', def: '100%');
    final String y1 = getAttribute(parserState.attributes, 'y1', def: '0%');
    final String y2 = getAttribute(parserState.attributes, 'y2', def: '0%');
    final String id = buildUrlIri(parserState.attributes);

    final TileMode spreadMethod = parseTileMode(parserState.attributes);

    final List<Color> colors = <Color>[];
    final List<double> offsets = <double>[];
    parseStops(parserState.reader, colors, offsets);

    final Matrix4 originalTransform = parseTransform(
      getAttribute(parserState.attributes, 'gradientTransform', def: null),
    );
    final Rect rootBounds = parserState.root.viewport.viewBoxRect;
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
  }

  static void clipPath(_SvgParserState parserState) {
    final String id = buildUrlIri(parserState.attributes);

    final List<Path> paths = <Path>[];
    Path currentPath;
    final int depth = parserState.reader.depth;

    while (parserState.reader.read() && depth < parserState.reader.depth) {
      final _PathFunc pathFn = _pathFuncs[parserState.reader.name.local];
      if (pathFn != null) {
        final Path nextPath = applyTransformIfNeeded(
            pathFn(parserState.attributes), parserState.attributes);
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
      } else {
        print('Unsupported clipPath child ${parserState.reader.name.local}');
      }
    }

    parserState.definitions.addClipPath(id, paths);
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

class _SvgParserState {
  _SvgParserState(this.reader) : assert(reader != null);

  final XmlPushReader reader;
  final DrawableDefinitionServer definitions = DrawableDefinitionServer();
  final Queue<DrawableParent> parentDrawables = ListQueue<DrawableParent>(10);
  DrawableRoot root;

  List<XmlAttribute> get attributes => reader.attributes;

  void addShape(_PathFunc pathFunc) {
    assert(pathFunc != null);
    final DrawableParent parent = parentDrawables.last;
    final DrawableStyle parentStyle = parent.style;
    final Path path = pathFunc(attributes);
    final DrawableStyleable drawable = DrawableSvgShape(
      path,
      parseStyle(
        attributes,
        definitions,
        path.getBounds(),
        parentStyle,
      ),
      parseTransform(getAttribute(attributes, 'transform')),
    );

    parent.children.add(drawable);

    _checkForIri(drawable, this);
  }
}

class SvgParser {
  _SvgParserState _state;

  Future<DrawableRoot> parse(String str) async {
    _state = _SvgParserState(XmlPushReader(str));
    while (_state.reader.read()) {
      switch (_state.reader.nodeType) {
        case XmlPushReaderNodeType.ELEMENT:
          final _PathFunc pathFunc = _pathFuncs[_state.reader.name.local];
          if (pathFunc != null) {
            _state.addShape(pathFunc);
            continue;
          }
          final _ParseFunc parseFunc = _parsers[_state.reader.name.local];
          if (parseFunc == null) {
            print('Unhandled Element ${_state.reader.name}');
          } else {
            parseFunc(_state);
          }
          break;
        case XmlPushReaderNodeType.END_ELEMENT:
          if (_groupNames.contains(_state.reader.name.local)) {
            _state.parentDrawables.removeLast();
          }
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
