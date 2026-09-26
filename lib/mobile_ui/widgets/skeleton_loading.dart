import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A pure-Flutter, high-performance shimmer container that sweeps a subtle
/// gradient highlight across its children.
class MobilisShimmer extends StatefulWidget {
  final Widget child;
  final bool? isDark;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const MobilisShimmer({
    super.key,
    required this.child,
    this.isDark,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<MobilisShimmer> createState() => _MobilisShimmerState();
}

class _MobilisShimmerState extends State<MobilisShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    final defaultBase = dark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFE2E8F0);
    final defaultHighlight = dark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFFF8FAFC);

    final base = widget.baseColor ?? defaultBase;
    final highlight = widget.highlightColor ?? defaultHighlight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double value = _controller.value;

            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(slidePercent: value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

/// A basic rectangular or pill placeholder block with rounded corners.
class MobilisShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  const MobilisShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.color,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A skeleton item matching the card rows in Mobilis (leading icon box,
/// title bar, subtitle bar, and optional trailing badge).
class MobilisSkeletonCard extends StatelessWidget {
  final bool? isDark;
  final IconData? leadingIcon;
  final double height;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const MobilisSkeletonCard({
    super.key,
    this.isDark,
    this.leadingIcon = Icons.directions_car_filled_rounded,
    this.height = 76,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final cardBg = dark ? const Color(0xFF0F1D2C) : Colors.white;
    final borderColor = dark ? Colors.white10 : const Color(0xFFE2E8F0);
    final placeholderColor = dark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE2E8F0);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                leadingIcon,
                color: dark ? Colors.white24 : Colors.grey.shade400,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 160,
                  height: 14,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                FractionallySizedBox(
                  widthFactor: 0.75,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 24,
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical column or list of skeleton cards wrapped with shimmer animation.
class MobilisSkeletonList extends StatelessWidget {
  final int itemCount;
  final bool? isDark;
  final IconData? leadingIcon;
  final EdgeInsetsGeometry padding;

  const MobilisSkeletonList({
    super.key,
    this.itemCount = 4,
    this.isDark,
    this.leadingIcon = Icons.directions_car_filled_rounded,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return MobilisShimmer(
      isDark: isDark,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            itemCount,
            (index) => MobilisSkeletonCard(
              isDark: isDark,
              leadingIcon: leadingIcon,
            ),
          ),
        ),
      ),
    );
  }
}

/// A vehicle card skeleton with top image area, vehicle model, specs and pricing.
class MobilisSkeletonVehicleCard extends StatelessWidget {
  final bool? isDark;
  final double width;
  final EdgeInsetsGeometry margin;

  const MobilisSkeletonVehicleCard({
    super.key,
    this.isDark,
    this.width = double.infinity,
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final cardBg = dark ? const Color(0xFF0F1D2C) : Colors.white;
    final borderColor = dark ? Colors.white10 : const Color(0xFFE2E8F0);
    final placeholderColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vehicle Image Area Placeholder
          Container(
            height: 140,
            width: double.infinity,
            color: placeholderColor,
            child: Center(
              child: Icon(
                Icons.directions_car_rounded,
                size: 42,
                color: dark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 130,
                      height: 14,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 18,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: 90,
                  height: 10,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 75,
                      height: 24,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical list or grid of vehicle card skeletons for exploration / catalogs.
class MobilisSkeletonVehicleGrid extends StatelessWidget {
  final int count;
  final bool? isDark;
  final EdgeInsetsGeometry padding;

  const MobilisSkeletonVehicleGrid({
    super.key,
    this.count = 3,
    this.isDark,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return MobilisShimmer(
      isDark: isDark,
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(
            count,
            (index) => MobilisSkeletonVehicleCard(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

/// A dashboard skeleton with top summary metrics tiles and a list of cards below.
class MobilisSkeletonDashboard extends StatelessWidget {
  final bool? isDark;
  final EdgeInsetsGeometry padding;

  const MobilisSkeletonDashboard({
    super.key,
    this.isDark,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final cardBg = dark ? const Color(0xFF0F1D2C) : Colors.white;
    final borderColor = dark ? Colors.white10 : const Color(0xFFE2E8F0);
    final placeholderColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return MobilisShimmer(
      isDark: dark,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header greeting skeleton
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 90,
                      height: 10,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2x2 Stats Summary Grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 84,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 10,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 80,
                          height: 18,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 84,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 10,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 70,
                          height: 18,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section title bar
            Container(
              width: 120,
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 14),

            // List of cards
            for (int i = 0; i < 3; i++)
              MobilisSkeletonCard(isDark: dark),
          ],
        ),
      ),
    );
  }
}

/// The exact radar pulse + satellite telemetry indicator that the user highlighted,
/// designed to work seamlessly in both mobile and web views.
class MobilisSkeletonTrackingRadar extends StatefulWidget {
  final bool? isDark;
  final Color accentColor;
  final String title;
  final String subtitle;
  final double height;
  final bool showCardsBelow;

  const MobilisSkeletonTrackingRadar({
    super.key,
    this.isDark,
    this.accentColor = AppColors.primary,
    this.title = 'Fetching live GPS tracker signals...',
    this.subtitle = 'Querying satellite telemetry & vehicle GPS units. Please wait a moment...',
    this.height = 320,
    this.showCardsBelow = true,
  });

  @override
  State<MobilisSkeletonTrackingRadar> createState() =>
      _MobilisSkeletonTrackingRadarState();
}

class _MobilisSkeletonTrackingRadarState
    extends State<MobilisSkeletonTrackingRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final accent = widget.accentColor;
    final bgColor = dark ? const Color(0xFF031A2C) : const Color(0xFFF1F5F9);
    final cardBg = dark ? const Color(0xFF08273E) : Colors.white;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(double.infinity, widget.height),
                  painter: _RadarGridPainter(
                    lineColor: dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: _pulseAnimation.value * 1.35,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(
                                  alpha: _opacityAnimation.value * 0.4,
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(
                                alpha: _opacityAnimation.value * 0.12,
                              ),
                              border: Border.all(
                                color: accent.withValues(
                                  alpha: _opacityAnimation.value * 0.7,
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        child!,
                      ],
                    );
                  },
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBg,
                      border: Border.all(color: accent, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        Icon(
                          Icons.radar_rounded,
                          size: 30,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: (dark ? const Color(0xFF0F172A) : Colors.white)
                              .withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: dark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: dark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.showCardsBelow) ...[
            const SizedBox(height: 14),
            MobilisSkeletonList(
              isDark: dark,
              itemCount: 3,
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  final Color lineColor;

  _RadarGridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2 - 18);

    for (double r = 35; r <= 150; r += 38) {
      canvas.drawCircle(center, r, paint);
    }

    canvas.drawLine(
      Offset(center.dx - 160, center.dy),
      Offset(center.dx + 160, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 120),
      Offset(center.dx, center.dy + 120),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

/// A full-screen / modal skeleton placeholder matching the BookingDetailModal layout:
/// - Overview & status header card with reference number and status badges
/// - Vehicle information card with car icon, title, plate, specs tags
/// - Renter information card with avatar circle, name, masked contact info, call button
/// - Trip schedule & route card with start/end date-times, duration, pickup & dropoff
/// - Pricing & payment breakdown card with rates, total price, payment state
/// - Action buttons bar
class MobilisSkeletonBookingDetail extends StatelessWidget {
  final bool? isDark;
  final bool showHeader;
  final VoidCallback? onClose;

  const MobilisSkeletonBookingDetail({
    super.key,
    this.isDark,
    this.showHeader = true,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final cardBg = dark ? const Color(0xFF0F1D2C) : Colors.white;
    final borderColor = dark ? Colors.white10 : const Color(0xFFE2E8F0);
    final placeholderColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return MobilisShimmer(
      isDark: dark,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 140,
                    height: 18,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(
                      Icons.close,
                      color: dark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 1. Overview & Status Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 110,
                        height: 11,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 130,
                        height: 18,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 75,
                        height: 24,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 85,
                        height: 24,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Vehicle Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 160,
                              height: 15,
                              decoration: BoxDecoration(
                                color: placeholderColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 90,
                              height: 11,
                              decoration: BoxDecoration(
                                color: placeholderColor,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 22,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(
                      4,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 65,
                        height: 22,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Renter Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 14,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 100,
                          height: 11,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 32,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Trip Schedule & Route Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 20,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: placeholderColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: placeholderColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 38,
                    decoration: BoxDecoration(
                      color: placeholderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 5. Pricing & Financials Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 90,
                        height: 12,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 110,
                        height: 16,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 18,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 6. Action Buttons Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton placeholder for the unified profile screen, including
/// the top profile card with avatar and stats row, followed by settings tiles.
class MobilisSkeletonProfile extends StatelessWidget {
  final bool? isDark;

  const MobilisSkeletonProfile({super.key, this.isDark});

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final cardColor = dark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary;
    final placeholderColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final borderColor = dark ? AppColors.borderColor : AppColors.lightBorderColor;

    return MobilisShimmer(
      isDark: dark,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // 1. Profile Top Card Skeleton
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar Box
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 20,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 14,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 180,
                            height: 12,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats Row
                Row(
                  children: List.generate(
                    3,
                    (index) => Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < 2 ? 10 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 2. Settings Tiles Skeletons
          ...List.generate(
            5,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 130,
                          height: 15,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 190,
                          height: 11,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

