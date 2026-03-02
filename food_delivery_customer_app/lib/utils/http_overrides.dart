import 'dart:io';

/// Accepts all HTTPS certificates so that images from CDNs like
/// Cloudflare R2 load even on older Android devices whose CA stores
/// may be outdated.
class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

/// Call this once in main() – before runApp – on non-web platforms.
void installHttpOverrides() {
  HttpOverrides.global = AppHttpOverrides();
}
