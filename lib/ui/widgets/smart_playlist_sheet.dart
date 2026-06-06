// Smart playlist rule builder bottom sheet.
// Mirrors the desktop NewPlaylistModal smart mode:
//   - match all | any
//   - list of conditions { field, op, value }
//   - sort selection
//   - live track count preview
//
// Long-press a user smart playlist card → opens this in edit mode.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../services/smart_playlist_engine.dart';

// ── Field / op metadata ───────────────────────────────────────────────────────

class _Field {
  final String id;
  final String label;
  final String type; // num | text | days
  const _Field(this.id, this.label, this.type);
}

class _Op {
  final String id;
  final String label;
  const _Op(this.id, this.label);
}

const _fields = [
  _Field('rating',      'Rating (0–100)',    'num'),
  _Field('plays',       'Play count',        'num'),
  _Field('durationSec', 'Duration (sec)',    'num'),
  _Field('year',        'Year',              'num'),
  _Field('lastDays',    'Last played',       'days'),
  _Field('genre',       'Genre',             'text'),
  _Field('artist',      'Artist',            'text'),
  _Field('album',       'Album',             'text'),
  _Field('title',       'Title',             'text'),
];

const _numOps  = [_Op('gte','≥'), _Op('lte','≤'), _Op('gt','>'), _Op('lt','<'), _Op('eq','=')];
const _textOps = [_Op('contains','contains'), _Op('is','is'), _Op('not','is not'), _Op('starts','starts with')];
const _daysOps = [_Op('within','within last N days'), _Op('before','not in last N days'), _Op('never','never played')];

const _sorts = [
  _Op('title',    'Title A–Z'),
  _Op('rating',   'Highest rated'),
  _Op('plays',    'Most played'),
  _Op('recent',   'Recently played'),
  _Op('added',    'Recently added'),
  _Op('duration', 'Longest first'),
];

String _fieldType(String id) => _fields.firstWhere((f) => f.id == id, orElse: () => const _Field('','','num')).type;
List<_Op> _opsFor(String id) {
  switch (_fieldType(id)) {
    case 'text': return _textOps;
    case 'days': return _daysOps;
    default:     return _numOps;
  }
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class SmartPlaylistSheet extends StatefulWidget {
  final Playlist? editing;
  const SmartPlaylistSheet({super.key, this.editing});
  @override State<SmartPlaylistSheet> createState() => _SmartPlaylistSheetState();
}

class _SmartPlaylistSheetState extends State<SmartPlaylistSheet> {
  late final TextEditingController _nameCtrl;
  late String _match;  // 'all' | 'any'
  late String _sort;
  late List<SmartCondition> _conds;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _match = e?.rules?.match ?? 'all';
    _sort  = e?.rules?.sort  ?? 'title';
    _conds = e?.rules?.conditions.map((c) => SmartCondition(field: c.field, op: c.op, value: c.value)).toList()
           ?? [const SmartCondition(field: 'rating', op: 'gte', value: '80')];
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  SmartRules get _rules => SmartRules(match: _match, conditions: _conds, sort: _sort);

  List<Track> get _preview {
    final lib = LibraryController.inst;
    return evalSmart(_rules, lib.tracks.toList());
  }

  void _addCond() => setState(() => _conds.add(const SmartCondition(field: 'plays', op: 'gte', value: '1')));

  void _removeCond(int i) => setState(() => _conds.removeAt(i));

  void _updateCond(int i, {String? field, String? op, String? value}) {
    setState(() {
      final old = _conds[i];
      String newField = field ?? old.field;
      String newOp    = op    ?? old.op;
      // Reset op when field type changes
      if (field != null && _fieldType(field) != _fieldType(old.field)) {
        newOp = _opsFor(newField).first.id;
      }
      _conds[i] = SmartCondition(field: newField, op: newOp, value: value ?? old.value);
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _nameCtrl.clear(); return; }
    if (_conds.isEmpty) return;
    final lib = LibraryController.inst;
    final e = widget.editing;
    if (e != null) {
      await lib.updateSmartPlaylist(e.id, name, _rules);
    } else {
      await lib.createSmartPlaylist(name, _rules, color: '#A78BFA');
    }
    if (mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: kBg1, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                widget.editing != null ? 'Edit Smart Playlist' : 'New Smart Playlist',
                style: const TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700))),
              // Preview count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1FA78BFA), borderRadius: BorderRadius.circular(6)),
                child: Text('${preview.length} tracks',
                    style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontFamily: 'Barlow')),
              ),
            ]),
          ),
          const Divider(color: kBorder, height: 1),
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
            // Name
            _label('Playlist name'),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: kFg1, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'My Smart Playlist…',
                hintStyle: const TextStyle(color: kFg3),
                filled: true, fillColor: kBg2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            // Match
            _label('Match'),
            Row(children: [
              _seg('All conditions', _match == 'all', () => setState(() => _match = 'all')),
              const SizedBox(width: 8),
              _seg('Any condition',  _match == 'any', () => setState(() => _match = 'any')),
            ]),
            const SizedBox(height: 16),
            // Conditions
            _label('Rules'),
            ..._conds.asMap().entries.map((e) => _condRow(e.key, e.value)),
            TextButton.icon(
              onPressed: _addCond,
              icon: const Icon(Icons.add, size: 16, color: Color(0xFFA78BFA)),
              label: const Text('Add rule', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 13)),
            ),
            const SizedBox(height: 16),
            // Sort
            _label('Sort by'),
            DropdownButtonFormField<String>(
              value: _sort,
              dropdownColor: kBg2,
              style: const TextStyle(color: kFg1, fontSize: 13),
              decoration: InputDecoration(
                filled: true, fillColor: kBg2, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(10)),
              ),
              items: _sorts.map((s) => DropdownMenuItem(value: s.id, child: Text(s.label))).toList(),
              onChanged: (v) { if (v != null) setState(() => _sort = v); },
            ),
            const SizedBox(height: 80),
          ])),
          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(color: kBg1, border: Border(top: BorderSide(color: kBorder))),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Get.back(),
                child: const Text('Cancel', style: TextStyle(color: kFg2)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _save,
                child: Text(widget.editing != null ? 'Update' : 'Create',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _condRow(int i, SmartCondition c) {
    final ops = _opsFor(c.field);
    final currentOp = ops.any((o) => o.id == c.op) ? c.op : ops.first.id;
    final isNever = c.op == 'never';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Field dropdown
        Expanded(flex: 3, child: _dd(
          value: c.field,
          items: _fields.map((f) => DropdownMenuItem(value: f.id, child: Text(f.label, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) _updateCond(i, field: v); },
        )),
        const SizedBox(width: 6),
        // Op dropdown
        Expanded(flex: 3, child: _dd(
          value: currentOp,
          items: ops.map((o) => DropdownMenuItem(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) _updateCond(i, op: v); },
        )),
        const SizedBox(width: 6),
        // Value input (hidden for 'never')
        if (!isNever)
          Expanded(flex: 2, child: TextFormField(
            initialValue: c.value,
            style: const TextStyle(color: kFg1, fontSize: 12),
            keyboardType: _fieldType(c.field) == 'num' || _fieldType(c.field) == 'days'
                ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true, fillColor: kBg2,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => _updateCond(i, value: v),
          )),
        const SizedBox(width: 4),
        // Remove
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18, color: kBrandCoral),
          onPressed: _conds.length > 1 ? () => _removeCond(i) : null,
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }

  Widget _dd<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) =>
    DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: kBg2,
      style: const TextStyle(color: kFg1, fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true, fillColor: kBg2,
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
      ),
      items: items,
      onChanged: onChanged,
    );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text.toUpperCase(),
        style: const TextStyle(color: kBrandGold, fontSize: 8, letterSpacing: 2, fontFamily: 'Barlow')),
  );

  Widget _seg(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? const Color(0x1FA78BFA) : kBg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? const Color(0xFFA78BFA) : kBorder)),
      child: Text(label, style: TextStyle(
          color: active ? const Color(0xFFA78BFA) : kFg2, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}
