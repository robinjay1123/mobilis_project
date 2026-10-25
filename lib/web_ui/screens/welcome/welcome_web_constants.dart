import 'package:url_launcher/url_launcher.dart';

class WelcomeWebConstants {
  WelcomeWebConstants._();

  static const String hotline1 = '0962-269-9862';
  static const String hotline2 = '0955-281-1306';
  static const String facebookUrl = 'https://www.facebook.com/psdc.dagupan';
  static const String mainOfficeLocation = 'Urdaneta City, Pangasinan, Philippines';
  static const String mainOfficePlusCode = 'XGFW+JQ Urdaneta City, Pangasinan';
  static const String googleMapsLocationUrl =
      'https://maps.app.goo.gl/5YNiPsuy2GTGxdUy7';
  static const String apkDownloadUrl =
      'https://github.com/robinjay1123/mobilis_project/releases/download/APK/mobilis-app_v1.3.3.apk';
  static const String githubReleasesUrl =
      'https://github.com/robinjay1123/mobilis_project/releases';

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
