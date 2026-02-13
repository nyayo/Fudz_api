class UrlUtils {
  static const String baseHost = 'http://129.151.165.133';

  static String? ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    
    // Prepend host for relative URLs
    if (url.startsWith('/')) {
      return '$baseHost$url';
    }
    return '$baseHost/$url';
  }
}
