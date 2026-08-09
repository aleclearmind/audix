import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audiobook_handler.dart';

const _channel = MethodChannel('audix/widget');

/// Mirrors the small amount of playback state needed by the native Android
/// home-screen widget. Other platforms never invoke the channel.
void bindAndroidWidget(AudiobookHandler handler) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  MediaItem? item = handler.mediaItem.value;
  var playing = handler.playbackState.value.playing;
  String? lastState;

  void sync() {
    final state =
        '${item?.id}|${item?.title}|${item?.displaySubtitle}|$playing';
    if (state == lastState) return;
    lastState = state;
    unawaited(
      _channel
          .invokeMethod<void>('sync', {
            'title': item?.title,
            'subtitle': item?.displaySubtitle ?? item?.artist,
            'playing': playing,
          })
          .catchError((Object _) {
            // The channel is absent on tests and can briefly be unavailable while
            // Android attaches an Activity to an already-running audio engine.
          }),
    );
  }

  handler.mediaItem.listen((value) {
    item = value;
    sync();
  });
  handler.playbackState.listen((value) {
    playing = value.playing;
    sync();
  });
  sync();
}
