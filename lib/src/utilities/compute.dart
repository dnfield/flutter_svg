import 'package:flutter/foundation.dart';

import '_compute_io.dart' if (dart.library.html) '_compute_none.dart';

/// A compute implementation that does not spawn isolates in tests.
final ComputeImpl compute = useRealCompute
    ? <Q, R>(ComputeCallback<Q, R> callback, Q message,
            {String? debugLabel}) async =>
        await callback(message)
    : compute;
