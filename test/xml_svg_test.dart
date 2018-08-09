import 'dart:ui';

import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'package:flutter_svg/src/svg/xml_parsers.dart';
import 'package:flutter_svg/src/utilities/xml.dart';

void main() {
  test('Attribute and style tests', () {
    final XmlElement el = parse(
            '<test stroke="#fff" fill="#eee" stroke-dashpattern="1 2" style="stroke-opacity:1;fill-opacity:.23" />')
        .rootElement;

    expect(getAttribute(el.attributes, 'stroke'), '#fff');
    expect(getAttribute(el.attributes, 'fill'), '#eee');
    expect(getAttribute(el.attributes, 'stroke-dashpattern'), '1 2');
    expect(getAttribute(el.attributes, 'stroke-opacity'), '1');
    expect(getAttribute(el.attributes, 'stroke-another'), '');
    expect(getAttribute(el.attributes, 'fill-opacity'), '.23');
  });
  // if the parsing logic changes, we can simplify some methods.  for now assert that whitespace in attributes is preserved
  test('Attribute WhiteSpace test', () {
    final XmlDocument xd =
        parse('<test attr="  asdf" attr2="asdf  " attr3="asdf" />');

    expect(
      xd.rootElement.getAttribute('attr'),
      '  asdf',
      reason:
          'XML Parsing implementation no longer preserves leading whitespace in attributes!',
    );
    expect(
      xd.rootElement.getAttribute('attr2'),
      'asdf  ',
      reason:
          'XML Parsing implementation no longer preserves trailing whitespace in attributes!',
    );
  });

  test('viewBox tests', () {
    final Rect rect = new Rect.fromLTWH(0.0, 0.0, 100.0, 100.0);

    final XmlElement svgWithViewBox =
        parse('<svg viewBox="0 0 100 100" />').rootElement;
    final XmlElement svgWithViewBoxAndWidthHeight =
        parse('<svg width="50cm" height="50cm" viewBox="0 0 100 100" />')
            .rootElement;
    final XmlElement svgWithWidthHeight =
        parse('<svg width="100cm" height="100cm" />').rootElement;

    final XmlElement svgWithNoSizeInfo = parse('<svg />').rootElement;
    expect(parseViewBox(svgWithViewBox.attributes), rect);
    expect(parseViewBox(svgWithViewBoxAndWidthHeight.attributes), rect);
    expect(parseViewBox(svgWithWidthHeight.attributes), rect);
    expect(parseViewBox(svgWithNoSizeInfo.attributes), Rect.zero);
  });

  test('TileMode tests', () {
    final XmlElement pad =
        parse('<linearGradient spreadMethod="pad" />').rootElement;
    final XmlElement reflect =
        parse('<linearGradient spreadMethod="reflect" />').rootElement;
    final XmlElement repeat =
        parse('<linearGradient spreadMethod="repeat" />').rootElement;
    final XmlElement invalid =
        parse('<linearGradient spreadMethod="invalid" />').rootElement;

    final XmlElement none = parse('<linearGradient />').rootElement;

    expect(parseTileMode(pad.attributes), TileMode.clamp);
    expect(parseTileMode(invalid.attributes), TileMode.clamp);
    expect(parseTileMode(none.attributes), TileMode.clamp);

    expect(parseTileMode(reflect.attributes), TileMode.mirror);
    expect(parseTileMode(repeat.attributes), TileMode.repeated);
  });

  test('@stroke-dashoffset tests', () {
    final XmlElement abs =
        parse('<stroke stroke-dashoffset="20" />').rootElement;
    final XmlElement pct =
        parse('<stroke stroke-dashoffset="20%" />').rootElement;

    // TODO: DashOffset is completely opaque right now, maybe expose the raw value?
    expect(parseDashOffset(abs.attributes), isNotNull);
    expect(parseDashOffset(pct.attributes), isNotNull);
  });
}
