import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefAccent    = 'auradec_theme_accent';
const _kPrefSecondary = 'auradec_theme_secondary';
const _kPrefSchemeId  = 'auradec_theme_scheme';

class ThemeScheme {
  final String id;
  final String name;
  final Color accent;
  final Color? secondary;
  const ThemeScheme(this.id, this.name, this.accent, [this.secondary]);
}

const kSchemes = [
  ThemeScheme('void',      'Void',       Color(0xFFFF5C1A)),
  ThemeScheme('ember',     'Ember',      Color(0xFFFF8000)),
  ThemeScheme('gold',      'Gold Rush',  Color(0xFFF5B32A)),
  ThemeScheme('pulse',     'Pulse',      Color(0xFF29F89E)),
  ThemeScheme('coral',     'Coral',      Color(0xFFFF4D6A)),
  ThemeScheme('tide',      'Tide',       Color(0xFF60A5FA)),
  ThemeScheme('dusk',      'Dusk',       Color(0xFFA78BFA)),
  ThemeScheme('bloom',     'Bloom',      Color(0xFFFF7AC6)),
  ThemeScheme('inferno',   'Inferno',    Color(0xFFFF5C1A), Color(0xFFFF8000)),
  ThemeScheme('harvest',   'Harvest',    Color(0xFFFF5C1A), Color(0xFFF5B32A)),
  ThemeScheme('spark',     'Spark',      Color(0xFFFF5C1A), Color(0xFF29F89E)),
  ThemeScheme('aurora',    'Aurora',     Color(0xFF29F89E), Color(0xFF60A5FA)),
  ThemeScheme('vivid',     'Vivid',      Color(0xFF29F89E), Color(0xFFFF4D6A)),
  ThemeScheme('cosmic',    'Cosmic',     Color(0xFFF5B32A), Color(0xFFFF4D6A)),
];

class ThemeController extends GetxController {
  static ThemeController get inst => Get.find();

  final accent    = const Color(0xFFFF5C1A).obs;
  final secondary = Rx<Color?>(null);
  final schemeId  = 'void'.obs;

  // Density: 0=Compact, 1=Comfy (default), 2=Loose
  final density = 1.obs;
  double get listItemPadding => [6.0, 11.0, 16.0][density.value.clamp(0, 2)];
  double get artSize         => [38.0, 46.0, 54.0][density.value.clamp(0, 2)];

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  ThemeData buildTheme() {
    final a = accent.value;
    final s = secondary.value ?? a;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF060507),
      colorScheme: ColorScheme.dark(
        primary:   a,
        secondary: s,
        surface:   const Color(0xFF0E0B13),
        onPrimary: Colors.white,
      ),
      dividerColor: const Color(0xFF2A1F30),
      iconTheme: const IconThemeData(color: Color(0xFF9E8FA0)),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF0E0B13)),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF9E8FA0),
        indicatorColor: a,
      ),
      splashColor:    a.withAlpha(20),
      highlightColor: a.withAlpha(10),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: a),
      sliderTheme: SliderThemeData(
        activeTrackColor: a,
        thumbColor: a,
        inactiveTrackColor: const Color(0xFF2A1F30),
        overlayColor: a.withAlpha(25),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: a, foregroundColor: Colors.white,
      )),
    );
  }

  Future<void> setDensity(int d) async {
    density.value = d.clamp(0, 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auradec_density', d);
  }

  Future<void> setScheme(String id) async {
    final s = kSchemes.firstWhereOrNull((x) => x.id == id);
    if (s == null) return;
    accent.value    = s.accent;
    secondary.value = s.secondary;
    schemeId.value  = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefAccent,    s.accent.toARGB32());
    await prefs.setInt(_kPrefSecondary, s.secondary?.toARGB32() ?? -1);
    await prefs.setString(_kPrefSchemeId, id);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kPrefSchemeId);
    if (id != null) {
      final s = kSchemes.firstWhereOrNull((x) => x.id == id);
      if (s != null) {
        accent.value    = s.accent;
        secondary.value = s.secondary;
        schemeId.value  = id;
        return;
      }
    }
    final d = prefs.getInt('auradec_density');
    if (d != null) density.value = d.clamp(0, 2);

    // Fallback: raw stored colors
    final a = prefs.getInt(_kPrefAccent);
    final sec = prefs.getInt(_kPrefSecondary);
    if (a != null) accent.value = Color(a);
    if (sec != null && sec != -1) secondary.value = Color(sec);
  }
}
