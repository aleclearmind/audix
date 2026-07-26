import 'package:flutter_test/flutter_test.dart';

import 'package:audix/core/database/database.dart';
import 'package:audix/features/bookmarks/bookmarks_sheet.dart';

Bookmark _bookmark({
  required int id,
  required int positionMs,
  required DateTime createdAt,
}) =>
    Bookmark(
      id: id,
      bookId: 1,
      positionMs: positionMs,
      chapterIndex: 0,
      note: null,
      kind: BookmarkKind.manual,
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
}
