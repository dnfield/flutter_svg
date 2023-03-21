import 'dart:typed_data';

// ignore: public_member_api_docs
extension Uint8ListExtensions on Uint8List? {
  // ignore: public_member_api_docs
  Uint8List get ifEmpty {
    return this ?? Uint8List.fromList(<int>[]);
  }
}

// ignore: public_member_api_docs
extension ByteDataExtensions on ByteData? {
  // ignore: public_member_api_docs
  ByteData get ifEmpty {
    return this ?? ByteData(0);
  }
}