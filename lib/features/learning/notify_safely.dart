import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that goes quiet once it is disposed.
///
/// A screen's controller is disposed when the person leaves the screen, and a request it started may still be
/// on its way: it comes back, sets its state and calls `notifyListeners`, which on a disposed notifier is an
/// assertion in a debug build ("used after being disposed"). Backing out of Flash Cards or the Knowledge Center
/// while they load is exactly that. With this mixin the late answer is dropped.
mixin NotifySafely on ChangeNotifier {
  bool _disposed = false;

  /// Whether the screen that owned this controller has been left.
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
