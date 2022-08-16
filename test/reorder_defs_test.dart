import 'package:flutter_svg/src/svg/parser_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/src/xml_events/event.dart';
import 'package:xml/xml_events.dart' as xml show parseEvents;

void main() {
  String _parseAndSort(String svgStr) {
    final Iterable<XmlEvent> parsed = xml.parseEvents(svgStr);
    final Iterable<XmlEvent> reordered = SvgParserState.reorderDefs(parsed);
    return reordered.map((XmlEvent e) => e.toString().trim()).join().replaceAll('\n', '');
  }

  test('dont reorder when no defs is added', () {
    const String svgStr = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
<linearGradient id="gradient" gradientUnits="userSpaceOnUse" x1="1em" x2="1.5em" y1="1.75em" y2="1.6em">
<stop offset="5%" stop-color="black"/>
<stop offset="50%" stop-color="red"/>
<stop offset="95%" stop-color="black"/>
</linearGradient>
<linearGradient id="gradient2" gradientUnits="userSpaceOnUse" x1="1em" x2="1.5em" y1="1.75em" y2="1.6em">
<stop offset="5%" stop-color="black"/>
<stop offset="50%" stop-color="red"/>
<stop offset="95%" stop-color="black"/>
</linearGradient>
</svg>''';

    expect(_parseAndSort(svgStr), svgStr.replaceAll('\n', ''));
  });

  test('reorder defs on depth 1', () {
    const String source = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)"/>
  <defs>
    <linearGradient id="gradient-1">
      <stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
      <stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
    </linearGradient>
  </defs>
</svg>''';

    const String output = '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
<defs>
<linearGradient id="gradient-1">
<stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
<stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
</linearGradient>
</defs>
<path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)"/>
</svg>''';

    expect(_parseAndSort(source), output.replaceAll('\n', ''));
  });

  test('reorder defs on depth 2', () {
    const String source = '''<svg color="currentColor" viewBox="0 0 166 202" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <g color="#c460b7">
    <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)"/>
    <defs>
      <linearGradient id="gradient-1">
        <stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
        <stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
      </linearGradient>
    </defs>
  </g>
</svg>''';

    const String output = '''<svg color="currentColor" viewBox="0 0 166 202" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<g color="#c460b7">
<defs>
<linearGradient id="gradient-1">
<stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
<stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
</linearGradient>
</defs>
<path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)"/>
</g>
</svg>''';

    expect(_parseAndSort(source), output.replaceAll('\n', ''));
  });

  test('reorder defs on multiple depths', () {
    const String source = '''<svg color="currentColor" viewBox="0 0 166 202" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <g color="#c460b7">
    <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)"/>
    <defs>
      <linearGradient id="gradient-1">
        <stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
        <stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
      </linearGradient>
    </defs>
  </g>
  <defs>
    <linearGradient id="gradient-2">
      <stop id="stop-3" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
      <stop id="stop-4" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
    </linearGradient>
  </defs>
</svg>''';

    const String output = '''<svg color="currentColor" viewBox="0 0 166 202" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<defs>
<linearGradient id="gradient-2">
<stop id="stop-3" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
<stop id="stop-4" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
</linearGradient>
</defs>
<g color="#c460b7">
<defs>
<linearGradient id="gradient-1">
<stop id="stop-1" offset="20%" stop-color="currentColor" stop-opacity="0.5"/>
<stop id="stop-2" offset="85%" stop-color="currentColor" stop-opacity="0.8"/>
</linearGradient>
</defs>
<path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#gradient-1)"/>
</g>
</svg>''';

    expect(_parseAndSort(source), output.replaceAll('\n', ''));
  });
}
