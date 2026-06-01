import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/audio_handler.dart';

class SettingsAudioScreen extends StatefulWidget {
  const SettingsAudioScreen({super.key});
  @override State<SettingsAudioScreen> createState() => _SettingsAudioScreenState();
}

class _SettingsAudioScreenState extends State<SettingsAudioScreen> {
  String _outputDevice  = 'System default';
  String _audioFocus    = 'Pause';
  bool   _resumeCall    = true;
  String _sampleRate    = 'Match source';
  int    _bitDepth      = 24;
  bool   _gapless       = true;
  double _crossfade     = 3.0;
  String _normMode      = 'Off';
  String _rgMode        = 'Album';
  double _rgPreamp      = -3.0;
  bool   _exclusiveMode = false;
  bool   _absVolume     = true;
  bool   _hiRes         = false;

  static const _sh = BorderSide(color: kBorder);

  @override
  Widget build(BuildContext context) {
    final h = AuradecAudioHandler.inst;
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg1,
        foregroundColor: kFg1,
        title: const Text('Audio', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => setState(() {
            _outputDevice = 'System default'; _audioFocus = 'Pause'; _resumeCall = true;
            _sampleRate = 'Match source'; _bitDepth = 24; _gapless = true; _crossfade = 3.0;
            _normMode = 'Off'; _rgMode = 'Album'; _rgPreamp = -3.0;
            _exclusiveMode = false; _absVolume = true; _hiRes = false;
          }),
          child: const Text('Reset', style: TextStyle(color: kFg2, fontSize: 12, fontFamily: 'Barlow', letterSpacing: 0.8))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        _sh2('Output & Routing'),
        _sel('Output device', null, _outputDevice,
            ['System default', 'Bluetooth A2DP', 'HDMI / USB-C', 'USB Audio Class 2'],
            (v) => setState(() => _outputDevice = v!)),
        _sel('Audio focus behaviour', 'What happens when another app requests audio focus',
            _audioFocus, ['Pause', 'Duck (−10 dB)', 'Continue', 'Stop'],
            (v) => setState(() => _audioFocus = v!)),
        _tog('Resume after call', 'Resumes playback when a phone call ends', _resumeCall,
            (v) => setState(() => _resumeCall = v)),

        _sh2('Format & Quality'),
        _sel('Sample rate', null, _sampleRate,
            ['Match source', '44.1 kHz', '48 kHz', '96 kHz', '192 kHz'],
            (v) => setState(() => _sampleRate = v!)),
        _pills('Bit depth', null, _bitDepth.toString(), ['16', '24', '32'],
            (v) => setState(() => _bitDepth = int.parse(v))),
        _tog('Gapless playback', 'Removes silence between consecutive tracks', _gapless,
            (v) { setState(() => _gapless = v); h.setGapless(v); }),
        _slide('Crossfade', null, _crossfade, 0, 12, 0.5, 's',
            (v) { setState(() => _crossfade = v); h.setCrossfade(v.round()); }),

        _sh2('Volume & ReplayGain'),
        _sel('Volume normalisation', 'Analyses and levels perceived loudness',
            _normMode, ['Off', 'R128 (−14 LUFS)', 'ReplayGain Track', 'ReplayGain Album', 'Peak (−1 dBFS)'],
            (v) => setState(() => _normMode = v!)),
        if (_normMode != 'Off') ...[
          _pills('ReplayGain mode', null, _rgMode, ['Off', 'Track', 'Album'],
              (v) => setState(() => _rgMode = v)),
          _slide('ReplayGain preamp', 'Applied on top of normalisation offset',
              _rgPreamp, -12, 12, 0.5, ' dB', (v) => setState(() => _rgPreamp = v)),
        ],

        _sh2('Advanced', color: kFg3),
        _tog('AudioTrack exclusive mode', 'Bypasses mixer on Pixel 6+ & Samsung Galaxy', _exclusiveMode,
            (v) => setState(() => _exclusiveMode = v)),
        _tog('Absolute volume control', 'Let Auradec set Bluetooth device volume directly', _absVolume,
            (v) => setState(() => _absVolume = v)),
        _tog('Hi-Res Audio passthrough', 'Bit-perfect USB audio via AudioRecord workaround', _hiRes,
            (v) => setState(() => _hiRes = v)),
      ]),
    );
  }

  Widget _sh2(String label, {Color color = kBrandGold}) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    decoration: const BoxDecoration(border: Border(bottom: _sh)),
    child: Text(label.toUpperCase(), style: TextStyle(
        color: color, fontSize: 8, letterSpacing: 2.5, fontFamily: 'Barlow', fontWeight: FontWeight.w700)),
  );

  Widget _row(String label, String? hint, Widget control) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w500)),
        if (hint != null) Padding(
          padding: const EdgeInsets.only(top: 2),
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
      value: val, dropdownColor: kBg2,
      style: const TextStyle(color: kFg1, fontSize: 12, fontFamily: 'Barlow'),
      underline: const SizedBox.shrink(),
      items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: cb,
    ));

  Widget _pills(String label, String? hint, String val, List<String> opts, ValueChanged<String> cb) =>
    _row(label, hint, Row(mainAxisSize: MainAxisSize.min, children: opts.map((o) {
      final on = val == o;
      return GestureDetector(
        onTap: () => cb(o),
        child: Container(
          margin: const EdgeInsets.only(left: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? kBrandOrange : kBg2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? kBrandOrange : kBorder),
          ),
          child: Text(o, style: TextStyle(color: on ? Colors.white : kFg2,
              fontSize: 10, fontFamily: 'Barlow', fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
        ),
      );
    }).toList()));

  Widget _slide(String label, String? hint, double val, double min, double max,
      double step, String unit, ValueChanged<double> cb) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w500))),
          Text('${val.toStringAsFixed(step < 1 ? 1 : 0)}$unit',
              style: const TextStyle(color: kBrandOrange, fontSize: 12, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
        ]),
        if (hint != null) Text(hint, style: const TextStyle(color: kFg2, fontSize: 11)),
        Slider(value: val, min: min, max: max, divisions: ((max - min) / step).round(),
            activeColor: kBrandOrange, inactiveColor: kBorder, onChanged: cb),
      ]),
    );
  }
}
