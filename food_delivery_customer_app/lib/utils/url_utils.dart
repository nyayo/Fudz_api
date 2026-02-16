class UrlUtils {
  static const String baseHost = 'https://unshifter.site';

  // Known old hosts that should be replaced with the current baseHost
  static const List<String> _oldHosts = [
    'http://129.151.165.133',
    'https://129.151.165.133',
  ];

  static String? ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Normalize old IP-based URLs to use the current domain
    for (final oldHost in _oldHosts) {
      if (url!.startsWith(oldHost)) {
        url = url.replaceFirst(oldHost, baseHost);
        return url;
      }
    }

    if (url!.startsWith('http://') || url.startsWith('https://')) return url;

    // Prepend host for relative URLs
    if (url.startsWith('/')) {
      return '$baseHost$url';
    }
    return '$baseHost/$url';
  }
}
