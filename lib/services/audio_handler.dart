import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import '../core/track.dart';

/// AURADEC audio handler — Namida-style just_audio + just_audio_background.
///
/// just_audio_background spawns an Android foreground service and registers
/// a MediaSession automatically. ExoPlayer is the backing engine.
/// Buffer is tuned to 3 minutes like Namida — smooth seeks and gapless.
class AuradecAudioHandler {
  static final AuradecAudioHandler inst = AuradecAudioHandler._();
  AuradecAudioHandler._();

  static const _eqChannel = MethodChannel('app.auradec/equalizer');

  late final AudioPlayer _player;
  bool _initialized = false;
  bool _eqInitialized = false;

  // Reactive state (GetX-friendly observables via RxDart)
  final _currentTrack   = BehaviorSubject<Track?>.seeded(null);
  final _isPlaying      = BehaviorSubject<bool>.seeded(false);
  final _positionMs     = BehaviorSubject<int>.seeded(0);
  final _durationMs     = BehaviorSubject<int>.seeded(0);
  final _volume         = BehaviorSubject<double>.seeded(0.85);
  final _repeatMode     = BehaviorSubject<LoopMode>.seeded(LoopMode.off);
  final _shuffleEnabled = BehaviorSubject<bool>.seeded(false);

  Stream<Track?>  get currentTrack   => _currentTrack.stream;
  Stream<bool>    get isPlaying      => _isPlaying.stream;
  Stream<int>     get positionMs     => _positionMs.stream;
  Stream<int>     get durationMs     => _durationMs.stream;
  Stream<double>  get volume         => _volume.stream;
  Stream<LoopMode> get repeatMode    => _repeatMode.stream;
  Stream<bool>    get shuffleEnabled => _shuffleEnabled.stream;

  Track?   get currentTrackValue   => _currentTrack.valueOrNull;
  bool     get isPlayingValue      => _isPlaying.valueOrNull ?? false;
  int      get positionMsValue     => _positionMs.valueOrNull ?? 0;
  int      get durationMsValue     => _durationMs.valueOrNull ?? 0;
  double   get volumeValue         => _volume.valueOrNull ?? 0.85;
  LoopMode get repeatModeValue     => _repeatMode.valueOrNull ?? LoopMode.off;
  bool     get shuffleEnabledValue => _shuffleEnabled.valueOrNull ?? false;

  double get progressFraction {
    final dur = durationMsValue;
    if (dur <= 0) return 0;
    return positionMsValue / dur;
  }

  // Queue
  final List<Track> _queue = [];
  int _queueIndex = 0;
  List<Track> get queue => List.unmodifiable(_queue);
  int  get queueIndex => _queueIndex;

  /// Call once at startup — Namida calls this in Player.initializePlayer()
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Namida ExoPlayer buffer tuning: maxBuffer 3 minutes, minBuffer 5s
    _player = AudioPlayer(
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 5),
          maxBufferDuration: Duration(minutes: 3),
          bufferForPlaybackDuration: Duration(seconds: 2),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 5),
          prioritizeTimeOverSizeThresholds: true,
          backBufferDuration: Duration(seconds: 30),
        ),
      ),
    );

    // Subscribe to player events
    _player.playingStream.listen((playing) => _isPlaying.add(playing));
    _player.positionStream.listen((pos) => _positionMs.add(pos.inMilliseconds));
    _player.durationStream.listen((dur) => _durationMs.add(dur?.inMilliseconds ?? 0));

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onTrackEnded();
      }
    });

    await _player.setVolume(volumeValue);
  }

  // ── Playback ──────────────────────────────────────────────────────

  Future<void> loadTrack(Track track, {bool autoPlay = true}) async {
    _currentTrack.add(track);

    final source = AudioSource.uri(
      Uri.parse(track.path),
      tag: MediaItem(
        id:       track.path,
        title:    track.title,
        artist:   track.artist,
        album:    track.album,
        artUri:   track.artUri != null ? Uri.tryParse(track.artUri!) : null,
        duration: track.durationMs > 0 ? track.duration : null,
      ),
    );

    await _player.setAudioSource(source);
    _initEQ(); // non-blocking, fire-and-forget
    if (autoPlay) await _player.play();
  }

  /// Load a live internet radio stream. Creates a synthetic Track so the
  /// rest of the UI (NowPlaying, MiniPlayer, MediaSession) works unchanged.
  Future<void> loadRadio({
    required String url,
    required String name,
    String genre = 'Radio',
    int bitrate = 128,
  }) async {
    final fake = Track(
      path:      url,
      title:     name,
      artist:    'LIVE · $genre',
      album:     'Internet Radio',
      durationMs: 0,
      codec:     'LIVE',
      bitrate:   bitrate,
    );
    _queue..clear()..add(fake);
    _queueIndex = 0;
    await loadTrack(fake);
  }

  Future<void> play()   async => await _player.play();
  Future<void> pause()  async => await _player.pause();
  Future<void> toggle() async => isPlayingValue ? pause() : play();

  Future<void> seekTo(Duration position) async => await _player.seek(position);
  Future<void> seekFraction(double fraction) async {
    final dur = durationMsValue;
    if (dur <= 0) return;
    await seekTo(Duration(milliseconds: (fraction * dur).round()));
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    _volume.add(clamped);
    await _player.setVolume(clamped);
  }

  Future<void> setRepeatMode(LoopMode mode) async {
    _repeatMode.add(mode);
    await _player.setLoopMode(mode);
  }

  void cyclRepeatMode() {
    final next = repeatModeValue == LoopMode.off  ? LoopMode.all
               : repeatModeValue == LoopMode.all  ? LoopMode.one
               : LoopMode.off;
    setRepeatMode(next);
  }

  Future<void> setShuffleEnabled(bool on) async {
    _shuffleEnabled.add(on);
    await _player.setShuffleModeEnabled(on);
  }

  // ── Queue ─────────────────────────────────────────────────────────

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0, bool autoPlay = true}) async {
    _queue
      ..clear()
      ..addAll(tracks);
    _queueIndex = startIndex.clamp(0, tracks.length - 1);
    if (tracks.isEmpty) return;
    await loadTrack(tracks[_queueIndex], autoPlay: autoPlay);
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (shuffleEnabledValue) {
      _queueIndex = (DateTime.now().millisecondsSinceEpoch % _queue.length);
    } else {
      _queueIndex = (_queueIndex + 1) % _queue.length;
    }
    await loadTrack(_queue[_queueIndex]);
  }

  Future<void> skipToPrev() async {
    if (_queue.isEmpty) return;
    // If >3s in, restart current track (Namida behaviour)
    if (positionMsValue > 3000) {
      await seekTo(Duration.zero);
      return;
    }
    _queueIndex = (_queueIndex - 1 + _queue.length) % _queue.length;
    await loadTrack(_queue[_queueIndex]);
  }

  void _onTrackEnded() {
    switch (repeatModeValue) {
      case LoopMode.one:
        seekTo(Duration.zero).then((_) => play());
        break;
      case LoopMode.all:
        skipToNext();
        break;
      case LoopMode.off:
        if (_queueIndex < _queue.length - 1) skipToNext();
        break;
    }
  }

  // ── Equalizer ─────────────────────────────────────────────────────

  Future<void> _initEQ() async {
    if (_eqInitialized) return;
    try {
      final sessionId = await _player.androidAudioSessionId;
      if (sessionId != null) {
        await _eqChannel.invokeMethod('init', {'sessionId': sessionId});
        _eqInitialized = true;
      }
    } catch (_) {}
  }

  Future<void> setEQEnabled(bool enabled) async {
    await _initEQ();
    try {
      await _eqChannel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  /// gainDb is -12.0 to +12.0; converts to milliBels internally.
  Future<void> setEQBand(int band, double gainDb) async {
    await _initEQ();
    try {
      final milliBel = (gainDb * 100).round();
      await _eqChannel.invokeMethod('setBand', {'band': band, 'gainMilliBel': milliBel});
    } catch (_) {}
  }

  Future<List<int>> getEQLevelRange() async {
    await _initEQ();
    try {
      final r = await _eqChannel.invokeListMethod<int>('getLevelRange');
      return r ?? [-1200, 1200];
    } catch (_) {
      return [-1200, 1200];
    }
  }

  void dispose() {
    _player.dispose();
    _currentTrack.close();
    _isPlaying.close();
    _positionMs.close();
    _durationMs.close();
    _volume.close();
    _repeatMode.close();
    _shuffleEnabled.close();
  }
}
