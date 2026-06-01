import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';

final _artCache = <String, Uint8List?>{};
const _ch = MethodChannel('app.auradec/media_store');

class AlbumArt extends StatefulWidget {
  final String? artUri;
  final String? filePath; // fallback for embedded art
  final String seed;
  final double size;
  final double radius;

  const AlbumArt({
    super.key,
    this.artUri,
    this.filePath,
    required this.seed,
    this.size = 48,
    this.radius = 10,
  });

  @override
  State<AlbumArt> createState() => _AlbumArtState();
}

class _AlbumArtState extends State<AlbumArt> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AlbumArt old) {
    super.didUpdateWidget(old);
    if (old.artUri != widget.artUri || old.filePath != widget.filePath) {
      _load();
    }
  }

  Future<void> _load() async {
    // Build cache key from artUri + filePath
    final key = '${widget.artUri ?? ""}|${widget.filePath ?? ""}';
    if (key == '|') return;

    if (_artCache.containsKey(key)) {
      if (mounted) setState(() => _bytes = _artCache[key]);
      return;
    }

    try {
      final bytes = await _ch.invokeMethod<Uint8List>('getArtwork', {
        'uri':      widget.artUri  ?? '',
        'filePath': widget.filePath ?? '',
      });
      _artCache[key] = bytes;
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      _artCache[key] = null;
      if (mounted) setState(() {});
    }
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
    const palettes = [
      [Color(0xFF3A2A1F), Color(0xFF7A3D1A), kBrandOrange],
      [Color(0xFF1F1A3A), Color(0xFF3D1A7A), Color(0xFF9333EA)],
      [Color(0xFF0D2A1F), Color(0xFF0A4D3A), kBrandGreen],
      [Color(0xFF2A0D1F), Color(0xFF7A1A3A), kBrandCoral],
      [Color(0xFF2A2A0D), Color(0xFF7A6A1A), kBrandGold],
      [Color(0xFF0D1A2A), Color(0xFF1A3D7A), Color(0xFF3A8FFF)],
    ];
    int h = 0;
    for (int i = 0; i < seed.length; i++) h = (h * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
    final p = palettes[h % palettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p[0], p[1], p[2]],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note, color: Colors.white.withAlpha(80), size: size * 0.4),
      ),
    );
  }
}
