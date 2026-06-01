import 'dart:async';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/track.dart';
import '../core/constants.dart';
import '../services/audio_handler.dart';
import '../services/scrobble_service.dart';
import 'library_controller.dart';

class PlayerController extends GetxController {
  static PlayerController get inst => Get.find();

  final handler = AuradecAudioHandler.inst;

  // ── Sleep timer ───────────────────────────────────────────────────
  final sleepUntil = Rx<DateTime?>(null);
  Timer? _sleepTimer;
  Timer? _sleepTick;  // 1-second tick to update remaining display

  // ── Scrobble tracking ─────────────────────────────────────────────
  Track? _lastTrack;

  @override
  void onInit() {
    super.onInit();
    _restoreSettings();
    ScrobbleService.inst.init();
    handler.currentTrack.listen((track) {
      // Scrobble the previous track when the current track changes
      if (_lastTrack != null &&
          _lastTrack!.path != track?.path &&
          !_lastTrack!.path.startsWith('http')) {
        ScrobbleService.inst.scrobble(_lastTrack!);
      }
      _lastTrack = track;

      if (track != null && !track.path.startsWith('http')) {
        LibraryController.inst.incrementPlayCount(track.path);
        ScrobbleService.inst.nowPlaying(track);
      }
    });
  }

  @override
  void onClose() {
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    super.onClose();
  }

  void playTrack(Track track, {List<Track>? queue, int? queueIndex}) {
    final q = queue ?? LibraryController.inst.tracks.toList();
    final idx = queueIndex ?? q.indexOf(track);
    handler.setQueue(q, startIndex: idx < 0 ? 0 : idx);
  }

  void playRadio({required String url, required String name, String genre = 'Radio', int bitrate = 128}) {
    handler.loadRadio(url: url, name: name, genre: genre, bitrate: bitrate);
  }

  void toggle()     => handler.toggle();
  void next()       => handler.skipToNext();
  void prev()       => handler.skipToPrev();
  void seekFraction(double f) => handler.seekFraction(f);
  void setVolume(double v)    => handler.setVolume(v);

  void cycleRepeat() {
    handler.cyclRepeatMode();
    _saveSettings();
  }

  void toggleShuffle() {
    handler.setShuffleEnabled(!handler.shuffleEnabledValue);
    _saveSettings();
  }

  void sleepAfter(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    sleepUntil.value = DateTime.now().add(duration);

    _sleepTimer = Timer(duration, () {
      if (handler.isPlayingValue) handler.pause();
      sleepUntil.value = null;
      _sleepTick?.cancel();
    });

    // 1-second tick forces Obx widgets to recompute remaining time
    _sleepTick = Timer.periodic(const Duration(seconds: 1), (_) {
      final u = sleepUntil.value;
      if (u == null || DateTime.now().isAfter(u)) {
        _sleepTick?.cancel();
        return;
      }
      sleepUntil.refresh(); // trigger Obx without changing value
    });
  }

  void cancelSleep() {
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    _sleepTimer = null;
    _sleepTick  = null;
    sleepUntil.value = null;
  }

  Future<void> _restoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final vol  = prefs.getDouble(kPrefVolume)  ?? 0.85;
    final rep  = prefs.getString(kPrefRepeat)  ?? 'off';
    final shuf = prefs.getBool(kPrefShuffle)   ?? false;
    await handler.setVolume(vol);
    await handler.setRepeatMode(
      rep == 'one' ? LoopMode.one : rep == 'all' ? LoopMode.all : LoopMode.off,
    );
    await handler.setShuffleEnabled(shuf);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rep = handler.repeatModeValue == LoopMode.one ? 'one'
              : handler.repeatModeValue == LoopMode.all ? 'all' : 'off';
    await prefs.setString(kPrefRepeat, rep);
    await prefs.setBool(kPrefShuffle, handler.shuffleEnabledValue);
    await prefs.setDouble(kPrefVolume, handler.volumeValue);
  }
}
