/// ignore_for_file: public_member_api_docs
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/avd.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Assets that will be rendered.
const List<String> assetNames = <String>[
  // 'assets/notfound.svg', // uncomment to test an asset that doesn't exist.
  'assets/flutter_logo.svg',
  'assets/dart.svg',
  'assets/simple/clip_path_3.svg',
  'assets/simple/clip_path_2.svg',
  'assets/simple/clip_path.svg',
  'assets/simple/fill-rule-inherit.svg',
  'assets/simple/group_fill_opacity.svg',
  'assets/simple/group_opacity.svg',
  'assets/simple/text.svg',
  'assets/simple/text_2.svg',
  'assets/simple/linear_gradient.svg',
  'assets/simple/linear_gradient_2.svg',
  'assets/simple/male.svg',
  'assets/simple/radial_gradient.svg',
  'assets/simple/rect_rrect.svg',
  'assets/simple/rect_rrect_no_ry.svg',
  'assets/simple/style_attr.svg',
  'assets/w3samples/aa.svg',
  'assets/w3samples/alphachannel.svg',
  'assets/simple/ellipse.svg',
  'assets/simple/dash_path.svg',
  'assets/simple/nested_group.svg',
  'assets/simple/stroke_inherit_circles.svg',
  'assets/simple/use_circles.svg',
  'assets/simple/use_opacity_grid.svg',
  'assets/wikimedia/chess_knight.svg',
  'assets/wikimedia/Ghostscript_Tiger.svg',
  'assets/wikimedia/Firefox_Logo_2017.svg',
];

/// Assets treated as "icons" - using a color filter to render differently.
const List<String> iconNames = <String>[
  'assets/deborah_ufw/new-action-expander.svg',
  'assets/deborah_ufw/new-camera.svg',
  'assets/deborah_ufw/new-gif-button.svg',
  'assets/deborah_ufw/new-gif.svg',
  'assets/deborah_ufw/new-image.svg',
  'assets/deborah_ufw/new-mention.svg',
  'assets/deborah_ufw/new-pause-button.svg',
  'assets/deborah_ufw/new-play-button.svg',
  'assets/deborah_ufw/new-send-circle.svg',
  'assets/deborah_ufw/numeric_25.svg',
];

/// Assets to test network access.
const List<String> uriNames = <String>[
  'http://upload.wikimedia.org/wikipedia/commons/0/02/SVG_logo.svg',
  'https://dev.w3.org/SVG/tools/svgweb/samples/svg-files/410.svg',
  'https://upload.wikimedia.org/wikipedia/commons/b/b4/Chess_ndd45.svg',
];

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter SVG Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Widget> _painters = <Widget>[];
  double _dimension;

  @override
  void initState() {
    super.initState();
    _dimension = 600.0;
    _painters.add(SvgPicture.string('''<svg xmlns="http://www.w3.org/2000/svg" width="95" height="108" fill="none">
  <defs>
    <filter id="filter0_d" width="53.163" height="53.297" x="41.837" y="15.748" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse">
      <feFlood flood-opacity="0" result="BackgroundImageFix"/>
      <feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0"/>
      <feOffset dx="4"/>
      <feGaussianBlur stdDeviation="4"/>
      <feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.1 0"/>
      <feBlend in2="BackgroundImageFix" result="effect1_dropShadow"/>
      <feBlend in="SourceGraphic" in2="effect1_dropShadow" result="shape"/>
    </filter>
    <filter id="filter1_d" width="62.247" height="62.414" x=".223" y="0" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse">
      <feFlood flood-opacity="0" result="BackgroundImageFix"/>
      <feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0"/>
      <feOffset dx="4"/>
      <feGaussianBlur stdDeviation="4"/>
      <feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.1 0"/>
      <feBlend in2="BackgroundImageFix" result="effect1_dropShadow"/>
      <feBlend in="SourceGraphic" in2="effect1_dropShadow" result="shape"/>
    </filter>
    <filter id="filter2_d" width="68.854" height="69.045" x="8.803" y="38.955" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse">
      <feFlood flood-opacity="0" result="BackgroundImageFix"/>
      <feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0"/>
      <feOffset dx="4"/>
      <feGaussianBlur stdDeviation="4"/>
      <feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.1 0"/>
      <feBlend in2="BackgroundImageFix" result="effect1_dropShadow"/>
      <feBlend in="SourceGraphic" in2="effect1_dropShadow" result="shape"/>
    </filter>
    <linearGradient id="paint0_linear" x1="64.418" x2="64.418" y1="23.748" y2="61.045" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFE354"/>
      <stop offset="1" stop-color="#E9C93C"/>
    </linearGradient>
    <linearGradient id="paint1_linear" x1="64.412" x2="64.412" y1="46.474" y2="50.552" gradientUnits="userSpaceOnUse">
      <stop stop-color="#fff"/>
      <stop offset="1" stop-color="#CDCDCD"/>
    </linearGradient>
    <linearGradient id="paint2_linear" x1="27.346" x2="27.346" y1="8" y2="54.414" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFE354"/>
      <stop offset="1" stop-color="#E9C93C"/>
    </linearGradient>
    <linearGradient id="paint3_linear" x1="39.23" x2="39.23" y1="46.955" y2="100" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFE354"/>
      <stop offset="1" stop-color="#E9C93C"/>
    </linearGradient>
  </defs>
  <path fill="url(#paint0_linear)" d="M64.418 61.045C74.681 61.045 83 52.695 83 42.396c0-10.299-8.32-18.648-18.582-18.648s-18.581 8.349-18.581 18.648c0 10.3 8.32 18.649 18.581 18.649z" filter="url(#filter0_d)"/>
  <path fill="#000" d="M55.45 45.474a.894.894 0 0 0-.906.835.902.902 0 0 0 .08.442 10.796 10.796 0 0 0 3.974 4.59 10.741 10.741 0 0 0 11.629 0 10.797 10.797 0 0 0 3.974-4.59.902.902 0 0 0-.826-1.277H55.45z"/>
  <path fill="url(#paint1_linear)" fill-rule="evenodd" d="M73.527 48c.25-.4.476-.817.674-1.25a.9.9 0 0 0-.826-1.276H55.45a.891.891 0 0 0-.764.41.9.9 0 0 0-.062.867c.198.432.423.85.673 1.249h18.23z" clip-rule="evenodd"/>
  <path fill="#F24E53" d="M50.482 45.643a2.329 2.329 0 0 0 2.325-2.333 2.329 2.329 0 0 0-2.325-2.333 2.329 2.329 0 0 0-2.324 2.333 2.329 2.329 0 0 0 2.324 2.333zM78.355 45.643a2.329 2.329 0 0 0 2.324-2.333 2.329 2.329 0 0 0-2.324-2.333 2.329 2.329 0 0 0-2.325 2.333 2.329 2.329 0 0 0 2.325 2.333z" opacity=".5"/>
  <path stroke="#000" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.325" d="M68.482 38.495c1.994-.828 4.129-.729 6.388 0M60.351 38.495c-1.99-.828-4.129-.729-6.388 0"/>
  <path fill="url(#paint2_linear)" d="M27.346 54.414c12.771 0 23.124-10.39 23.124-23.207S40.117 8 27.346 8C14.576 8 4.223 18.39 4.223 31.207s10.352 23.207 23.123 23.207z" filter="url(#filter1_d)"/>
  <path stroke="#000" stroke-linecap="round" stroke-linejoin="round" stroke-width="2.896" d="M15.892 23.731l5.566 3.987-6.652 3.394M38.8 23.731l-5.57 3.987 6.657 3.394"/>
  <path fill="#6793FD" d="M8.17 34.675c-.948.54-2.07.683-3.123.396a4.132 4.132 0 0 1-2.494-1.927 4.157 4.157 0 0 1-.416-3.131 4.143 4.143 0 0 1 1.904-2.516c2.329-1.351 6.301-.995 8.176-.73a.85.85 0 0 1 .728.786.856.856 0 0 1-.06.38c-.705 1.76-2.386 5.39-4.715 6.742z" opacity=".8"/>
  <path stroke="#C2EDFF" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.088" d="M7.885 27.92a7.725 7.725 0 0 0-3.088.828 3.002 3.002 0 0 0-1.363 1.6" opacity=".8"/>
  <path fill="#6793FD" d="M46.498 34.675a4.119 4.119 0 0 0 5.664-1.503 4.154 4.154 0 0 0-1.535-5.675c-2.329-1.351-6.301-.995-8.176-.73a.849.849 0 0 0-.729.786.858.858 0 0 0 .06.38c.706 1.76 2.387 5.39 4.716 6.742z" opacity=".8"/>
  <path stroke="#C2EDFF" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.088" d="M46.782 27.92a7.725 7.725 0 0 1 3.09.828c.63.351 1.115.92 1.362 1.6" opacity=".8"/>
  <path fill="#000" d="M16.185 36.284a1.112 1.112 0 0 0-.944.512 1.122 1.122 0 0 0-.076 1.075 13.438 13.438 0 0 0 4.946 5.711 13.369 13.369 0 0 0 14.47 0 13.438 13.438 0 0 0 4.947-5.711 1.123 1.123 0 0 0-.483-1.453 1.112 1.112 0 0 0-.537-.134H16.185z"/>
  <path fill="#F24E53" fill-rule="evenodd" d="M33.722 44.091a10.183 10.183 0 0 0-6.376-2.225c-2.414 0-4.632.833-6.375 2.225a13.365 13.365 0 0 0 12.751 0z" clip-rule="evenodd"/>
  <path fill="url(#paint3_linear)" d="M39.23 100c14.596 0 26.427-11.874 26.427-26.522 0-14.648-11.831-26.523-26.427-26.523-14.595 0-26.427 11.875-26.427 26.523S24.635 100 39.23 100z" filter="url(#filter2_d)"/>
  <path fill="#000" d="M25.021 71.256a1.484 1.484 0 0 0-1.465 1.265c-.036.233-.016.472.057.695 2.577 7.791 8.598 13.262 15.617 13.262 7.02 0 13.036-5.466 15.613-13.262a1.497 1.497 0 0 0-.733-1.795 1.484 1.484 0 0 0-.675-.165H25.02z"/>
  <path fill="#F24E53" fill-rule="evenodd" d="M48.602 82.857a13.578 13.578 0 0 0-9.372-3.74 13.578 13.578 0 0 0-9.372 3.74c2.684 2.287 5.906 3.62 9.372 3.62 3.467 0 6.689-1.332 9.372-3.62z" clip-rule="evenodd"/>
  <path fill="#F24E53" d="M19.236 78.45a3.31 3.31 0 0 0 3.303-3.315 3.31 3.31 0 0 0-3.303-3.315 3.31 3.31 0 0 0-3.304 3.315 3.31 3.31 0 0 0 3.304 3.316zM59.225 78.45a3.31 3.31 0 0 0 3.303-3.315 3.31 3.31 0 0 0-3.303-3.315 3.31 3.31 0 0 0-3.304 3.315 3.31 3.31 0 0 0 3.304 3.316z" opacity=".5"/>
  <path stroke="#000" stroke-linecap="round" stroke-linejoin="round" stroke-width="3.309" d="M33.45 66.018c-.587-2.395-2.396-4.144-4.543-4.144-2.147 0-3.96 1.749-4.542 4.144M54.095 66.018c-.586-2.395-2.395-4.144-4.542-4.144s-3.96 1.749-4.542 4.144"/>
</svg>
'''));
    for (String assetName in assetNames) {
      _painters.add(
        SvgPicture.asset(assetName),
      );
    }

    for (int i = 0; i < iconNames.length; i++) {
      _painters.add(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SvgPicture.asset(
            iconNames[i],
            color: Colors.blueGrey[(i + 1) * 100],
            matchTextDirection: true,
          ),
        ),
      );
    }

    for (String uriName in uriNames) {
      _painters.add(
        SvgPicture.network(
          uriName,
          placeholderBuilder: (BuildContext context) => Container(
              padding: const EdgeInsets.all(30.0),
              child: const CircularProgressIndicator()),
        ),
      );
    }
    // Shows an example of an SVG image that will fetch a raster image from a URL.
    _painters.add(SvgPicture.string('''<svg viewBox="0 0 200 200"
  xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <image xlink:href="https://mdn.mozillademos.org/files/6457/mdn_logo_only_color.png" height="200" width="200"/>
</svg>'''));
    _painters.add(AvdPicture.asset('assets/android_vd/battery_charging.xml'));
  }

  @override
  Widget build(BuildContext context) {
    if (_dimension > MediaQuery.of(context).size.width - 10.0) {
      _dimension = MediaQuery.of(context).size.width - 10.0;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(children: <Widget>[
        Slider(
            min: 5.0,
            max: MediaQuery.of(context).size.width - 10.0,
            value: _dimension,
            onChanged: (double val) {
              setState(() => _dimension = val);
            }),
        Expanded(
          child: GridView.extent(
            shrinkWrap: true,
            maxCrossAxisExtent: _dimension,
            padding: const EdgeInsets.all(4.0),
            mainAxisSpacing: 4.0,
            crossAxisSpacing: 4.0,
            children: _painters.toList(),
          ),
        ),
      ]),
    );
  }
}
