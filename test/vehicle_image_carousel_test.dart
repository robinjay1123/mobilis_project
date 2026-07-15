import 'package:flutter_test/flutter_test.dart';
import 'package:mobilis_by_psdc_app/mobile_ui/widgets/vehicle_image_carousel.dart';

void main() {
  test(
    'vehicleImageUrls sorts, deduplicates, and keeps the fallback image',
    () {
      final urls = vehicleImageUrls({
        'image_url': 'https://example.com/primary.jpg',
        'vehicle_images': [
          {'image_url': 'https://example.com/back.jpg', 'display_order': 2},
          {'image_url': 'https://example.com/primary.jpg', 'display_order': 0},
          {'image_url': 'https://example.com/side.jpg', 'display_order': 1},
        ],
      });

      expect(urls, [
        'https://example.com/primary.jpg',
        'https://example.com/side.jpg',
        'https://example.com/back.jpg',
      ]);
    },
  );
}
