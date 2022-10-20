import 'dart:convert' show utf8;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/src/utilities/http.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

final ComputeImpl _computeImpl = Platform.executable.endsWith('flutter_tester')
    ? <Q, R>(ComputeCallback<Q, R> callback, Q message,
            {String? debugLabel}) async =>
        await callback(message)
    : compute;

class SvgStringLoader extends BytesLoader {
  const SvgStringLoader(
    this.svg, {
    this.theme = const SvgTheme(),
  });

  final String svg;
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

class SvgBytesLoader extends BytesLoader {
  const SvgBytesLoader(
    this.svg, {
    this.theme = const SvgTheme(),
  });

  final Uint8List svg;
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

class SvgFileLoader extends BytesLoader {
  const SvgFileLoader(
    this.file, {
    this.theme = const SvgTheme(),
  });

  final File file;
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

class SvgAssetLoader extends BytesLoader {
  const SvgAssetLoader(
    this.assetName, {
    this.packageName,
    this.assetBundle,
    this.theme = const SvgTheme(),
  });

  final String assetName;
  final String? packageName;
  final AssetBundle? assetBundle;
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

class SvgNetworkLoader extends BytesLoader {
  const SvgNetworkLoader(
    this.url, {
    this.headers,
    this.theme = const SvgTheme(),
  });

  final String url;
  final Map<String, String>? headers;
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
