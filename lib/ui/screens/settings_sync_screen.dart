import 'package:flutter/material.dart';
import '../../core/constants.dart';

class SettingsSyncScreen extends StatefulWidget {
  const SettingsSyncScreen({super.key});
  @override State<SettingsSyncScreen> createState() => _SettingsSyncScreenState();
}

class _SettingsSyncScreenState extends State<SettingsSyncScreen> {
  String _role         = 'bidirectional';
  bool   _transferAudio = true;
  String _syncOver     = 'LAN';
  String _transcode    = 'FLAC→AAC 256';
  bool   _autoSync     = true;
  bool   _connected    = false;

  static const _roles = [
    ['bidirectional', 'Bidirectional', 'Phone ⇄ PC · merge with conflict resolution'],
    ['client',        'Phone is Client', 'PC is source of truth · phone pulls'],
    ['server',        'Phone is Server', 'Phone hosts; PC pulls from phone'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      appBar: AppBar(
        backgroundColor: kBg1, foregroundColor: kFg1,
        title: const Text('Devices & Sync', style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        // Status banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF60A5FA).withAlpha(15),
            border: Border.all(color: const Color(0xFF60A5FA).withAlpha(64)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(_connected ? Icons.wifi : Icons.wifi_off,
                color: _connected ? const Color(0xFF60A5FA) : kFg3, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_connected ? 'Sync · Auradec Desktop' : 'Sync · Not connected',
                  style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(_connected ? '● Online · 128 tracks on PC' : 'Open Auradec on desktop to pair',
                  style: TextStyle(
                      color: _connected ? const Color(0xFF60A5FA) : kFg3,
                      fontSize: 10, fontFamily: 'Barlow')),
            ])),
            if (!_connected)
              GestureDetector(
                onTap: () => setState(() => _connected = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF60A5FA).withAlpha(20),
                    border: Border.all(color: const Color(0xFF60A5FA).withAlpha(60)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Pair', style: TextStyle(
                      color: Color(0xFF60A5FA), fontSize: 11, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),

        // Sync direction
        _sh('Sync Direction'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(children: _roles.map((r) {
            final on = _role == r[0];
            return GestureDetector(
              onTap: () => setState(() => _role = r[0]),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: on ? kBrandOrange.withAlpha(20) : kBg1,
                  border: Border.all(color: on ? kBrandOrange.withAlpha(90) : kBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: on ? kBrandOrange : kFg3, width: 2),
                    ),
                    child: on ? Center(child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: kBrandOrange),
                    )) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r[1], style: TextStyle(
                        color: on ? kFg1 : kFg1, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(r[2], style: const TextStyle(color: kFg2, fontSize: 11, height: 1.3)),
                  ])),
                ]),
              ),
            );
          }).toList()),
        ),

        _sh('Options'),
        _tog('Transfer audio files', 'Off = sync metadata/ratings/playlists only',
            _transferAudio, (v) => setState(() => _transferAudio = v)),
        _seg('Sync over', _syncOver, ['LAN', 'Relay', 'Both'],
            (v) => setState(() => _syncOver = v)),
        _sel('Transcode for phone', 'Down-convert hi-res to save storage',
            _transcode, ['Off', 'FLAC→AAC 256', 'FLAC→Opus 192', 'Original'],
            (v) => setState(() => _transcode = v!)),
        _tog('Auto-sync on Wi-Fi', 'Automatically sync when on Wi-Fi',
            _autoSync, (v) => setState(() => _autoSync = v)),
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

  Widget _sel(String label, String? hint, String val, List<String> opts, ValueChanged<String?> cb) =>
    _row(label, hint, DropdownButton<String>(
      value: opts.contains(val) ? val : opts.first, dropdownColor: kBg2,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: on ? kBrandOrange : kBg2, borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? kBrandOrange : kBorder),
          ),
          child: Text(o, style: TextStyle(color: on ? Colors.white : kFg2,
              fontSize: 10, fontFamily: 'Barlow', fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
        ),
      );
    }).toList()));
}
