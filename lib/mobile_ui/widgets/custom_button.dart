import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/database_health_service.dart';
import '../theme/app_colors.dart';

/// Reusable application button equipped with anti-spam button guards,
/// debounce protection, and automatic database health error handling.
class CustomButton extends StatefulWidget {
  final String label;
  final FutureOr<void> Function()? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final Duration cooldown;
  final Widget? icon;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 12,
    this.cooldown = const Duration(milliseconds: 1000),
    this.icon,
    this.height,
    this.width,
    this.padding,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isLocallyExecuting = false;
  DateTime? _lastPressedAt;

  Future<void> _handlePress() async {
    final now = DateTime.now();
    // Guard against spam or concurrent taps
    if (widget.isLoading || _isLocallyExecuting || widget.onPressed == null) {
      return;
    }

    if (_lastPressedAt != null &&
        now.difference(_lastPressedAt!) < widget.cooldown) {
      return;
    }
    _lastPressedAt = now;

    try {
      final result = widget.onPressed!();
      if (result is Future) {
        if (mounted) setState(() => _isLocallyExecuting = true);
        await result;
      }
    } catch (e) {
      if (mounted) {
        DatabaseHealthService.handlePossibleDatabaseError(e, context);
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLocallyExecuting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isLoading || _isLocallyExecuting;
    final isDisabled = widget.onPressed == null;

    final baseBg = widget.backgroundColor ?? AppColors.primary;
    final effectiveBg =
        isDisabled ? baseBg.withValues(alpha: 0.5) : baseBg;
    final effectiveFg = widget.textColor ?? Colors.black;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 48,
      child: ElevatedButton(
        onPressed: busy || isDisabled ? null : _handlePress,
        style: ElevatedButton.styleFrom(
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: effectiveBg,
          foregroundColor: effectiveFg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          elevation: 0,
          disabledBackgroundColor: baseBg.withValues(alpha: 0.5),
          disabledForegroundColor: effectiveFg.withValues(alpha: 0.5),
        ),
        child: busy
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    widget.icon!,
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
