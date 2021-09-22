import 'dart:ui';

/// A theme used when decoding an SVG picture.
class SvgTheme {
  /// Instantiates an SVG theme with the [colorFilter] and [currentColor].
  const SvgTheme({
    this.colorFilter,
    this.currentColor,
  });

  /// The color filter, if any, to apply to this widget.
  final ColorFilter? colorFilter;

  /// The default color applied to SVG elements that inherit the color property.
  /// See: https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#currentcolor_keyword
  final Color? currentColor;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SvgTheme &&
        colorFilter == other.colorFilter &&
        currentColor == other.currentColor;
  }

  @override
  int get hashCode => hashValues(colorFilter, currentColor);
}
