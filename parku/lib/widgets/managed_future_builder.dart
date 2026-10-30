import 'package:flutter/widgets.dart';

import '../controllers/analytics_controller.dart';
import '../utils/screen_load_reporter.dart';

/// Owns the Future outside build and reloads only for a new explicit request key.
class ManagedFutureBuilder<T> extends StatefulWidget {
  final Object requestKey;
  final Future<T> Function() load;
  final AsyncWidgetBuilder<T> builder;
  final AnalyticsController? analytics;
  final String? screenName;
  final String Function(T? data)? loadSource;

  const ManagedFutureBuilder({
    super.key,
    required this.requestKey,
    required this.load,
    required this.builder,
    this.analytics,
    this.screenName,
    this.loadSource,
  });

  @override
  State<ManagedFutureBuilder<T>> createState() =>
      _ManagedFutureBuilderState<T>();
}

class _ManagedFutureBuilderState<T> extends State<ManagedFutureBuilder<T>> {
  late Future<T> _future;
  ScreenLoadReporter? _screenLoad;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant ManagedFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) {
      _startLoad(trigger: 'refresh');
    }
  }

  void _startLoad({String trigger = 'navigation'}) {
    _screenLoad?.cancel();
    if (widget.screenName != null) {
      _screenLoad = ScreenLoadReporter(
        widget.analytics,
        widget.screenName!,
        trigger: trigger,
      );
    }
    _future = Future<T>.sync(widget.load);
  }

  @override
  void dispose() {
    _screenLoad?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    key: ValueKey(widget.requestKey),
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        _screenLoad?.presented(
          context,
          source: snapshot.hasError
              ? 'none'
              : widget.loadSource?.call(snapshot.data) ?? 'network',
          failed: snapshot.hasError,
        );
      }
      return widget.builder(context, snapshot);
    },
  );
}
