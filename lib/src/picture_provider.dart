// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'
    show BlendMode, Color, ColorFilter, Locale, Rect, TextDirection, hashValues;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, DefaultAssetBundle, Directionality, Localizations;

import 'picture_cache.dart';
import 'picture_stream.dart';

typedef FutureOr<PictureInfo> PictureInfoDecoder<T>(
    T data, ColorFilter colorFilter, String key);

/// Creates an [PictureConfiguration] based on the given [BuildContext] (and
/// optionally size).
///
/// This is the object that must be passed to [PictureProvider.resolve].
///
/// If this is not called from a build method, then it should be reinvoked
/// whenever the dependencies change, e.g. by calling it from
/// [State.didChangeDependencies], so that any changes in the environment are
/// picked up (e.g. if the device pixel ratio changes).
///
/// See also:
///
///  * [PictureProvider], which has an example showing how this might be used.
PictureConfiguration createLocalPictureConfiguration(BuildContext context,
    {Rect viewBox, Color color, BlendMode colorBlendMode}) {
  return new PictureConfiguration(
    bundle: DefaultAssetBundle.of(context),
    locale: Localizations.localeOf(context, nullOk: true),
    textDirection: Directionality.of(context),
    viewBox: viewBox,
    platform: defaultTargetPlatform,
    colorFilter: ColorFilter.mode(color, colorBlendMode ?? BlendMode.srcIn),
  );
}

/// Configuration information passed to the [PictureProvider.resolve] method to
/// select a specific picture.
///
/// See also:
///
///  * [createLocalPictureConfiguration], which creates an [PictureConfiguration]
///    based on ambient configuration in a [Widget] environment.
///  * [PictureProvider], which uses [PictureConfiguration] objects to determine
///    which picture to obtain.
@immutable
class PictureConfiguration {
  /// Creates an object holding the configuration information for an [PictureProvider].
  ///
  /// All the arguments are optional. Configuration information is merely
  /// advisory and best-effort.
  const PictureConfiguration({
    this.bundle,
    this.locale,
    this.textDirection,
    this.viewBox,
    this.platform,
    this.colorFilter,
  });

  /// Creates an object holding the configuration information for an [PictureProvider].
  ///
  /// All the arguments are optional. Configuration information is merely
  /// advisory and best-effort.
  PictureConfiguration copyWith({
    AssetBundle bundle,
    Locale locale,
    TextDirection textDirection,
    Rect viewBox,
    String platform,
    ColorFilter colorFilter,
  }) {
    return new PictureConfiguration(
      bundle: bundle ?? this.bundle,
      locale: locale ?? this.locale,
      textDirection: textDirection ?? this.textDirection,
      viewBox: viewBox ?? this.viewBox,
      platform: platform ?? this.platform,
      colorFilter: colorFilter ?? this.colorFilter,
    );
  }

  /// The preferred [AssetBundle] to use if the [PictureProvider] needs one and
  /// does not have one already selected.
  final AssetBundle bundle;

  /// The language and region for which to select the picture.
  final Locale locale;

  /// The reading direction of the language for which to select the picture.
  final TextDirection textDirection;

  /// The size at which the picture will be rendered.
  final Rect viewBox;

  /// The [TargetPlatform] for which assets should be used. This allows pictures
  /// to be specified in a platform-neutral fashion yet use different assets on
  /// different platforms, to match local conventions e.g. for color matching or
  /// shadows.
  final TargetPlatform platform;

  /// The [ColorFilter], if any, that was applied to the drawing.
  final ColorFilter colorFilter;

  /// a picture configuration that provides no additional information.
  ///
  /// Useful when resolving an [PictureProvider] without any context.
  static const PictureConfiguration empty = const PictureConfiguration();

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final PictureConfiguration typedOther = other;
    return typedOther.bundle == bundle &&
        typedOther.locale == locale &&
        typedOther.textDirection == textDirection &&
        typedOther.viewBox == viewBox &&
        typedOther.platform == platform &&
        typedOther.colorFilter == colorFilter;
  }

  @override
  int get hashCode =>
      hashValues(bundle, locale, viewBox, platform, colorFilter);

  @override
  String toString() {
    final StringBuffer result = new StringBuffer();
    result.write('PictureConfiguration(');
    bool hasArguments = false;
    if (bundle != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('bundle: $bundle');
      hasArguments = true;
    }
    if (locale != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('locale: $locale');
      hasArguments = true;
    }
    if (textDirection != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('textDirection: $textDirection');
      hasArguments = true;
    }
    if (viewBox != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('viewBox: $viewBox');
      hasArguments = true;
    }
    if (platform != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('platform: ${describeEnum(platform)}');
      hasArguments = true;
    }
    if (colorFilter != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('colorFilter: $colorFilter');
      hasArguments = true;
    }
    result.write(')');
    return result.toString();
  }
}

// TODO: allow other people to implement this.
PictureCache _cache = new PictureCache();

/// Identifies a picture without committing to the precise final asset. This
/// allows a set of pictures to be identified and for the precise picture to later
/// be resolved based on the environment, e.g. the device pixel ratio.
///
/// To obtain an [PictureStream] from an [PictureProvider], call [resolve],
/// passing it an [PictureConfiguration] object.
///
/// [PictureProvider] uses the global [pictureCache] to cache pictures.
///
/// The type argument `T` is the type of the object used to represent a resolved
/// configuration. This is also the type used for the key in the picture cache. It
/// should be immutable and implement the [==] operator and the [hashCode]
/// getter. Subclasses should subclass a variant of [PictureProvider] with an
/// explicit `T` type argument.
///
/// The type argument does not have to be specified when using the type as an
/// argument (where any Picture provider is acceptable).
///
/// The following picture formats are supported: {@macro flutter.dart:ui.pictureFormats}
///
/// ## Sample code
///
/// The following shows the code required to write a widget that fully conforms
/// to the [PictureProvider] and [Widget] protocols. (It is essentially a
/// bare-bones version of the [widgets.Picture] widget.)
///
/// ```dart
/// class MyPicture extends StatefulWidget {
///   const MyPicture({
///     Key key,
///     @required this.PictureProvider,
///   }) : assert(PictureProvider != null),
///        super(key: key);
///
///   final PictureProvider PictureProvider;
///
///   @override
///   _MyPictureState createState() => new _MyPictureState();
/// }
///
/// class _MyPictureState extends State<MyPicture> {
///   PictureStream _PictureStream;
///   PictureInfo _pictureInfo;
///
///   @override
///   void didChangeDependencies() {
///     super.didChangeDependencies();
///     // We call _getPicture here because createLocalPictureConfiguration() needs to
///     // be called again if the dependencies changed, in case the changes relate
///     // to the DefaultAssetBundle, MediaQuery, etc, which that method uses.
///     _getPicture();
///   }
///
///   @override
///   void didUpdateWidget(MyPicture oldWidget) {
///     super.didUpdateWidget(oldWidget);
///     if (widget.PictureProvider != oldWidget.PictureProvider)
///       _getPicture();
///   }
///
///   void _getPicture() {
///     final PictureStream oldPictureStream = _PictureStream;
///     _PictureStream = widget.PictureProvider.resolve(createLocalPictureConfiguration(context));
///     if (_PictureStream.key != oldPictureStream?.key) {
///       // If the keys are the same, then we got the same picture back, and so we don't
///       // need to update the listeners. If the key changed, though, we must make sure
///       // to switch our listeners to the new picture stream.
///       oldPictureStream?.removeListener(_updatePicture);
///       _PictureStream.addListener(_updatePicture);
///     }
///   }
///
///   void _updatePicture(PictureInfo pictureInfo, bool synchronousCall) {
///     setState(() {
///       // Trigger a build whenever the picture changes.
///       _pictureInfo = pictureInfo;
///     });
///   }
///
///   @override
///   void dispose() {
///     _PictureStream.removeListener(_updatePicture);
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return new RawPicture(
///       picture: _pictureInfo?.picture, // this is a dart:ui Picture object
///       scale: _pictureInfo?.scale ?? 1.0,
///     );
///   }
/// }
/// ```
@optionalTypeArgs
abstract class PictureProvider<T> {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const PictureProvider();

  /// Resolves this Picture provider using the given `configuration`, returning
  /// an [PictureStream].
  ///
  /// This is the public entry-point of the [PictureProvider] class hierarchy.
  ///
  /// Subclasses should implement [obtainKey] and [load], which are used by this
  /// method.
  PictureStream resolve(PictureConfiguration picture) {
    // assert(picture != null);
    final PictureStream stream = new PictureStream();
    T obtainedKey;
    obtainKey().then<void>((T key) {
      obtainedKey = key;
      stream.setCompleter(_cache.putIfAbsent(key, () => load(key)));
    }).catchError((dynamic exception, StackTrace stack) async {
      FlutterError.reportError(new FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: 'while resolving a picture',
          silent: true, // could be a network error or whatnot
          informationCollector: (StringBuffer information) {
            information.writeln('Picture provider: $this');
            if (obtainedKey != null)
              information.writeln('Picture key: $obtainedKey');
          }));
      return null;
    });
    return stream;
  }

  /// Converts a pictureProvider's settings plus a pictureConfiguration to a key
  /// that describes the precise picture to load.
  ///
  /// The type of the key is determined by the subclass. It is a value that
  /// unambiguously identifies the picture (_including its scale_) that the [load]
  /// method will fetch. Different [PictureProvider]s given the same constructor
  /// arguments and [PictureConfiguration] objects should return keys that are
  /// '==' to each other (possibly by using a class for the key that itself
  /// implements [==]).
  @protected
  Future<T> obtainKey();

  /// Converts a key into an [PictureStreamCompleter], and begins fetching the
  /// picture.
  @protected
  PictureStreamCompleter load(T key);

  @override
  String toString() => '$runtimeType()';
}

/// Key for the picture obtained by an [AssetPicture] or [ExactAssetPicture].
///
/// This is used to identify the precise resource in the [pictureCache].
@immutable
class AssetBundlePictureKey {
  /// Creates the key for an [AssetPicture] or [AssetBundlePictureProvider].
  ///
  /// The arguments must not be null.
  const AssetBundlePictureKey(
      {@required this.bundle, @required this.name, this.colorFilter})
      : assert(bundle != null),
        assert(name != null);

  /// The bundle from which the picture will be obtained.
  ///
  /// The picture is obtained by calling [AssetBundle.load] on the given [bundle]
  /// using the key given by [name].
  final AssetBundle bundle;

  /// The key to use to obtain the resource from the [bundle]. This is the
  /// argument passed to [AssetBundle.load].
  final String name;

  /// The [ColorFilter], if any, to be applied to the drawing.
  final ColorFilter colorFilter;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final AssetBundlePictureKey typedOther = other;
    return bundle == typedOther.bundle &&
        name == typedOther.name &&
        colorFilter == typedOther.colorFilter;
  }

  @override
  int get hashCode => hashValues(bundle, name, colorFilter);

  @override
  String toString() =>
      '$runtimeType(bundle: $bundle, name: "$name", colorFilter: $colorFilter)';
}

/// A subclass of [PictureProvider] that knows about [AssetBundle]s.
///
/// This factors out the common logic of [AssetBundle]-based [PictureProvider]
/// classes, simplifying what subclasses must implement to just [obtainKey].
abstract class AssetBundlePictureProvider
    extends PictureProvider<AssetBundlePictureKey> {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const AssetBundlePictureProvider(this.decoder) : assert(decoder != null);

  final PictureInfoDecoder<Uint8List> decoder;

  /// Converts a key into an [PictureStreamCompleter], and begins fetching the
  /// picture using [_loadAsync].
  @override
  PictureStreamCompleter load(AssetBundlePictureKey key) {
    return new OneFramePictureStreamCompleter(_loadAsync(key),
        informationCollector: (StringBuffer information) {
      information.writeln('Picture provider: $this');
      information.write('Picture key: $key');
    });
  }

  /// Fetches the picture from the asset bundle, decodes it, and returns a
  /// corresponding [PictureInfo] object.
  ///
  /// This function is used by [load].
  @protected
  Future<PictureInfo> _loadAsync(AssetBundlePictureKey key) async {
    final ByteData data = await key.bundle.load(key.name);
    if (data == null) {
      throw 'Unable to read data';
    }

    return await decoder(
        data.buffer.asUint8List(), key.colorFilter, key.toString());
  }
}

final HttpClient _httpClient = new HttpClient();

/// Fetches the given URL from the network, associating it with the given scale.
///
/// The picture will be cached regardless of cache headers from the server.
///
/// See also:
///
///  * [SvgPicture.network] for a shorthand of an [SvgPicture] widget backed by [NetworkPicture].
// TODO(ianh): Find some way to honour cache headers to the extent that when the
// last reference to a picture is released, we proactively evict the picture from
// our cache if the headers describe the picture as having expired at that point.
class NetworkPicture extends PictureProvider<NetworkPicture> {
  /// Creates an object that fetches the picture at the given URL.
  ///
  /// The arguments must not be null.
  const NetworkPicture(this.decoder, this.url, {this.headers, this.colorFilter})
      : assert(url != null);

  final PictureInfoDecoder<Uint8List> decoder;

  /// The URL from which the picture will be fetched.
  final String url;

  /// The HTTP headers that will be used with [HttpClient.get] to fetch picture from network.
  final Map<String, String> headers;

  /// The [ColorFilter], if any, to apply to the drawing.
  final ColorFilter colorFilter;

  @override
  Future<NetworkPicture> obtainKey() {
    return new SynchronousFuture<NetworkPicture>(this);
  }

  @override
  PictureStreamCompleter load(NetworkPicture key) {
    return new OneFramePictureStreamCompleter(_loadAsync(key),
        informationCollector: (StringBuffer information) {
      information.writeln('Picture provider: $this');
      information.write('Picture key: $key');
    });
  }

  Future<PictureInfo> _loadAsync(NetworkPicture key) async {
    assert(key == this);
    final Uri uri = Uri.base.resolve(url);
    final HttpClientRequest request = await _httpClient.getUrl(uri);
    if (headers != null) {
      headers.forEach((String key, String value) {
        request.headers.add(key, value);
      });
    }
    final HttpClientResponse response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw new HttpException('Could not get network asset', uri: uri);
    }
    final Uint8List bytes = await consolidateHttpClientResponseBytes(response);

    return await decoder(bytes, colorFilter, key.toString());
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final NetworkPicture typedOther = other;
    return url == typedOther.url && colorFilter == typedOther.colorFilter;
  }

  @override
  int get hashCode => hashValues(url.hashCode, colorFilter);

  @override
  String toString() =>
      '$runtimeType("$url", headers: $headers, colorFilter: $colorFilter)';
}

/// Decodes the given [File] object as a picture, associating it with the given
/// scale.
///
/// See also:
///
///  * [SvgPicture.file] for a shorthand of an [SvgPicture] widget backed by [FilePicture].
class FilePicture extends PictureProvider<FilePicture> {
  /// Creates an object that decodes a [File] as a picture.
  ///
  /// The arguments must not be null.
  const FilePicture(this.decoder, this.file, {this.colorFilter})
      : assert(decoder != null),
        assert(file != null);

  /// The file to decode into a picture.
  final File file;

  /// The [PictureInfoDecoder] to use for loading this picture.
  final PictureInfoDecoder<Uint8List> decoder;

  /// The [ColorFilter], if any, to use when drawing this picture.
  final ColorFilter colorFilter;

  @override
  Future<FilePicture> obtainKey() {
    return new SynchronousFuture<FilePicture>(this);
  }

  @override
  PictureStreamCompleter load(FilePicture key) {
    return new OneFramePictureStreamCompleter(_loadAsync(key),
        informationCollector: (StringBuffer information) {
      information.writeln('Path: ${file?.path}');
    });
  }

  Future<PictureInfo> _loadAsync(FilePicture key) async {
    assert(key == this);

    final Uint8List data = await file.readAsBytes();
    if (data == null || data.isEmpty) {
      return null;
    }

    return await decoder(data, colorFilter, key.toString());
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final FilePicture typedOther = other;
    return file?.path == typedOther.file?.path &&
        typedOther.colorFilter == colorFilter;
  }

  @override
  int get hashCode => hashValues(file?.path?.hashCode, colorFilter);

  @override
  String toString() =>
      '$runtimeType("${file?.path}", colorFilter: $colorFilter)';
}

/// Decodes the given [String] buffer as a picture, associating it with the
/// given scale.
///
/// The provided [bytes] buffer should not be changed after it is provided
/// to a [MemoryPicture]. To provide an [PictureStream] that represents a picture
/// that changes over time, consider creating a new subclass of [PictureProvider]
/// whose [load] method returns a subclass of [PictureStreamCompleter] that can
/// handle providing multiple pictures.
///
/// See also:
///
///  * [SvgPicture.memory] for a shorthand of an [SvgPicture] widget backed by [MemoryPicture].
class MemoryPicture extends PictureProvider<MemoryPicture> {
  /// Creates an object that decodes a [Uint8List] buffer as a picture.
  ///
  /// The arguments must not be null.
  const MemoryPicture(this.decoder, this.bytes, {this.colorFilter})
      : assert(bytes != null);

  /// The [PictureInfoDecoder] to use when drawing this picture.
  final PictureInfoDecoder<Uint8List> decoder;

  /// The [ColorFilter], if any, to use when drawing this picture.
  final ColorFilter colorFilter;

  /// The bytes to decode into a picture.
  final Uint8List bytes;

  @override
  Future<MemoryPicture> obtainKey() {
    return new SynchronousFuture<MemoryPicture>(this);
  }

  @override
  PictureStreamCompleter load(MemoryPicture key) {
    return new OneFramePictureStreamCompleter(_loadAsync(key));
  }

  Future<PictureInfo> _loadAsync(MemoryPicture key) async {
    assert(key == this);
    return await decoder(bytes, colorFilter, key.toString());
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final MemoryPicture typedOther = other;
    return bytes == typedOther.bytes && colorFilter == typedOther.colorFilter;
  }

  @override
  int get hashCode => hashValues(bytes.hashCode, colorFilter);

  @override
  String toString() => '$runtimeType(${describeIdentity(bytes)})';
}

class StringPicture extends PictureProvider<StringPicture> {
  /// Creates an object that decodes a [Uint8List] buffer as a picture.
  ///
  /// The arguments must not be null.
  const StringPicture(this.decoder, this.string, {this.colorFilter})
      : assert(string != null);

  /// The [PictureInfoDecoder] to use for decoding this picture.
  final PictureInfoDecoder<String> decoder;

  /// The [ColorFilter], if any, to use when drawing this picture.
  final ColorFilter colorFilter;

  /// The string to decode into a picture.
  final String string;

  @override
  Future<StringPicture> obtainKey() {
    return new SynchronousFuture<StringPicture>(this);
  }

  @override
  PictureStreamCompleter load(StringPicture key) {
    return new OneFramePictureStreamCompleter(_loadAsync(key));
  }

  Future<PictureInfo> _loadAsync(StringPicture key) async {
    assert(key == this);
    return await decoder(string, colorFilter, key.toString());
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final StringPicture typedOther = other;
    return string == typedOther.string && colorFilter == typedOther.colorFilter;
  }

  @override
  int get hashCode => hashValues(string.hashCode, colorFilter);

  @override
  String toString() =>
      '$runtimeType(${describeIdentity(string)}, colorFilter: $colorFilter)';
}

/// Fetches a picture from an [AssetBundle], associating it with the given scale.
///
/// This implementation requires an explicit final [assetName] and [scale] on
/// construction, and ignores the device pixel ratio and size in the
/// configuration passed into [resolve]. For a resolution-aware variant that
/// uses the configuration to pick an appropriate picture based on the device
/// pixel ratio and size, see [AssetPicture].
///
/// ## Fetching assets
///
/// When fetching a picture provided by the app itself, use the [assetName]
/// argument to name the asset to choose. For instance, consider a directory
/// `icons` with a picture `heart.png`. First, the [pubspec.yaml] of the project
/// should specify its assets in the `flutter` section:
///
/// ```yaml
/// flutter:
///   assets:
///     - icons/heart.png
/// ```
///
/// Then, to fetch the picture and associate it with scale `1.5`, use
///
/// ```dart
/// new AssetPicture('icons/heart.png', scale: 1.5)
/// ```
///
///## Assets in packages
///
/// To fetch an asset from a package, the [package] argument must be provided.
/// For instance, suppose the structure above is inside a package called
/// `my_icons`. Then to fetch the picture, use:
///
/// ```dart
/// new AssetPicture('icons/heart.png', scale: 1.5, package: 'my_icons')
/// ```
///
/// Assets used by the package itself should also be fetched using the [package]
/// argument as above.
///
/// If the desired asset is specified in the `pubspec.yaml` of the package, it
/// is bundled automatically with the app. In particular, assets used by the
/// package itself must be specified in its `pubspec.yaml`.
///
/// A package can also choose to have assets in its 'lib/' folder that are not
/// specified in its `pubspec.yaml`. In this case for those pictures to be
/// bundled, the app has to specify which ones to include. For instance a
/// package named `fancy_backgrounds` could have:
///
/// ```
/// lib/backgrounds/background1.png
/// lib/backgrounds/background2.png
/// lib/backgrounds/background3.png
///```
///
/// To include, say the first picture, the `pubspec.yaml` of the app should specify
/// it in the `assets` section:
///
/// ```yaml
///  assets:
///    - packages/fancy_backgrounds/backgrounds/background1.png
/// ```
///
/// Note that the `lib/` is implied, so it should not be included in the asset
/// path.
///
/// See also:
///
///  * [SvgPicture.asset] for a shorthand of an [SvgPicture] widget backed by
///    [ExactAssetPicture] when using a scale.
class ExactAssetPicture extends AssetBundlePictureProvider {
  /// Creates an object that fetches the given picture from an asset bundle.
  ///
  /// The [assetName] and [scale] arguments must not be null. The [scale] arguments
  /// defaults to 1.0. The [bundle] argument may be null, in which case the
  /// bundle provided in the [PictureConfiguration] passed to the [resolve] call
  /// will be used instead.
  ///
  /// The [package] argument must be non-null when fetching an asset that is
  /// included in a package. See the documentation for the [ExactAssetPicture] class
  /// itself for details.
  const ExactAssetPicture(
    PictureInfoDecoder<Uint8List> decoder,
    this.assetName, {
    this.bundle,
    this.package,
    this.colorFilter,
  })  : assert(assetName != null),
        super(decoder);

  /// The name of the asset.
  final String assetName;

  /// The key to use to obtain the resource from the [bundle]. This is the
  /// argument passed to [AssetBundle.load].
  String get keyName =>
      package == null ? assetName : 'packages/$package/$assetName';

  /// The [ColorFilter], if any, to use when drawing this picture.
  final ColorFilter colorFilter;

  /// The bundle from which the picture will be obtained.
  ///
  /// If the provided [bundle] is null, the bundle provided in the
  /// [PictureConfiguration] passed to the [resolve] call will be used instead. If
  /// that is also null, the [rootBundle] is used.
  ///
  /// The picture is obtained by calling [AssetBundle.load] on the given [bundle]
  /// using the key given by [keyName].
  final AssetBundle bundle;

  /// The name of the package from which the picture is included. See the
  /// documentation for the [ExactAssetPicture] class itself for details.
  final String package;

  @override
  Future<AssetBundlePictureKey> obtainKey() {
    return new SynchronousFuture<AssetBundlePictureKey>(
        new AssetBundlePictureKey(
            bundle: bundle ?? rootBundle,
            name: keyName,
            colorFilter: colorFilter));
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final ExactAssetPicture typedOther = other;
    return keyName == typedOther.keyName &&
        bundle == typedOther.bundle &&
        colorFilter == typedOther.colorFilter;
  }

  @override
  int get hashCode => hashValues(keyName, bundle, colorFilter);

  @override
  String toString() =>
      '$runtimeType(name: "$keyName", bundle: $bundle, colorFilter: $colorFilter)';
}
