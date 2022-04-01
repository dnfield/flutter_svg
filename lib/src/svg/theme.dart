import 'dart:ui';

import 'package:meta/meta.dart';

/// A theme used when decoding an SVG picture.
@immutable
class SvgTheme {
  /// Instantiates an SVG theme with the [currentColor]
  /// and [fontSize].
  ///
  /// Defaults the [fontSize] to 14.
  const SvgTheme({
    this.currentColor,
    this.fontSize = 14,
    double? xHeight,
    this.locale,
    this.decideFontFamily,
  }) : xHeight = xHeight ?? fontSize / 2;

  /// The default color applied to SVG elements that inherit the color property.
  /// See: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#currentcolor_keyword
  final Color? currentColor;

  /// The font size used when calculating em units of SVG elements.
  /// See: https://www.w3.org/TR/SVG11/coords.html#Units
  final double fontSize;

  /// The x-height (corpus size) of the font used when calculating ex units of SVG elements.
  /// Defaults to [fontSize] / 2 if not provided.
  /// See: https://www.w3.org/TR/SVG11/coords.html#Units, https://en.wikipedia.org/wiki/X-height
  final double xHeight;

  /// Locale used when rendering texts.
  /// See: https://github.com/dnfield/flutter_svg/issues/688
  final Locale? locale;

  /// Decide a font family based on specified font families.
  /// [fontFamilies] may be null but never be an empty list.
  /// The function may return null if it could not determine suitable font and in that case,
  /// the text is rendered using the default font.
  final String? Function(List<String>? fontFamilies)? decideFontFamily;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is SvgTheme &&
        currentColor == other.currentColor &&
        fontSize == other.fontSize &&
        xHeight == other.xHeight &&
        locale == other.locale &&
        decideFontFamily == other.decideFontFamily;
  }

  @override
  int get hashCode => hashValues(currentColor, fontSize, xHeight, locale, decideFontFamily);

  @override
  String toString() {
    return 'SvgTheme(currentColor: $currentColor, fontSize: $fontSize, xHeight: $xHeight, locale: $locale)';
  }
}
