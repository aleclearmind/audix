import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audix/core/database/database.dart';
import 'package:audix/core/util/format.dart';
import 'package:audix/features/bookmarks/bookmarks_sheet.dart';

Bookmark _bookmark({
  required int id,
  required int positionMs,
  required DateTime createdAt,
  int bookId = 1,
  BookmarkKind kind = BookmarkKind.manual,
}) =>
    Bookmark(
      id: id,
      bookId: bookId,
      positionMs: positionMs,
      chapterIndex: 0,
      note: null,
      kind: kind,
      createdAt: createdAt,
    );

void main() {
  final bookmarks = [
    _bookmark(id: 1, positionMs: 3000, createdAt: DateTime(2024, 1, 2)),
    _bookmark(id: 2, positionMs: 1000, createdAt: DateTime(2024, 1, 3)),
    _bookmark(id: 3, positionMs: 2000, createdAt: DateTime(2024, 1, 1)),
  ];

  test('sorts by creation time newest first', () {
    expect(
      sortBookmarks(bookmarks, BookmarkSort.creation).map((b) => b.id),
      [2, 1, 3],
    );
  });

  test('sorts by bookmark time from earliest position', () {
    expect(
      sortBookmarks(bookmarks, BookmarkSort.bookmarkTime).map((b) => b.id),
      [2, 3, 1],
    );
  });

  test('does not mutate the source list', () {
    sortBookmarks(bookmarks, BookmarkSort.creation);

    expect(bookmarks.map((b) => b.id), [1, 2, 3]);
  });

  test('formats bookmark day headings', () {
    final now = DateTime(2024, 8, 9, 12);

    expect(formatDayHeading(DateTime(2024, 8, 9), now: now), 'Today');
    expect(formatDayHeading(DateTime(2024, 8, 8), now: now), 'Yesterday');
    expect(formatDayHeading(DateTime(2024, 7, 3), now: now), 'July 3');
    expect(formatDayHeading(DateTime(2023, 7, 3), now: now), 'July 3 2023');
  });

  test('pairs start bookmarks with the following stop per book', () {
    final sessions = startBookmarkPlaybackDurations([
      _bookmark(
        id: 4,
        positionMs: 0,
        createdAt: DateTime(2024, 1, 1, 10, 30),
        kind: BookmarkKind.autoStop,
      ),
      _bookmark(
        id: 1,
        positionMs: 0,
        createdAt: DateTime(2024, 1, 1, 10),
        kind: BookmarkKind.autoStart,
      ),
      _bookmark(
        id: 2,
        bookId: 2,
        positionMs: 0,
        createdAt: DateTime(2024, 1, 1, 10, 5),
        kind: BookmarkKind.autoStart,
      ),
      _bookmark(
        id: 3,
        positionMs: 0,
        createdAt: DateTime(2024, 1, 1, 10, 10),
      ),
    ]);

    expect(sessions[1], const Duration(minutes: 30));
    expect(sessions.containsKey(2), isTrue);
    expect(sessions[2], isNull);
    expect(sessions.containsKey(3), isFalse);
  });

  testWidgets('renders a labelled separator for a bookmark day', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BookmarkDaySeparator(date: DateTime(2000, 1, 2))),
      ),
    );

    expect(find.text('January 2 2000'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('displays playback duration on a start bookmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookmarkTile(
            bookmark: _bookmark(
              id: 1,
              positionMs: 120000,
              createdAt: DateTime(2024, 1, 1),
              kind: BookmarkKind.autoStart,
            ),
            playedFor: const Duration(minutes: 30),
            onTap: () {},
            onEditNote: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Played for 30:00'), findsOneWidget);
  });
}
