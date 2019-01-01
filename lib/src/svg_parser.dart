import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import 'vector_drawable.dart';

/// An SVG Shape element that will be drawn to the canvas.
class DrawableSvgShape extends DrawableShape {
  const DrawableSvgShape(Path path, DrawableStyle style, this.transform)
      : super(path, style);

  /// The transformation matrix, if any, to apply to the [Canvas] before
  /// [draw]ing this shape.
  final Matrix4 transform;

  @override
  void draw(Canvas canvas, ColorFilter colorFilter) {
    if (transform != null) {
      canvas.save();
      canvas.transform(transform.storage);
      super.draw(canvas, colorFilter);
      canvas.restore();
    } else {
      super.draw(canvas, colorFilter);
    }
  }
}
