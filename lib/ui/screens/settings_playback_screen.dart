import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/audio_handler.dart';

class SettingsPlaybackScreen extends StatefulWidget {
  const SettingsPlaybackScreen({super.key});
  @override State<SettingsPlaybackScreen> createState() => _SettingsPlaybackScreenState();
}

class _SettingsPlaybackScreenState extends State<SettingsPlaybackScreen> {
  bool   _gapless      = true;
  double _crossfade    = 3.0;
  String _fadeCurve    = 'Equal Power';
  bool   _fadeOnPlay   = true;
  bool   _fadeOnPause  = true;
  double _fadeDur      = 0.4;
  String _normMode     = 'Off';
  double _targetLufs   = -14.0;
  double _preamp       = -3.0;
  bool   _limiter      = true;
  String _drMode       = 'Subtle';
  bool   _eqOn         = true;
  String _eqPreset     = 'Rock';
  final _eqBands       = [5.0, 4.0, 3.0, 1.0, -1.0, -1.0, 1.0, 3.0, 4.0, 5.0];
  double _bassBoost    = 0.0;
  bool   _spatial      = false;
  double _stereoWidth  = 100.0;
  bool   _mono         = false;
  String _queueEnd     = 'Similar Tracks';
  String _shuffleMode  = 'Songs';
  bool   _autoplay     = false;
  bool   _resumeStart  = true;
  bool   _rememberPos  = true;
  String _sleepTimer   = 'Off';
  bool   _skipSilence  = false;
  double _silenceThresh = -55.0;
  double _speed        = 1.0;
  bool   _pitchLock    = true;
  int    _semitone     = 0;
  String _singlePress  = 'Play / Pause';
  String _doublePress  = 'Next track';
  String _triplePress  = 'Previous track';
  String _longPress    = 'Like track';
  bool   _volChangeTracks = false;

  static const _freqs = ['32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];
  static const _eqPresets = {
    'Flat':  [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0],
    'Rock':  [5.0,4.0,3.0,1.0,-1.0,-1.0,1.0,3.0,4.0,5.0],
    'Jazz':  [4.0,3.0,1.0,2.0,-1.0,-1.0,0.0,1.0,3.0,4.0],
    'Vocal': [-2.0,-1.0,0.0,2.0,4.0,4.0,3.0,1.0,0.0,-1.0],
    'Bass':  [7.0,6.0,5.0,3.0,1.0,0.0,0.0,0.0,0.0,0.0],
  };
  static const _hsBtns = ['Play / Pause','Next track','Previous track','Like track',
      'Seek +10s','Seek −10s','Toggle shuffle','Toggle repeat','Volume up','Volume down','Disabled'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg1, foregroundColor: kFg1,
        title: const Text('Playback', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
        actions: [TextButton(onPressed: _resetAll,
          child: const Text('Reset', style: TextStyle(color: kFg2, fontSize: 12, letterSpacing: 0.8)))],
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        _sh('Transitions'),
        _tog('Gapless playback', 'Removes silence between consecutive tracks', _gapless,
            (v) { setState(() => _gapless = v); AuradecAudioHandler.inst.setGapless(v); }),
        _slide('Crossfade duration', _crossfade == 0 ? 'Off — abrupt cut' : 'Overlap between ending and next track',
            _crossfade, 0, 12, 0.5, 's', kBrandOrange, (v) { setState(() => _crossfade = v); AuradecAudioHandler.inst.setCrossfade(v.round()); }),
        if (_crossfade > 0) ...[
          _seg('Fade curve', _fadeCurve, ['Linear', 'Sine', 'Equal Power', 'Log'],
              (v) => setState(() => _fadeCurve = v)),
        ],
        _tog('Fade in on play', 'Ramps volume up from silence when playback starts', _fadeOnPlay,
            (v) => setState(() => _fadeOnPlay = v)),
        _tog('Fade out on pause', 'Gracefully ducks volume before stopping', _fadeOnPause,
            (v) => setState(() => _fadeOnPause = v)),
        if (_fadeOnPlay || _fadeOnPause)
          _slide('Fade duration', null, _fadeDur, 0.1, 2, 0.1, 's', kBrandGold,
              (v) => setState(() => _fadeDur = v)),

        _sh('Volume & Dynamics'),
        _drMeter(),
        _sel('Volume normalisation', 'Analyses and levels perceived loudness',
            _normMode, ['Off', 'R128 (−14 LUFS)', 'ReplayGain Track', 'ReplayGain Album', 'Peak (−1 dBFS)'],
            (v) => setState(() => _normMode = v!)),
        if (_normMode != 'Off') ...[
          _slide('Target loudness', 'Lower = quieter master reference', _targetLufs, -23, -9, 0.5, ' LUFS', const Color(0xFF29F89E), (v) => setState(() => _targetLufs = v)),
          _slide('Pre-amp gain', 'Applied on top of the normalisation offset', _preamp, -12, 12, 0.5, ' dB', kBrandOrange, (v) => setState(() => _preamp = v)),
          _tog('Clip protection / hard limiter', 'Prevents clipping after applying pre-amp', _limiter, (v) => setState(() => _limiter = v)),
        ],
        _seg('Dynamic range mode', _drMode, ['Flat', 'Subtle', 'Full'], (v) => setState(() => _drMode = v)),

        _sh('Equaliser & DSP'),
        _tog('Equaliser', '10-band graphic EQ applied to all output', _eqOn,
            (v) { setState(() => _eqOn = v); AuradecAudioHandler.inst.setEQEnabled(v); }),
        _eqWidget(),
        _slide('Bass boost', 'Low-shelf lift below 120 Hz', _bassBoost, 0, 10, 1, '', kBrandGold,
            (v) => setState(() => _bassBoost = v)),
        _tog('Spatial audio', 'Virtualised surround widening for headphones', _spatial,
            (v) => setState(() => _spatial = v)),
        if (_spatial)
          _slide('Stereo width', '100% = original', _stereoWidth, 0, 200, 5, '%', const Color(0xFF29F89E),
              (v) => setState(() => _stereoWidth = v)),
        _tog('Mono downmix', 'Combine L+R — for single-speaker or accessibility', _mono,
            (v) => setState(() => _mono = v)),

        _sh('Queue & Auto-Play'),
        _sel('When queue ends', 'Behaviour once all queued tracks have played', _queueEnd,
            ['Stop', 'Repeat All', 'Shuffle & Repeat', 'Similar Tracks', 'Radio Mode'],
            (v) => setState(() => _queueEnd = v!)),
        _seg('Shuffle mode', _shuffleMode, ['Off', 'Songs', 'Albums', 'Smart'],
            (v) => setState(() => _shuffleMode = v)),
        _tog('Auto-play on headset connect', 'Resumes last session when headset is plugged in', _autoplay,
            (v) => setState(() => _autoplay = v)),
        _tog('Resume on startup', 'Pick up where you left off on app launch', _resumeStart,
            (v) => setState(() => _resumeStart = v)),
        _tog('Remember position in long tracks', 'For classical, audiobooks, podcasts (>10 min)', _rememberPos,
            (v) => setState(() => _rememberPos = v)),

        _sh('Timing'),
        if (_sleepTimer != 'Off') _sleepDisplay(),
        _sel('Sleep timer', 'Automatically stop playback after a period or track', _sleepTimer,
            ['Off', 'End of track', '15 min', '30 min', '45 min', '60 min', '90 min'],
            (v) => setState(() => _sleepTimer = v!)),
        _tog('Skip silence', 'Automatically skips over silent gaps mid-track', _skipSilence,
            (v) => setState(() => _skipSilence = v)),
        if (_skipSilence)
          _slide('Silence threshold', 'Sections quieter than this are skipped', _silenceThresh, -70, -30, 1, ' dB', kBrandCoral, (v) => setState(() => _silenceThresh = v)),

        _sh('Speed & Pitch'),
        _speedDial(),
        _slide('Playback speed', '1× = original; time-stretching applied', _speed, 0.5, 2.0, 0.05, '×',
            _speed == 1 ? kBrandOrange : _speed < 1 ? kBrandCoral : const Color(0xFF29F89E),
            (v) => setState(() => _speed = v)),
        if (_speed != 1.0)
          _tog('Key lock (pitch correction)', 'Keeps original pitch while changing speed', _pitchLock,
              (v) => setState(() => _pitchLock = v)),
        _slide('Pitch shift', 'Transpose up/down independent of speed', _semitone.toDouble(), -6, 6, 1,
            _semitone == 0 ? ' st' : ' st', kFg3,
            (v) => setState(() => _semitone = v.round())),

        _sh('Headset Controls'),
        _hsCard(),
        ...['Single press', 'Double press', 'Triple press', 'Long press']
            .asMap().entries.map((e) => _sel(
              e.value, null,
              [_singlePress, _doublePress, _triplePress, _longPress][e.key],
              _hsBtns,
              (v) { setState(() {
                switch (e.key) {
                  case 0: _singlePress = v!; break;
                  case 1: _doublePress = v!; break;
                  case 2: _triplePress = v!; break;
                  case 3: _longPress   = v!; break;
                }
              }); },
            )),
        _tog('Volume buttons change tracks', 'When headset long-pressed; still changes volume normally',
            _volChangeTracks, (v) => setState(() => _volChangeTracks = v)),
      ]),
    );
  }

  void _resetAll() => setState(() {
    _gapless = true; _crossfade = 3.0; _fadeCurve = 'Equal Power'; _fadeOnPlay = true;
    _fadeOnPause = true; _fadeDur = 0.4; _normMode = 'Off'; _targetLufs = -14.0;
    _preamp = -3.0; _limiter = true; _drMode = 'Subtle'; _eqOn = true; _eqPreset = 'Rock';
    _bassBoost = 0.0; _spatial = false; _stereoWidth = 100.0; _mono = false;
    _queueEnd = 'Similar Tracks'; _shuffleMode = 'Songs'; _autoplay = false;
    _resumeStart = true; _rememberPos = true; _sleepTimer = 'Off'; _skipSilence = false;
    _silenceThresh = -55.0; _speed = 1.0; _pitchLock = true; _semitone = 0;
    _singlePress = 'Play / Pause'; _doublePress = 'Next track'; _triplePress = 'Previous track';
    _longPress = 'Like track'; _volChangeTracks = false;
  });

  Widget _sh(String label, {Color color = kBrandGold}) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
    child: Text(label.toUpperCase(), style: TextStyle(
        color: color, fontSize: 8, letterSpacing: 2.5, fontFamily: 'Barlow', fontWeight: FontWeight.w700)),
  );

  static const _rowBorder = BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))));

  Widget _row(String label, String? hint, Widget control) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: _rowBorder,
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w500)),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 2),
          child: Text(hint, style: const TextStyle(color: kFg2, fontSize: 11, height: 1.4))),
      ])),
      const SizedBox(width: 12),
      control,
    ]),
  );

  Widget _tog(String label, String? hint, bool val, ValueChanged<bool> cb) =>
    _row(label, hint, Switch(value: val, onChanged: cb, activeColor: kBrandOrange, inactiveTrackColor: kBorder));

  Widget _sel(String label, String? hint, String val, List<String> opts, ValueChanged<String?> cb) =>
    _row(label, hint, DropdownButton<String>(
      value: opts.contains(val) ? val : opts.first,
      dropdownColor: kBg2,
      style: const TextStyle(color: kFg1, fontSize: 11, fontFamily: 'Barlow'),
      underline: const SizedBox.shrink(),
      items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: cb,
    ));

  Widget _seg(String label, String val, List<String> opts, ValueChanged<String> cb) =>
    _row(label, null, Wrap(spacing: 3, children: opts.map((o) {
      final on = val == o;
      return GestureDetector(
        onTap: () => cb(o),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: on ? kBrandOrange : kBg2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? kBrandOrange : kBorder),
          ),
          child: Text(o, style: TextStyle(color: on ? Colors.white : kFg2,
              fontSize: 9, fontFamily: 'Barlow', fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 0.5)),
        ),
      );
    }).toList()));

  Widget _slide(String label, String? hint, double val, double min, double max,
      double step, String unit, Color color, ValueChanged<double> cb) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: _rowBorder,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w500))),
          Text('${val.toStringAsFixed(step < 1 ? (step < 0.1 ? 2 : 1) : 0)}$unit',
              style: TextStyle(color: color, fontSize: 12, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
        ]),
        if (hint != null) Text(hint, style: const TextStyle(color: kFg2, fontSize: 11)),
        Slider(value: val.clamp(min, max), min: min, max: max,
            divisions: ((max - min) / step).round().clamp(1, 200),
            activeColor: color, inactiveColor: kBorder, onChanged: cb),
      ]),
    );
  }

  Widget _drMeter() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF29F89E).withAlpha(12),
      border: Border.all(color: const Color(0xFF29F89E).withAlpha(45)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DYNAMIC RANGE METER', style: TextStyle(color: Color(0xFF29F89E), fontSize: 7, letterSpacing: 2.5, fontFamily: 'Barlow')),
      SizedBox(height: 6),
      Text('DR analysis requires audio processing — available after playback.',
          style: TextStyle(color: kFg3, fontSize: 12, height: 1.4)),
    ]),
  );

  Widget _eqWidget() {
    final dim = !_eqOn;
    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: IgnorePointer(
        ignoring: dim,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Wrap(spacing: 4, children: ['Flat', 'Rock', 'Jazz', 'Vocal', 'Bass', 'Custom'].map((p) {
              final on = _eqPreset == p;
              return GestureDetector(
                onTap: () => setState(() {
                  _eqPreset = p;
                  if (_eqPresets.containsKey(p)) {
                    final v = _eqPresets[p]!;
                    for (int i = 0; i < 10; i++) { _eqBands[i] = v[i]; }
                  }
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: on ? kBrandOrange.withAlpha(40) : kBg2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: on ? kBrandOrange : kBorder),
                  ),
                  child: Text(p, style: TextStyle(
                      color: on ? kBrandOrange : kFg2, fontSize: 10, fontFamily: 'Barlow')),
                ),
              );
            }).toList()),
          ),
          SizedBox(height: 80, child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(10, (i) {
              return Expanded(child: Column(children: [
                Text(_eqBands[i] > 0 ? '+${_eqBands[i].toInt()}' : '${_eqBands[i].toInt()}',
                    style: TextStyle(color: _eqBands[i] == 0 ? kFg3 : kBrandOrange,
                        fontSize: 7, fontFamily: 'Barlow')),
                Expanded(child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                  child: RotatedBox(quarterTurns: 3, child: Slider(
                    value: _eqBands[i].clamp(-12, 12),
                    min: -12, max: 12, divisions: 24,
                    activeColor: kBrandOrange, inactiveColor: kBorder,
                    onChanged: (v) => setState(() { _eqBands[i] = v.roundToDouble(); _eqPreset = 'Custom'; }),
                  )),
                )),
                Text(_freqs[i], style: const TextStyle(color: kFg3, fontSize: 7, fontFamily: 'Barlow')),
              ]));
            }),
          )),
        ]),
      ),
    );
  }

  Widget _sleepDisplay() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kBrandGold.withAlpha(15),
      border: Border.all(color: kBrandGold.withAlpha(64)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: [
      const Icon(Icons.bedtime_outlined, color: kBrandGold, size: 28),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sleep timer active', style: TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(_sleepTimer == 'End of track'
            ? 'Stops after current track ends'
            : 'Stops playback in ${_sleepTimer.replaceAll(' min', '')} min',
            style: const TextStyle(color: kFg2, fontSize: 11)),
      ])),
      IconButton(
        icon: const Icon(Icons.close, color: kBrandCoral, size: 18),
        onPressed: () => setState(() => _sleepTimer = 'Off'),
      ),
    ]),
  );

  Widget _speedDial() {
    final color = _speed == 1.0 ? kBrandOrange : _speed < 1.0 ? kBrandCoral : const Color(0xFF29F89E);
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Text('${_speed.toStringAsFixed(2)}×',
            style: TextStyle(color: color, fontSize: 28, fontFamily: 'Syne', fontWeight: FontWeight.w800)),
      ),
    ));
  }

  Widget _hsCard() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kBg1, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(16)),
    child: const Row(children: [
      Icon(Icons.headset_outlined, color: kBrandOrange, size: 32),
      SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Configure button gestures', style: TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w700)),
        SizedBox(height: 2),
        Text('Works with 3-button inline remotes and BT headsets via AVRCP.',
            style: TextStyle(color: kFg2, fontSize: 11, height: 1.4)),
      ])),
    ]),
  );
}
