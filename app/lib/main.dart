import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Spec 9 gives errors a surface in the UI; that surface does not exist
  // yet (it arrives with the operation/progress work). Until then, an
  // uncaught framework or platform error at least reaches the log with its
  // stack instead of vanishing in a release build.
  final FlutterExceptionHandler? presentError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    presentError?.call(details);
    debugPrint('Spectra: uncaught Flutter error: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Spectra: uncaught platform error: $error');
    debugPrintStack(stackTrace: stack);
    // Handled: the app keeps running, exactly as it did before this
    // handler existed.
    return true;
  };

  runApp(const ProviderScope(child: SpectraRoot()));
}
