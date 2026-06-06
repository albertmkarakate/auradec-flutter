import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';

/// Shared bulk tag-edit bottom sheet. Pre-fills fields with values common to
/// all [tracks] (blank where they differ), writes via [LibraryController.bulkEditTags].
/// Returns the number of tracks updated (0 if cancelled / nothing written).
Future<int> showBulkEditSheet(BuildContext context, List<Track> tracks) async {
  if (tracks.isEmpty) return 0;

  String common(String Function(Track) f) {
    final v = f(tracks.first);
    return tracks.every((t) => f(t) == v) ? v : '';
  }

  final albumC       = TextEditingController(text: common((t) => t.album));
  final albumArtistC = TextEditingController(text: common((t) => t.albumArtist));
  final artistC      = TextEditingController(text: common((t) => t.artist));
  final genreC       = TextEditingController(text: common((t) => t.genre));
  final yearC        = TextEditingController(text: common((t) => t.year > 0 ? '${t.year}' : ''));

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kBg1,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: BulkEditForm(
        count: tracks.length,
        albumC: albumC, albumArtistC: albumArtistC,
        artistC: artistC, genreC: genreC, yearC: yearC,
      ),
    ),
  );

  if (saved != true) return 0;

  if (Platform.isAndroid) {
    final perm = Permission.manageExternalStorage;
    if (!await perm.isGranted) {
      final r = await perm.request();
      if (!r.isGranted) {
        if (r.isPermanentlyDenied) openAppSettings();
        return -1; // caller shows "permission needed"
      }
    }
  }

  return LibraryController.inst.bulkEditTags(
    tracks.map((t) => t.path).toList(),
    album:       albumC.text.trim().isEmpty ? null : albumC.text.trim(),
    albumArtist: albumArtistC.text.trim().isEmpty ? null : albumArtistC.text.trim(),
    artist:      artistC.text.trim().isEmpty ? null : artistC.text.trim(),
    genre:       genreC.text.trim().isEmpty ? null : genreC.text.trim(),
    year:        int.tryParse(yearC.text.trim()),
  );
}

class BulkEditForm extends StatelessWidget {
  final int count;
  final TextEditingController albumC, albumArtistC, artistC, genreC, yearC;
  const BulkEditForm({
    super.key,
    required this.count, required this.albumC, required this.albumArtistC,
    required this.artistC, required this.genreC, required this.yearC,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          width: 40, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
        Text('Edit $count track${count == 1 ? '' : 's'}',
            style: const TextStyle(color: kFg1, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Blank fields are left unchanged',
            style: TextStyle(color: kFg3, fontSize: 11)),
        const SizedBox(height: 16),
        _field('Album', albumC),
        _field('Album artist', albumArtistC),
        _field('Artist', artistC),
        _field('Genre', genreC),
        _field('Year', yearC, keyboard: TextInputType.number),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: kFg2)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kBrandOrange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ]),
      ]),
    ));
  }

  Widget _field(String label, TextEditingController c, {TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: keyboard,
      style: const TextStyle(color: kFg1, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kFg3, fontSize: 12),
        isDense: true,
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: kBorder)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kBrandOrange)),
      ),
    ),
  );
}
