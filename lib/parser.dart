import 'dart:ui';

import 'package:flutter_svg/src/svg/parsers.dart';
import 'package:flutter_svg/src/svg/xml_parsers.dart';
import 'package:flutter_svg/src/utilities/xml.dart';
import 'package:flutter_svg/src/vector_drawable.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml/utils/node_list.dart';

/// Parses style attributes or @style attribute.
///
/// Remember that @style attribute takes precedence.
DrawableStyle parseStyle(
    XmlNodeList<XmlAttribute> attributes,
    DrawableDefinitionServer definitions,
    Rect bounds,
    DrawableStyle parentStyle,
    {bool needsTransform = false,
    Color defaultFillIfNotSpecified,
    Color defaultStrokeIfNotSpecified}) {
  final Matrix4 transform = needsTransform
      ? parseTransform(getAttribute(attributes, 'transform'))
      : null;

  return DrawableStyle.mergeAndBlend(
    parentStyle,
    transform: transform?.storage,
    stroke: parseStroke(
        attributes, bounds, definitions, defaultStrokeIfNotSpecified),
    dashArray: parseDashArray(attributes),
    dashOffset: parseDashOffset(attributes),
    fill: parseFill(attributes, bounds, definitions, defaultFillIfNotSpecified),
    pathFillType: parseFillRule(attributes),
    groupOpacity: parseOpacity(attributes),
    clipPath: parseClipPath(attributes, definitions),
    textStyle: new DrawableTextStyle(
      fontFamily: getAttribute(attributes, 'font-family'),
      fontSize: parseFontSize(getAttribute(attributes, 'font-size'),
          parentValue: parentStyle?.textStyle?.fontSize),
      height: -1.0,
    ),
  );
}

class SvgParser {
  int _depth = -1;
  int get depth => _depth;

  Drawable drawable;

  static const Map<String, Function> _parsers = const <String, Function>{
    'svg': _svg,
    'g': _g,
  };

  static void _g(SvgParser parser, List<XmlAttribute> attributes) {

  }

  static void _svg(SvgParser parser, List<XmlAttribute> attributes) {
    final Rect viewBox = parseViewBox(attributes);
    final DrawableDefinitionServer definitions = DrawableDefinitionServer();

    parser.drawable = new DrawableRoot(
      viewBox,
      <Drawable>[],
      definitions,
      parseStyle(attributes, definitions, viewBox, null),
    );
  }

  List<String> parentElements = List<String>(10);
  List<DrawableParent> parentDrawables = List<DrawableParent>(10);

  void _startElement(XmlName name, XmlNodeList<XmlAttribute> attributes) {
    _depth++;

    if (parentElements.length <= depth) {
      parentElements = List<String>.generate(depth * 2,
          (int index) => index < depth ? parentElements[index] : null,
          growable: false);
    }
    parentElements[depth] = name.local;
    _parsers[name.local]?.call(this, attributes);
  }

  void _endElement(XmlName name) {
    _depth--;
  }

  void _characterData(String text) {
    // print(text?.trim());
  }

  void parse(String str) {
    final XmlReader reader = XmlReader(
      onStartElement: _startElement,
      onEndElement: _endElement,
      onCharacterData: _characterData,
    );

    reader.parse(str);
  }
}

void main() {
  SvgParser().parse(
      '''<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 166 202">
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
    <path fill="#42A5F5" fill-opacity=".8" d="M37.7 128.9 9.8 101 100.4 10.4 156.2 10.4"/>
    <path fill="#42A5F5" fill-opacity=".8" d="M156.2 94 100.4 94 79.5 114.9 107.4 142.8"/>
    <path fill="#0D47A1" d="M79.5 170.7 100.4 191.6 156.2 191.6 156.2 191.6 107.4 142.8"/>
    <g transform="matrix(0.7071, -0.7071, 0.7071, 0.7071, -77.667, 98.057)">
        <rect width="39.4" height="39.4" x="59.8" y="123.1" fill="#42A5F5" />
        <rect width="39.4" height="5.5" x="59.8" y="162.5" fill="url(#rectangleGradient)" />
    </g>
    <path d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#triangleGradient)" />
</svg>''');
}
