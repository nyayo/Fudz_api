class UrlUtils {
  static const String baseHost = 'https://unshifter.site';

  static const List<String> _oldHosts = [
    'http://129.151.165.133',
    'https://129.151.165.133',
  ];

  static String? ensureAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) {
      print('⚠️ ensureAbsoluteUrl received null/empty URL');
      return null;
    }

    String workingUrl = url;
    print('🔍 ensureAbsoluteUrl processing: "$workingUrl"');

    for (final oldHost in _oldHosts) {
      if (workingUrl.startsWith(oldHost)) {
        workingUrl = workingUrl.replaceFirst(oldHost, baseHost);
        print('🔍 Replaced old host, result: "$workingUrl"');
        return workingUrl;
      }
    }

    if (workingUrl.startsWith('http://') || workingUrl.startsWith('https://')) {
      print('🔍 URL already absolute, returning: "$workingUrl"');
      return workingUrl;
    }

    if (workingUrl.startsWith('/')) {
      final result = '$baseHost$workingUrl';
      print('🔍 Made URL absolute: "$result"');
      return result;
    }
    
    final result = '$baseHost/$workingUrl';
    print('🔍 Made URL absolute (added slash): "$result"');
    return result;
  }
}
