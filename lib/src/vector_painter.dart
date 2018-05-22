import 'dart:ui';

import 'package:flutter/widgets.dart' hide TextStyle, Image;
import 'package:flutter_svg/src/vector_drawable.dart';

/// A [CustomPainter] that can render a [DrawableRoot] to a [Canvas].
class VectorPainter extends CustomPainter {
  final DrawableRoot drawable;
  final bool _clipToViewBox;

  VectorPainter(this.drawable, {bool clipToViewBox = true})
      : _clipToViewBox = clipToViewBox;

  @override
  void paint(Canvas canvas, Size size) {
    Rect p;
    p.hashCode;
    if (drawable == null ||
        drawable.viewBox == null ||
        drawable.viewBox.size.width == 0) {
      return;
    }

    drawable.scaleCanvasToViewBox(canvas, size);
    if (_clipToViewBox) {
      drawable.clipCanvasToViewBox(canvas);
    }

    drawable.draw(canvas);
  }

  // TODO: implement semanticsBuilder

  @override
  bool shouldRepaint(VectorPainter oldDelegate) => true;
}
