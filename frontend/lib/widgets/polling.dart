import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config.dart';

/// Every screen polls every 3 seconds (spec rule 8). No WebSocket.
mixin PollingMixin<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;
  bool _pollBusy = false;

  Duration get pollInterval => AppConfig.pollInterval;

  /// Implement sa screen: fetch data + setState. Dapat dili mo-throw.
  Future<void> refreshData();

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _runPoll());
  }

  Future<void> _runPoll() async {
    if (_pollBusy || !mounted) return;
    _pollBusy = true;
    try {
      await refreshData();
    } finally {
      _pollBusy = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
