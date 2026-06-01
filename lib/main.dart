import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'controllers/library_controller.dart';
import 'controllers/player_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/audio_handler.dart';
import 'ui/shell.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId:   'app.auradec.android.channel.audio',
    androidNotificationChannelName: 'AURADEC Playback',
    androidNotificationOngoing:     false,
    androidStopForegroundOnPause:   false,
    androidShowNotificationBadge:   false,
    preloadArtwork:     true,
    artDownscaleWidth:  300,
    artDownscaleHeight: 300,
  );

  await AuradecAudioHandler.inst.init();

  Get.put(ThemeController(),   permanent: true);
  Get.put(LibraryController(), permanent: true);
  Get.put(PlayerController(),  permanent: true);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:            Colors.transparent,
    statusBarIconBrightness:   Brightness.light,
    systemNavigationBarColor:  kBg0,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const AuradecApp());
}

class AuradecApp extends StatelessWidget {
  const AuradecApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.barlowTextTheme(ThemeData.dark().textTheme);
    return GetBuilder<ThemeController>(
      builder: (tc) => GetMaterialApp(
        title: 'AURADEC',
        debugShowCheckedModeBanner: false,
        theme: tc.buildTheme().copyWith(textTheme: baseText),
        home: const _SplashGate(),
      ),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) _ctrl.forward().then((_) {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const MainShell();
    return Stack(children: [
      const MainShell(),
      FadeTransition(
        opacity: ReverseAnimation(_fade),
        child: const _SplashScreen(),
      ),
    ]);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: Stack(children: [
        // Radial glow
        Center(child: Container(
          width: 320, height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              kBrandOrange.withAlpha(55), Colors.transparent,
            ]),
          ),
        )),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo mark
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBrandOrange,
              boxShadow: [BoxShadow(color: kBrandOrange.withAlpha(80), blurRadius: 40, spreadRadius: 4)],
            ),
            child: const Icon(Icons.headphones, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 24),
          // Wordmark
          RichText(text: TextSpan(children: [
            TextSpan(text: 'AURA', style: GoogleFonts.syne(
              fontSize: 36, fontWeight: FontWeight.w800, color: kFg1, letterSpacing: -0.5)),
            TextSpan(text: 'DEC', style: GoogleFonts.syne(
              fontSize: 36, fontWeight: FontWeight.w800, color: kBrandOrange, letterSpacing: -0.5)),
          ])),
          const SizedBox(height: 8),
          Text('Sound for every culture', style: GoogleFonts.jetBrainsMono(
            fontSize: 9, letterSpacing: 3.5, color: kBrandGold,
          )),
          const SizedBox(height: 56),
          // EQ bars
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
            _AnimBar(delay: Duration(milliseconds: i * 100)),
          )),
        ])),
      ]),
    );
  }
}

class _AnimBar extends StatefulWidget {
  final Duration delay;
  const _AnimBar({required this.delay});
  @override
  State<_AnimBar> createState() => _AnimBarState();
}

class _AnimBarState extends State<_AnimBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _h;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addStatusListener((s) { if (s == AnimationStatus.completed) _ctrl.reverse(); else if (s == AnimationStatus.dismissed) _ctrl.forward(); });
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
    _h = Tween(begin: 6.0, end: 24.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _h,
    builder: (_, __) => Container(
      width: 4, height: _h.value,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: kBrandOrange, borderRadius: BorderRadius.circular(2)),
    ),
  );
}
