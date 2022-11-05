import 'dart:convert' show utf8;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/src/utilities/http.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

import 'utilities/compute.dart';
import 'utilities/file.dart';

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
  Future<ByteData> loadBytes(BuildContext? context) async {
    return await compute((String svg) async {
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
  Future<ByteData> loadBytes(BuildContext? context) async {
    return await compute((_) async {
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
  Future<ByteData> loadBytes(BuildContext? context) async {
    return await compute((File file) async {
      final Uint8List bytes = file.readAsBytesSync();
      final Uint8List compiledBytes = await encodeSvg(
        xml: utf8.decode(bytes),
        theme: theme,
        debugName: file.path,
        enableClippingOptimizer: false,
        enableMaskingOptimizer: false,
        enableOverdrawOptimizer: false,
      );
      return compiledBytes.buffer.asByteData();
    }, file, debugLabel: 'Load Bytes');
  }
}

// Replaces the cache key for [AssetBytesLoader] to account for the fact that
// different widgets may select a different asset bundle based on the return
// value of `DefaultAssetBundle.of(context)`.
@immutable
class _AssetByteLoaderCacheKey {
  const _AssetByteLoaderCacheKey(
    this.assetName,
    this.packageName,
    this.assetBundle,
  );

  final String assetName;
  final String? packageName;

  final AssetBundle assetBundle;

  @override
  int get hashCode => Object.hash(assetName, packageName, assetBundle);

  @override
  bool operator ==(Object other) {
    return other is _AssetByteLoaderCacheKey &&
        other.assetName == assetName &&
        other.assetBundle == assetBundle &&
        other.packageName == packageName;
  }

  @override
  String toString() =>
      'VectorGraphicAsset(${packageName != null ? '$packageName/' : ''}$assetName)';
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

  AssetBundle _resolveBundle(BuildContext? context) {
    if (assetBundle != null) {
      return assetBundle!;
    }
    if (context != null) {
      return DefaultAssetBundle.of(context);
    }
    return rootBundle;
  }

  @override
  Future<ByteData> loadBytes(BuildContext? context) async {
    final ByteData bytes = await _resolveBundle(context).load(assetName);

    return await compute((_) async {
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
  Object cacheKey(BuildContext? context) {
    return _AssetByteLoaderCacheKey(
      assetName,
      packageName,
      _resolveBundle(context),
    );
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
  Future<ByteData> loadBytes(BuildContext? context) async {
    return await compute((String svgUrl) async {
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
