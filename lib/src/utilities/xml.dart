import 'package:xml/xml_events.dart';

/// The namespace for xlink from the SVG 1.1 spec.
const String kXlinkNamespace = 'http://www.w3.org/1999/xlink';

/// Get the `xlink:href` or `href` attribute, preferring `xlink`.
///
/// SVG 1.1 specifies that these attributes should be in the xlink namespace.
/// SVG 2 deprecates that namespace.
String? getHrefAttribute(Map<String, String> attributes) => getAttribute(
      attributes,
      'href',
      def: getAttribute(attributes, 'href'),
    );

/// Gets the attribute, trims it, and returns the attribute or default if the attribute
/// is null or ''.
///
/// Will look to the style first if it can.
String? getAttribute(
  Map<String, String> el,
  String name, {
  String? def = '',
  bool checkStyle = true,
  bool useRegexp = false,
}) {
  String raw = '';
  if (checkStyle) {
    final String? style = _getAttribute(el, 'style');
    if (style != '' && style != null) {
      // We could do this, but split is a tiny bit faster:
      // final int attributeIndex = style.indexOf(RegExp('(^|;)\s*$name\s*:'));
      // if (attributeIndex != -1) {
      //   final int endIndex = style.indexOf(';', attributeIndex + 1);
      //   final String attribute = style.substring(attributeIndex + 1, endIndex == -1 ? null : endIndex);
      //   raw = attribute.substring(attribute.indexOf(':') + 1).trim();
      // }
      final List<String> styles = style.split(';');
      raw = styles.firstWhere(
          (String str) => str.trimLeft().startsWith(name + ':'),
          orElse: () => '');

      if (raw != '') {
        raw = raw.substring(raw.indexOf(':') + 1).trim();
      }
    }

    if (raw == '') {
      raw = _getAttribute(el, name);
    }
  } else {
    raw = _getAttribute(el, name);
  }

  return raw == '' ? def : raw;
}

String _getAttribute(
  Map<String, String> attributes,
  String localName, {
  String def = '',
}) {
  return attributes[localName] ?? def;
}

/// Extension on List<XmlEventAttribute> for easy conversion to an attribute
/// map.
extension AttributeMapXmlEventAttributeExtension on List<XmlEventAttribute> {
  /// Converts the List<XmlEventAttribute> to an attribute map.
  Map<String, String> toAttributeMap() => <String, String>{
        for (final XmlEventAttribute attribute in this)
          attribute.localName: attribute.value.trim(),
      };
}
