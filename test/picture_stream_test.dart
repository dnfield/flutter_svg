import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:test/test.dart';

void main() {
  test('PictureInfo Tests', () {
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawPaint(Paint()..color = const Color(0xFFFA0000));
    final Picture picture = recorder.endRecording();

    final PictureInfo info1 = PictureInfo(
      picture: picture,
      viewport: Rect.zero,
      size: Size.zero,
      offset: Offset.zero
    );

    final PictureInfo info2 = PictureInfo(
      picture: picture,
      viewport: Rect.zero,
      size: Size.zero,
      offset: Offset.zero
    );
    expect(info1.hashCode, equals(info2.hashCode));
    expect(info1, equals(info2));
  });
}
