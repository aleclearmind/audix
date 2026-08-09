import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audix/core/audio/audio_providers.dart';
import 'package:audix/core/database/database.dart';
import 'package:audix/features/player/transcript_screen.dart';

void main() {
  testWidgets('opens focused on the currently playing subtitle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cues = [
      for (var i = 0; i < 600; i++)
        SubtitleCueRow(
          id: i,
          bookId: 1,
          cueIndex: i,
          startMs: i * 1000,
          endMs: (i + 1) * 1000,
          content: 'Subtitle line $i',
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSubtitlesProvider.overrideWith((ref) => Stream.value(cues)),
          positionProvider.overrideWith(
            (ref) => Stream.value(const Duration(milliseconds: 500500)),
          ),
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState()),
          ),
        ],
        child: const MaterialApp(home: TranscriptScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final current = find.text('Subtitle line 500');
    expect(current, findsOneWidget);

    final centre = tester.getCenter(current);
    expect(centre.dy, greaterThan(250));
    expect(centre.dy, lessThan(550));

    await tester.drag(current, const Offset(0, 300));
    await tester.pumpAndSettle();

    final restoredCentre = tester.getCenter(current);
    expect(restoredCentre.dy, greaterThan(250));
    expect(restoredCentre.dy, lessThan(550));
  });
}
