class UrlUtils {
  static const String baseHost = 'https://unshifter.site';

  static const List<String> _oldHosts = [
    'http://129.151.165.133',
    'https://129.151.165.133',
  ];

  static String? ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    String workingUrl = url;

    for (final oldHost in _oldHosts) {
      if (workingUrl.startsWith(oldHost)) {
        workingUrl = workingUrl.replaceFirst(oldHost, baseHost);
        return workingUrl;
      }
    }

    if (workingUrl.startsWith('http://') || workingUrl.startsWith('https://')) {
      return workingUrl;
    }

    if (workingUrl.startsWith('/')) {
      return '$baseHost$workingUrl';
    }
    return '$baseHost/$workingUrl';
  }
}
