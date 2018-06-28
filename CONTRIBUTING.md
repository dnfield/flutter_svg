# Contributing to Flutter SVG

Found a bug? Want an enhancement?  Feel free to submit a pull request for it!

## Creating a Pull Request

Contributions are welcome in this repo. Before submitting, please ensure that
your request will pass CI:

```bash
flutter format .
flutter analyze .
flutter test
```

If you're adding a feature that impacts rendering, please add an SVG asset to
the `assets/` folder, and then run `flutter test tool/gen_golden.dart` to
update the golden image files.  Note that this has not been tested in Windows
platforms. If you're unable to run it, let me know and I'll work with you to
update the goldens.

Passing the golden tests is critical to ensure backward compatibility, and that
your code has not unintentionally broken a previously working feature. While
sometimes such changes are necessary to fix a broken rendering method, they
should not be introduced without care.

If you're fixing a bug, please make sure to include some tests that fail before
applying your fix and now succeed. This might be a regular Dart unit test, or
it could be a SVG in the `assets/` folder and a corresponding PNG in `goldens/`
that now renders correctly because of your fix.

For the PR to be incorporated into the package, it must be compatible with
the the latest `beta` channel for Flutter (or, the latest stable/mainline
release). If it someday becomes possible to conditionally pre-process the
Dart code based on Flutter/Dart version, this can be relaxed.

## Opening an issue

If you've got an issue and you're not able to fix it yourself, or you're
looking for feedback before doing any coding work for a PR, feel free to open
an issue about it.

If the issue is related to rendering or a specific SVG feature, be sure to
include at least one sample SVG. The smaller/simpler the example, the better.

If the issue is related to architecture/project structure/coding standards,
consider including some kind of example of what you're trying to achieve. For
example, instead of saying

> This project should use Design Pattern X to solve Problem Y! I love pattern
X and when we used it on Project Z it made everything better.

consider

> Here's an example of implementing this feature using Deisgn Pattern X.
This memory/time benchmark shows that it makes rendering perform 10% faster
on Phone Model W....

or

> It's very difficult to implement feature A in the current codebase. Applying
Pattern X could help solve this, as in the following example....

which will be received better.