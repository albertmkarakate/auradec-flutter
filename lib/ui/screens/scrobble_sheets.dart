import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../services/scrobble_service.dart';

// ---------------------------------------------------------------------------
// Last.fm connection bottom sheet
// ---------------------------------------------------------------------------

class LfmSheet extends StatefulWidget {
  final ScrobbleService svc;
  const LfmSheet({super.key, required this.svc});

  @override
  State<LfmSheet> createState() => _LfmSheetState();
}

class _LfmSheetState extends State<LfmSheet> {
  final _keyCtrl    = TextEditingController();
  final _secretCtrl = TextEditingController();
  String? _pendingToken;
  String  _status  = '';
  bool    _loading = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    return SafeArea(top: false, child: Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Last.fm',
            style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(svc.lfmConnected ? 'Connected' : 'Not connected',
            style: TextStyle(color: svc.lfmConnected ? kBrandGreen : kFg2, fontSize: 12)),
        const SizedBox(height: 16),
        if (!svc.lfmConnected) ...[
          _inputField(_keyCtrl,    'API Key',    obscure: false),
          const SizedBox(height: 10),
          _inputField(_secretCtrl, 'API Secret', obscure: true),
          const SizedBox(height: 14),
          if (_pendingToken == null)
            _btn('Step 1: Get auth token', kBrandOrange, _onGetToken)
          else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: kBg2, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Open this URL in a browser, then tap Complete:',
                    style: TextStyle(color: kFg2, fontSize: 11)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => Clipboard.setData(
                      ClipboardData(text: svc.authUrl(_pendingToken!))),
                  child: Text(svc.authUrl(_pendingToken!),
                      style: const TextStyle(
                          color: kBrandOrange, fontSize: 10,
                          decoration: TextDecoration.underline),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            _btn('Step 2: Complete auth', kBrandGreen, _onComplete),
          ],
        ] else
          _btn('Disconnect', kBrandCoral, _onDisconnect),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_status, style: const TextStyle(color: kFg2, fontSize: 11)),
        ],
        if (_loading) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator(color: kBrandOrange, strokeWidth: 2)),
        ],
      ]),
    ));
  }

  Widget _inputField(TextEditingController c, String hint, {required bool obscure}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: kFg1, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kFg3, fontSize: 13),
        filled: true, fillColor: kBg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBrandOrange)),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _onGetToken() async {
    final key    = _keyCtrl.text.trim();
    final secret = _secretCtrl.text.trim();
    if (key.isEmpty || secret.isEmpty) {
      setState(() => _status = 'Please enter your API key and secret.');
      return;
    }
    setState(() { _loading = true; _status = ''; });
    await widget.svc.setLfmCredentials(key, secret);
    final token = await widget.svc.getToken();
    setState(() => _loading = false);
    if (token == null) {
      setState(() => _status = 'Failed to get token. Check your API key.');
      return;
    }
    setState(() { _pendingToken = token; _status = ''; });
  }

  Future<void> _onComplete() async {
    setState(() { _loading = true; _status = ''; });
    final ok = await widget.svc.getSession(_pendingToken!);
    setState(() => _loading = false);
    if (ok) {
      setState(() => _status = 'Connected to Last.fm!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _status = 'Auth failed. Did you approve the token?');
    }
  }

  Future<void> _onDisconnect() async {
    await widget.svc.disconnectLfm();
    if (mounted) Navigator.pop(context);
  }
}

// ---------------------------------------------------------------------------
// ListenBrainz connection bottom sheet
// ---------------------------------------------------------------------------

class LbzSheet extends StatefulWidget {
  final ScrobbleService svc;
  const LbzSheet({super.key, required this.svc});

  @override
  State<LbzSheet> createState() => _LbzSheetState();
}

class _LbzSheetState extends State<LbzSheet> {
  final _tokenCtrl = TextEditingController();
  String _status   = '';
  bool   _loading  = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.svc;
    return SafeArea(top: false, child: Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ListenBrainz',
            style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(svc.lbzConnected ? 'Connected' : 'Not connected',
            style: TextStyle(color: svc.lbzConnected ? kBrandGreen : kFg2, fontSize: 12)),
        const SizedBox(height: 16),
        if (!svc.lbzConnected) ...[
          TextField(
            controller: _tokenCtrl,
            obscureText: true,
            style: const TextStyle(color: kFg1, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ListenBrainz user token',
              hintStyle: const TextStyle(color: kFg3, fontSize: 13),
              filled: true, fillColor: kBg2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kBrandOrange)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrandOrange.withValues(alpha: 0.15),
                foregroundColor: kBrandOrange,
                side: const BorderSide(color: kBrandOrange, width: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Save token',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _onDisconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrandCoral.withValues(alpha: 0.15),
                foregroundColor: kBrandCoral,
                side: const BorderSide(color: kBrandCoral, width: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Disconnect',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_status, style: const TextStyle(color: kFg2, fontSize: 11)),
        ],
        if (_loading) ...[
          const SizedBox(height: 12),
          const Center(
              child: CircularProgressIndicator(color: kBrandOrange, strokeWidth: 2)),
        ],
      ]),
    ));
  }

  Future<void> _onSave() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _status = 'Please enter your ListenBrainz token.');
      return;
    }
    setState(() { _loading = true; _status = ''; });
    await widget.svc.setLbzToken(token);
    setState(() { _loading = false; _status = 'Token saved.'; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onDisconnect() async {
    await widget.svc.disconnectLbz();
    if (mounted) Navigator.pop(context);
  }
}
