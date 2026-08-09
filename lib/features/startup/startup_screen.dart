import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_providers.dart';
import '../../core/providers.dart';
import '../home/home_screen.dart';
import '../player/player_screen.dart';

/// Restores the most recently read unfinished book before the first app screen.
final restoreLastBookProvider = FutureProvider<bool>((ref) async {
  final book = await ref.watch(databaseProvider).mostRecentlyPlayedBook();
  if (book == null) return false;
  await ref.read(playerControllerProvider).openBook(book);
  return true;
});

/// Holds the launch screen until restoration finishes, then opens the player
/// over the library so Back still returns to the normal app home.
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({
    super.key,
    this.homeBuilder = _defaultHomeBuilder,
    this.playerBuilder = _defaultPlayerBuilder,
  });

  final WidgetBuilder homeBuilder;
  final WidgetBuilder playerBuilder;

  static Widget _defaultHomeBuilder(BuildContext context) => const HomeScreen();
  static Widget _defaultPlayerBuilder(BuildContext context) =>
      const PlayerScreen();

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  late final Future<bool> _restore = ref.read(restoreLastBookProvider.future);
  bool _playerScheduled = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true && !_playerScheduled) {
          _playerScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: widget.playerBuilder));
          });
        }

        // A missing/deleted audio file must not make the app unusable: provider
        // errors deliberately fall through to the library.
        return widget.homeBuilder(context);
      },
    );
  }
}
