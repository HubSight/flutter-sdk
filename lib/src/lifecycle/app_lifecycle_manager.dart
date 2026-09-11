import 'package:flutter/widgets.dart';

/// Lifecycle observer to conserve battery and connection pool by pausing media streams in background.
class HubSightLifecycleManager with WidgetsBindingObserver {
  final VoidCallback? onAppBackground;
  final VoidCallback? onAppForeground;

  bool _isObserving = false;

  HubSightLifecycleManager({
    this.onAppBackground,
    this.onAppForeground,
  });

  /// Start observing application lifecycle events.
  void start() {
    if (_isObserving) return;
    WidgetsBinding.instance.addObserver(this);
    _isObserving = true;
  }

  /// Stop observing application lifecycle events.
  void stop() {
    if (!_isObserving) return;
    WidgetsBinding.instance.removeObserver(this);
    _isObserving = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        onAppBackground?.call();
        break;
      case AppLifecycleState.resumed:
        onAppForeground?.call();
        break;
      default:
        break;
    }
  }

  void dispose() {
    stop();
  }
}
