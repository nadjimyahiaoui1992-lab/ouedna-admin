import 'package:flutter_test/flutter_test.dart';
import 'package:ouedna_admin/core/media/image_upload_mime.dart';

void main() {
  group('ImageUploadMime', () {
    test('normalise JPG et JPEG vers l’extension et le MIME standards', () {
      expect(ImageUploadMime.normalizedExtension('photo.jpg'), 'jpeg');
      expect(ImageUploadMime.normalizedExtension('photo.JPEG'), 'jpeg');
      expect(ImageUploadMime.contentTypeForExtension('jpg'), 'image/jpeg');
      expect(ImageUploadMime.contentTypeForExtension('jpeg'), 'image/jpeg');
    });

    test('conserve PNG et WebP avec leur MIME correct', () {
      expect(ImageUploadMime.normalizedExtension('photo.png'), 'png');
      expect(ImageUploadMime.contentTypeForExtension('png'), 'image/png');
      expect(ImageUploadMime.normalizedExtension('photo.webp'), 'webp');
      expect(ImageUploadMime.contentTypeForExtension('webp'), 'image/webp');
    });
  });
}
