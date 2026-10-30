import 'package:flutter/foundation.dart';

/// Runs [job] on [message] somewhere other than the screen's own thread and returns what it gives back.
/// Reading a big workbook or a ZIP takes long enough to stall a scrolling list, so the app does it in a
/// background isolate; a test gives [runHere] and gets the answer at once.
typedef PreviewRunner = Future<R> Function<M, R>(R Function(M message) job, M message);

/// The app's runner: a background isolate.
Future<R> runInBackground<M, R>(R Function(M message) job, M message) => compute<M, R>(job, message);

/// A runner that does the work in place, for tests.
Future<R> runHere<M, R>(R Function(M message) job, M message) async => job(message);
