/// Parses a `String` to a `double`.
///
/// Passing `null` will return `null`.
///
/// Will strip off a `px` prefix.
double? parseDouble(String? maybeDouble,
    {bool tryParse = false, String xy = ''}) {
  assert(tryParse != null); // ignore: unnecessary_null_comparison
  if (maybeDouble == null) {
    return null;
  }
  maybeDouble = maybeDouble.trim().replaceFirst('px', '').trim();
  // Ziemlich dreckiger Hack nur für mich
  if (maybeDouble.contains('%') && xy != null) {
    double _percentage = double.tryParse(maybeDouble.replaceAll('%', '')) ?? 0;
    maybeDouble = (_percentage / 100 - (xy == 'x' ? 0 : 0.25)).toString();
  }
  if (tryParse) {
    return double.tryParse(maybeDouble);
  }
  return double.parse(maybeDouble);
}

