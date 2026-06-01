import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../services/indexer_service.dart';
import '../../services/media_store_service.dart';
import '../../controllers/library_controller.dart';

/// Musicolet-style folder picker: shows all MediaStore folders as a checklist.
class FolderPickerScreen extends StatefulWidget {
  const FolderPickerScreen({super.key});
  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  List<_FolderItem> _folders = [];
  bool _loading = true;
  String _query = '';
  Set<String> _checked = {};

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _loading = true);
    try {
      final lib = LibraryController.inst;

      await IndexerService.inst.requestPermission();

      // Use embedded Kotlin MediaStore plugin — Namida getFolders pattern
      final folderInfos = await MediaStoreService.inst.getFolders();

      final savedChecked = lib.checkedFolders.isNotEmpty
          ? Set<String>.from(lib.checkedFolders)
          : folderInfos.map((f) => f.path).toSet(); // default: all checked

      _folders = folderInfos
          .map((f) => _FolderItem(path: f.path, count: f.count))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      _checked = savedChecked;
    } catch (e) {
      debugPrint('FolderPickerScreen load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_FolderItem> get _visible {
    if (_query.isEmpty) return _folders;
    return _folders.where((f) => f.path.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  int get _checkedTrackCount => _folders
      .where((f) => _checked.contains(f.path))
      .fold(0, (s, f) => s + f.count);

  void _toggle(String path) {
    setState(() => _checked.contains(path) ? _checked.remove(path) : _checked.add(path));
  }

  Future<void> _apply() async {
    await LibraryController.inst.saveCheckedFolders(_checked.toList());
    Get.back();
    await LibraryController.inst.scanLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(child: _buildList()),
      ])),
    );
  }

  Widget _buildHeader() {
    final allChecked  = _folders.isNotEmpty && _folders.every((f) => _checked.contains(f.path));
    final noneChecked = !_folders.any((f) => _checked.contains(f.path));

    return Container(
      color: kBg1,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        // Top row
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: kFg2), onPressed: () => Get.back()),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Music Folders', style: TextStyle(color: kFg1, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            Text(
              _loading ? 'Loading…' : '${_folders.length} folders · ${_checked.length} selected · $_checkedTrackCount tracks',
              style: const TextStyle(color: kFg2, fontSize: 11),
            ),
          ])),
          ElevatedButton(
            onPressed: noneChecked ? null : _apply,
            style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange, foregroundColor: Colors.white, disabledBackgroundColor: kBg2),
            child: Obx(() => LibraryController.inst.isScanning.value
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Rescan')),
          ),
        ]),
        const SizedBox(height: 10),

        // Search bar
        Container(
          height: 40,
          decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
          child: TextField(
            style: const TextStyle(color: kFg1, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Filter folders…', hintStyle: TextStyle(color: kFg3, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: kFg3, size: 16),
              border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),

        // Select all / deselect all
        Row(children: [
          TextButton(
            onPressed: allChecked ? null : () => setState(() => _checked = _folders.map((f) => f.path).toSet()),
            child: Text('Select all', style: TextStyle(color: allChecked ? kFg3 : kBrandOrange, fontSize: 12)),
          ),
          TextButton(
            onPressed: noneChecked ? null : () => setState(() => _checked.clear()),
            child: Text('Deselect all', style: TextStyle(color: noneChecked ? kFg3 : const Color(0xFFFF4D6A), fontSize: 12)),
          ),
          const Spacer(),
          Text('$_checkedTrackCount tracks', style: const TextStyle(color: kFg3, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: kBrandOrange),
        SizedBox(height: 16),
        Text('Reading folders…', style: TextStyle(color: kFg2, fontSize: 13)),
      ]));
    }

    if (_folders.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.folder_off, color: kFg3, size: 48),
        const SizedBox(height: 12),
        const Text('No music folders found', style: TextStyle(color: kFg2, fontSize: 14)),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Scan device first'),
          style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange, foregroundColor: Colors.white),
          onPressed: () async { Get.back(); await LibraryController.inst.scanLibrary(); },
        ),
      ]));
    }

    final visible = _visible;
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (ctx, i) {
        final f = visible[i];
        final on = _checked.contains(f.path);
        final depth = '/'.allMatches(f.path).length - 1;
        final indent = (depth - 2).clamp(0, 5) * 14.0;
        final name = f.path.split('/').last;

        return InkWell(
          onTap: () => _toggle(f.path),
          child: Container(
            color: on ? kBrandOrange.withAlpha(12) : Colors.transparent,
            padding: EdgeInsets.fromLTRB(16 + indent, 12, 16, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder.withAlpha(60)))),
            child: Row(children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: on ? kBrandOrange : kFg3, width: 2),
                  color: on ? kBrandOrange : Colors.transparent,
                ),
                child: on ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
              ),
              const SizedBox(width: 12),
              Icon(Icons.folder_outlined, color: on ? kBrandOrange : kFg3, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? f.path : name, style: TextStyle(color: on ? kFg1 : kFg2, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(f.path, style: const TextStyle(color: kFg3, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Text(f.count.toString(), style: TextStyle(color: on ? kBrandOrange : kFg3, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      },
    );
  }
}

class _FolderItem {
  final String path;
  final int count;
  _FolderItem({required this.path, required this.count});
}
