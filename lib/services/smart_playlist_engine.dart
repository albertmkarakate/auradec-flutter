// Smart-playlist rule engine — Dart port of desktop evalSmart.
//
// Rules schema (matches desktop):
//   SmartRules { match:'all'|'any', conditions:[SmartCondition], sort }
//
// Supported fields:
//   rating      — 0–100 numeric
//   plays       — int
//   durationSec — int seconds
//   year        — int
//   lastDays    — derived from lastPlayed timestamp
//   genre / artist / album / title — text
//
// Numeric ops:  gte lte gt lt eq
// Text ops:     contains is not starts
// Days ops:     within before never
//
// Sort keys:  rating plays recent added duration title

import '../core/track.dart';

// ── Field type map ────────────────────────────────────────────────────────────

enum _FieldType { num, text, days }

_FieldType _fieldType(String field) {
  switch (field) {
    case 'rating':
    case 'plays':
    case 'durationSec':
    case 'year':      return _FieldType.num;
    case 'lastDays':  return _FieldType.days;
    default:          return _FieldType.text;
  }
}

// ── Field extraction ──────────────────────────────────────────────────────────

dynamic _fieldVal(Track t, String field) {
  switch (field) {
    case 'rating':      return t.rating;
    case 'plays':       return t.plays;
    case 'durationSec': return (t.durationMs / 1000).round();
    case 'year':        return t.year;
    case 'genre':       return t.genre;
    case 'artist':      return t.artist;
    case 'album':       return t.album;
    case 'title':       return t.title;
    default:            return '';
  }
}

// ── Single condition evaluation ───────────────────────────────────────────────

bool _evalCond(Track t, SmartCondition c) {
  final type = _fieldType(c.field);

  if (type == _FieldType.days) {
    final lastMs = t.lastPlayed; // ms since epoch, 0 = never
    final n = double.tryParse(c.value) ?? 0;
    if (c.op == 'never') return lastMs == 0 && t.plays == 0;
    if (lastMs == 0) {
      // Never played — treat as Infinity days ago
      return c.op == 'before'; // "not in last N" = true; "within" = false
    }
    final days = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastMs)).inHours / 24.0;
    if (c.op == 'within') return days <= n;
    if (c.op == 'before') return days > n;
    return true;
  }

  if (type == _FieldType.text) {
    final v = (_fieldVal(t, c.field) as String? ?? '').toLowerCase();
    final q = c.value.trim().toLowerCase();
    if (q.isEmpty) return true;
    switch (c.op) {
      case 'is':     return v == q;
      case 'not':    return v != q;
      case 'starts': return v.startsWith(q);
      default:       return v.contains(q); // 'contains'
    }
  }

  // Numeric
  final raw = _fieldVal(t, c.field);
  final v = (raw is int ? raw.toDouble() : (raw is double ? raw : 0.0));
  final n = double.tryParse(c.value);
  if (n == null) return true;
  // durationSec already in seconds; desktop used minutes, convert if needed
  final nv = (c.field == 'durationSec' && c.value.contains('.'))
      ? n * 60 // fractional minute input → seconds
      : n;
  switch (c.op) {
    case 'gte': return v >= nv;
    case 'lte': return v <= nv;
    case 'gt':  return v > nv;
    case 'lt':  return v < nv;
    default:    return v == nv; // 'eq'
  }
}

// ── Public evalSmart ──────────────────────────────────────────────────────────

/// Evaluate [rules] against [tracks] and return matching tracks sorted per rules.sort.
/// Returns [] if rules has no conditions.
List<Track> evalSmart(SmartRules rules, List<Track> tracks) {
  final conds = rules.conditions.where((c) => c.field.isNotEmpty).toList();
  if (conds.isEmpty) return [];

  final any = rules.match == 'any';
  var out = tracks.where((t) =>
    any ? conds.any((c) => _evalCond(t, c)) : conds.every((c) => _evalCond(t, c))
  ).toList();

  switch (rules.sort) {
    case 'rating':
      out.sort((a, b) => b.rating.compareTo(a.rating));
      break;
    case 'plays':
      out.sort((a, b) => b.plays.compareTo(a.plays));
      break;
    case 'recent':
      out.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
      break;
    case 'added':
      // Use path lexicographic as proxy (indexed on scan order); flip for newest first
      out.sort((a, b) => b.path.compareTo(a.path));
      break;
    case 'duration':
      out.sort((a, b) => b.durationMs.compareTo(a.durationMs));
      break;
    default: // 'title'
      out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
  return out;
}

// ── Built-in preset factory ───────────────────────────────────────────────────
// These replace the 7 hardcoded _Smart objects. They are SmartRules instances
// so they evaluate live and can be shown using the same path as user playlists.

class SmartPreset {
  final String name;
  final String icon;   // material icon name string
  final String color;  // hex
  final SmartRules rules;
  const SmartPreset({required this.name, required this.icon, required this.color, required this.rules});
}

const kBuiltinPresets = [
  SmartPreset(
    name: 'Favourites', icon: 'favorite', color: '#FF6B6B',
    rules: SmartRules(
      match: 'all',
      conditions: [SmartCondition(field: 'plays', op: 'gte', value: '0')], // loved filter via custom field
      sort: 'plays',
    ),
  ),
  SmartPreset(
    name: 'Top Rated', icon: 'star', color: '#F5B32A',
    rules: SmartRules(
      match: 'all',
      conditions: [SmartCondition(field: 'rating', op: 'gte', value: '80')],
      sort: 'rating',
    ),
  ),
  SmartPreset(
    name: 'Most Played', icon: 'local_fire_department', color: '#FF5C1A',
    rules: SmartRules(
      match: 'all',
      conditions: [SmartCondition(field: 'plays', op: 'gte', value: '1')],
      sort: 'plays',
    ),
  ),
  SmartPreset(
    name: 'Recently Played', icon: 'history', color: '#4ADE80',
    rules: SmartRules(
      match: 'all',
      conditions: [SmartCondition(field: 'lastDays', op: 'within', value: '30')],
      sort: 'recent',
    ),
  ),
  SmartPreset(
    name: 'On Repeat', icon: 'repeat', color: '#FF5C1A',
    rules: SmartRules(
      match: 'all',
      conditions: [SmartCondition(field: 'plays', op: 'gte', value: '5')],
      sort: 'plays',
    ),
  ),
  SmartPreset(
    name: 'Hidden Gems', icon: 'diamond', color: '#F5B32A',
    rules: SmartRules(
      match: 'all',
      conditions: [
        SmartCondition(field: 'rating', op: 'gte', value: '80'),
        SmartCondition(field: 'plays',  op: 'lte', value: '2'),
      ],
      sort: 'rating',
    ),
  ),
  SmartPreset(
    name: 'Not Played', icon: 'fiber_new', color: '#94A3B8',
    rules: SmartRules(
      match: 'all',
      conditions: [SmartCondition(field: 'plays', op: 'eq', value: '0')],
      sort: 'title',
    ),
  ),
];

/// Evaluate a built-in preset (uses loved field for Favourites).
List<Track> evalPreset(SmartPreset preset, List<Track> tracks) {
  if (preset.name == 'Favourites') {
    return (tracks.where((t) => t.loved).toList())
      ..sort((a, b) => b.plays.compareTo(a.plays));
  }
  return evalSmart(preset.rules, tracks);
}
