import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../services/audio_handler.dart';
import '../../services/lyrics_service.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/library_controller.dart';
import '../widgets/album_art.dart';
import 'artist_detail_screen.dart';
import 'album_detail_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});
  @override State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyrics = false;
  bool _showQueue  = false;
  LyricsResult? _lyrics;
  bool _lyricsLoading = false;

  @override
  Widget build(BuildContext context) {
    final h = AuradecAudioHandler.inst;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          Get.back();
        }
      },
      child: Scaffold(
      backgroundColor: kBg0,
      body: StreamBuilder<Track?>(
        stream: h.currentTrack,
        builder: (ctx, snap) {
          final track = snap.data;
          return Stack(children: [
            // Blurred album art background
            if (track != null && !_showQueue)
              Positioned.fill(child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: AlbumArt(artUri: track.artUri, seed: track.title, size: double.infinity, radius: 0),
              )),
            // Dark gradient overlay
            Positioned.fill(child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [kBg0.withAlpha(180), kBg0.withAlpha(210), kBg0],
              )),
            )),
            // Content
            SafeArea(child: Column(children: [
              _header(track),
              Expanded(child: _showQueue ? _queueView() : _showLyrics ? _lyricsView(track) : _mainView(track, h)),
              _extraBar(h, track),
            ])),
          ]);
        },
      ),
    ));
  }

  Widget _header(Track? track) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: kFg2, size: 28), onPressed: () => Get.back()),
      Expanded(child: Column(children: [
        Text(_showLyrics ? 'LYRICS' : _showQueue ? 'QUEUE' : 'NOW PLAYING',
          style: const TextStyle(color: kFg3, fontSize: 9, letterSpacing: 3, fontFamily: 'Barlow')),
        if (track != null && !_showLyrics && !_showQueue)
          Text(track.codec == 'LIVE'
            ? 'INTERNET RADIO · ${track.bitrate}kbps'
            : '${track.codec} · ${track.bitrate}k',
            style: TextStyle(
              color: track.codec == 'LIVE' ? kBrandCoral : kBrandOrange,
              fontSize: 9, letterSpacing: 1)),
      ])),
      IconButton(icon: const Icon(Icons.more_vert, color: kFg2, size: 24), onPressed: () => _showTrackMenu(track)),
    ]),
  );

  Widget _mainView(Track? track, AuradecAudioHandler h) => Column(children: [
    Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
      child: Builder(builder: (ctx) {
        final accent = Theme.of(ctx).colorScheme.primary;
        final isLive = track?.codec == 'LIVE';
        return StreamBuilder<bool>(
          stream: h.isPlaying,
          builder: (_, s) {
            final playing = s.data ?? false;
            return Stack(alignment: Alignment.topRight, children: [
              AnimatedScale(
                scale: playing ? 1.02 : 0.96, duration: const Duration(milliseconds: 400), curve: Curves.easeOut,
                child: AspectRatio(aspectRatio: 1, child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: playing ? [BoxShadow(color: accent.withAlpha(80), blurRadius: 60, spreadRadius: 2)] : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AlbumArt(artUri: track?.artUri, seed: track?.title ?? '', size: double.infinity, radius: 0),
                  ),
                )),
              ),
              if (isLive) Positioned(top: 8, right: 8, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kBrandCoral, borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: kBrandCoral.withAlpha(80), blurRadius: 8)],
                ),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              )),
            ]);
          },
        );
      }),
    )),
    _trackInfo(track, h),
    _progressBar(h),
    _transportControls(h),
    const SizedBox(height: 8),
  ]);

  Widget _trackInfo(Track? track, AuradecAudioHandler h) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(track?.title ?? '—',
          style: const TextStyle(color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        if ((track?.artist ?? '').isNotEmpty)
          GestureDetector(
            onTap: () {
              if (track == null) return;
              Get.to(() => ArtistDetailScreen(artistName: track.artist));
            },
            child: Text(track!.artist,
              style: const TextStyle(color: kFg2, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if ((track?.album ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () {
              if (track == null) return;
              final lib = LibraryController.inst;
              final trks = lib.albums[track.album];
              if (trks != null) {
                Get.to(() => AlbumDetailScreen(albumName: track.album, tracks: trks));
              }
            },
            child: Text(track!.album,
              style: const TextStyle(color: kFg3, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ])),
      StreamBuilder<Track?>(stream: h.currentTrack, builder: (_, s) {
        final loved = s.data?.loved ?? false;
        return IconButton(
          icon: Icon(loved ? Icons.favorite : Icons.favorite_border,
            color: loved ? kBrandCoral : kFg2, size: 26),
          onPressed: () { if (track != null) LibraryController.inst.toggleLoved(track.path); },
        );
      }),
    ]),
  );

  Widget _progressBar(AuradecAudioHandler h) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Builder(builder: (ctx) {
      final accent = Theme.of(ctx).colorScheme.primary;
      return StreamBuilder<int>(stream: h.positionMs, builder: (_, posSnap) =>
        StreamBuilder<int>(stream: h.durationMs, builder: (_, durSnap) {
          final pos = posSnap.data ?? 0;
          final dur = durSnap.data ?? 0;
          return ProgressBar(
            progress: Duration(milliseconds: pos), total: Duration(milliseconds: dur > 0 ? dur : 1),
            progressBarColor: accent, thumbColor: accent, baseBarColor: kBorder,
            timeLabelTextStyle: const TextStyle(color: kFg2, fontSize: 10),
            onSeek: (d) => h.seekTo(d),
          );
        }),
      );
    }),
  );

  Widget _transportControls(AuradecAudioHandler h) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Builder(builder: (ctx) {
      final accent = Theme.of(ctx).colorScheme.primary;
      return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          StreamBuilder<bool>(stream: h.shuffleEnabled, builder: (_, s) =>
            IconButton(icon: Icon(Icons.shuffle, color: (s.data ?? false) ? accent : kFg2, size: 22),
              onPressed: () => PlayerController.inst.toggleShuffle())),
          IconButton(icon: const Icon(Icons.skip_previous, color: kFg1, size: 32), onPressed: () => PlayerController.inst.prev()),
          StreamBuilder<bool>(stream: h.isPlaying, builder: (_, s) {
            final playing = s.data ?? false;
            return GestureDetector(
              onTap: () => PlayerController.inst.toggle(),
              child: Container(width: 72, height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent,
                  boxShadow: [BoxShadow(color: accent.withAlpha(100), blurRadius: 28, spreadRadius: 2)]),
                child: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36)),
            );
          }),
          IconButton(icon: const Icon(Icons.skip_next, color: kFg1, size: 32), onPressed: () => PlayerController.inst.next()),
          StreamBuilder<LoopMode>(stream: h.repeatMode, builder: (_, s) {
            final mode = s.data ?? LoopMode.off;
            return IconButton(
              icon: Icon(mode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                color: mode != LoopMode.off ? accent : kFg2, size: 22),
              onPressed: () => PlayerController.inst.cycleRepeat());
        }),
      ]);
    }),
  );

  Widget _extraBar(AuradecAudioHandler h, Track? track) => Container(
    decoration: BoxDecoration(border: Border(top: BorderSide(color: kBorder.withAlpha(80)))),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        _iconBtn(Icons.lyrics_outlined, 'Lyrics', active: _showLyrics, onTap: () {
          setState(() { _showLyrics = !_showLyrics; _showQueue = false; });
          if (_showLyrics && _lyrics == null && track != null) _fetchLyrics(track);
        }),
        const SizedBox(width: 4),
        _iconBtn(Icons.queue_music, 'Queue', active: _showQueue, onTap: () => setState(() { _showQueue = !_showQueue; _showLyrics = false; })),
        const SizedBox(width: 4),
        _iconBtn(Icons.equalizer, 'EQ', onTap: () => _showEQSheet()),
        const SizedBox(width: 4),
        Obx(() {
          final until = PlayerController.inst.sleepUntil.value;
          String label = 'Sleep';
          bool active = false;
          if (until != null) {
            final rem = until.difference(DateTime.now());
            if (rem.isNegative) {
              label = 'Sleep';
            } else {
              label = '${rem.inMinutes}:${(rem.inSeconds % 60).toString().padLeft(2,'0')}';
              active = true;
            }
          }
          return _iconBtn(Icons.bedtime_outlined, label, active: active, onTap: () {
            if (active) {
              PlayerController.inst.cancelSleep();
            } else {
              _showSleepTimer();
            }
          });
        }),
        const SizedBox(width: 4),
        _iconBtn(Icons.star_border, 'Rate', onTap: () => track != null ? _showRateSheet(track) : null),
        const SizedBox(width: 4),
        StreamBuilder<double>(stream: h.volume, builder: (_, s) =>
          _iconBtn(Icons.volume_up_outlined, '${((s.data ?? 0.85) * 100).round()}%', onTap: () => _showVolumeSheet(h))),
      ]),
    ),
  );

  Widget _iconBtn(IconData icon, String label, {bool active = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kBrandOrange.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? kBrandOrange.withAlpha(80) : Colors.transparent),
        ),
        child: Column(children: [
          Icon(icon, color: active ? kBrandOrange : kFg3, size: 20),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: active ? kBrandOrange : kFg3, fontSize: 8, letterSpacing: 1, fontFamily: 'Barlow')),
        ]),
      ),
    );
  }

  // ── Lyrics ────────────────────────────────────────────────────────

  Future<void> _fetchLyrics(Track track) async {
    setState(() => _lyricsLoading = true);
    final result = await LyricsService.inst.fetch(track);
    if (mounted) setState(() { _lyrics = result; _lyricsLoading = false; });
  }

  Widget _lyricsView(Track? track) {
    if (_lyricsLoading) return const Center(child: CircularProgressIndicator(color: kBrandOrange));
    if (_lyrics == null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lyrics_outlined, color: kFg3, size: 40),
      const SizedBox(height: 10),
      const Text('No lyrics found', style: TextStyle(color: kFg2, fontSize: 14)),
      const SizedBox(height: 4),
      const Text('LRCLIB · NetEase searched', style: TextStyle(color: kFg3, fontSize: 11)),
    ]));

    return StreamBuilder<int>(stream: AuradecAudioHandler.inst.positionMs, builder: (_, snap) {
      final posSec = (snap.data ?? 0) / 1000.0;
      final lines = _lyrics!.hasSynced ? _lyrics!.synced : _lyrics!.plain.split('\n').map((l) => LyricLine(0, l)).toList();
      final activeIdx = _lyrics!.hasSynced ? lines.lastIndexWhere((l) => l.time <= posSec) : -1;

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        itemCount: lines.length + 1,
        itemBuilder: (ctx, i) {
          if (i == lines.length) return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${_lyrics!.source} · ${_lyrics!.hasSynced ? "Synced" : "Plain text"}',
              style: const TextStyle(color: kFg3, fontSize: 9, letterSpacing: 1.5), textAlign: TextAlign.center),
          );
          final l = lines[i];
          final isActive = i == activeIdx;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(l.text.isEmpty ? ' ' : l.text, style: TextStyle(
              fontFamily: isActive ? 'Syne' : 'Barlow',
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w300,
              fontSize: isActive ? 22 : 16,
              color: isActive ? kFg1 : const Color(0x6AECE5D8),
              height: 1.3,
            )),
          );
        },
      );
    });
  }

  // ── Queue ─────────────────────────────────────────────────────────

  Widget _queueView() {
    final h = AuradecAudioHandler.inst;
    final queue = h.queue;
    if (queue.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.queue_music, color: kFg3, size: 40),
      const SizedBox(height: 10),
      const Text('Queue is empty', style: TextStyle(color: kFg2, fontSize: 14)),
    ]));
    return ListView.builder(
      itemCount: queue.length,
      itemBuilder: (ctx, i) {
        final t = queue[i];
        final isCurrent = i == h.queueIndex;
        return ListTile(
          leading: Stack(children: [
            AlbumArt(artUri: t.artUri, seed: t.title, size: 42, radius: 8),
            if (isCurrent) Positioned.fill(child: Container(
              decoration: BoxDecoration(color: kBrandOrange.withAlpha(120), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.volume_up, color: Colors.white, size: 18),
            )),
          ]),
          title: Text(t.title, style: TextStyle(color: isCurrent ? kBrandOrange : kFg1, fontSize: 13, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(t.artist, style: const TextStyle(color: kFg2, fontSize: 11)),
          trailing: Text(_fmtMs(t.durationMs), style: const TextStyle(color: kFg3, fontSize: 10)),
          onTap: () => PlayerController.inst.playTrack(t, queue: queue, queueIndex: i),
        );
      },
    );
  }

  // ── Bottom sheets ─────────────────────────────────────────────────

  void _showEQSheet() {
    showModalBottomSheet(context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _EQSheet(),
    );
  }

  void _showSleepTimer() {
    showModalBottomSheet(context: context, backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SleepTimerSheet(),
    );
  }

  void _showRateSheet(Track track) {
    showModalBottomSheet(context: context, backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RateSheet(track: track),
    );
  }

  void _showVolumeSheet(AuradecAudioHandler h) {
    showModalBottomSheet(context: context, backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VolumeSheet(handler: h),
    );
  }

  void _showTrackMenu(Track? track) {
    if (track == null) return;
    showModalBottomSheet(context: context, backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.info_outline, color: kFg2), title: const Text('Track info', style: TextStyle(color: kFg1)),
          subtitle: Text('${track.codec} · ${track.bitrate}kbps · ${track.sampleRate}Hz', style: const TextStyle(color: kFg3, fontSize: 11))),
        const Divider(color: kBorder, height: 1),
        ListTile(leading: const Icon(Icons.block, color: kBrandCoral), title: const Text('Exclude from library', style: TextStyle(color: kBrandCoral)),
          onTap: () { LibraryController.inst.excludeTrack(track.path); Get.back(); Get.back(); }),
        const SizedBox(height: 8),
      ]),
    );
  }

  String _fmtMs(int ms) { final m = ms ~/ 60000; final s = (ms % 60000) ~/ 1000; return '$m:${s.toString().padLeft(2,'0')}'; }
}

// ── EQ Sheet ─────────────────────────────────────────────────────────

class _EQSheet extends StatefulWidget {
  const _EQSheet();
  @override State<_EQSheet> createState() => _EQSheetState();
}

class _EQSheetState extends State<_EQSheet> {
  final _bands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  final _freqs = ['32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];
  String _preset = 'Flat';

  final _presets = {
    'Flat':  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass+': [6.0, 5.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Vocal': [-2.0, -1.0, 0.0, 2.0, 4.0, 4.0, 3.0, 1.0, 0.0, -1.0],
    'Rock':  [4.0, 3.0, 2.0, 0.0, -1.0, -1.0, 1.0, 3.0, 4.0, 4.0],
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Equaliser', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
          const Icon(Icons.equalizer, color: kBrandOrange),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: _presets.keys.map((p) => FilterChip(
          label: Text(p), selected: _preset == p,
          onSelected: (_) {
            setState(() { _preset = p; for (int i = 0; i < 10; i++) _bands[i] = _presets[p]![i]; });
            AuradecAudioHandler.inst.setEQEnabled(true);
            for (int i = 0; i < 10; i++) AuradecAudioHandler.inst.setEQBand(i, _presets[p]![i]);
          },
          backgroundColor: kBg2, selectedColor: kBrandOrange.withAlpha(40),
          labelStyle: TextStyle(color: _preset == p ? kBrandOrange : kFg2, fontSize: 11),
          side: BorderSide(color: _preset == p ? kBrandOrange : kBorder),
        )).toList()),
        const SizedBox(height: 16),
        SizedBox(height: 160, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(10, (i) => Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('${_bands[i] > 0 ? '+' : ''}${_bands[i].toInt()}', style: TextStyle(color: _bands[i] == 0 ? kFg3 : kBrandOrange, fontSize: 8)),
            const SizedBox(height: 4),
            Expanded(child: RotatedBox(quarterTurns: 3, child: SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(value: _bands[i], min: -12, max: 12, activeColor: kBrandOrange, inactiveColor: kBorder,
                onChanged: (v) {
                  setState(() { _bands[i] = v.roundToDouble(); _preset = 'Custom'; });
                  AuradecAudioHandler.inst.setEQEnabled(true);
                  AuradecAudioHandler.inst.setEQBand(i, v);
                },
              ),
            ))),
            Text(_freqs[i], style: const TextStyle(color: kFg3, fontSize: 7)),
          ]))),
        )),
      ]),
    );
  }
}

// ── Sleep Timer ────────────────────────────────────────────────────

class _SleepTimerSheet extends StatefulWidget {
  @override State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}
class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  int _mins = 30;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Sleep timer', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [15, 30, 45, 60].map((m) =>
          GestureDetector(onTap: () => setState(() => _mins = m), child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: _mins == m ? kBrandOrange : kBorder, width: 2),
              color: _mins == m ? kBrandOrange.withAlpha(30) : kBg2),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$m', style: TextStyle(color: _mins == m ? kBrandOrange : kFg1, fontSize: 18, fontWeight: FontWeight.w800)),
              Text('min', style: TextStyle(color: _mins == m ? kBrandOrange : kFg3, fontSize: 8)),
            ]),
          )),
        ).toList()),
        const SizedBox(height: 12),
        Slider(value: _mins.toDouble(), min: 5, max: 120, divisions: 23, activeColor: kBrandOrange, inactiveColor: kBorder,
          label: '$_mins min', onChanged: (v) => setState(() => _mins = v.round())),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () { PlayerController.inst.sleepAfter(Duration(minutes: _mins)); Get.back(); Get.snackbar('Sleep timer', 'Stops in $_mins minutes', backgroundColor: kBg2, colorText: kFg1, duration: const Duration(seconds: 2)); },
          child: Text('Set timer · $_mins min'),
        )),
      ]),
    );
  }
}

// ── Rate Sheet ────────────────────────────────────────────────────

class _RateSheet extends StatelessWidget {
  final Track track;
  const _RateSheet({required this.track});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(track.title, style: const TextStyle(color: kFg1, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(track.artist, style: const TextStyle(color: kFg2, fontSize: 12)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
          final stars = i + 1;
          final cur = track.rating;
          return GestureDetector(
            onTap: () { LibraryController.inst.setRating(track.path, stars * 20); Get.back(); },
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(
              stars <= (cur / 20).round() ? Icons.star : Icons.star_border,
              color: stars <= (cur / 20).round() ? const Color(0xFFFBBF24) : kFg3, size: 40,
            )),
          );
        })),
        const SizedBox(height: 8),
        Text(['', 'Poor', 'Fair', 'Good', 'Great', 'Perfect'][(track.rating / 20).round().clamp(0, 5)],
          style: const TextStyle(color: kFg3, fontSize: 12)),
      ]),
    );
  }
}

// ── Volume Sheet ───────────────────────────────────────────────────

class _VolumeSheet extends StatelessWidget {
  final AuradecAudioHandler handler;
  const _VolumeSheet({required this.handler});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Volume', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        StreamBuilder<double>(stream: handler.volume, builder: (_, s) {
          final vol = s.data ?? 0.85;
          return Column(children: [
            Text('${(vol * 100).round()}%', style: const TextStyle(color: kBrandOrange, fontSize: 28, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            Slider(value: vol, min: 0, max: 1, activeColor: kBrandOrange, inactiveColor: kBorder,
              onChanged: handler.setVolume),
          ]);
        }),
      ]),
    );
  }
}
