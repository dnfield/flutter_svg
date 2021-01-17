import 'package:xml/xml_events.dart' as xml show parseEvents;

import 'src/svg/parser_state.dart';
import 'src/vector_drawable.dart';

/// Parses SVG data into a [DrawableRoot].
class SvgParser {
  /// Parses SVG from a string to a [DrawableRoot].
  ///
  /// The [key] parameter is used for debugging purposes.
  ///
  /// The [dryRun] detects if an SVG contains contains unsupported features.
  /// If true the function will throw with an error.
  /// If false only warnings are logged to the console.
  /// Defaults to false.
  Future<DrawableRoot> parse(
    String str, {
    String? key,
    bool dryRun = false,
  }) async {
    final SvgParserState state =
        SvgParserState(xml.parseEvents(str), key, dryRun);
    return await state.parse();
  }
}
