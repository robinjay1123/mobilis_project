import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_colors.dart';

class SignatureCaptureScreen extends StatefulWidget {
  final String title;
  final Uint8List? initialSignature;

  const SignatureCaptureScreen({
    super.key,
    required this.title,
    this.initialSignature,
  });

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final List<Offset?> _points = [];
  bool _saving = false;
  bool _showInitialSignature = true;

  bool get _hasDrawnSignature => _points.whereType<Offset>().length >= 6;

  void _startStroke(Offset point) {
    setState(() {
      if (_showInitialSignature) {
        _showInitialSignature = false;
        _points.clear();
      }
      _points.add(point);
    });
  }

  void _clear() {
    setState(() {
      _showInitialSignature = false;
      _points.clear();
    });
  }

  Future<void> _save() async {
    if (!_hasDrawnSignature) {
      if (_showInitialSignature && widget.initialSignature != null) {
        Navigator.pop(context, widget.initialSignature);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw your signature before saving.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Signature board is not ready');
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Signature could not be saved');
      }
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInitial = _showInitialSignature && widget.initialSignature != null;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign inside the large area below using your finger.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: RepaintBoundary(
                  key: _captureKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) =>
                        _startStroke(details.localPosition),
                    onPanUpdate: (details) =>
                        setState(() => _points.add(details.localPosition)),
                    onPanEnd: (_) => setState(() => _points.add(null)),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _hasDrawnSignature || hasInitial
                              ? AppColors.success
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasInitial
                          ? Image.memory(
                              widget.initialSignature!,
                              fit: BoxFit.contain,
                            )
                          : CustomPaint(
                              painter: _FullScreenSignaturePainter(_points),
                              child: _points.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Draw your signature here',
                                        style: TextStyle(
                                          color: Colors.black38,
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _clear,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving...' : 'Save Signature'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenSignaturePainter extends CustomPainter {
  final List<Offset?> points;

  const _FullScreenSignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      } else if (current != null) {
        canvas.drawCircle(current, 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FullScreenSignaturePainter oldDelegate) => true;
}
