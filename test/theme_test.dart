// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/svg/theme.dart';
import 'package:test/test.dart';

void main() {
  group('SvgTheme', () {
    group('constructor', () {
      test('sets currentColor', () {
        const Color currentColor = Color(0xFFB0E3BE);

        expect(
          SvgTheme(
            currentColor: currentColor,
            fontSize: 14.0,
          ).currentColor,
          equals(currentColor),
        );
      });

      test('sets fontSize', () {
        const double fontSize = 14.0;

        expect(
          SvgTheme(
            currentColor: Color(0xFFB0E3BE),
            fontSize: fontSize,
          ).fontSize,
          equals(fontSize),
        );
      });
    });

    test('empty sets fontSize to 14', () {
      expect(
        SvgTheme.empty(),
        equals(
          SvgTheme(fontSize: 14.0),
        ),
      );
    });

    test('supports value equality', () {
      expect(
        SvgTheme(
          currentColor: Color(0xFF6F2173),
          fontSize: 14.0,
        ),
        equals(
          SvgTheme(
            currentColor: Color(0xFF6F2173),
            fontSize: 14.0,
          ),
        ),
      );
    });
  });
}
