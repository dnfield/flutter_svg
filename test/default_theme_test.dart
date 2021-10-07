// ignore_for_file: prefer_const_constructors

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/src/svg/default_theme.dart';
import 'package:flutter_svg/src/svg/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultSvgTheme', () {
    testWidgets('changes propagate to SvgPicture', (WidgetTester tester) async {
      const SvgTheme svgTheme = SvgTheme(
        currentColor: Color(0xFF733821),
        fontSize: 14.0,
      );

      final SvgPicture svgPictureWidget = SvgPicture.string('''
<svg viewBox="0 0 10 10">
  <rect x="0" y="0" width="10em" height="10" fill="currentColor" />
</svg>''');

      await tester.pumpWidget(DefaultSvgTheme(
        theme: svgTheme,
        child: svgPictureWidget,
      ));

      SvgPicture svgPicture = tester.firstWidget(find.byType(SvgPicture));
      expect(svgPicture, isNotNull);
      expect(
        svgPicture.pictureProvider.currentColor,
        equals(svgTheme.currentColor),
      );
      expect(
        svgPicture.pictureProvider.fontSize,
        equals(svgTheme.fontSize),
      );

      const SvgTheme anotherSvgTheme = SvgTheme(
        currentColor: Color(0xFF05290E),
        fontSize: 12.0,
      );

      await tester.pumpWidget(DefaultSvgTheme(
        theme: anotherSvgTheme,
        child: svgPictureWidget,
      ));

      svgPicture = tester.firstWidget(find.byType(SvgPicture));
      expect(svgPicture, isNotNull);
      expect(
        svgPicture.pictureProvider.currentColor,
        equals(anotherSvgTheme.currentColor),
      );
      expect(
        svgPicture.pictureProvider.fontSize,
        equals(anotherSvgTheme.fontSize),
      );
    });

    testWidgets(
        'currentColor from the widget\'s theme takes precedence over '
        'the theme from DefaultSvgTheme', (WidgetTester tester) async {
      const SvgTheme svgTheme = SvgTheme(
        currentColor: Color(0xFF733821),
        fontSize: 14.0,
      );

      final SvgPicture svgPictureWidget = SvgPicture.string(
        '''
<svg viewBox="0 0 10 10">
  <rect x="0" y="0" width="10" height="10" fill="currentColor" />
</svg>''',
        theme: SvgTheme(
          currentColor: Color(0xFF05290E),
          fontSize: 14.0,
        ),
      );

      await tester.pumpWidget(DefaultSvgTheme(
        theme: svgTheme,
        child: svgPictureWidget,
      ));

      final SvgPicture svgPicture = tester.firstWidget(find.byType(SvgPicture));
      expect(svgPicture, isNotNull);
      expect(
        svgPicture.pictureProvider.currentColor,
        equals(Color(0xFF05290E)),
      );
    });

    testWidgets(
        'fontSize from the widget\'s theme takes precedence over '
        'the theme from DefaultSvgTheme', (WidgetTester tester) async {
      const SvgTheme svgTheme = SvgTheme(
        fontSize: 14.0,
      );

      final SvgPicture svgPictureWidget = SvgPicture.string(
        '''
<svg viewBox="0 0 10 10">
  <rect x="0" y="0" width="10em" height="10em" />
</svg>''',
        theme: SvgTheme(
          fontSize: 12.0,
        ),
      );

      await tester.pumpWidget(DefaultSvgTheme(
        theme: svgTheme,
        child: svgPictureWidget,
      ));

      final SvgPicture svgPicture = tester.firstWidget(find.byType(SvgPicture));
      expect(svgPicture, isNotNull);
      expect(
        svgPicture.pictureProvider.fontSize,
        equals(12.0),
      );
    });

    testWidgets(
        'fontSize defaults to the font size from DefaultTextStyle '
        'if no widget\'s theme or DefaultSvgTheme is provided',
        (WidgetTester tester) async {
      final SvgPicture svgPictureWidget = SvgPicture.string(
        '''
<svg viewBox="0 0 10 10">
  <rect x="0" y="0" width="10em" height="10em" />
</svg>''',
      );

      await tester.pumpWidget(
        DefaultTextStyle(
          style: TextStyle(fontSize: 26.0),
          child: svgPictureWidget,
        ),
      );

      final SvgPicture svgPicture = tester.firstWidget(find.byType(SvgPicture));
      expect(svgPicture, isNotNull);
      expect(
        svgPicture.pictureProvider.fontSize,
        equals(26.0),
      );
    });

    testWidgets(
        'fontSize defaults to 14.0 '
        'if no widget\'s theme, DefaultSvgTheme or DefaultTextStyle is provided',
        (WidgetTester tester) async {
      final SvgPicture svgPictureWidget = SvgPicture.string(
        '''
<svg viewBox="0 0 10 10">
  <rect x="0" y="0" width="10em" height="10em" />
</svg>''',
      );

      await tester.pumpWidget(svgPictureWidget);

      final SvgPicture svgPicture = tester.firstWidget(find.byType(SvgPicture));
      expect(svgPicture, isNotNull);
      expect(
        svgPicture.pictureProvider.fontSize,
        equals(14.0),
      );
    });
  });
}
