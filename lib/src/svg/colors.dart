import 'dart:ui';

import '../utilities/numbers.dart';

/// The color black, with full opacity.
const Color colorBlack = Color(0xFF000000);

/// Converts a SVG Color String (either a # prefixed color string or a named color) to a [Color].
Color? parseColor(String? colorString) {
  if (colorString == null || colorString.isEmpty) {
    return null;
  }

  if (colorString == 'none') {
    return null;
  }

  // handle hex colors e.g. #fff or #ffffff.  This supports #RRGGBBAA
  if (colorString[0] == '#') {
    if (colorString.length == 4) {
      final String r = colorString[1];
      final String g = colorString[2];
      final String b = colorString[3];
      colorString = '#$r$r$g$g$b$b';
    }
    int color = int.parse(colorString.substring(1), radix: 16);

    if (colorString.length == 7) {
      return Color(color |= 0xFF000000);
    }

    if (colorString.length == 9) {
      return Color(color);
    }
  }

  // handle rgba() colors e.g. rgba(255, 255, 255, 1.0)
  if (colorString.toLowerCase().startsWith('rgba')) {
    final List<String> rawColorElements = colorString
        .substring(colorString.indexOf('(') + 1, colorString.indexOf(')'))
        .split(',')
        .map((String rawColor) => rawColor.trim())
        .toList();

    final double opacity = parseDouble(rawColorElements.removeLast())!;

    final List<int> rgb =
        rawColorElements.map((String rawColor) => int.parse(rawColor)).toList();

    return Color.fromRGBO(rgb[0], rgb[1], rgb[2], opacity);
  }

  // Conversion code from: https://github.com/MichaelFenwick/Color, thanks :)
  if (colorString.toLowerCase().startsWith('hsl')) {
    final List<int> values = colorString
        .substring(colorString.indexOf('(') + 1, colorString.indexOf(')'))
        .split(',')
        .map((String rawColor) {
      rawColor = rawColor.trim();

      if (rawColor.endsWith('%')) {
        rawColor = rawColor.substring(0, rawColor.length - 1);
      }

      if (rawColor.contains('.')) {
        return (parseDouble(rawColor)! * 2.55).round();
      }

      return int.parse(rawColor);
    }).toList();
    final double hue = values[0] / 360 % 1;
    final double saturation = values[1] / 100;
    final double luminance = values[2] / 100;
    final int alpha = values.length > 3 ? values[3] : 255;
    List<double> rgb = <double>[0, 0, 0];

    if (hue < 1 / 6) {
      rgb[0] = 1;
      rgb[1] = hue * 6;
    } else if (hue < 2 / 6) {
      rgb[0] = 2 - hue * 6;
      rgb[1] = 1;
    } else if (hue < 3 / 6) {
      rgb[1] = 1;
      rgb[2] = hue * 6 - 2;
    } else if (hue < 4 / 6) {
      rgb[1] = 4 - hue * 6;
      rgb[2] = 1;
    } else if (hue < 5 / 6) {
      rgb[0] = hue * 6 - 4;
      rgb[2] = 1;
    } else {
      rgb[0] = 1;
      rgb[2] = 6 - hue * 6;
    }

    rgb =
        rgb.map((double val) => val + (1 - saturation) * (0.5 - val)).toList();

    if (luminance < 0.5) {
      rgb = rgb.map((double val) => luminance * 2 * val).toList();
    } else {
      rgb = rgb
          .map((double val) => luminance * 2 * (1 - val) + 2 * val - 1)
          .toList();
    }

    rgb = rgb.map((double val) => val * 255).toList();

    return Color.fromARGB(
        alpha, rgb[0].round(), rgb[1].round(), rgb[2].round());
  }

  // handle rgb() colors e.g. rgb(255, 255, 255)
  if (colorString.toLowerCase().startsWith('rgb')) {
    final List<int> rgb = colorString
        .substring(colorString.indexOf('(') + 1, colorString.indexOf(')'))
        .split(',')
        .map((String rawColor) {
      rawColor = rawColor.trim();
      if (rawColor.endsWith('%')) {
        rawColor = rawColor.substring(0, rawColor.length - 1);
        return (parseDouble(rawColor)! * 2.55).round();
      }
      return int.parse(rawColor);
    }).toList();

    // rgba() isn't really in the spec, but Firefox supported it at one point so why not.
    final int a = rgb.length > 3 ? rgb[3] : 255;
    return Color.fromARGB(a, rgb[0], rgb[1], rgb[2]);
  }

  // handle named colors ('red', 'green', etc.).
  final Color? namedColor = _namedColors[colorString];
  if (namedColor != null) {
    return namedColor;
  }

  throw StateError('Could not parse "$colorString" as a color.');
}

// https://www.w3.org/TR/SVG11/types.html#ColorKeywords
const Map<String, Color> _namedColors = <String, Color>{
  'aliceblue': Color.fromARGB(255, 240, 248, 255),
  'antiquewhite': Color.fromARGB(255, 250, 235, 215),
  'aqua': Color.fromARGB(255, 0, 255, 255),
  'aquamarine': Color.fromARGB(255, 127, 255, 212),
  'azure': Color.fromARGB(255, 240, 255, 255),
  'beige': Color.fromARGB(255, 245, 245, 220),
  'bisque': Color.fromARGB(255, 255, 228, 196),
  'black': Color.fromARGB(255, 0, 0, 0),
  'blanchedalmond': Color.fromARGB(255, 255, 235, 205),
  'blue': Color.fromARGB(255, 0, 0, 255),
  'blueviolet': Color.fromARGB(255, 138, 43, 226),
  'brown': Color.fromARGB(255, 165, 42, 42),
  'burlywood': Color.fromARGB(255, 222, 184, 135),
  'cadetblue': Color.fromARGB(255, 95, 158, 160),
  'chartreuse': Color.fromARGB(255, 127, 255, 0),
  'chocolate': Color.fromARGB(255, 210, 105, 30),
  'coral': Color.fromARGB(255, 255, 127, 80),
  'cornflowerblue': Color.fromARGB(255, 100, 149, 237),
  'cornsilk': Color.fromARGB(255, 255, 248, 220),
  'crimson': Color.fromARGB(255, 220, 20, 60),
  'cyan': Color.fromARGB(255, 0, 255, 255),
  'darkblue': Color.fromARGB(255, 0, 0, 139),
  'darkcyan': Color.fromARGB(255, 0, 139, 139),
  'darkgoldenrod': Color.fromARGB(255, 184, 134, 11),
  'darkgray': Color.fromARGB(255, 169, 169, 169),
  'darkgreen': Color.fromARGB(255, 0, 100, 0),
  'darkgrey': Color.fromARGB(255, 169, 169, 169),
  'darkkhaki': Color.fromARGB(255, 189, 183, 107),
  'darkmagenta': Color.fromARGB(255, 139, 0, 139),
  'darkolivegreen': Color.fromARGB(255, 85, 107, 47),
  'darkorange': Color.fromARGB(255, 255, 140, 0),
  'darkorchid': Color.fromARGB(255, 153, 50, 204),
  'darkred': Color.fromARGB(255, 139, 0, 0),
  'darksalmon': Color.fromARGB(255, 233, 150, 122),
  'darkseagreen': Color.fromARGB(255, 143, 188, 143),
  'darkslateblue': Color.fromARGB(255, 72, 61, 139),
  'darkslategray': Color.fromARGB(255, 47, 79, 79),
  'darkslategrey': Color.fromARGB(255, 47, 79, 79),
  'darkturquoise': Color.fromARGB(255, 0, 206, 209),
  'darkviolet': Color.fromARGB(255, 148, 0, 211),
  'deeppink': Color.fromARGB(255, 255, 20, 147),
  'deepskyblue': Color.fromARGB(255, 0, 191, 255),
  'dimgray': Color.fromARGB(255, 105, 105, 105),
  'dimgrey': Color.fromARGB(255, 105, 105, 105),
  'dodgerblue': Color.fromARGB(255, 30, 144, 255),
  'firebrick': Color.fromARGB(255, 178, 34, 34),
  'floralwhite': Color.fromARGB(255, 255, 250, 240),
  'forestgreen': Color.fromARGB(255, 34, 139, 34),
  'fuchsia': Color.fromARGB(255, 255, 0, 255),
  'gainsboro': Color.fromARGB(255, 220, 220, 220),
  'ghostwhite': Color.fromARGB(255, 248, 248, 255),
  'gold': Color.fromARGB(255, 255, 215, 0),
  'goldenrod': Color.fromARGB(255, 218, 165, 32),
  'gray': Color.fromARGB(255, 128, 128, 128),
  'grey': Color.fromARGB(255, 128, 128, 128),
  'green': Color.fromARGB(255, 0, 128, 0),
  'greenyellow': Color.fromARGB(255, 173, 255, 47),
  'honeydew': Color.fromARGB(255, 240, 255, 240),
  'hotpink': Color.fromARGB(255, 255, 105, 180),
  'indianred': Color.fromARGB(255, 205, 92, 92),
  'indigo': Color.fromARGB(255, 75, 0, 130),
  'ivory': Color.fromARGB(255, 255, 255, 240),
  'khaki': Color.fromARGB(255, 240, 230, 140),
  'lavender': Color.fromARGB(255, 230, 230, 250),
  'lavenderblush': Color.fromARGB(255, 255, 240, 245),
  'lawngreen': Color.fromARGB(255, 124, 252, 0),
  'lemonchiffon': Color.fromARGB(255, 255, 250, 205),
  'lightblue': Color.fromARGB(255, 173, 216, 230),
  'lightcoral': Color.fromARGB(255, 240, 128, 128),
  'lightcyan': Color.fromARGB(255, 224, 255, 255),
  'lightgoldenrodyellow': Color.fromARGB(255, 250, 250, 210),
  'lightgray': Color.fromARGB(255, 211, 211, 211),
  'lightgreen': Color.fromARGB(255, 144, 238, 144),
  'lightgrey': Color.fromARGB(255, 211, 211, 211),
  'lightpink': Color.fromARGB(255, 255, 182, 193),
  'lightsalmon': Color.fromARGB(255, 255, 160, 122),
  'lightseagreen': Color.fromARGB(255, 32, 178, 170),
  'lightskyblue': Color.fromARGB(255, 135, 206, 250),
  'lightslategray': Color.fromARGB(255, 119, 136, 153),
  'lightslategrey': Color.fromARGB(255, 119, 136, 153),
  'lightsteelblue': Color.fromARGB(255, 176, 196, 222),
  'lightyellow': Color.fromARGB(255, 255, 255, 224),
  'lime': Color.fromARGB(255, 0, 255, 0),
  'limegreen': Color.fromARGB(255, 50, 205, 50),
  'linen': Color.fromARGB(255, 250, 240, 230),
  'magenta': Color.fromARGB(255, 255, 0, 255),
  'maroon': Color.fromARGB(255, 128, 0, 0),
  'mediumaquamarine': Color.fromARGB(255, 102, 205, 170),
  'mediumblue': Color.fromARGB(255, 0, 0, 205),
  'mediumorchid': Color.fromARGB(255, 186, 85, 211),
  'mediumpurple': Color.fromARGB(255, 147, 112, 219),
  'mediumseagreen': Color.fromARGB(255, 60, 179, 113),
  'mediumslateblue': Color.fromARGB(255, 123, 104, 238),
  'mediumspringgreen': Color.fromARGB(255, 0, 250, 154),
  'mediumturquoise': Color.fromARGB(255, 72, 209, 204),
  'mediumvioletred': Color.fromARGB(255, 199, 21, 133),
  'midnightblue': Color.fromARGB(255, 25, 25, 112),
  'mintcream': Color.fromARGB(255, 245, 255, 250),
  'mistyrose': Color.fromARGB(255, 255, 228, 225),
  'moccasin': Color.fromARGB(255, 255, 228, 181),
  'navajowhite': Color.fromARGB(255, 255, 222, 173),
  'navy': Color.fromARGB(255, 0, 0, 128),
  'oldlace': Color.fromARGB(255, 253, 245, 230),
  'olive': Color.fromARGB(255, 128, 128, 0),
  'olivedrab': Color.fromARGB(255, 107, 142, 35),
  'orange': Color.fromARGB(255, 255, 165, 0),
  'orangered': Color.fromARGB(255, 255, 69, 0),
  'orchid': Color.fromARGB(255, 218, 112, 214),
  'palegoldenrod': Color.fromARGB(255, 238, 232, 170),
  'palegreen': Color.fromARGB(255, 152, 251, 152),
  'paleturquoise': Color.fromARGB(255, 175, 238, 238),
  'palevioletred': Color.fromARGB(255, 219, 112, 147),
  'papayawhip': Color.fromARGB(255, 255, 239, 213),
  'peachpuff': Color.fromARGB(255, 255, 218, 185),
  'peru': Color.fromARGB(255, 205, 133, 63),
  'pink': Color.fromARGB(255, 255, 192, 203),
  'plum': Color.fromARGB(255, 221, 160, 221),
  'powderblue': Color.fromARGB(255, 176, 224, 230),
  'purple': Color.fromARGB(255, 128, 0, 128),
  'red': Color.fromARGB(255, 255, 0, 0),
  'rosybrown': Color.fromARGB(255, 188, 143, 143),
  'royalblue': Color.fromARGB(255, 65, 105, 225),
  'saddlebrown': Color.fromARGB(255, 139, 69, 19),
  'salmon': Color.fromARGB(255, 250, 128, 114),
  'sandybrown': Color.fromARGB(255, 244, 164, 96),
  'seagreen': Color.fromARGB(255, 46, 139, 87),
  'seashell': Color.fromARGB(255, 255, 245, 238),
  'sienna': Color.fromARGB(255, 160, 82, 45),
  'silver': Color.fromARGB(255, 192, 192, 192),
  'skyblue': Color.fromARGB(255, 135, 206, 235),
  'slateblue': Color.fromARGB(255, 106, 90, 205),
  'slategray': Color.fromARGB(255, 112, 128, 144),
  'slategrey': Color.fromARGB(255, 112, 128, 144),
  'snow': Color.fromARGB(255, 255, 250, 250),
  'springgreen': Color.fromARGB(255, 0, 255, 127),
  'steelblue': Color.fromARGB(255, 70, 130, 180),
  'tan': Color.fromARGB(255, 210, 180, 140),
  'teal': Color.fromARGB(255, 0, 128, 128),
  'thistle': Color.fromARGB(255, 216, 191, 216),
  'tomato': Color.fromARGB(255, 255, 99, 71),
  'transparent': Color.fromARGB(0, 255, 255, 255),
  'turquoise': Color.fromARGB(255, 64, 224, 208),
  'violet': Color.fromARGB(255, 238, 130, 238),
  'wheat': Color.fromARGB(255, 245, 222, 179),
  'white': Color.fromARGB(255, 255, 255, 255),
  'whitesmoke': Color.fromARGB(255, 245, 245, 245),
  'yellow': Color.fromARGB(255, 255, 255, 0),
  'yellowgreen': Color.fromARGB(255, 154, 205, 50),
};
