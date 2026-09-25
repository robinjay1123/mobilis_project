import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/database_health_service.dart';

/// Centralized utility and widget for guarding buttons against rapid multi-clicks (spamming)
/// and automatically handling database health errors.
class ButtonGuard {
  static const Duration defaultCooldown = Duration(milliseconds: 1000);

  /// Wraps any callback with anti-spam debouncing and database health error handling.
  static VoidCallback? wrap(
    FutureOr<void> Function()? callback, {
    Duration cooldown = defaultCooldown,
  }) {
    if (callback == null) return null;

    DateTime? lastExecution;
    bool isExecuting = false;

    return () async {
      final now = DateTime.now();

      // Guard: ignore if already executing or within cooldown period
      if (isExecuting) return;
      if (lastExecution != null && now.difference(lastExecution!) < cooldown) {
        return;
      }
      lastExecution = now;

      try {
        final result = callback();
        if (result is Future) {
          isExecuting = true;
          await result;
        }
      } catch (e) {
        DatabaseHealthService.handlePossibleDatabaseError(e);
        rethrow;
      } finally {
        isExecuting = false;
      }
    };
  }
}

/// A drop-in widget wrapper that adds anti-spam protection and loading state
/// to any button or gesture widget.
class GuardedButton extends StatefulWidget {
  final FutureOr<void> Function()? onPressed;
  final Widget Function(
    BuildContext context,
    bool isExecuting,
    VoidCallback? guardedOnPressed,
  ) builder;
  final Duration cooldown;

  const GuardedButton({
    super.key,
    required this.onPressed,
    required this.builder,
    this.cooldown = ButtonGuard.defaultCooldown,
  });

  @override
  State<GuardedButton> createState() => _GuardedButtonState();
}

class _GuardedButtonState extends State<GuardedButton> {
  bool _isExecuting = false;
  DateTime? _lastExecution;

  Future<void> _handlePress() async {
    final now = DateTime.now();
    if (_isExecuting || widget.onPressed == null) return;
    if (_lastExecution != null &&
        now.difference(_lastExecution!) < widget.cooldown) {
      return;
    }
    _lastExecution = now;

    try {
      final result = widget.onPressed!();
      if (result is Future) {
        if (mounted) setState(() => _isExecuting = true);
        await result;
      }
    } catch (e) {
      if (mounted) {
        DatabaseHealthService.handlePossibleDatabaseError(e, context);
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed =
        widget.onPressed == null || _isExecuting ? null : _handlePress;

    return widget.builder(context, _isExecuting, effectiveOnPressed);
  }
}

/// Global root-level tap guard that intercepts and absorbs rapid duplicate taps
/// on any button, icon, or touchable element across the entire application.
class GlobalTapGuard extends StatefulWidget {
  final Widget child;
  final Duration cooldown;
  final double distanceThreshold;

  const GlobalTapGuard({
    super.key,
    required this.child,
    this.cooldown = const Duration(milliseconds: 350),
    this.distanceThreshold = 60.0,
  });

  @override
  State<GlobalTapGuard> createState() => _GlobalTapGuardState();
}

class _GlobalTapGuardState extends State<GlobalTapGuard> {
  final GlobalKey<_RenderTapGuardWidgetState> _guardKey =
      GlobalKey<_RenderTapGuardWidgetState>();

  void _onPointerDown(PointerDownEvent event) {
    _guardKey.currentState?.triggerCooldown(
      event.position,
      widget.cooldown,
      widget.distanceThreshold,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      behavior: HitTestBehavior.translucent,
      child: _TapGuardRenderWidget(
        key: _guardKey,
        child: widget.child,
      ),
    );
  }
}

class _TapGuardRenderWidget extends StatefulWidget {
  final Widget child;

  const _TapGuardRenderWidget({
    super.key,
    required this.child,
  });

  @override
  State<_TapGuardRenderWidget> createState() => _RenderTapGuardWidgetState();
}

class _RenderTapGuardWidgetState extends State<_TapGuardRenderWidget> {
  Offset? _cooldownPosition;
  DateTime? _cooldownUntil;
  double _threshold = 60.0;
  Timer? _timer;

  void triggerCooldown(
      Offset position, Duration duration, double distanceThreshold) {
    _cooldownPosition = position;
    _cooldownUntil = DateTime.now().add(duration);
    _threshold = distanceThreshold;

    _timer?.cancel();
    _timer = Timer(duration, () {
      _cooldownPosition = null;
      _cooldownUntil = null;
    });
  }

  bool isTappedWithinCooldown(Offset position) {
    if (_cooldownPosition == null || _cooldownUntil == null) return false;
    final now = DateTime.now();
    if (now.isAfter(_cooldownUntil!)) {
      _cooldownPosition = null;
      _cooldownUntil = null;
      return false;
    }
    return (position - _cooldownPosition!).distance < _threshold;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TapGuardProxyWidget(
      checker: isTappedWithinCooldown,
      child: widget.child,
    );
  }
}

class _TapGuardProxyWidget extends SingleChildRenderObjectWidget {
  final bool Function(Offset position) checker;

  const _TapGuardProxyWidget({
    required this.checker,
    required super.child,
  });

  @override
  RenderTapGuardProxy createRenderObject(BuildContext context) {
    return RenderTapGuardProxy(checker: checker);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderTapGuardProxy renderObject) {
    renderObject.checker = checker;
  }
}

class RenderTapGuardProxy extends RenderProxyBox {
  bool Function(Offset position) checker;

  RenderTapGuardProxy({
    required this.checker,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }

    // If tap falls within cooldown position and time window, absorb it!
    if (checker(position)) {
      return true;
    }

    return super.hitTest(result, position: position);
  }
}

