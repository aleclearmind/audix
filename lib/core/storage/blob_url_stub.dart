import 'dart:typed_data';

/// Non-web stub. These are only ever called on the web (guarded by kIsWeb).
String objectUrlFromBytes(Uint8List bytes, String mimeType) =>
    throw UnsupportedError('Blob URLs are only available on the web');

void revokeObjectUrl(String url) {}
