import 'package:flutter_svg/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Report tag not found', (WidgetTester tester) async {
    // TODO(ikbendewilliam): check for error
    const String svgStr = '''
<svg id="svgRoot" xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 166 202">
  <path id="path4" d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#triangleGradient)" />
</svg>
''';
    final SvgParser parser = SvgParser();
    await parser.parse(
      svgStr,
      key: 'some_svg.svg',
    );
  });
}
