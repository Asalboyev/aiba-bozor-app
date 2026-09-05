// BOZORKOM TEMA — OQ (light) va QORA (dark) fon, ikkalasi AIBA uslubida.
// «Ekranni o'zgartirish» toggle'i temani almashtiradi (saqlanadi).
// Hamma ekran ranglarni faqat `bz(context)` orqali oladi — bitta joydan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';

/// Joriy tema: true = oq (light), false = qora (dark). Saqlanadi.
final lightThemeProvider = StateNotifierProvider<ThemeCtl, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeCtl(prefs.getBool('bozor_light') ?? false, (v) => prefs.setBool('bozor_light', v));
});

class ThemeCtl extends StateNotifier<bool> {
  ThemeCtl(super.initial, this._save);
  final Future<bool> Function(bool) _save;
  void toggle() {
    state = !state;
    _save(state);
  }
  void set(bool v) {
    state = v;
    _save(v);
  }
}

/// Rang tokenlari — ThemeExtension, widgetlar `bz(context)` bilan oladi.
@immutable
class BzColors extends ThemeExtension<BzColors> {
  const BzColors({
    required this.bg,
    required this.panel,
    required this.card,
    required this.border,
    required this.field,
    required this.chip,
    required this.text,
    required this.label,
    required this.muted,
    required this.blue,
    required this.green,
    required this.red,
    required this.amber,
    required this.orange,
    required this.isLight,
  });

  final Color bg; // ekran foni
  final Color panel; // yon menyu / filtr paneli
  final Color card; // karta
  final Color border; // karta chegarasi
  final Color field; // input foni
  final Color chip; // ikon fon (kvadratcha)
  final Color text; // asosiy matn
  final Color label; // ikkilamchi matn
  final Color muted; // xira matn
  final Color blue; // asosiy urg'u (AIBA)
  final Color green;
  final Color red;
  final Color amber; // oldindan buyurtma
  final Color orange; // qabul qilinmagan
  final bool isLight;

  /// QORA — Figma «Pos Design» (kassa bilan bir xil).
  static const dark = BzColors(
    bg: Color(0xFF06090B),
    panel: Color(0xFF111113),
    card: Color(0xFF1B1B1C),
    border: Color(0x14FFFFFF),
    field: Color(0xFF141519),
    chip: Color(0xFF232329),
    text: Color(0xFFFAFAFA),
    label: Color(0xFF9AA0A6),
    muted: Color(0xFF8A9098),
    blue: Color(0xFF2277EA),
    green: Color(0xFF2FBF71),
    red: Color(0xFFE5484D),
    amber: Color(0xFFD97706),
    orange: Color(0xFFE8863A),
    isLight: false,
  );

  /// OQ — AIBA yorug' uslubi: sovuq oq fon, oq kartalar, to'q matn, o'sha ko'k.
  static const light = BzColors(
    bg: Color(0xFFF4F6FA),
    panel: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE3E8EF),
    field: Color(0xFFF0F3F8),
    chip: Color(0xFFE8EDF5),
    text: Color(0xFF0B1220),
    label: Color(0xFF5B6472),
    muted: Color(0xFF8A94A3),
    blue: Color(0xFF2277EA),
    green: Color(0xFF16A34A),
    red: Color(0xFFDC2626),
    amber: Color(0xFFD97706),
    orange: Color(0xFFEA7A2E),
    isLight: true,
  );

  @override
  BzColors copyWith() => this;

  @override
  BzColors lerp(ThemeExtension<BzColors>? other, double t) => this;
}

/// Qisqa kirish: `final c = bz(context);`
BzColors bz(BuildContext context) =>
    Theme.of(context).extension<BzColors>() ?? BzColors.dark;

/// To'liq ThemeData — Material komponentlari (dialog, switch, snackbar,
/// input) ham shu palitrada chiqadi.
ThemeData bzTheme(bool light) {
  final c = light ? BzColors.light : BzColors.dark;
  final scheme = light
      ? ColorScheme.light(
          primary: c.blue, onPrimary: Colors.white, secondary: c.blue,
          surface: c.card, onSurface: c.text, error: c.red)
      : ColorScheme.dark(
          primary: c.blue, onPrimary: Colors.white, secondary: c.blue,
          surface: c.card, onSurface: c.text, error: c.red);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.border,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: DrawerThemeData(backgroundColor: c.panel, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: c.panel, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.panel, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: light ? const Color(0xFF1C1D22) : const Color(0xFF1C1D22),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Inter'),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.blue),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.blue : c.chip),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(textColor: c.text, iconColor: c.blue),
    textTheme: ThemeData(brightness: light ? Brightness.light : Brightness.dark)
        .textTheme
        .apply(bodyColor: c.text, displayColor: c.text, fontFamily: 'Inter'),
    extensions: [c],
  );
}

/// Kenglik toifalari — har telefonga moslashish.
bool isNarrow(BuildContext c) => MediaQuery.sizeOf(c).width < 400; // kichik telefon
bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 720; // planshet
double hPad(BuildContext c) => isWide(c) ? 24 : (isNarrow(c) ? 12 : 16);
