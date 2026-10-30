import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with WidgetsBindingObserver {
  final _connectivity = ConnectivityService();
  StreamSubscription<bool>? _subscription;
  bool? _connected;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onNetworkChanged.listen((connected) {
      _revision++;
      if (mounted) setState(() => _connected = connected);
    }, onError: (Object _) {});
    unawaited(_check());
  }

  Future<void> _check() async {
    final revision = _revision;
    final connected = await _connectivity.connectionStatus();
    if (mounted && revision == _revision) {
      setState(() => _connected = connected);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_connected == false)
          Material(
            color: AppColors.lightPurple,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 19,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You're offline. Loading may take longer.",
                          style: TextStyle(
                            color: AppColors.darkText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          key: const ValueKey('app_content'),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: _connected == false,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
