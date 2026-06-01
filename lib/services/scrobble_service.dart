import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/track.dart';

// ---------------------------------------------------------------------------
// ScrobbleService — Last.fm + ListenBrainz scrobbling
// ---------------------------------------------------------------------------
// Last.fm: MD5-signed API calls (api_sig = sorted key=value pairs + secret)
// ListenBrainz: token-based Bearer auth
// ---------------------------------------------------------------------------

const _kLfmBase  = 'https://ws.audioscrobbler.com/2.0/';
const _kLbzBase  = 'https://api.listenbrainz.org/1/submit-listens';
const _kPrefLfmSession   = 'lfm_session';
const _kPrefLfmApiKey    = 'lfm_api_key';
const _kPrefLfmApiSecret = 'lfm_api_secret';
const _kPrefLbzToken     = 'lbz_token';
const _kPrefScrobbleCount = 'scrobble_count';

class ScrobbleService {
  static final ScrobbleService inst = ScrobbleService._();
  ScrobbleService._();

  // Observable state
  final Rx<int> scrobbleCount = 0.obs;

  // In-memory credentials (loaded once from prefs)
  String _lfmApiKey    = '';
  String _lfmApiSecret = '';
  String? _lfmSessionKey;
  String? _lbzToken;

  bool get lfmConnected => _lfmSessionKey != null && _lfmSessionKey!.isNotEmpty;
  bool get lbzConnected => _lbzToken != null && _lbzToken!.isNotEmpty;

  /// Call once at app startup (e.g. from PlayerController.onInit).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _lfmApiKey    = prefs.getString(_kPrefLfmApiKey)    ?? '';
    _lfmApiSecret = prefs.getString(_kPrefLfmApiSecret) ?? '';
    _lfmSessionKey = prefs.getString(_kPrefLfmSession);
    _lbzToken      = prefs.getString(_kPrefLbzToken);
    scrobbleCount.value = prefs.getInt(_kPrefScrobbleCount) ?? 0;
  }

  // ── Public API ──────────────────────────────────────────────────────

  /// Call when a track starts playing. Reports "now playing" to both services.
  Future<void> nowPlaying(Track t) async {
    if (lfmConnected) await _lfmNowPlaying(t);
    if (lbzConnected) await _lbzNowPlaying(t);
  }

  /// Call when a track has been listened to (typically when the next track loads).
  Future<void> scrobble(Track t) async {
    bool submitted = false;
    if (lfmConnected) {
      final ok = await _lfmScrobble(t);
      if (ok) submitted = true;
    }
    if (lbzConnected) {
      final ok = await _lbzScrobble(t);
      if (ok) submitted = true;
    }
    if (submitted) await _incrementCount();
  }

  // ── Last.fm credentials management ─────────────────────────────────

  /// Persist API key + secret; does NOT connect yet.
  Future<void> setLfmCredentials(String apiKey, String apiSecret) async {
    _lfmApiKey    = apiKey;
    _lfmApiSecret = apiSecret;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefLfmApiKey,    apiKey);
    await prefs.setString(_kPrefLfmApiSecret, apiSecret);
  }

  /// Step 1: Request a short-lived token from Last.fm.
  /// Returns null on failure.
  Future<String?> getToken() async {
    if (_lfmApiKey.isEmpty) return null;
    try {
      final uri = Uri.parse('$_kLfmBase?method=auth.getToken'
          '&api_key=$_lfmApiKey&format=json');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return j['token'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Step 2: Returns the URL the user should open to authorise the token.
  String authUrl(String token) =>
      'https://www.last.fm/api/auth/?api_key=$_lfmApiKey&token=$token';

  /// Step 3: Exchange the authorised token for a session key.
  /// Returns true on success.
  Future<bool> getSession(String token) async {
    if (_lfmApiKey.isEmpty || _lfmApiSecret.isEmpty) return false;
    try {
      final params = <String, String>{
        'method':  'auth.getSession',
        'api_key': _lfmApiKey,
        'token':   token,
      };
      params['api_sig'] = _sign(params);
      params['format']  = 'json';

      final res = await http.post(Uri.parse(_kLfmBase), body: params)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;

      final j    = jsonDecode(res.body) as Map<String, dynamic>;
      final sess = j['session'] as Map<String, dynamic>?;
      if (sess == null) return false;

      _lfmSessionKey = sess['key'] as String?;
      if (_lfmSessionKey == null || _lfmSessionKey!.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefLfmSession, _lfmSessionKey!);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Disconnect Last.fm.
  Future<void> disconnectLfm() async {
    _lfmSessionKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefLfmSession);
  }

  // ── ListenBrainz credentials management ────────────────────────────

  Future<void> setLbzToken(String token) async {
    _lbzToken = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefLbzToken, _lbzToken!);
  }

  Future<void> disconnectLbz() async {
    _lbzToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefLbzToken);
  }

  // ── Last.fm internals ───────────────────────────────────────────────

  Future<bool> _lfmNowPlaying(Track t) async {
    try {
      final params = <String, String>{
        'method':    'track.updateNowPlaying',
        'artist':    t.artist,
        'track':     t.title,
        'album':     t.album,
        'api_key':   _lfmApiKey,
        'sk':        _lfmSessionKey!,
      };
      if (t.durationMs > 0) {
        params['duration'] = '${(t.durationMs / 1000).round()}';
      }
      params['api_sig'] = _sign(params);
      params['format']  = 'json';

      final res = await http.post(Uri.parse(_kLfmBase), body: params)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _lfmScrobble(Track t) async {
    try {
      final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final params = <String, String>{
        'method':       'track.scrobble',
        'artist[0]':    t.artist,
        'track[0]':     t.title,
        'album[0]':     t.album,
        'timestamp[0]': ts,
        'api_key':      _lfmApiKey,
        'sk':           _lfmSessionKey!,
      };
      params['api_sig'] = _sign(params);
      params['format']  = 'json';

      final res = await http.post(Uri.parse(_kLfmBase), body: params)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// MD5 signature: sort keys alphabetically, concatenate as key=value pairs
  /// (excluding 'format' and 'callback'), then append secret, MD5 the whole string.
  String _sign(Map<String, String> params) {
    final keys = params.keys
        .where((k) => k != 'format' && k != 'callback')
        .toList()
      ..sort();
    final raw = keys.fold('', (buf, k) => '$buf$k${params[k]}') + _lfmApiSecret;
    return md5.convert(utf8.encode(raw)).toString();
  }

  // ── ListenBrainz internals ──────────────────────────────────────────

  Future<bool> _lbzNowPlaying(Track t) async {
    try {
      final body = jsonEncode({
        'listen_type': 'playing_now',
        'payload': [
          {
            'track_metadata': {
              'artist_name':  t.artist,
              'track_name':   t.title,
              'release_name': t.album,
            },
          }
        ],
      });
      final res = await http.post(
        Uri.parse(_kLbzBase),
        headers: {
          'Authorization': 'Token $_lbzToken',
          'Content-Type':  'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _lbzScrobble(Track t) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = jsonEncode({
        'listen_type': 'single',
        'payload': [
          {
            'listened_at':   ts,
            'track_metadata': {
              'artist_name':  t.artist,
              'track_name':   t.title,
              'release_name': t.album,
            },
          }
        ],
      });
      final res = await http.post(
        Uri.parse(_kLbzBase),
        headers: {
          'Authorization': 'Token $_lbzToken',
          'Content-Type':  'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  Future<void> _incrementCount() async {
    scrobbleCount.value += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefScrobbleCount, scrobbleCount.value);
  }
}
