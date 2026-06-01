import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/scrobble_service.dart';

class SettingsScrobbleScreen extends StatefulWidget {
  const SettingsScrobbleScreen({super.key});
  @override State<SettingsScrobbleScreen> createState() => _SettingsScrobbleScreenState();
}

class _SettingsScrobbleScreenState extends State<SettingsScrobbleScreen> {
  late final ScrobbleService _svc;
  final _lfmApiKey  = TextEditingController(text: 'b25b959554ed76058ac220b7b2e0a026');
  final _lfmSecret  = TextEditingController(text: '');
  final _lbzToken   = TextEditingController();
  final _webhookUrl = TextEditingController();
  bool _useLfmBios    = true;
  double _threshold   = 50;
  bool _cacheOffline  = true;
  bool _submitLbz     = false;
  bool _webhookOn     = false;

  @override
  void initState() {
    super.initState();
    _svc = ScrobbleService.inst;
  }

  @override
  void dispose() {
    _lfmApiKey.dispose(); _lfmSecret.dispose();
    _lbzToken.dispose(); _webhookUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg1, foregroundColor: kFg1,
        title: const Text('Scrobbling', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        // ── Last.fm ─────────────────────────────────────────────────
        _sh('Last.fm'),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBrandCoral.withAlpha(15),
            border: Border.all(color: kBrandCoral.withAlpha(55)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.album_outlined, color: kBrandCoral, size: 18),
              const SizedBox(width: 8),
              const Text('Last.fm', style: TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Syne')),
              const Spacer(),
              Text(_svc.lfmConnected ? '● Connected' : '○ Not connected',
                  style: TextStyle(
                      color: _svc.lfmConnected ? kBrandGreen : kFg3,
                      fontSize: 9, letterSpacing: 1.5, fontFamily: 'Barlow')),
            ]),
            if (_svc.lfmConnected) ...[
              const SizedBox(height: 4),
              const Text('@auradec_user · 12,481 scrobbles',
                  style: TextStyle(color: kFg2, fontSize: 11, fontFamily: 'Barlow')),
            ],
            const SizedBox(height: 8),
            const Text(
              'Uses your own API key + shared secret — same credentials power bios and scrobbling.',
              style: TextStyle(color: kFg2, fontSize: 11, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              if (_svc.lfmConnected)
                _actionBtn('Re-auth', kBorder, kFg1, () {})
              else
                _actionBtn('Connect', kBrandOrange.withAlpha(60), kBrandOrange, () {}),
              const SizedBox(width: 8),
              if (_svc.lfmConnected)
                _actionBtn('Disconnect', kBrandCoral.withAlpha(60), kBrandCoral, () {}),
            ]),
          ]),
        ),
        _fieldRow('API key', _lfmApiKey, 'API key from last.fm/api'),
        _fieldRow('Shared secret', _lfmSecret, '••••••••••••••••', obscure: true),
        _tog('Use Last.fm for artist bios', 'Falls back to Wikipedia then AI', _useLfmBios,
            (v) => setState(() => _useLfmBios = v)),
        _slide('Scrobble threshold', 'Percentage of track played before scrobbling',
            _threshold, 30, 100, 5, '%', (v) => setState(() => _threshold = v)),
        _tog('Cache when offline', 'Flush to Last.fm when back online', _cacheOffline,
            (v) => setState(() => _cacheOffline = v)),

        // ── ListenBrainz ─────────────────────────────────────────
        _sh('ListenBrainz'),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBrandGold.withAlpha(15),
            border: Border.all(color: kBrandGold.withAlpha(55)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.hearing_outlined, color: kBrandGold, size: 18),
              const SizedBox(width: 8),
              const Text('ListenBrainz', style: TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Syne')),
              const Spacer(),
              Text(_svc.lbzConnected ? '● Connected' : '○ Not connected',
                  style: TextStyle(
                      color: _svc.lbzConnected ? kBrandGreen : kFg3,
                      fontSize: 9, letterSpacing: 1.5, fontFamily: 'Barlow')),
            ]),
            const SizedBox(height: 8),
            const Text('Open-source listen tracking by MetaBrainz. Free, no account limit.',
                style: TextStyle(color: kFg2, fontSize: 11, height: 1.5)),
            const SizedBox(height: 10),
            _actionBtn('Connect ListenBrainz', kBrandGold.withAlpha(30), kBrandGold, () {}),
          ]),
        ),
        _fieldRow('ListenBrainz user token', _lbzToken, 'Paste token…'),
        _tog('Submit to ListenBrainz', 'Send listens to ListenBrainz', _submitLbz,
            (v) => setState(() => _submitLbz = v)),

        // ── Webhook ─────────────────────────────────────────────
        _sh('Webhook'),
        _fieldRow('Webhook URL', _webhookUrl, 'https://…'),
        _tog('Enable webhook', 'POST JSON payload on each scrobble', _webhookOn,
            (v) => setState(() => _webhookOn = v)),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _sh(String label) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
    child: Text(label.toUpperCase(), style: const TextStyle(
        color: kBrandGold, fontSize: 8, letterSpacing: 2.5, fontFamily: 'Barlow', fontWeight: FontWeight.w700)),
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
      const SizedBox(width: 12), control,
    ]),
  );

  Widget _tog(String label, String? hint, bool val, ValueChanged<bool> cb) =>
    _row(label, hint, Switch(value: val, onChanged: cb, activeColor: kBrandOrange, inactiveTrackColor: kBorder));

  Widget _slide(String label, String? hint, double val, double min, double max, double step, String unit, ValueChanged<double> cb) =>
    Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), decoration: _rowBorder,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w500))),
          Text('${val.toStringAsFixed(0)}$unit', style: const TextStyle(color: kBrandOrange, fontSize: 12, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
        ]),
        if (hint != null) Text(hint, style: const TextStyle(color: kFg2, fontSize: 11)),
        Slider(value: val, min: min, max: max, divisions: ((max - min) / step).round(),
            activeColor: kBrandOrange, inactiveColor: kBorder, onChanged: cb),
      ]),
    );

  Widget _fieldRow(String label, TextEditingController ctrl, String placeholder, {bool obscure = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: _rowBorder,
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w500))),
      const SizedBox(width: 12),
      SizedBox(width: 160, child: TextField(
        controller: ctrl, obscureText: obscure,
        style: const TextStyle(color: kFg1, fontSize: 11, fontFamily: 'Barlow'),
        decoration: InputDecoration(
          hintText: placeholder, hintStyle: const TextStyle(color: kFg3, fontSize: 11),
          filled: true, fillColor: kBg2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBrandOrange)),
        ),
      )),
    ]),
  );

  Widget _actionBtn(String label, Color bg, Color fg, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withAlpha(60)),
        ),
        child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
      ),
    );
}
