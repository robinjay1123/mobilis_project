import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';

/// Full-screen camera interface for capturing a Selfie with ID.
/// Features a dedicated viewport outline overlay that guides the user
/// to align their face in the upper oval and their ID card in the lower rectangle.
class SelfieWithIdCameraScreen extends StatefulWidget {
  const SelfieWithIdCameraScreen({super.key});

  /// Opens the camera screen and returns the captured [File], or null if cancelled.
  static Future<File?> open(BuildContext context) async {
    return await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => const SelfieWithIdCameraScreen(),
      ),
    );
  }

  @override
  State<SelfieWithIdCameraScreen> createState() =>
      _SelfieWithIdCameraScreenState();
}

class _SelfieWithIdCameraScreenState extends State<SelfieWithIdCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  File? _previewPhoto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(cameraController.description);
    }
  }

  Future<void> _initCameras() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'No camera hardware detected on this device. You can still use the system camera or upload from gallery.';
        });
        return;
      }

      // Default to front camera for selfie with ID
      int frontIndex = _availableCameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex >= 0 ? frontIndex : 0;

      await _initCameraController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Error discovering cameras: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Camera access was denied or could not be initialized. Please check camera permissions in your settings.';
        });
      }
    }
  }

  Future<void> _initCameraController(CameraDescription description) async {
    final oldController = _controller;
    if (oldController != null) {
      await oldController.dispose();
    }

    final newController = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = newController;

    try {
      await newController.initialize();
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Failed to start camera feed: $e. You can try the system camera fallback.';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isCapturing) return;

    _selectedCameraIndex =
        (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() => _isInitializing = true);
    await _initCameraController(_availableCameras[_selectedCameraIndex]);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile xFile = await controller.takePicture();
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _previewPhoto = File(xFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _fallbackPickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked != null && mounted) {
        Navigator.of(context).pop(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _previewPhoto != null
            ? _buildReviewScreen()
            : _errorMessage != null
                ? _buildErrorScreen()
                : _isInitializing
                    ? _buildLoadingScreen()
                    : _buildCameraFeedScreen(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 56,
              color: AppColors.warning,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Unable to start camera preview.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _fallbackPickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Open System Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _fallbackPickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Choose from Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraFeedScreen() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final isFrontCamera =
        controller.description.lensDirection == CameraLensDirection.front;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview Feed
        Center(
          child: CameraPreview(controller),
        ),

        // Custom Outline Overlay (Cutout with Face Oval and ID Card Rectangle)
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SelfieWithIdOverlayPainter(),
            ),
          ),
        ),

        // Top Navigation Bar and Instructions
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Selfie with ID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_availableCameras.length > 1)
                      IconButton(
                        icon: Icon(
                          isFrontCamera
                              ? Icons.camera_front
                              : Icons.camera_rear,
                          color: Colors.white,
                        ),
                        tooltip: 'Switch camera',
                        onPressed: _switchCamera,
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Align Face in Oval & ID Card in Rectangle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Controls Bar (Shutter button and fallback)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Fallback Gallery button
                IconButton(
                  tooltip: 'Choose from Gallery',
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: () => _fallbackPickImage(ImageSource.gallery),
                ),

                // Shutter Button
                GestureDetector(
                  onTap: _isCapturing ? null : _takePicture,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.transparent,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.black),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                              size: 32,
                            ),
                    ),
                  ),
                ),

                // Fallback Native Camera button
                IconButton(
                  tooltip: 'System Camera',
                  icon: const Icon(
                    Icons.settings_overscan,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: () => _fallbackPickImage(ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewScreen() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _previewPhoto = null),
              ),
              const Text(
                'Review Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Photo Preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              _previewPhoto!,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
        ),

        // Verification Checklist Notice
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verification Quality Check:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(
                    'Your entire face is clearly visible',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(
                    'Name and ID photo are readable and glare-free',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Review Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _previewPhoto = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retake'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_previewPhoto);
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Use Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter that draws the darkened cutout overlay with:
/// 1. A rounded Face Oval in the upper section
/// 2. An ID Card rectangle in the lower-middle section
/// 3. Glowing alignment corner brackets, dashed outlines, and visual guides
class SelfieWithIdOverlayPainter extends CustomPainter {
  const SelfieWithIdOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final isLandscape = size.width > size.height;

    Rect faceRect;
    RRect idRRect;

    if (isLandscape) {
      // Landscape: Face on left half, ID card on right half
      final faceCenterX = size.width * 0.32;
      final faceCenterY = size.height * 0.50;
      final faceRadiusX = size.height * 0.22;
      final faceRadiusY = size.height * 0.30;
      faceRect = Rect.fromCenter(
        center: Offset(faceCenterX, faceCenterY),
        width: faceRadiusX * 2,
        height: faceRadiusY * 2,
      );

      final idCenterX = size.width * 0.70;
      final idCenterY = size.height * 0.50;
      const idRatio = 85.6 / 53.98; // standard credit card aspect ratio ~1.58
      final idHeight = size.height * 0.48;
      final idWidth = idHeight * idRatio;
      idRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(idCenterX, idCenterY),
          width: idWidth,
          height: idHeight,
        ),
        const Radius.circular(14),
      );
    } else {
      // Portrait: Face Oval in upper area, ID Card in lower area
      final faceCenterX = size.width * 0.50;
      final faceCenterY = size.height * 0.30;
      final faceRadiusX = size.width * 0.25;
      final faceRadiusY = size.height * 0.16;
      faceRect = Rect.fromCenter(
        center: Offset(faceCenterX, faceCenterY),
        width: faceRadiusX * 2,
        height: faceRadiusY * 2,
      );

      final idCenterX = size.width * 0.50;
      final idCenterY = size.height * 0.65;
      const idRatio = 85.6 / 53.98; // standard credit card aspect ratio ~1.58
      final idWidth = (size.width * 0.78).clamp(220.0, 320.0);
      final idHeight = idWidth / idRatio;
      idRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(idCenterX, idCenterY),
          width: idWidth,
          height: idHeight,
        ),
        const Radius.circular(14),
      );
    }

    // 1. Draw darkened transparent mask outside the guide frames
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final facePath = Path()..addOval(faceRect);
    final idPath = Path()..addRRect(idRRect);

    Path combinedMask =
        Path.combine(PathOperation.difference, backgroundPath, facePath);
    combinedMask =
        Path.combine(PathOperation.difference, combinedMask, idPath);

    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(combinedMask, maskPaint);

    // 2. Draw Face Oval Guide Line
    final guideBorderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawOval(faceRect, guideBorderPaint);

    // Subtle dashed tick marks around face oval
    final softPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(
      faceRect.inflate(6),
      softPaint,
    );

    // 3. Draw ID Card Guide Line & Rounded Corner Brackets
    canvas.drawRRect(idRRect, guideBorderPaint);

    // High-visibility Corner Brackets for ID Card
    final bracketPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final idRect = idRRect.outerRect;
    const bracketLen = 22.0;

    // Top-left bracket
    canvas.drawLine(
      Offset(idRect.left, idRect.top + bracketLen),
      Offset(idRect.left, idRect.top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(idRect.left, idRect.top),
      Offset(idRect.left + bracketLen, idRect.top),
      bracketPaint,
    );

    // Top-right bracket
    canvas.drawLine(
      Offset(idRect.right - bracketLen, idRect.top),
      Offset(idRect.right, idRect.top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(idRect.right, idRect.top),
      Offset(idRect.right, idRect.top + bracketLen),
      bracketPaint,
    );

    // Bottom-left bracket
    canvas.drawLine(
      Offset(idRect.left, idRect.bottom - bracketLen),
      Offset(idRect.left, idRect.bottom),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(idRect.left, idRect.bottom),
      Offset(idRect.left + bracketLen, idRect.bottom),
      bracketPaint,
    );

    // Bottom-right bracket
    canvas.drawLine(
      Offset(idRect.right - bracketLen, idRect.bottom),
      Offset(idRect.right, idRect.bottom),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(idRect.right, idRect.bottom),
      Offset(idRect.right, idRect.bottom - bracketLen),
      bracketPaint,
    );

    // 4. Draw Guide Labels on Canvas
    _drawLabelBadge(
      canvas: canvas,
      center: Offset(faceRect.center.dx, faceRect.top - 16),
      label: 'CENTER FACE HERE',
      icon: '👤',
    );

    _drawLabelBadge(
      canvas: canvas,
      center: Offset(idRRect.center.dx, idRRect.top - 16),
      label: 'HOLD ID CARD HERE (FRONT)',
      icon: '🪪',
    );
  }

  void _drawLabelBadge({
    required Canvas canvas,
    required Offset center,
    required String label,
    required String icon,
  }) {
    final textSpan = TextSpan(
      text: '$icon $label',
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromCenter(
      center: center,
      width: textPainter.width + 16,
      height: textPainter.height + 8,
    );

    final badgeBgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final badgeBorderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(12)),
      badgeBgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(12)),
      badgeBorderPaint,
    );

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
