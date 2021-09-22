// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/svg/theme.dart';
import 'package:test/test.dart';

void main() {
  group('SvgTheme', () {
    group('constructor', () {
      test('sets colorFilter', () {
        const ColorFilter colorFilter =
            ColorFilter.mode(Color(0xFF00FF00), BlendMode.color);

        expect(
          SvgTheme(colorFilter: colorFilter).colorFilter,
          equals(colorFilter),
        );
      });

      test('sets currentColor', () {
        const Color currentColor = Color(0xFFB0E3BE);

        expect(
          SvgTheme(currentColor: currentColor).currentColor,
          equals(currentColor),
        );
      });
    });

    test('supports value equality', () {
      expect(
        SvgTheme(
          colorFilter: ColorFilter.mode(Color(0xFF00FF00), BlendMode.darken),
          currentColor: Color(0xFF6F2173),
        ),
        equals(
          SvgTheme(
            colorFilter: ColorFilter.mode(Color(0xFF00FF00), BlendMode.darken),
            currentColor: Color(0xFF6F2173),
          ),
        ),
      );
    });
  });
}
