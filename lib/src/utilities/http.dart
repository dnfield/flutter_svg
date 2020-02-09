import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Fetches an HTTP resource from the specified [url] using the specified [headers].
Future<Uint8List> httpGet(http.BaseClient client, String url, {Map<String, String> headers}) async {
  final Uri uri = Uri.base.resolve(url);

  final http.Response response = await client.get(uri, headers: headers ?? <String, String>{});

  if (response.statusCode < 200 || response.statusCode >= 400) {
    throw Exception('Could not get network asset from $uri');
  }
  return response.bodyBytes;
}
