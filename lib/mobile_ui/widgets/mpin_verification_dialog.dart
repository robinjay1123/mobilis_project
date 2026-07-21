import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/mpin_service.dart';
import '../theme/app_colors.dart';

class MpinVerificationDialog extends StatefulWidget {
  const MpinVerificationDialog({super.key});

  @override
  State<MpinVerificationDialog> createState() => _MpinVerificationDialogState();
}

class _MpinVerificationDialogState extends State<MpinVerificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mpinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _service = MpinService();

  late final bool _isConfigured;
  bool _isSubmitting = false;
  bool _obscureMpin = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _isConfigured = _service.currentState().isConfigured;
  }

  @override
  void dispose() {
    _mpinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateMpin(String? value) {
    final mpin = value?.trim() ?? '';
    if (!RegExp(r'^\d{6}$').hasMatch(mpin)) {
      return 'Enter exactly 6 digits.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final mpin = _mpinController.text.trim();
      if (_isConfigured) {
        if (!_service.verify(mpin)) {
          setState(() {
            _errorText = 'Incorrect MPIN. Please try again.';
            _mpinController.clear();
          });
          return;
        }
      } else {
        await _service.configure(mpin);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = 'Unable to verify MPIN: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.textPrimary
        : AppColors.lightTextPrimary;
    final secondary = isDark
        ? AppColors.textSecondary
        : AppColors.lightTextSecondary;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 14, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pin_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isConfigured ? 'Confirm with MPIN' : 'Create Your MPIN',
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            color: secondary,
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isConfigured
                  ? 'Enter your 6-digit MPIN to authorize this booking and continue to payment.'
                  : 'Set a 6-digit MPIN to protect this and future booking payments.',
              style: TextStyle(color: secondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _mpinController,
              autofocus: true,
              obscureText: _obscureMpin,
              keyboardType: TextInputType.number,
              textInputAction: _isConfigured
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: _validateMpin,
              onFieldSubmitted: (_) {
                if (_isConfigured) _submit();
              },
              decoration: InputDecoration(
                labelText: _isConfigured ? '6-digit MPIN' : 'New 6-digit MPIN',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureMpin = !_obscureMpin),
                  icon: Icon(
                    _obscureMpin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (!_isConfigured) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) {
                  final validation = _validateMpin(value);
                  if (validation != null) return validation;
                  return value == _mpinController.text
                      ? null
                      : 'MPINs do not match.';
                },
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Confirm MPIN',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            minimumSize: const Size(138, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.lock_open_rounded, size: 19),
          label: Text(_isConfigured ? 'Authorize' : 'Set & Continue'),
        ),
      ],
    );
  }
}
