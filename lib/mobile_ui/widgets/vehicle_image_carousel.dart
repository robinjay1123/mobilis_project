import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'optimized_network_image.dart';

List<String> vehicleImageUrls(Map<String, dynamic> vehicle) {
  final orderedImages = <Map<String, dynamic>>[];
  final rawImages = vehicle['vehicle_images'];
  if (rawImages is List) {
    for (final rawImage in rawImages) {
      if (rawImage is Map) {
        orderedImages.add(Map<String, dynamic>.from(rawImage));
      }
    }
  }

  orderedImages.sort((a, b) {
    final aOrder = (a['display_order'] as num?)?.toInt() ?? 9999;
    final bOrder = (b['display_order'] as num?)?.toInt() ?? 9999;
    return aOrder.compareTo(bOrder);
  });

  final urls = <String>[];
  void addUrl(dynamic value) {
    final raw = value?.toString().trim();
    if (raw != null && raw.isNotEmpty) {
      var url = raw;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        final path = url.startsWith('/') ? url.substring(1) : url;
        url = Supabase.instance.client.storage
            .from('vehicle_images')
            .getPublicUrl(path);
      }
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  for (final image in orderedImages) {
    addUrl(image['image_url']);
  }
  addUrl(vehicle['image_url']);
  return urls;
}

class VehicleImageCarousel extends StatefulWidget {
  const VehicleImageCarousel({
    super.key,
    required this.vehicle,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.isThumbnail = true,
    this.backgroundColor,
    this.iconColor,
    this.showArrows = true,
    this.showIndicator = true,
  });

  final Map<String, dynamic> vehicle;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final bool isThumbnail;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool showArrows;
  final bool showIndicator;

  @override
  State<VehicleImageCarousel> createState() => _VehicleImageCarouselState();
}

class _VehicleImageCarouselState extends State<VehicleImageCarousel> {
  late final PageController _pageController;
  var _currentPage = 0;

  List<String> get _images => vehicleImageUrls(widget.vehicle);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant VehicleImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final imageCount = _images.length;
    if (_currentPage >= imageCount && _currentPage != 0) {
      _currentPage = imageCount > 0 ? imageCount - 1 : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final backgroundColor =
        widget.backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainer;
    final iconColor =
        widget.iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    final content = images.isEmpty
        ? ColoredBox(
            color: backgroundColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car, size: 46, color: iconColor),
                  const SizedBox(height: 6),
                  Text(
                    'No images available',
                    style: TextStyle(fontSize: 11, color: iconColor),
                  ),
                ],
              ),
            ),
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => OptimizedNetworkImage(
                  imageUrl: images[index],
                  fit: widget.fit,
                  isThumbnail: widget.isThumbnail,
                  errorWidget: ColoredBox(
                    color: backgroundColor,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 42,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              ),
              if (images.length > 1 && widget.showArrows) ...[
                _CarouselArrow(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left,
                  onTap: _currentPage > 0
                      ? () => _goToPage(_currentPage - 1)
                      : null,
                ),
                _CarouselArrow(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right,
                  onTap: _currentPage < images.length - 1
                      ? () => _goToPage(_currentPage + 1)
                      : null,
                ),
              ],
              if (images.length > 1 && widget.showIndicator)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          images.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: index == _currentPage ? 15 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: index == _currentPage
                                  ? const Color(0xFFFFD600)
                                  : Colors.white70,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (images.length > 1)
                Positioned(
                  left: 10,
                  bottom: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${_currentPage + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          );

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: content,
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  final Alignment alignment;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: IgnorePointer(
          ignoring: onTap == null,
          child: AnimatedOpacity(
            opacity: onTap == null ? 0.3 : 1,
            duration: const Duration(milliseconds: 160),
            child: Material(
              color: Colors.black.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 34,
                  height: 42,
                  child: Icon(icon, color: Colors.white, size: 25),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
