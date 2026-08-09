import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_providers.dart';
import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';

/// Available ordering modes for bookmark lists.
enum BookmarkSort { creation, bookmarkTime }

/// Returns bookmarks ordered by [sort] without mutating the source list.
List<Bookmark> sortBookmarks(
  Iterable<Bookmark> bookmarks,
  BookmarkSort sort,
) =>
    [...bookmarks]..sort((a, b) => _compareBookmarks(a, b, sort));

/// Returns global bookmark rows ordered by their bookmark fields.
List<BookmarkEntry> sortBookmarkEntries(
  Iterable<BookmarkEntry> entries,
  BookmarkSort sort,
) =>
    [...entries]..sort(
      (a, b) => _compareBookmarks(a.bookmark, b.bookmark, sort),
    );

int _compareBookmarks(Bookmark a, Bookmark b, BookmarkSort sort) {
  final comparison = switch (sort) {
    BookmarkSort.creation => b.createdAt.compareTo(a.createdAt),
    BookmarkSort.bookmarkTime => a.positionMs.compareTo(b.positionMs),
  };
  return comparison != 0 ? comparison : b.id.compareTo(a.id);
}

/// Maps every automatic start bookmark to the wall-clock time until its
/// following automatic stop. A null value means that start has no matching
/// stop yet. Pairing is per book and does not depend on the list's UI order.
Map<int, Duration?> startBookmarkPlaybackDurations(
  Iterable<Bookmark> bookmarks,
) {
  final ordered = [...bookmarks]
    ..sort((a, b) {
      final comparison = a.createdAt.compareTo(b.createdAt);
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });
  final openStarts = <int, Bookmark>{};
  final durations = <int, Duration?>{};

  for (final bookmark in ordered) {
    switch (bookmark.kind) {
      case BookmarkKind.manual:
        break;
      case BookmarkKind.autoStart:
        final previous = openStarts[bookmark.bookId];
        if (previous != null) durations.remove(previous.id);
        durations[bookmark.id] = null;
        openStarts[bookmark.bookId] = bookmark;
        break;
      case BookmarkKind.autoStop:
        final start = openStarts.remove(bookmark.bookId);
        if (start != null) {
          final elapsed = bookmark.createdAt.difference(start.createdAt);
          durations[start.id] = elapsed.isNegative ? Duration.zero : elapsed;
        }
        break;
    }
  }
  return durations;
}

/// True if a bookmark's note / book title / "Chapter N" label contains [query].
bool bookmarkMatches(
  String? note,
  int chapterIndex,
  String query, {
  String? bookTitle,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final haystack =
      '${note ?? ''} ${bookTitle ?? ''} chapter ${chapterIndex + 1}'
          .toLowerCase();
  return haystack.contains(q);
}

/// Icon representing how a bookmark was created.
IconData bookmarkKindIcon(BookmarkKind kind) => switch (kind) {
      BookmarkKind.manual => Icons.bookmark,
      BookmarkKind.autoStart => Icons.play_circle_outline,
      BookmarkKind.autoStop => Icons.pause_circle_outline,
    };

/// Short label for a bookmark kind.
String bookmarkKindLabel(BookmarkKind kind) => switch (kind) {
      BookmarkKind.manual => 'Bookmark',
      BookmarkKind.autoStart => 'Started',
      BookmarkKind.autoStop => 'Stopped',
    };

/// A reusable menu for selecting bookmark ordering.
class BookmarkSortButton extends StatelessWidget {
  const BookmarkSortButton({
    super.key,
    required this.value,
    required this.onSelected,
  });

  final BookmarkSort value;
  final ValueChanged<BookmarkSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BookmarkSort>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort bookmarks',
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: BookmarkSort.creation,
          child: Text('Creation time'),
        ),
        PopupMenuItem(
          value: BookmarkSort.bookmarkTime,
          child: Text('Bookmark time'),
        ),
      ],
    );
  }
}

/// A reusable rounded filter field for the bookmark views.
class BookmarkSearchField extends StatelessWidget {
  const BookmarkSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Filter bookmarks…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Opens the per-book bookmarks bottom sheet for the current book.
void showBookmarksSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _BookmarksSheet(),
  );
}

class _BookmarksSheet extends ConsumerStatefulWidget {
  const _BookmarksSheet();

  @override
  ConsumerState<_BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends ConsumerState<_BookmarksSheet> {
  final _controller = TextEditingController();
  String _query = '';
  bool _manualOnly = false;
  BookmarkSort _sort = BookmarkSort.creation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks =
        ref.watch(currentBookmarksProvider).value ?? const <Bookmark>[];
    final controller = ref.read(playerControllerProvider);
    final bookId = ref.watch(currentBookIdProvider);
    final playing = ref.watch(playbackStateProvider).value?.playing ?? false;

    if (bookmarks.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No bookmarks yet')),
        ),
      );
    }

    final hasAuto = bookmarks.any((b) => b.kind != BookmarkKind.manual);
    final playbackDurations = startBookmarkPlaybackDurations(bookmarks);
    final filtered = sortBookmarks([
      for (final b in bookmarks)
        if ((!_manualOnly || b.kind == BookmarkKind.manual) &&
            bookmarkMatches(b.note, b.chapterIndex, _query))
          b,
    ], _sort);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: BookmarkSearchField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                BookmarkSortButton(
                  value: _sort,
                  onSelected: (sort) => setState(() => _sort = sort),
                ),
              ],
            ),
          ),
          if (hasAuto)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Manual only'),
                    selected: _manualOnly,
                    onSelected: (v) => setState(() => _manualOnly = v),
                  ),
                  const Spacer(),
                  if (bookId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.auto_delete_outlined, size: 18),
                      label: const Text('Clear auto'),
                      onPressed: () => ref
                          .read(databaseProvider)
                          .clearAutoBookmarks(bookId),
                    ),
                ],
              ),
            ),
          Flexible(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No matching bookmarks'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final b = filtered[i];
                      final startsDay =
                          _sort == BookmarkSort.creation &&
                          (i == 0 ||
                              !isSameDay(
                                filtered[i - 1].createdAt,
                                b.createdAt,
                              ));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (startsDay)
                            BookmarkDaySeparator(date: b.createdAt),
                          BookmarkTile(
                            bookmark: b,
                            playedFor: playbackDurations[b.id],
                            playingNow: playing &&
                                playbackDurations.containsKey(b.id) &&
                                playbackDurations[b.id] == null,
                            onTap: () {
                              controller.seek(
                                Duration(milliseconds: b.positionMs),
                              );
                              Navigator.pop(context);
                            },
                            onEditNote: () => showBookmarkNoteDialog(
                              context,
                              ref,
                              b.id,
                              b.note,
                            ),
                            onDelete: () =>
                                ref.read(databaseProvider).deleteBookmark(b.id),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A labelled divider between calendar days in creation-sorted bookmark lists.
class BookmarkDaySeparator extends StatelessWidget {
  const BookmarkDaySeparator({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          children: [
            Expanded(child: Divider(color: scheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                formatDayHeading(date),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: Divider(color: scheme.outlineVariant)),
          ],
        ),
      ),
    );
  }
}

/// A single bookmark row showing its kind, location and the time it was added.
class BookmarkTile extends StatelessWidget {
  const BookmarkTile({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onEditNote,
    required this.onDelete,
    this.bookTitle,
    this.playedFor,
    this.playingNow = false,
  });

  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onEditNote;
  final VoidCallback onDelete;
  final Duration? playedFor;
  final bool playingNow;

  /// When set (global list), shown in the subtitle to identify the book.
  final String? bookTitle;

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final chapterNo = b.chapterIndex + 1;
    final pos = formatDuration(Duration(milliseconds: b.positionMs));
    final when = formatTimestamp(b.createdAt);
    final hasNote = b.note?.isNotEmpty == true;
    final title = hasNote ? b.note! : bookmarkKindLabel(b.kind);
    final where = 'Chapter $chapterNo • $pos';
    final location = [
      if (bookTitle != null) bookTitle,
      where,
      when,
    ].join(' • ');
    final session = playedFor != null
        ? 'Played for ${formatDuration(playedFor!)}'
        : playingNow
            ? 'Playing now'
            : null;
    final subtitle = session == null ? location : '$location\n$session';

    return ListTile(
      leading: Icon(bookmarkKindIcon(b.kind)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'note') onEditNote();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'note', child: Text('Edit note')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Shows a dialog to add/edit a bookmark's note.
Future<void> showBookmarkNoteDialog(
  BuildContext context,
  WidgetRef ref,
  int bookmarkId,
  String? currentNote,
) async {
  final db = ref.read(databaseProvider);
  final textController = TextEditingController(text: currentNote ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bookmark note'),
      content: TextField(
        controller: textController,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Note'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, textController.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result == null) return;
  await db.updateBookmarkNote(bookmarkId, result.isEmpty ? null : result);
}
