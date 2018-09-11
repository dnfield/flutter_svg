import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Picture;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter/widgets.dart';
import 'package:xml/xml.dart' hide parse;
import 'package:xml/xml.dart' as xml show parse;

import 'src/picture_provider.dart';
import 'src/picture_stream.dart';
import 'src/render_picture.dart';
import 'src/svg/xml_parsers.dart';
import 'src/svg_parser.dart';
import 'src/vector_drawable.dart';

/// Instance for [Svg]'s utility methods, which can produce a [DrawableRoot]
/// or [PictureInfo] from [String] or [Uint8List].
final Svg svg = new Svg._();

/// A utility class for decoding SVG data to a [DrawableRoot] or a [PictureInfo].
///
/// These methods are used by [SvgPicture], but can also be directly used e.g.
/// to create a [DrawableRoot] you manipulate or render to your own [Canvas].
/// Access to this class is provided by the exported [svg] member.
class Svg {
  Svg._();

  /// Produces a [PictureInfo] from a [Uint8List] of SVG byte data (assumes UTF8 encoding).
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// The `colorFilter` property will be applied to any [Paint] objects used during drawing.
  ///
  /// The [key] will be used for debugging purposes.
  FutureOr<PictureInfo> svgPictureDecoder(
      Uint8List raw,
      bool allowDrawingOutsideOfViewBox,
      ColorFilter colorFilter,
      String key) async {
    final DrawableRoot svgRoot = await fromSvgBytes(raw, key);
    final Picture pic = svgRoot.toPicture(
        clipToViewBox: allowDrawingOutsideOfViewBox == true ? false : true,
        colorFilter: colorFilter);
    return new PictureInfo(picture: pic, viewBox: svgRoot.viewport.rect);
  }

  /// Produces a [PictureInfo] from a [String] of SVG data.
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// The `colorFilter` property will be applied to any [Paint] objects used during drawing.
  ///
  /// The [key] will be used for debugging purposes.
  FutureOr<PictureInfo> svgPictureStringDecoder(String raw,
      bool allowDrawingOutsideOfViewBox, ColorFilter colorFilter, String key) {
    final DrawableRoot svg = fromSvgString(raw, key);
    return new PictureInfo(
        picture: svg.toPicture(
            clipToViewBox: allowDrawingOutsideOfViewBox == true ? false : true,
            colorFilter: colorFilter),
        viewBox: svg.viewport.rect);
  }

  /// Produces a [Drawableroot] from a [Uint8List] of SVG byte data (assumes UTF8 encoding).
  ///
  /// The [key] will be used for debugging purposes.
  FutureOr<DrawableRoot> fromSvgBytes(Uint8List raw, String key) async {
    // TODO - do utf decoding in another thread?
    // Might just have to live with potentially slow(ish) decoding, this is causing errors.
    // See: https://github.com/dart-lang/sdk/issues/31954
    // See: https://github.com/flutter/flutter/blob/bf3bd7667f07709d0b817ebfcb6972782cfef637/packages/flutter/lib/src/services/asset_bundle.dart#L66
    // if (raw.lengthInBytes < 20 * 1024) {
    return fromSvgString(utf8.decode(raw), key);
    // } else {
    //   final String str =
    //       await compute(_utf8Decode, raw, debugLabel: 'UTF8 decode for SVG');
    //   return fromSvgString(str);
    // }
  }

  // String _utf8Decode(Uint8List data) {
  //   return utf8.decode(data);
  // }

  /// Creates a [DrawableRoot] from a string of SVG data.
  ///
  /// The `key` is used for debugging purposes.
  DrawableRoot fromSvgString(String rawSvg, String key) {
    final XmlElement svg = xml.parse(rawSvg).rootElement;
    final DrawableViewport viewBox = parseViewBox(svg);
    //final Map<String, PaintServer> paintServers = <String, PaintServer>{};
    final DrawableDefinitionServer definitions = new DrawableDefinitionServer();
    final DrawableStyle style =
        parseStyle(svg, definitions, viewBox.rect, null);

    final List<Drawable> children = svg.children
        .where((XmlNode child) => child is XmlElement)
        .map(
          (XmlNode child) => parseSvgElement(
                child,
                definitions,
                viewBox.rect,
                style,
                key,
              ),
        )
        .toList();
    return new DrawableRoot(
      viewBox,
      children,
      definitions,
      parseStyle(svg, definitions, viewBox.rect, null),
    );
  }
}

/// A widget that will parse SVG data into a [Picture] using a [PictureProvider].
///
/// The picture will be cached using the [PictureCache], incorporating any color
/// filterting used into the key (meaning the same SVG with two different `color`
/// arguments applied would be two cache entries).
class SvgPicture extends StatefulWidget {
  /// The default placeholder for a SVG that may take time to parse or
  /// retreieve, e.g. from a network location.
  static WidgetBuilder defaultPlaceholderBuilder =
      (BuildContext ctx) => const LimitedBox();

  /// Instantiates a widget that renders an SVG picture using the `pictureProvider`.
  ///
  /// If `width` or `height` are specified, a [SizedBox] will be used to dictate
  /// the width and height of the rendered output.  Otherwise, the picture will
  /// be sized to its parent.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time, e.g. for a network picture.
  const SvgPicture(this.pictureProvider,
      {Key key,
      this.width,
      this.height,
      this.matchTextDirection = false,
      this.allowDrawingOutsideViewBox = false,
      this.placeholderBuilder})
      : super(key: key);

  /// Instantiates a widget that renders an SVG picture from an [AssetBundle].
  ///
  /// The key will be derived from the `assetName`, `package`, and `bundle`
  /// arguments. The `package` argument must be non-null when displaying an SVG
  /// from a package and null otherwise. See the `Assets in packages` section for
  /// details.
  ///
  /// If `width` or `height` are specified, a [SizedBox] will be used to dictate
  /// the width and height of the rendered output.  Otherwise, the picture will
  /// be sized to its parent.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// ## Assets in packages
  ///
  /// To create the widget with an asset from a package, the [package] argument
  /// must be provided. For instance, suppose a package called `my_icons` has
  /// `icons/heart.svg` .
  ///
  /// Then to display the image, use:
  ///
  /// ```dart
  /// new SvgPicture.asset('icons/heart.svg', package: 'my_icons')
  /// ```
  ///
  /// Assets used by the package itself should also be displayed using the
  /// [package] argument as above.
  ///
  /// If the desired asset is specified in the `pubspec.yaml` of the package, it
  /// is bundled automatically with the app. In particular, assets used by the
  /// package itself must be specified in its `pubspec.yaml`.
  ///
  /// A package can also choose to have assets in its 'lib/' folder that are not
  /// specified in its `pubspec.yaml`. In this case for those images to be
  /// bundled, the app has to specify which ones to include. For instance a
  /// package named `fancy_backgrounds` could have:
  ///
  /// ```
  /// lib/backgrounds/background1.svg
  /// lib/backgrounds/background2.svg
  /// lib/backgrounds/background3.svg
  ///```
  ///
  /// To include, say the first image, the `pubspec.yaml` of the app should
  /// specify it in the assets section:
  ///
  /// ```yaml
  ///  assets:
  ///    - packages/fancy_backgrounds/backgrounds/background1.svg
  /// ```
  ///
  /// The `lib/` is implied, so it should not be included in the asset path.
  ///
  ///
  /// See also:
  ///
  ///  * [AssetPicture], which is used to implement the behavior when the scale is
  ///    omitted.
  ///  * [ExactAssetPicture], which is used to implement the behavior when the
  ///    scale is present.
  ///  * <https://flutter.io/assets-and-images/>, an introduction to assets in
  ///    Flutter.
  SvgPicture.asset(String assetName,
      {Key key,
      this.matchTextDirection = false,
      AssetBundle bundle,
      String package,
      this.width,
      this.height,
      this.fit = BoxFit.contain,
      this.alignment = Alignment.center,
      this.allowDrawingOutsideViewBox = false,
      this.placeholderBuilder,
      Color color,
      BlendMode colorBlendMode = BlendMode.srcIn})
      : pictureProvider = new ExactAssetPicture(
            allowDrawingOutsideViewBox == true
                ? svgByteDecoderOutsideViewBox
                : svgByteDecoder,
            assetName,
            bundle: bundle,
            package: package,
            colorFilter: _getColorFilter(color, colorBlendMode)),
        super(key: key);

  /// Creates a widget that displays a [PictureStream] obtained from the network.
  ///
  /// The `url` argument must not be null.
  ///
  /// If `width` or `height` are specified, a [SizedBox] will be used to dictate
  /// the width and height of the rendered output.  Otherwise, the picture will
  /// be sized to its parent.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time, such as high latency scenarios.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// All network images are cached regardless of HTTP headers.
  ///
  /// An optional `headers` argument can be used to send custom HTTP headers
  /// with the image request.
  SvgPicture.network(String url,
      {Key key,
      Map<String, String> headers,
      this.width,
      this.height,
      this.fit = BoxFit.contain,
      this.alignment = Alignment.center,
      this.matchTextDirection = false,
      this.allowDrawingOutsideViewBox = false,
      this.placeholderBuilder,
      Color color,
      BlendMode colorBlendMode = BlendMode.srcIn})
      : pictureProvider = new NetworkPicture(
            allowDrawingOutsideViewBox == true
                ? svgByteDecoderOutsideViewBox
                : svgByteDecoder,
            url,
            headers: headers,
            colorFilter: _getColorFilter(color, colorBlendMode)),
        super(key: key);

  /// Creates a widget that displays a [PictureStream] obtained from a [File].
  ///
  /// The [file] argument must not be null.
  ///
  /// If `width` or `height` are specified, a [SizedBox] will be used to dictate
  /// the width and height of the rendered output.  Otherwise, the picture will
  /// be sized to its parent.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  ///
  /// On Android, this may require the
  /// `android.permission.READ_EXTERNAL_STORAGE` permission.
  SvgPicture.file(File file,
      {Key key,
      this.width,
      this.height,
      this.fit = BoxFit.contain,
      this.alignment = Alignment.center,
      this.matchTextDirection = false,
      this.allowDrawingOutsideViewBox = false,
      this.placeholderBuilder,
      Color color,
      BlendMode colorBlendMode = BlendMode.srcIn})
      : pictureProvider = new FilePicture(
            allowDrawingOutsideViewBox == true
                ? svgByteDecoderOutsideViewBox
                : svgByteDecoder,
            file,
            colorFilter: _getColorFilter(color, colorBlendMode)),
        super(key: key);

  /// Creates a widget that displays a [PictureStream] obtained from a [Uint8List].
  ///
  /// The [bytes] argument must not be null.
  ///
  /// If `width` or `height` are specified, a [SizedBox] will be used to dictate
  /// the width and height of the rendered output.  Otherwise, the picture will
  /// be sized to its parent.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  SvgPicture.memory(Uint8List bytes,
      {Key key,
      this.width,
      this.height,
      this.fit = BoxFit.contain,
      this.alignment = Alignment.center,
      this.matchTextDirection = false,
      this.allowDrawingOutsideViewBox = false,
      this.placeholderBuilder,
      Color color,
      BlendMode colorBlendMode = BlendMode.srcIn})
      : pictureProvider = new MemoryPicture(
            allowDrawingOutsideViewBox == true
                ? svgByteDecoderOutsideViewBox
                : svgByteDecoder,
            bytes,
            colorFilter: _getColorFilter(color, colorBlendMode)),
        super(key: key);

  /// Creates a widget that displays a [PictureStream] obtained from a [String].
  ///
  /// The [bytes] argument must not be null.
  ///
  /// If `width` or `height` are specified, a [SizedBox] will be used to dictate
  /// the width and height of the rendered output.  Otherwise, the picture will
  /// be sized to its parent.
  ///
  /// If `matchTextDirection` is set to true, the picture will be flipped
  /// horizontally in [TextDirection.rtl] contexts.
  ///
  /// The `allowDrawingOutsideOfViewBox` parameter should be used with caution -
  /// if set to true, it will not clip the canvas used internally to the view box,
  /// meaning the picture may draw beyond the intended area and lead to undefined
  /// behavior or additional memory overhead.
  ///
  /// A custom `placeholderBuilder` can be specified for cases where decoding or
  /// acquiring data may take a noticeably long time.
  ///
  /// The `color` and `colorBlendMode` arguments, if specified, will be used to set a
  /// [ColorFilter] on any [Paint]s created for this drawing.
  SvgPicture.string(String bytes,
      {Key key,
      this.width,
      this.height,
      this.fit = BoxFit.contain,
      this.alignment = Alignment.center,
      this.matchTextDirection = false,
      this.allowDrawingOutsideViewBox = false,
      this.placeholderBuilder,
      Color color,
      BlendMode colorBlendMode = BlendMode.srcIn})
      : pictureProvider = new StringPicture(
            allowDrawingOutsideViewBox == true
                ? svgStringDecoderOutsideViewBox
                : svgStringDecoder,
            bytes,
            colorFilter: _getColorFilter(color, colorBlendMode)),
        super(key: key);

  static ColorFilter _getColorFilter(Color color, BlendMode colorBlendMode) =>
      color == null
          ? null
          : new ColorFilter.mode(color, colorBlendMode ?? BlendMode.srcIn);

  /// A [PictureInfoDecoder] for [Uint8List]s that will clip to the viewBox.
  static final PictureInfoDecoder<Uint8List> svgByteDecoder =
      (Uint8List bytes, ColorFilter colorFilter, String key) =>
          svg.svgPictureDecoder(bytes, false, colorFilter, key);

  /// A [PictureInfoDecoder] for strings that will clip to the viewBox.
  static final PictureInfoDecoder<String> svgStringDecoder =
      (String data, ColorFilter colorFilter, String key) =>
          svg.svgPictureStringDecoder(data, false, colorFilter, key);

  /// A [PictureInfoDecoder] for [Uint8List]s that will not clip to the viewBox.
  static final PictureInfoDecoder<Uint8List> svgByteDecoderOutsideViewBox =
      (Uint8List bytes, ColorFilter colorFilter, String key) =>
          svg.svgPictureDecoder(bytes, true, colorFilter, key);

  /// A [PictureInfoDecoder] for [String]s that will not clip to the viewBox.
  static final PictureInfoDecoder<String> svgStringDecoderOutsideViewBox =
      (String data, ColorFilter colorFilter, String key) =>
          svg.svgPictureStringDecoder(data, true, colorFilter, key);

  /// If specified, the width to use for the SVG.  If unspecified, the SVG
  /// will take the width of its parent.
  final double width;

  /// If specified, the height to use for the SVG.  If unspecified, the SVG
  /// will take the height of its parent.
  final double height;

  final BoxFit fit;

  final Alignment alignment;

  /// The [PictureProvider] used to resolve the SVG.
  final PictureProvider pictureProvider;

  /// The placeholder to use while fetching, decoding, and parsing the SVG data.
  final WidgetBuilder placeholderBuilder;

  /// If true, will horizontally flip the picture in [TextDirection.rtl] contexts.
  final bool matchTextDirection;

  /// If true, will allow the SVG to be drawn outside of the clip boundary of its
  /// viewBox.
  final bool allowDrawingOutsideViewBox;

  @override
  State<SvgPicture> createState() => new _SvgPictureState();
}

class _SvgPictureState extends State<SvgPicture> {
  PictureInfo _picture;
  PictureStream _pictureStream;
  bool _isListeningToStream = false;

  @override
  void didChangeDependencies() {
    _resolveImage();

    if (TickerMode.of(context)) {
      _listenToStream();
    } else {
      _stopListeningToStream();
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(SvgPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pictureProvider != oldWidget.pictureProvider) {
      _resolveImage();
    }
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    final PictureStream newStream = widget.pictureProvider
        .resolve(createLocalPictureConfiguration(context));
    assert(newStream != null);
    _updateSourceStream(newStream);
  }

  void _handleImageChanged(PictureInfo imageInfo, bool synchronousCall) {
    setState(() {
      _picture = imageInfo;
    });
  }

  // Update _pictureStream to newStream, and moves the stream listener
  // registration from the old stream to the new stream (if a listener was
  // registered).
  void _updateSourceStream(PictureStream newStream) {
    if (_pictureStream?.key == newStream?.key) {
      return;
    }

    if (_isListeningToStream)
      _pictureStream.removeListener(_handleImageChanged);

    _pictureStream = newStream;
    if (_isListeningToStream) {
      _pictureStream.addListener(_handleImageChanged);
    }
  }

  void _listenToStream() {
    if (_isListeningToStream) {
      return;
    }
    _pictureStream.addListener(_handleImageChanged);
    _isListeningToStream = true;
  }

  void _stopListeningToStream() {
    if (!_isListeningToStream) {
      return;
    }
    _pictureStream.removeListener(_handleImageChanged);
    _isListeningToStream = false;
  }

  @override
  void dispose() {
    assert(_pictureStream != null);
    _stopListeningToStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_picture != null) {
      Widget picture = new RawPicture(
        _picture,
        matchTextDirection: widget.matchTextDirection,
        allowDrawingOutsideViewBox: widget.allowDrawingOutsideViewBox,
      );
      picture = new SizedBox.fromSize(size: _picture.viewBox.size, child: picture);
      double width = widget.width;
      double height = widget.height;
      if (width == null && height == null) {
        return picture;
      }

      if (height != null) {
        width = height / _picture.viewBox.height * _picture.viewBox.width;
      } else if (width != null) {
        height = width / _picture.viewBox.width * _picture.viewBox.height;
      }
      picture = new FittedBox(fit: widget.fit, alignment:  widget.alignment, child: picture);

      return new SizedBox(width: width, height: height, child: picture);
    }

    return widget.placeholderBuilder == null
        ? _getDefaultPlaceholder(context, widget.width, widget.height)
        : widget.placeholderBuilder(context);
  }

  Widget _getDefaultPlaceholder(
      BuildContext context, double width, double height) {
    if (width != null || height != null) {
      return new SizedBox(width: width, height: height);
    }

    return SvgPicture.defaultPlaceholderBuilder(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description
        .add(new DiagnosticsProperty<PictureStream>('stream', _pictureStream));
  }
}
