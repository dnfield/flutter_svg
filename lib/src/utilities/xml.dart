import 'package:xml/xml.dart';
import 'package:xml/xml/utils/node_list.dart';

/// Gets the attribute, trims it, and returns the attribute or default if the attribute
/// is null or ''.
///
/// Will look to the style first if it can.
String getAttribute(List<XmlAttribute> el, String name,
    {String def = '', String namespace, bool checkStyle = true}) {
  String raw = '';
  if (checkStyle) {
    final String style = _getAttribute(el, 'style')?.trim();
    if (style != '' && style != null) {
      // Probably possible to slightly optimize this (e.g. use indexOf instead of split),
      // but handling potential whitespace will get complicated and this just works.
      // I also don't feel like writing benchmarks for what is likely a micro-optimization.
      final List<String> styles = style.split(';');
      raw = styles.firstWhere(
          (String str) => str.trimLeft().startsWith(name + ':'),
          orElse: () => '');

      if (raw != '') {
        raw = raw.substring(raw.indexOf(':') + 1)?.trim();
      }
    }

    if (raw == '' || raw == null) {
      raw = _getAttribute(el, name, namespace: namespace)?.trim();
    }
  } else {
    raw = _getAttribute(el, name, namespace: namespace)?.trim();
  }

  return raw == '' || raw == null ? def : raw;
}

String _getAttribute(List<XmlAttribute> list, String localName,
    {String def = '', String namespace}) {
  return list
          .firstWhere((XmlAttribute attr) => attr.name.local == localName,
              orElse: () => null)
          ?.value ??
      def;
}
