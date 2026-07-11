import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../theme/app_colors.dart';

class MobilisImageCache {
  MobilisImageCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'mobilis_network_images_v1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 600,
    ),
  );

  static String cacheKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final isSupabaseSignedObject = uri.path.contains(
      '/storage/v1/object/sign/',
    );
    if (!isSupabaseSignedObject) return url;
    final stableQuery = Map<String, String>.from(uri.queryParameters)
      ..remove('token');
    return uri
        .replace(
          queryParameters: stableQuery.isEmpty ? null : stableQuery,
          fragment: null,
        )
        .toString();
  }
}

class OptimizedNetworkImage extends StatelessWidget {
  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isThumbnail = true,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isThumbnail;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final targetWidth = width == null
        ? (isThumbnail ? 720 : 1920)
        : (width! * pixelRatio).round();
    final targetHeight = height == null ? null : (height! * pixelRatio).round();
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: MobilisImageCache.cacheKey(imageUrl),
      cacheManager: MobilisImageCache.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: targetWidth,
      memCacheHeight: targetHeight,
      maxWidthDiskCache: isThumbnail ? 960 : 2048,
      fadeInDuration: const Duration(milliseconds: 140),
      placeholder: (_, __) => placeholder ?? const _ImageLoadingPlaceholder(),
      errorWidget: (_, __, ___) =>
          errorWidget ?? const _ImageErrorPlaceholder(),
    );

    return borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class OptimizedNetworkImageProvider extends CachedNetworkImageProvider {
  OptimizedNetworkImageProvider(String url)
    : super(
        url,
        cacheKey: MobilisImageCache.cacheKey(url),
        cacheManager: MobilisImageCache.instance,
      );
}

class OnDemandNetworkImage extends StatefulWidget {
  const OnDemandNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.label = 'Tap to load document',
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String label;

  @override
  State<OnDemandNetworkImage> createState() => _OnDemandNetworkImageState();
}

class _OnDemandNetworkImageState extends State<OnDemandNetworkImage> {
  bool _showImage = false;

  @override
  Widget build(BuildContext context) {
    if (_showImage) {
      return OptimizedNetworkImage(
        imageUrl: widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        isThumbnail: false,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Material(
        color: AppColors.darkBgTertiary,
        child: InkWell(
          onTap: () => setState(() => _showImage = true),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.darkBgTertiary,
    child: Center(
      child: SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.darkBgTertiary,
    child: Center(
      child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
    ),
  );
}
