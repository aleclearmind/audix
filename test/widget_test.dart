import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audix/app.dart';
import 'package:audix/core/audio/audio_providers.dart';
import 'package:audix/core/database/database.dart';
import 'package:audix/core/providers.dart';
import 'package:audix/core/settings/settings_controller.dart';
import 'package:audix/features/startup/startup_screen.dart';

void main() {
  testWidgets('App boots to an empty Library', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryEntriesProvider
              .overrideWith((ref) => Stream.value(const <LibraryEntry>[])),
          serversProvider.overrideWith((ref) => Stream.value(const <Server>[])),
          allBookmarksProvider
              .overrideWith((ref) => Stream.value(const <BookmarkEntry>[])),
          mediaItemProvider.overrideWith((ref) => Stream.value(null)),
          restoreLastBookProvider.overrideWith((ref) async => false),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AudixApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsWidgets);
    expect(find.text('No audiobooks yet'), findsOneWidget);
  });

  testWidgets('Startup opens the restored player over the Library', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryEntriesProvider
              .overrideWith((ref) => Stream.value(const <LibraryEntry>[])),
          serversProvider.overrideWith((ref) => Stream.value(const <Server>[])),
          allBookmarksProvider
              .overrideWith((ref) => Stream.value(const <BookmarkEntry>[])),
          mediaItemProvider.overrideWith((ref) => Stream.value(null)),
          restoreLastBookProvider.overrideWith((ref) async => true),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: StartupScreen(
            homeBuilder: (_) => const Scaffold(
              body: Center(child: Text('Library home')),
            ),
            playerBuilder: (_) => const Scaffold(
              body: Center(child: Text('Restored player')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restored player'), findsOneWidget);
    Navigator.of(tester.element(find.text('Restored player'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Library home'), findsOneWidget);
  });
}
