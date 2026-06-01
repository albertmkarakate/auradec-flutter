import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';

final _artCache = <String, Uint8List?>{};
const _ch = MethodChannel('app.auradec/media_store');

class AlbumArt extends StatefulWidget {
  final String? artUri;
  final String seed;
  final double size;
  final double radius;

  const AlbumArt({super.key, this.artUri, required this.seed, this.size = 48, this.radius = 10});

  @override
  State<AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<AlbumArt> {
  Uint8List? _bytes;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AlbumArt old) {
    super.didUpdateWidget(old);
    if (old.artUri != widget.artUri) { _tried = false; _load(); }
  }

  Future<void> _load() async {
    final uri = widget.artUri;
    if (uri == null || uri.isEmpty) return;
    if (_artCache.containsKey(uri)) {
      if (mounted) setState(() => _bytes = _artCache[uri]);
      return;
    }
    try {
      final bytes = await _ch.invokeMethod<Uint8List>('getArtwork', {'uri': uri});
      _artCache[uri] = bytes;
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      _artCache[uri] = null;
    }
    if (mounted) setState(() => _tried = true);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size, height: widget.size,
        child: _bytes != null
            ? Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : _Placeholder(seed: widget.seed, size: widget.size),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String seed;
  final double size;
  const _Placeholder({required this.seed, required this.size});

  @override
  Widget build(BuildContext context) {
    final palettes = [
      [const Color(0xFF3A2A1F), const Color(0xFF7A3D1A), kBrandOrange],
      [const Color(0xFF1F1A3A), const Color(0xFF3D1A7A), const Color(0xFF9333EA)],
      [const Color(0xFF0D2A1F), const Color(0xFF0A4D3A), kBrandGreen],
      [const Color(0xFF2A0D1F), const Color(0xFF7A1A3A), kBrandCoral],
      [const Color(0xFF2A2A0D), const Color(0xFF7A6A1A), kBrandGold],
      [const Color(0xFF0D1A2A), const Color(0xFF1A3D7A), const Color(0xFF3A8FFF)],
    ];
    int h = 0;
    for (int i = 0; i < seed.length; i++) h = (h * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
    final p = palettes[h % palettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [p[0], p[1], p[2]], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(child: Icon(Icons.music_note, color: Colors.white.withAlpha(80), size: size * 0.4)),
    );
  }
}
