# Script invoked by the Flutter customer tests repository.

set -e

pushd packages/flutter_svg
flutter analyze --no-fatal-infos
flutter test
popd
