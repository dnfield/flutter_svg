import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Image;

import 'src/vector_drawable.dart';
import 'src/vector_painter.dart';

enum PaintLocation { Foreground, Background }

/// Handles rendering the [DrawableRoot] from `future` to a [Canvas].
///
/// To control the coordinate space, use the `size` parameter. In most
/// contexts, you should prefer keeping `clipToViewBox` as true to avoid
/// potentially drawing outside the bounds of the canvas.  By default,
/// this will draw to the background (meaning the child widget will be
/// rendered after drawing).  You can change that by specifying
/// `PaintLocation.Foreground`.
///
/// By default, a [LimitedBox] will be rendered while the `future` is resolving.
/// This can be replaced by specifying `loadingPlaceholderBuilder`, and is
/// especially useful if you're loading a network asset.
///
/// By default, an [ErrorWidget] will be rendered if an error occurs. This
/// can be replace with a custom [ErrorWidgetBuilder] to taste.
class VectorDrawablePainter extends StatelessWidget {
  static final WidgetBuilder defaultPlaceholderBuilder =
      (BuildContext ctx) => const LimitedBox();

  /// The size of the coordinate space to render this image in.
  final Size size;

  /// The [Future] that resolves the drawing content.
  final Future<DrawableRoot> future;

  /// Whether to allow drawing outside of the canvas or not.  Defaults to
  /// true.
  final bool clipToViewBox;

  /// Whether to draw before or after child content.  Defaults to background
  /// (before).
  final PaintLocation paintLocation;

  /// [ErrorWidgetBuilder] to specify what to render if an exception is thrown.
  final ErrorWidgetBuilder errorWidgetBuilder;

  /// [WidgetBuilder] to use while the [future] is resolving.
  final WidgetBuilder loadingPlaceholderBuilder;

  /// Child content for this widget.
  final Widget child;

  const VectorDrawablePainter(this.future, this.size,
      {this.clipToViewBox = true,
      Key key,
      this.paintLocation = PaintLocation.Background,
      this.errorWidgetBuilder,
      this.loadingPlaceholderBuilder,
      this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ErrorWidgetBuilder localErrorBuilder =
        errorWidgetBuilder ?? ErrorWidget.builder;
    final WidgetBuilder localPlaceholder =
        loadingPlaceholderBuilder ?? defaultPlaceholderBuilder;
    return new FutureBuilder<DrawableRoot>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<DrawableRoot> snapShot) {
        if (snapShot.hasError) {
          return localErrorBuilder(new FlutterErrorDetails(
            context: 'SVG Rendering',
            exception: snapShot.error,
            library: 'flutter_svg',
            stack: StackTrace.current,
          ));
        } else if (snapShot.hasData) {
          final CustomPainter painter =
              new VectorPainter(snapShot.data, clipToViewBox: clipToViewBox);
          return new RepaintBoundary.wrap(
              CustomPaint(
                  painter: paintLocation == PaintLocation.Background
                      ? painter
                      : null,
                  foregroundPainter: paintLocation == PaintLocation.Foreground
                      ? painter
                      : null,
                  size: size,
                  isComplex: true,
                  willChange: false,
                  child: child),
              0);
        }
        return localPlaceholder(context);

        // return const LimitedBox();
      },
    );
  }
}

/// Key for the image obtained by an [VectorAssetImage] or [ExactVectorAssetImage].
///
/// This is used to identify the precise resource in the [imageCache].
@immutable
class VectorAssetBundleImageKey {
  /// Creates the key for an [AssetImage] or [AssetBundleImageProvider].
  ///
  /// The arguments must not be null.
  const VectorAssetBundleImageKey({
    @required this.bundle,
    @required this.name,
    @required this.size,
  })  : assert(bundle != null),
        assert(name != null),
        assert(size != null);

  /// The bundle from which the image will be obtained.
  ///
  /// The image is obtained by calling [AssetBundle.load] on the given [bundle]
  /// using the key given by [name].
  final AssetBundle bundle;

  /// The key to use to obtain the resource from the [bundle]. This is the
  /// argument passed to [AssetBundle.load].
  final String name;

  /// The size to render this SVG as.
  final Size size;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final VectorAssetBundleImageKey typedOther = other;
    return bundle == typedOther.bundle &&
        name == typedOther.name &&
        size == typedOther.size;
  }

  @override
  int get hashCode => hashValues(bundle, name, size);

  @override
  String toString() =>
      '$runtimeType(bundle: $bundle, name: "$name", size: $size)';
}

abstract class VectorAssetBundleImageProvider
    extends ImageProvider<VectorAssetBundleImageKey> {
  const VectorAssetBundleImageProvider();

  /// Fetches the image from the asset bundle, decodes it, and returns a
  /// corresponding [ImageInfo] object.
  ///
  /// This function is used by [load].
  @protected
  Future<ImageInfo> loadAsync(VectorAssetBundleImageKey key);

  /// Converts a key into an [ImageStreamCompleter], and begins fetching the
  /// image using [loadAsync].
  @override
  ImageStreamCompleter load(VectorAssetBundleImageKey key) {
    return new OneFrameImageStreamCompleter(loadAsync(key),
        informationCollector: (StringBuffer information) {
      information.writeln('Image provider: $this');
      information.write('Image key: $key');
    });
  }
}
