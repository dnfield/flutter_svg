import 'dart:collection';
import 'dart:ui';

import 'package:flutter_svg/src/svg/colors.dart';
import 'package:flutter_svg/src/svg/xml_parsers.dart';
import 'package:flutter_svg/src/svg_parser.dart';
import 'package:flutter_svg/src/utilities/xml.dart';
import 'package:flutter_svg/src/vector_drawable.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml/reader.dart';

final Set<String> _groupNames = Set.from<String>(<String>[
  'svg',
  'g',
  'text',
]);

typedef _ParseFunc = void Function(SvgParser parser);
typedef _PathFunc = Path Function(List<XmlAttribute> attributes);

const Map<String, _ParseFunc> _parsers = const <String, _ParseFunc>{
  'svg': _svg,
  'g': _g,
  'circle': _circle,
  'path': _path,
  'rect': _rect,
  'polygon': _polygon,
  'polyline': _polyline,
  'ellipse': _ellipse,
  'line': _line,
  'radialGradient': _radialGradient,
  'linearGradient': _linearGradient,
  'clipPath': _clipPath,
};

const Map<String, _PathFunc> _pathFuncs = const <String, _PathFunc>{
  'circle': _circlePath,
  'path': _pathPath,
  'rect': _rectPath,
  'polygon': _polygonPath,
  'polyline': _polylinePath,
  'ellipse': _ellipsePath,
  'line': _linePath,
};

void _svg(SvgParser parser) {
  final Rect viewBox = parseViewBox(parser._reader.attributes);
  parser._definitions = DrawableDefinitionServer();

  parser._drawable = new DrawableRoot(
    viewBox,
    <Drawable>[],
    parser._definitions,
    parseStyle(parser._reader.attributes, parser._definitions, viewBox, null),
  );
  parser._parentDrawables.add(parser._drawable);
}

void _g(SvgParser parser) {
  final DrawableParent parent = parser._parentDrawables.last;
  final DrawableGroup group = new DrawableGroup(
    <Drawable>[],
    parseStyle(
        parser._reader.attributes, parser._definitions, null, parent.style,
        needsTransform: true),
  );
  parent.children.add(group);
  parser._parentDrawables.add(group);
}

Path _circlePath(List<XmlAttribute> attributes) {
  final double cx = double.parse(getAttribute(attributes, 'cx', def: '0'));
  final double cy = double.parse(getAttribute(attributes, 'cy', def: '0'));
  final double r = double.parse(getAttribute(attributes, 'r', def: '0'));
  final Rect oval = new Rect.fromCircle(center: new Offset(cx, cy), radius: r);
  return new Path()..addOval(oval);
}

void _circle(SvgParser parser) {
  parser._addShape(_circlePath(parser._reader.attributes));
}

Path _pathPath(List<XmlAttribute> attributes) {
  final String d = getAttribute(attributes, 'd');
  return parseSvgPathData(d);
}

void _path(SvgParser parser) {
  parser._addShape(_pathPath(parser._reader.attributes));
}

Path _rectPath(List<XmlAttribute> attributes) {
  final double x = double.parse(getAttribute(attributes, 'x', def: '0'));
  final double y = double.parse(getAttribute(attributes, 'y', def: '0'));
  final double w = double.parse(getAttribute(attributes, 'width', def: '0'));
  final double h = double.parse(getAttribute(attributes, 'height', def: '0'));
  final Rect rect = new Rect.fromLTWH(x, y, w, h);
  String rxRaw = getAttribute(attributes, 'rx', def: null);
  String ryRaw = getAttribute(attributes, 'ry', def: null);
  rxRaw ??= ryRaw;
  ryRaw ??= rxRaw;

  if (rxRaw != null && rxRaw != '') {
    final double rx = double.parse(rxRaw);
    final double ry = double.parse(ryRaw);

    return new Path()..addRRect(new RRect.fromRectXY(rect, rx, ry));
  }

  return new Path()..addRect(rect);
}

void _rect(SvgParser parser) {
  parser._addShape(_rectPath(parser._reader.attributes));
}

Path _polygonPath(List<XmlAttribute> attributes) {
  return parsePathFromPoints(attributes, true);
}

void _polygon(SvgParser parser) {
  parser._addShape(_polygonPath(parser._reader.attributes));
}

Path _polylinePath(List<XmlAttribute> attributes) {
  return parsePathFromPoints(attributes, false);
}

void _polyline(SvgParser parser) {
  parser._addShape(_polylinePath(parser._reader.attributes));
}

Path parsePathFromPoints(List<XmlAttribute> attributes, bool close) {
  final String points = getAttribute(attributes, 'points');
  if (points == '') {
    return null;
  }
  final String path = 'M$points${close ? 'z' : ''}';

  return parseSvgPathData(path);
}

Path _ellipsePath(List<XmlAttribute> attributes) {
  final double cx = double.parse(getAttribute(attributes, 'cx', def: '0'));
  final double cy = double.parse(getAttribute(attributes, 'cy', def: '0'));
  final double rx = double.parse(getAttribute(attributes, 'rx', def: '0'));
  final double ry = double.parse(getAttribute(attributes, 'ry', def: '0'));

  final Rect r = new Rect.fromLTWH(cx - rx, cy - ry, rx * 2, ry * 2);
  return new Path()..addOval(r);
}

void _ellipse(SvgParser parser) {
  parser._addShape(_ellipsePath(parser._reader.attributes));
}

Path _linePath(List<XmlAttribute> attributes) {
  final double x1 = double.parse(getAttribute(attributes, 'x1', def: '0'));
  final double x2 = double.parse(getAttribute(attributes, 'x2', def: '0'));
  final double y1 = double.parse(getAttribute(attributes, 'y1', def: '0'));
  final double y2 = double.parse(getAttribute(attributes, 'y2', def: '0'));

  return new Path()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2);
}

void _line(SvgParser parser) {
  parser._addShape(_linePath(parser._reader.attributes));
}

double _parseDecimalOrPercentage(String val, {double multiplier = 1.0}) {
  if (val.endsWith('%')) {
    return double.parse(val.substring(0, val.length - 1)) / 100 * multiplier;
  } else {
    return double.parse(val);
  }
}

void _parseStops(
    XmlTextReader reader, List<Color> colors, List<double> offsets) {
  final int depth = reader.depth;

  while (reader.read() && depth < reader.depth) {
    final String rawOpacity =
        getAttribute(reader.attributes, 'stop-opacity', def: '1');
    colors.add(parseColor(getAttribute(reader.attributes, 'stop-color'))
        .withOpacity(double.parse(rawOpacity)));

    final String rawOffset = getAttribute(reader.attributes, 'offset');
    offsets.add(_parseDecimalOrPercentage(rawOffset));
  }
}

void _radialGradient(SvgParser parser) {
  final String rawCx =
      getAttribute(parser._reader.attributes, 'cx', def: '50%');
  final String rawCy =
      getAttribute(parser._reader.attributes, 'cy', def: '50%');
  final String rawR = getAttribute(parser._reader.attributes, 'r', def: '50%');
  final String rawFx =
      getAttribute(parser._reader.attributes, 'fx', def: rawCx);
  final String rawFy =
      getAttribute(parser._reader.attributes, 'fy', def: rawCy);
  final TileMode spreadMethod = parseTileMode(parser._reader.attributes);
  final String id = buildUrlIri(parser._reader.attributes);

  final List<Color> colors = <Color>[];
  final List<double> offsets = <double>[];
  _parseStops(parser._reader, colors, offsets);

  final PaintServer shaderFunc = (Rect bounds) {
    final double cx = _parseDecimalOrPercentage(rawCx,
        multiplier: bounds.width + bounds.left + bounds.left);
    final double cy = _parseDecimalOrPercentage(rawCy,
        multiplier: bounds.height + bounds.top + bounds.top);
    final double r = _parseDecimalOrPercentage(rawR,
        multiplier: (bounds.width + bounds.height) / 2);
    final double fx = _parseDecimalOrPercentage(rawFx,
        multiplier: bounds.width + (bounds.left * 2));
    final double fy = _parseDecimalOrPercentage(rawFy,
        multiplier: bounds.height + (bounds.top));

    final Offset center = new Offset(cx, cy);
    final Offset focal =
        (fx != cx || fy != cy) ? new Offset(fx, fy) : new Offset(cx, cy);

    return new Gradient.radial(
      center,
      r,
      colors,
      offsets,
      spreadMethod,
      null,
      focal,
      0.0,
    );
  };

  parser._definitions.addPaintServer(
    id,
    shaderFunc,
  );
}

void _linearGradient(SvgParser parser) {
  final double x1 = _parseDecimalOrPercentage(
      getAttribute(parser._reader.attributes, 'x1', def: '0%'));
  final double x2 = _parseDecimalOrPercentage(
      getAttribute(parser._reader.attributes, 'x2', def: '100%'));
  final double y1 = _parseDecimalOrPercentage(
      getAttribute(parser._reader.attributes, 'y1', def: '0%'));
  final double y2 = _parseDecimalOrPercentage(
      getAttribute(parser._reader.attributes, 'y2', def: '0%'));
  final String id = buildUrlIri(parser._reader.attributes);

  final TileMode spreadMethod = parseTileMode(parser._reader.attributes);

  final List<Color> colors = <Color>[];
  final List<double> offsets = <double>[];

  _parseStops(parser._reader, colors, offsets);

  final PaintServer shaderFunc = (Rect bounds) {
    final Offset from = new Offset(
      bounds.left + (bounds.width * x1),
      bounds.left + (bounds.height * y1),
    );
    final Offset to = new Offset(
      bounds.left + (bounds.width * x2),
      bounds.left + (bounds.height * y2),
    );

    return new Gradient.linear(
      from,
      to,
      colors,
      offsets,
      spreadMethod,
    );
  };

  parser._definitions.addPaintServer(
    id,
    shaderFunc,
  );
}

void _clipPath(SvgParser parser) {
  final String id = buildUrlIri(parser._reader.attributes);

  final List<Path> paths = <Path>[];
  Path currentPath;
  final int depth = parser._reader.depth;

  while (parser._reader.read() && depth < parser._reader.depth) {
    final _PathFunc pathFn = _pathFuncs[parser._reader.name.local];
    if (pathFn != null) {
      final Path nextPath = applyTransformIfNeeded(
          pathFn(parser._reader.attributes), parser._reader.attributes);
      nextPath.fillType = parseFillRule(parser._reader.attributes, 'clip-rule');
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
      print('Unsupported clipPath child ${parser._reader.name.local}');
    }
  }

  parser._definitions.addClipPath(id, paths);
}

class SvgParser {
  DrawableRoot _drawable;
  DrawableDefinitionServer _definitions;
  final Queue<DrawableParent> _parentDrawables = ListQueue<DrawableParent>(10);
  XmlTextReader _reader;

  void _addShape(Path path) {
    assert(path != null);
    final DrawableParent parent = _parentDrawables.last;
    final DrawableStyle parentStyle = parent.style;

    final Color defaultFill = parentStyle == null || parentStyle.fill == null
        ? colorBlack
        : identical(parentStyle.fill, DrawablePaint.empty)
            ? null
            : parentStyle.fill.color;

    final Color defaultStroke =
        identical(parentStyle.stroke, DrawablePaint.empty)
            ? null
            : parentStyle?.stroke?.color;

    parent.children.add(new DrawableShape(
      applyTransformIfNeeded(path, _reader.attributes),
      parseStyle(
          _reader.attributes, _definitions, path.getBounds(), parentStyle,
          defaultFillIfNotSpecified: defaultFill,
          defaultStrokeIfNotSpecified: defaultStroke),
    ));
  }

  void _reset() {
    _drawable = null;
    // _attributes = null;
    _definitions = null;
    _parentDrawables.clear();
    _reader = null;
  }

  DrawableRoot parse(String str) {
    _reset();
    _reader = XmlTextReader(str);
    while (_reader.read()) {
      switch (_reader.nodeType) {
        case XmlNodeType.ATTRIBUTE:
        case XmlNodeType.COMMENT:
        case XmlNodeType.DOCUMENT:
        case XmlNodeType.DOCUMENT_FRAGMENT:
        case XmlNodeType.DOCUMENT_TYPE:
        case XmlNodeType.PROCESSING:
        case XmlNodeType.TEXT: // handled by `text` parser
        case XmlNodeType.CDATA: // handled by `text` parser
          break;
        case XmlNodeType.ELEMENT:
          final _ParseFunc parseFunc = _parsers[_reader.name.local];
          if (parseFunc == null) {
            print('Unhandled Element ${_reader.name}');
          } else {
            parseFunc(this);
          }
          break;
        case XmlNodeType.END_ELEMENT:
          if (_groupNames.contains(_reader.name.local)) {
            _parentDrawables.removeLast();
          }
          break;
      }
    }

    return _drawable;
  }
}
