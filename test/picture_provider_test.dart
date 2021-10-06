import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockPictureInfo extends Mock implements PictureInfo {}

class MockFile extends Mock implements File {}

void main() {
  group('PictureProvider', () {
    Color? currentColor;

    PictureInfoDecoder<T> decoderBuilder<T>(Color? color, double fontSize) {
      currentColor = color;
      return (T bytes, ColorFilter? colorFilter, String key) async =>
          MockPictureInfo();
    }

    test(
        'NetworkPicture rebuilds the decoder using decoderBuilder '
        'when currentColor changes', () async {
      const Color color = Color(0xFFB0E3BE);
      final NetworkPicture networkPicture =
          NetworkPicture(decoderBuilder, 'url')..fontSize = 14.0;

      final PictureInfoDecoder<Uint8List>? decoder = networkPicture.decoder;

      // Update the currentColor of PictureProvider.
      networkPicture.currentColor = color;

      expect(networkPicture.decoder, isNotNull);
      expect(networkPicture.decoder, isNot(equals(decoder)));
      expect(currentColor, equals(color));
    });

    test(
        'FilePicture rebuilds the decoder using decoderBuilder '
        'when currentColor changes', () async {
      const Color color = Color(0xFFB0E3BE);
      final FilePicture filePicture = FilePicture(decoderBuilder, MockFile())
        ..fontSize = 14.0;

      final PictureInfoDecoder<Uint8List>? decoder = filePicture.decoder;

      // Update the currentColor of PictureProvider.
      filePicture.currentColor = color;

      expect(filePicture.decoder, isNotNull);
      expect(filePicture.decoder, isNot(equals(decoder)));
      expect(currentColor, equals(color));
    });

    test(
        'MemoryPicture rebuilds the decoder using decoderBuilder '
        'when currentColor changes', () async {
      const Color color = Color(0xFFB0E3BE);
      final MemoryPicture memoryPicture =
          MemoryPicture(decoderBuilder, Uint8List(0))..fontSize = 14.0;

      final PictureInfoDecoder<Uint8List>? decoder = memoryPicture.decoder;

      // Update the currentColor of PictureProvider.
      memoryPicture.currentColor = color;

      expect(memoryPicture.decoder, isNotNull);
      expect(memoryPicture.decoder, isNot(equals(decoder)));
      expect(currentColor, equals(color));
    });

    test(
        'StringPicture rebuilds the decoder using decoderBuilder '
        'when currentColor changes', () async {
      const Color color = Color(0xFFB0E3BE);
      final StringPicture stringPicture = StringPicture(decoderBuilder, '')
        ..fontSize = 14.0;

      final PictureInfoDecoder<String>? decoder = stringPicture.decoder;

      // Update the currentColor of PictureProvider.
      stringPicture.currentColor = color;

      expect(stringPicture.decoder, isNotNull);
      expect(stringPicture.decoder, isNot(equals(decoder)));
      expect(currentColor, equals(color));
    });

    test(
        'ExactAssetPicture rebuilds the decoder using decoderBuilder '
        'when currentColor changes', () async {
      const Color color = Color(0xFFB0E3BE);
      final ExactAssetPicture exactAssetPicture =
          ExactAssetPicture(decoderBuilder, '')..fontSize = 14.0;

      final PictureInfoDecoder<String>? decoder = exactAssetPicture.decoder;

      // Update the currentColor of PictureProvider.
      exactAssetPicture.currentColor = color;

      expect(exactAssetPicture.decoder, isNotNull);
      expect(exactAssetPicture.decoder, isNot(equals(decoder)));
      expect(exactAssetPicture.currentColor, equals(color));
    });
  });
}
