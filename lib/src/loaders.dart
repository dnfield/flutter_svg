import 'dart:convert' show utf8;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/src/utilities/http.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

/// Compute will mess up tests because of FakeAsync.
final bool _isTest = Platform.executable.endsWith('flutter_tester') ||
    Platform.executable.endsWith('flutter_tester.exe');

final ComputeImpl _computeImpl = _isTest
    ? <Q, R>(ComputeCallback<Q, R> callback, Q message,
            {String? debugLabel}) async =>
        await callback(message)
    : compute;

/// A [BytesLoader] that parses an SVG string in an isolate and creates a
/// vector_graphics binary representation.
class SvgStringLoader extends BytesLoader {
  /// See class doc.
  const SvgStringLoader(
    this.svg, {
    this.theme = const SvgTheme(),
  });

  /// The raw XML string.
  final String svg;

  /// The theme to determine currentColor and font sizing attributes.
  final SvgTheme theme;

  @override
  Future<ByteData> loadBytes(BuildContext context) async {
    return await _computeImpl((String svg) async {
      final Uint8List compiledBytes = await encodeSvg(
        xml: svg,
        theme: theme,
        debugName: 'Svg loader',
        enableClippingOptimizer: false,
        enableMaskingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
      return compiledBytes.buffer.asByteData();
    }, svg, debugLabel: 'Load Bytes');
  }
}

/// A [BytesLoader] that decodes and parses a UTF-8 encoded SVG string from a
/// [Uint8List] in an isolate and creates a vector_graphics binary
/// representation.
class SvgBytesLoader extends BytesLoader {
  /// See class doc.
  const SvgBytesLoader(
    this.svg, {
    this.theme = const SvgTheme(),
  });

  /// The UTF-8 encoded XML bytes.
  final Uint8List svg;

  /// The theme to determine currentColor and font sizing attributes.
  final SvgTheme theme;

  @override
  Future<ByteData> loadBytes(BuildContext context) async {
    return await _computeImpl((_) async {
      final Uint8List compiledBytes = await encodeSvg(
        xml: utf8.decode(svg),
        theme: theme,
        debugName: 'Svg loader',
        enableClippingOptimizer: false,
        enableMaskingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
      return compiledBytes.buffer.asByteData();
    }, null, debugLabel: 'Load Bytes');
  }
}

/// A [BytesLoader] that decodes SVG data from a file in an isolate and creates
/// a vector_graphics binary representation.
class SvgFileLoader extends BytesLoader {
  /// See class doc.
  const SvgFileLoader(
    this.file, {
    this.theme = const SvgTheme(),
  });

  /// The file containing the SVG data to decode and render.
  final File file;

  /// The theme to determine currentColor and font sizing attributes.
  final SvgTheme theme;

  @override
  Future<ByteData> loadBytes(BuildContext context) async {
    final Uint8List bytes = file.readAsBytesSync();

    return await _computeImpl((_) async {
      final Uint8List compiledBytes = await encodeSvg(
        xml: utf8.decode(bytes),
        theme: theme,
        debugName: file.path,
        enableClippingOptimizer: false,
        enableMaskingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
      return compiledBytes.buffer.asByteData();
    }, null, debugLabel: 'Load Bytes');
  }
}

/// A [BytesLoader] that decodes and parses an SVG asset in an isolate and
/// creates a vector_graphics binary representation.
class SvgAssetLoader extends BytesLoader {
  /// See class doc.
  const SvgAssetLoader(
    this.assetName, {
    this.packageName,
    this.assetBundle,
    this.theme = const SvgTheme(),
  });

  /// The name of the asset, e.g. foo.svg.
  final String assetName;

  /// The package containing the asset.
  final String? packageName;

  /// The asset bundle to use, or [DefaultAssetBundle] if null.
  final AssetBundle? assetBundle;

  /// The theme to determine currentColor and font sizing attributes.
  final SvgTheme theme;

  @override
  Future<ByteData> loadBytes(BuildContext context) async {
    final ByteData bytes =
        await (assetBundle ?? DefaultAssetBundle.of(context)).load(assetName);

    return await _computeImpl((_) async {
      final Uint8List compiledBytes = await encodeSvg(
        xml: utf8.decode(bytes.buffer.asUint8List()),
        theme: theme,
        debugName: assetName,
        enableClippingOptimizer: false,
        enableMaskingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
      return compiledBytes.buffer.asByteData();
    }, null, debugLabel: 'Load Bytes');
  }

  @override
  int get hashCode => Object.hash(assetName, packageName, assetBundle);

  @override
  bool operator ==(Object other) {
    return other is SvgAssetLoader &&
        other.assetName == assetName &&
        other.packageName == packageName &&
        other.assetBundle == assetBundle;
  }
}

/// A [BytesLoader] that decodes and parses a UTF-8 encoded SVG string the
/// network in an isolate and creates a vector_graphics binary representation.
class SvgNetworkLoader extends BytesLoader {
  /// See class doc.
  const SvgNetworkLoader(
    this.url, {
    this.headers,
    this.theme = const SvgTheme(),
  });

  /// The [Uri] encoded resource address.
  final String url;

  /// Optional HTTP headers to send as part of the request.
  final Map<String, String>? headers;

  /// The theme to determine currentColor and font sizing attributes.
  final SvgTheme theme;

  @override
  Future<ByteData> loadBytes(BuildContext context) async {
    return await _computeImpl((String svgUrl) async {
      final Uint8List bytes = await httpGet(svgUrl, headers: headers);
      final Uint8List compiledBytes = await encodeSvg(
        xml: utf8.decode(bytes),
        theme: theme,
        debugName: svgUrl,
        enableClippingOptimizer: false,
        enableMaskingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
      return compiledBytes.buffer.asByteData();
    }, url, debugLabel: 'Load Bytes');
  }

  @override
  int get hashCode => Object.hash(url, headers);

  @override
  bool operator ==(Object other) {
    return other is SvgNetworkLoader &&
        other.url == url &&
        other.headers == headers;
  }
}
