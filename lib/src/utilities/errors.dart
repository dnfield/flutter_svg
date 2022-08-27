import 'package:flutter/foundation.dart';

/// Reports a missing or undefined `<defs>` element.
void reportMissingDef(String? key, String? href, String methodName) {
  FlutterError.onError!(
    FlutterErrorDetails(
      exception: FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Failed to find definition for $href'),
        ErrorHint(
            'Could not find a definition for $href, check your SVG file if it is defined.'),
        ErrorDescription(
            'This error is treated as non-fatal, but your SVG file will likely not render as intended'),
      ]),
      context: ErrorDescription('while parsing $key in $methodName'),
      library: 'SVG',
    ),
  );
}
