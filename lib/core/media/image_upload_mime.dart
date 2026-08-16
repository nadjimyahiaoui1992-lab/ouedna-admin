/// Normalise les noms de fichiers avant un téléversement Supabase Storage.
///
/// Le type MIME `image/jpg` n'est pas standard : les fichiers JPG et JPEG
/// doivent toujours être envoyés comme `image/jpeg`.
class ImageUploadMime {
  static String normalizedExtension(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final extension =
        normalized.contains('.') ? normalized.split('.').last : '';

    switch (extension) {
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'jpeg';
    }
  }

  static String contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
