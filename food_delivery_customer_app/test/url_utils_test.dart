import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery_customer_app/utils/url_utils.dart';

void main() {
  group('UrlUtils Tests', () {
    test('ensureAbsoluteUrl returns null for null/empty input', () {
      expect(UrlUtils.ensureAbsoluteUrl(null), isNull);
      expect(UrlUtils.ensureAbsoluteUrl(''), isNull);
    });

    test('ensureAbsoluteUrl leaves absolute URLs unchanged', () {
      const String httpUrl = 'http://example.com/image.jpg';
      const String httpsUrl = 'https://example.com/image.jpg';
      
      expect(UrlUtils.ensureAbsoluteUrl(httpUrl), httpUrl);
      expect(UrlUtils.ensureAbsoluteUrl(httpsUrl), httpsUrl);
    });

    test('ensureAbsoluteUrl prepends host to relative URLs', () {
      const String relativeWithSlash = '/media/item.jpg';
      const String relativeWithoutSlash = 'media/item.jpg';
      const String expected = 'http://129.151.165.133/media/item.jpg';
      
      expect(UrlUtils.ensureAbsoluteUrl(relativeWithSlash), expected);
      expect(UrlUtils.ensureAbsoluteUrl(relativeWithoutSlash), expected);
    });
  });
}
