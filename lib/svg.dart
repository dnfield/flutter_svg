import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/services.dart' show rootBundle, AssetBundle;
import 'package:flutter/widgets.dart';
import 'package:xml/xml.dart' hide parse;
import 'package:xml/xml.dart' as xml show parse;

import 'src/svg/xml_parsers.dart';
import 'src/svg_parser.dart';
import 'src/vector_drawable.dart';
import 'vector_drawable.dart';

/// Extends [VectorDrawableImage] to parse SVG data to [Drawable].
class SvgPainter extends VectorDrawablePainter {
  const SvgPainter._(Future<DrawableRoot> future, Size size,
      {bool clipToViewBox,
      Key key,
      Widget child,
      PaintLocation paintLocation,
      ErrorWidgetBuilder errorWidgetBuilder,
      WidgetBuilder loadingPlaceholderBuilder})
      : super(future, size,
            clipToViewBox: clipToViewBox,
            child: child,
            key: key,
            paintLocation: paintLocation,
            errorWidgetBuilder: errorWidgetBuilder,
            loadingPlaceholderBuilder: loadingPlaceholderBuilder);

  factory SvgPainter.fromString(String svg, Size size,
      {Key key,
      bool clipToViewBox = true,
      PaintLocation paintLocation = PaintLocation.Background,
      Widget child,
      ErrorWidgetBuilder errorWidgetBuilder,
      WidgetBuilder loadingPlaceholderBuilder}) {
    return new SvgPainter._(
      new Future<DrawableRoot>.value(fromSvgString(svg, size)),
      size,
      clipToViewBox: clipToViewBox,
      child: child,
      key: key,
      paintLocation: paintLocation,
      errorWidgetBuilder: errorWidgetBuilder,
      loadingPlaceholderBuilder: loadingPlaceholderBuilder,
    );
  }

  /// Creates an [SvgImage] from a bundled asset (possibly from a [package]).
  factory SvgPainter.asset(String assetName, Size size,
      {Key key,
      AssetBundle bundle,
      String package,
      bool clipToViewBox = true,
      PaintLocation paintLocation = PaintLocation.Background,
      Widget child,
      ErrorWidgetBuilder errorWidgetBuilder,
      WidgetBuilder loadingPlaceholderBuilder}) {
    return new SvgPainter._(
      loadAsset(assetName, size, bundle: bundle, package: package),
      size,
      clipToViewBox: clipToViewBox,
      child: child,
      key: key,
      paintLocation: paintLocation,
      errorWidgetBuilder: errorWidgetBuilder,
      loadingPlaceholderBuilder: loadingPlaceholderBuilder,
    );
  }

  /// Creates an [SvgImage] from a HTTP [uri].
  factory SvgPainter.network(String uri, Size size,
      {Map<String, String> headers,
      Key key,
      bool clipToViewBox = true,
      Widget child,
      PaintLocation paintLocation = PaintLocation.Background,
      ErrorWidgetBuilder errorWidgetBuilder,
      WidgetBuilder loadingPlaceholderBuilder}) {
    return new SvgPainter._(
      loadNetworkAsset(uri, size),
      size,
      clipToViewBox: clipToViewBox,
      child: child,
      key: key,
      paintLocation: paintLocation,
      errorWidgetBuilder: errorWidgetBuilder,
      loadingPlaceholderBuilder: loadingPlaceholderBuilder,
    );
  }
}

/// Creates a [DrawableRoot] from a string of SVG data.  [size] specifies the
/// size of the coordinate space to draw to.
DrawableRoot fromSvgString(String rawSvg, Size size) {
  final XmlElement svg = xml.parse(rawSvg).rootElement;
  final Rect viewBox = parseViewBox(svg);
  //final Map<String, PaintServer> paintServers = <String, PaintServer>{};
  final DrawableDefinitionServer definitions = new DrawableDefinitionServer();
  final DrawableStyle style = parseStyle(svg, definitions, viewBox, null);

  final List<Drawable> children = svg.children
      .where((XmlNode child) => child is XmlElement)
      .map(
        (XmlNode child) => parseSvgElement(
              child,
              definitions,
              new Rect.fromPoints(
                Offset.zero,
                new Offset(size.width, size.height),
              ),
              style,
            ),
      )
      .toList();
  return new DrawableRoot(
    viewBox,
    children,
    definitions,
    parseStyle(svg, definitions, viewBox, null),
  );
}

class SvgExactAssetImage extends VectorAssetBundleImageProvider {
  /// Creates an object that fetches the given image from an asset bundle.
  ///
  /// The [assetName] and [size] arguments must not be null. The [bundle] argument
  /// may be null, in which case the bundle provided in the [ImageConfiguration] p
  /// assed to the [resolve] call will be used instead.
  ///
  /// The [package] argument must be non-null when fetching an asset that is
  /// included in a package. See the documentation for the [ExactAssetImage] class
  /// itself for details.
  const SvgExactAssetImage(
    this.assetName,
    this.size, {
    this.bundle,
    this.package,
  })  : assert(assetName != null),
        assert(size != null);

  /// The name of the asset.
  final String assetName;

  /// The size to render this asset to.
  final Size size;

  /// The key to use to obtain the resource from the [bundle]. This is the
  /// argument passed to [AssetBundle.load].
  String get keyName =>
      package == null ? assetName : 'packages/$package/$assetName';

  /// The bundle from which the image will be obtained.
  ///
  /// If the provided [bundle] is null, the bundle provided in the
  /// [ImageConfiguration] passed to the [resolve] call will be used instead. If
  /// that is also null, the [rootBundle] is used.
  ///
  /// The image is obtained by calling [AssetBundle.load] on the given [bundle]
  /// using the key given by [keyName].
  final AssetBundle bundle;

  /// The name of the package from which the image is included. See the
  /// documentation for the [ExactAssetImage] class itself for details.
  final String package;

  @override
  Future<VectorAssetBundleImageKey> obtainKey(
      ImageConfiguration configuration) {
    return new SynchronousFuture<VectorAssetBundleImageKey>(
        new VectorAssetBundleImageKey(
            bundle: bundle ?? configuration.bundle ?? rootBundle,
            size: size,
            name: keyName));
  }

  /// Fetches the image from the asset bundle, decodes it, and returns a
  /// corresponding [ImageInfo] object.
  ///
  /// This function is used by [load].
  @override
  @protected
  Future<ImageInfo> loadAsync(VectorAssetBundleImageKey key) async {
    final DrawableRoot svg =
        await loadAsset(key.name, key.size, bundle: key.bundle);
    if (svg == null) {
      throw 'Unable to read data';
    }

    final ui.Image img = svg.toImage(key.size);
    return new ImageInfo(image: img);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final SvgExactAssetImage typedOther = other;
    return keyName == typedOther.keyName &&
        size == typedOther.size &&
        bundle == typedOther.bundle;
  }

  @override
  int get hashCode => hashValues(keyName, size, bundle);

  @override
  String toString() =>
      '$runtimeType(name: "$keyName", size: $size, bundle: $bundle)';
}

/// Creates a [DrawableRoot] from a bundled asset.  [size] specifies the size
/// of the coordinate space to draw to.
Future<DrawableRoot> loadAsset(String assetName, Size size,
    {AssetBundle bundle, String package}) async {
  bundle ??= rootBundle;
  final String rawSvg = await bundle.loadString(
    package == null ? assetName : 'packages/$package/$assetName',
  );
  return fromSvgString(rawSvg, size);
}

final HttpClient _httpClient = new HttpClient();

/// Creates a [DrawableRoot] from a network asset with an HTTP get request.
/// [size] specifies the size of the coordinate space to draw to.
Future<DrawableRoot> loadNetworkAsset(String url, Size size) async {
  final Uri uri = Uri.base.resolve(url);
  final HttpClientRequest request = await _httpClient.getUrl(uri);
  final HttpClientResponse response = await request.close();

  if (response.statusCode != HttpStatus.OK) {
    throw new HttpException('Could not get network SVG asset', uri: uri);
  }
  final String rawSvg = await _consolidateHttpClientResponse(response);

  return fromSvgString(rawSvg, size);
}

Future<String> _consolidateHttpClientResponse(
    HttpClientResponse response) async {
  final Completer<String> completer = new Completer<String>.sync();
  final StringBuffer buffer = new StringBuffer();

  response.transform(utf8.decoder).listen((String chunk) {
    buffer.write(chunk);
  }, onDone: () {
    completer.complete(buffer.toString());
  }, onError: completer.completeError, cancelOnError: true);

  return completer.future;
}
