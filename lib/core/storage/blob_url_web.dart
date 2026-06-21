import 'dart:js_interop';
import 'dart:typed_data';

// `web` ships with the Flutter web SDK; it's referenced only from this web-only
// file, so it isn't declared as a direct dependency.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Wraps [bytes] in an object URL so just_audio (HTMLAudioElement) can play them.
String objectUrlFromBytes(Uint8List bytes, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

void revokeObjectUrl(String url) => web.URL.revokeObjectURL(url);
