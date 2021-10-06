import 'dart:ui';

/// A theme used when decoding an SVG picture.
class SvgTheme {
  /// Instantiates an SVG theme with the [currentColor].
  const SvgTheme({
    this.currentColor,
    required this.fontSize,
  });

  /// The default color applied to SVG elements that inherit the color property.
  /// See: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#currentcolor_keyword
  final Color? currentColor;

  /// The font size used when calculating em units of SVG elements.
  /// See: https://www.w3.org/TR/SVG11/coords.html#Units
  final double fontSize;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SvgTheme &&
        currentColor == other.currentColor &&
        fontSize == other.fontSize;
  }

  @override
  int get hashCode => hashValues(currentColor, fontSize);
}
