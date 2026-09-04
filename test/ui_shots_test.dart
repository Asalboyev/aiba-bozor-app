// BOZOR ILOVASI — UI SNAPSHOT HARNESS (dizaynni ko'z bilan tekshirish uchun).
//
// `flutter test test/ui_shots_test.dart --update-goldens` — har ekranni
// telefon va planshet o'lchamida PNG qilib `test/shots/` ga yozadi. Server
// ham, emulyator ham kerak emas: dio soxta javob qaytaradi.
//
// Bu test HECH NARSANI tasdiqlamaydi — faqat rasm chiqaradi (dizayn ko'rigi).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aiba_pos_terminal/core/config/app_config.dart';
import 'package:aiba_pos_terminal/core/network/dio_client.dart';
import 'package:aiba_pos_terminal/core/providers/core_providers.dart';
import 'package:aiba_pos_terminal/core/theme/app_theme.dart';
import 'package:aiba_pos_terminal/features/auth/domain/entities/auth_session.dart';
import 'package:aiba_pos_terminal/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiba_pos_terminal/features/auth/presentation/providers/auth_providers.dart';
import 'package:aiba_pos_terminal/features/auth/presentation/screens/login_screen.dart';
import 'package:aiba_pos_terminal/features/market/bozor_shell.dart';

// ── Soxta server javoblari ───────────────────────────────────────────────────

const _aggregate = {
  'items': [
    {
      'name': 'Kartoshka',
      'unit': 'kg',
      'total_qty': 80,
      'branches': [
        {'restaurant': 'Diet Bistro', 'qty': 50},
        {'restaurant': 'Milli Grill', 'qty': 30},
      ],
    },
    {
      'name': "Mol go'shti (mol lahm)",
      'unit': 'kg',
      'total_qty': 24.5,
      'branches': [
        {'restaurant': 'Diet Bistro', 'qty': 14.5},
        {'restaurant': 'Milli Grill', 'qty': 10},
      ],
      'bought_qty': 24.5,
      'price': 92000,
    },
    {
      'name': 'Pomidor',
      'unit': 'kg',
      'total_qty': 18,
      'branches': [
        {'restaurant': 'Diet Bistro', 'qty': 12},
        {'restaurant': 'Milli Grill', 'qty': 6},
      ],
    },
    {
      'name': 'Tuxum',
      'unit': 'dona',
      'total_qty': 300,
      'branches': [
        {'restaurant': 'Diet Bistro', 'qty': 180},
        {'restaurant': 'Milli Grill', 'qty': 120},
      ],
    },
    {
      'name': 'Sut',
      'unit': 'l',
      'total_qty': 40,
      'branches': [
        {'restaurant': 'Diet Bistro', 'qty': 25},
        {'restaurant': 'Milli Grill', 'qty': 15},
      ],
      'bought_qty': 40,
      'price': 12500,
    },
  ],
};

const _my = {
  'lines': [
    {
      'id': 'l1',
      'name': "Mol go'shti (mol lahm)",
      'unit': 'kg',
      'qty': 14.5,
      'price': 92000,
      'total': 1334000,
      'status': 'bought',
      'buyer': 'Oshpaz Ali',
      'bought_at': '2026-09-02T09:41:00',
    },
    {
      'id': 'l2',
      'name': 'Sut',
      'unit': 'l',
      'qty': 25,
      'price': 12500,
      'total': 312500,
      'status': 'bought',
      'buyer': 'Oshpaz Ali',
      'bought_at': '2026-09-02T09:44:00',
    },
    {
      'id': 'l3',
      'name': 'Kartoshka',
      'unit': 'kg',
      'qty': 50,
      'status': 'pending',
    },
    {
      'id': 'l4',
      'name': 'Pomidor',
      'unit': 'kg',
      'qty': 12,
      'status': 'pending',
    },
    {
      'id': 'l5',
      'name': 'Tuxum',
      'unit': 'dona',
      'qty': 180,
      'price': 1400,
      'total': 252000,
      'status': 'accepted',
      'accepted_qty': 180,
      'accepted_at': '2026-09-02T10:12:00',
    },
  ],
};

const _branches = {
  'date': '2026-09-02',
  'total_lines': 23,
  'total_pending': 9,
  'total_sum': 3860000,
  'branches': [
    {'restaurant_id': 'r1', 'name': 'Diet Bistro', 'code': 'DIET',
     'total': 8, 'pending': 3, 'bought': 4, 'accepted': 1, 'sum': 1640000},
    {'restaurant_id': 'r2', 'name': 'Milli Grill', 'code': 'MG',
     'total': 6, 'pending': 0, 'bought': 5, 'accepted': 1, 'sum': 980000},
    {'restaurant_id': 'r3', 'name': 'Grill 3 — Chilonzor', 'code': 'G3',
     'total': 5, 'pending': 5, 'bought': 0, 'accepted': 0, 'sum': 0},
    {'restaurant_id': 'r4', 'name': 'Grill 4 — Yunusobod', 'code': 'G4',
     'total': 4, 'pending': 1, 'bought': 3, 'accepted': 0, 'sum': 1240000},
  ],
};

const _branchLines = {
  'date': '2026-09-02',
  'restaurant_id': 'r1',
  'restaurant': 'Diet Bistro',
  'lines': [
    {'id': 'b1', 'name': 'Kartoshka', 'unit': 'kg', 'qty': 50,
     'status': 'pending', 'hint_price': 4200},
    {'id': 'b2', 'name': 'Pomidor', 'unit': 'kg', 'qty': 12,
     'status': 'pending'},
    {'id': 'b3', 'name': 'Tuxum', 'unit': 'dona', 'qty': 180,
     'status': 'pending', 'hint_price': 1400},
    {'id': 'b4', 'name': "Mol go'shti (mol lahm)", 'unit': 'kg', 'qty': 14.5,
     'price': 92000, 'total': 1334000, 'status': 'bought'},
    {'id': 'b5', 'name': 'Sut', 'unit': 'l', 'qty': 25, 'price': 12500,
     'total': 312500, 'status': 'accepted', 'accepted_qty': 25},
  ],
};

const _history = {
  'items': [
    {'date': '2026-09-02', 'lines': 8, 'accepted': 1, 'bought': 4,
     'pending': 3, 'total': 1640000, 'created_by': 'Menejer Habib'},
    {'date': '2026-09-01', 'lines': 11, 'accepted': 11, 'bought': 0,
     'pending': 0, 'total': 2415000, 'created_by': 'Menejer Habib'},
    {'date': '2026-08-31', 'lines': 7, 'accepted': 7, 'bought': 0,
     'pending': 0, 'total': 890000, 'created_by': 'Menejer Habib'},
    {'date': '2026-08-30', 'lines': 9, 'accepted': 9, 'bought': 0,
     'pending': 0, 'total': 1725000, 'created_by': 'Menejer Habib'},
  ],
};

const _stock = {
  'items': [
    {'name': 'Kartoshka', 'unit': 'kg', 'qty': 12.4},
    {'name': "Mol go'shti (mol lahm)", 'unit': 'kg', 'qty': 0.86},
    {'name': 'Pomidor', 'unit': 'kg', 'qty': 3},
    {'name': 'Tuxum', 'unit': 'dona', 'qty': 42},
    {'name': 'Sut', 'unit': 'l', 'qty': 6},
    {'name': 'Guruch', 'unit': 'kg', 'qty': 25},
  ],
};

class _FakeDio extends DioClient {
  _FakeDio(super.config);

  Response<T> _ok<T>(String path, Object body) => Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: body as T,
      );

  @override
  Future<Response<T>> get<T>(String path,
      {Map<String, dynamic>? query, bool noAuth = false, bool noLogout = false}) async {
    if (path.contains('market/branches')) return _ok<T>(path, _branches);
    if (path.contains('market/branch')) return _ok<T>(path, _branchLines);
    if (path.contains('market/history')) return _ok<T>(path, _history);
    if (path.contains('aggregate')) return _ok<T>(path, _aggregate);
    if (path.contains('market/my')) return _ok<T>(path, _my);
    if (path.contains('market/items')) return _ok<T>(path, _stock);
    return _ok<T>(path, const <String, dynamic>{});
  }

  @override
  Future<Response<T>> post<T>(String path,
      {Object? data, bool noAuth = false, bool noLogout = false}) async =>
      _ok<T>(path, const <String, dynamic>{'ok': true});
}

class _FakeRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

AuthSession _session(String role, String name) => AuthSession(
      accessToken: 'x',
      restaurant: const RestaurantInfo(id: 'r1', name: 'Diet Bistro', code: 'DIET'),
      terminal: const TerminalInfo(id: 't1', name: 'T1', code: 'T1'),
      staff: StaffInfo(id: 's1', name: name, role: role),
    );

// ── Yordamchilar ─────────────────────────────────────────────────────────────

const _phone = Size(390, 844);
const _tablet = Size(1280, 800);

Future<void> _loadFonts() async {
  // Flutter SDK'ning material_fonts keshi (Roboto + MaterialIcons) —
  // yo'lini FLUTTER_MATERIAL_FONTS env beradi. Aks holda matn "quti"
  // bo'lib chiqadi va rasm ko'rikka yaramaydi.
  // Ilova shrifti — Inter (pubspec'dagi bir xil fayl).
  final inter = File('assets/fonts/Inter-Variable.ttf');
  if (inter.existsSync()) {
    final l = FontLoader('Inter')
      ..addFont(Future.value(ByteData.view(inter.readAsBytesSync().buffer)));
    await l.load();
  }
  final fontsDir = Directory(_materialFontsDir());
  if (!fontsDir.existsSync()) return;
  final icons = FontLoader('MaterialIcons');
  final iconFile = File('${fontsDir.path}/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    icons.addFont(Future.value(ByteData.view(iconFile.readAsBytesSync().buffer)));
    await icons.load();
  }
}

String _materialFontsDir() =>
    Platform.environment['FLUTTER_MATERIAL_FONTS'] ?? '';

Future<void> _shot(
  WidgetTester tester,
  String name,
  Size size,
  Widget child, {
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester t)? after,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: child,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
  if (after != null) await after(tester);
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Override> base;

  setUpAll(() async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://next.aiba.uz',
      'terminal_code': 'T1',
    });
    // connectivity_plus — test muhitida plagin yo'q, soxta javob beramiz.
    const status = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(status, (c) async => ['wifi']);
    const events = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(events, (c) async => null);
    final prefs = await SharedPreferences.getInstance();
    final cfg = AppConfig(prefs, const FlutterSecureStorage());
    base = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      dioClientProvider.overrideWithValue(_FakeDio(cfg)),
      appConfigProvider.overrideWithValue(cfg),
    ];
  });

  testWidgets('bozorchi — planshet', (t) async {
    await _shot(t, 'market_tablet', _tablet, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith(
          (ref) => SessionNotifier(_FakeRepo())..setSession(_session('kitchen', 'Oshpaz Ali'))),
    ]);
  });

  testWidgets('bozorchi — telefon', (t) async {
    await _shot(t, 'market_phone', _phone, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith(
          (ref) => SessionNotifier(_FakeRepo())..setSession(_session('kitchen', 'Oshpaz Ali'))),
    ]);
  });

  testWidgets('menejer — zakaz (planshet)', (t) async {
    await _shot(t, 'zakaz_tablet', _tablet, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith(
          (ref) => SessionNotifier(_FakeRepo())..setSession(_session('manager', 'Habib aka'))),
    ]);
  });

  testWidgets('menejer — zakaz (telefon)', (t) async {
    await _shot(t, 'zakaz_phone', _phone, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith(
          (ref) => SessionNotifier(_FakeRepo())..setSession(_session('manager', 'Habib aka'))),
    ]);
  });

  testWidgets('menejer — qabul (planshet)', (t) async {
    await _shot(t, 'qabul_tablet', _tablet, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith(
          (ref) => SessionNotifier(_FakeRepo())..setSession(_session('manager', 'Habib aka'))),
    ], after: (t) async {
      await t.tap(find.text('Qabul'));
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  testWidgets('menejer — qabul (telefon)', (t) async {
    await _shot(t, 'qabul_phone', _phone, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith(
          (ref) => SessionNotifier(_FakeRepo())..setSession(_session('manager', 'Habib aka'))),
    ], after: (t) async {
      await t.tap(find.text('Qabul'));
      await t.pump(const Duration(milliseconds: 400));
    });
  });

  testWidgets('bozorchi — filial ichi (planshet)', (t) async {
    await _shot(t, 'branch_tablet', _tablet, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith((ref) => SessionNotifier(_FakeRepo())
        ..setSession(_session('kitchen', 'Oshpaz Ali'))),
    ], after: (t) async {
      await t.tap(find.text('Diet Bistro').first);
      await t.pumpAndSettle();
    });
  });

  testWidgets('bozorchi — filial ichi (telefon)', (t) async {
    await _shot(t, 'branch_phone', _phone, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith((ref) => SessionNotifier(_FakeRepo())
        ..setSession(_session('kitchen', 'Oshpaz Ali'))),
    ], after: (t) async {
      await t.tap(find.text('Diet Bistro').first);
      await t.pumpAndSettle();
    });
  });

  testWidgets('menejer — tarix (telefon)', (t) async {
    await _shot(t, 'tarix_phone', _phone, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith((ref) => SessionNotifier(_FakeRepo())
        ..setSession(_session('manager', 'Habib aka'))),
    ], after: (t) async {
      await t.tap(find.text('Tarix'));
      await t.pumpAndSettle();
    });
  });

  testWidgets('mahsulot tanlash oynasi', (t) async {
    await _shot(t, 'picker_phone', _phone, const BozorShell(), overrides: [
      ...base,
      sessionProvider.overrideWith(
          (ref) => SessionNotifier(_FakeRepo())..setSession(_session('manager', 'Habib aka'))),
    ], after: (t) async {
      await t.tap(find.text('Kartoshka').first);
      await t.pumpAndSettle();
    });
  });

  testWidgets('login', (t) async {
    await _shot(t, 'login_phone', _phone, const LoginScreen(), overrides: base);
  });

  testWidgets('sozlash', (t) async {
    await _shot(t, 'setup_phone', _phone, const BozorSetupScreen(), overrides: base);
  });
}
