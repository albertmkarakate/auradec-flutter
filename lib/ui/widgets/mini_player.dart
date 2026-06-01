import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/audio_handler.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/library_controller.dart';
import '../widgets/album_art.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final h = AuradecAudioHandler.inst;
    return StreamBuilder(
      stream: h.currentTrack,
      builder: (ctx, snap) {
        final track = snap.data;
        if (track == null) return const SizedBox.shrink();
        return GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -400)       PlayerController.inst.next();
            else if (v > 400)   PlayerController.inst.prev();
          },
          child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xF20E0B13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AlbumArt(artUri: track.artUri, filePath: track.filePath, seed: track.title, size: 40, radius: 10),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.title, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(track.artist, style: const TextStyle(color: kFg2, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            StreamBuilder<bool>(
              stream: h.isPlaying,
              builder: (_, s) => s.data == true ? _EqBars() : const SizedBox(width: 8),
            ),
            const SizedBox(width: 4),
            StreamBuilder<bool>(
              stream: h.isPlaying,
              builder: (_, s) {
                final playing = s.data ?? false;
                return Builder(builder: (ctx) {
                  final accent = Theme.of(ctx).colorScheme.primary;
                  return GestureDetector(
                    onTap: () => PlayerController.inst.toggle(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: playing
                            ? [BoxShadow(color: accent.withAlpha(70), blurRadius: 14)]
                            : null,
                      ),
                      child: Icon(playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white, size: 20),
                    ),
                  );
                });
              },
            ),
          ]),
        ), // Container
        ); // GestureDetector
      },
    );
  }
}

class _EqBars extends StatefulWidget {
  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    const heights = [5, 10, 6, 12, 4];
    _ctrls = List.generate(5, (i) => AnimationController(
      vsync: this, duration: Duration(milliseconds: 300 + i * 70),
    )..repeat(reverse: true));
    _anims = List.generate(5, (i) => Tween(begin: 2.0, end: heights[i].toDouble())
        .animate(CurvedAnimation(parent: _ctrls[i], curve: Curves.easeInOut)));
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) => AnimatedBuilder(
        animation: _anims[i],
        builder: (_, __) => Container(
          width: 2.5,
          height: _anims[i].value,
          margin: const EdgeInsets.only(right: 1.5),
          decoration: BoxDecoration(
            color: kBrandOrange,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      )),
    );
  }
}
