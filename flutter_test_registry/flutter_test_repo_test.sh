# Script invoked by the Flutter customer tests repository.

set -e

cd packages/flutter_svg
flutter analyze --no-fatal-infos
flutter test
cd ../..
