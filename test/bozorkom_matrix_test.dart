// BOZORKOM UI MATRITSA — har ekran × 9 qurilma × uz/ru × shrift 1.0/1.3.
// Golden SOLISHTIRMAYDI: rasmlarni test/matrix/ ga yozadi (QA ko'rishi uchun) va
// RenderFlex overflow / xatolarni test xatosi sifatida chiqaradi.
//   FLUTTER_MATERIAL_FONTS=... flutter test test/bozorkom_matrix_test.dart --update-goldens
// (asl: bozorkom_shots_test.dart — mock/fake qismi o'sha yerdan nusxa.)
// BOZORKOM EKRANLARI — telefon (390 / tor 360) / planshet (landshaft, portret),
// OQ va QORA tema, Bozorkom/menejer, uz/ru/en. Server yo'q: Dio soxta.
//   FLUTTER_MATERIAL_FONTS=<flutter>/bin/cache/artifacts/material_fonts \
//   flutter test test/bozorkom_shots_test.dart --update-goldens   → test/shots/bk_*.png

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aiba_pos_terminal/core/config/app_config.dart';
import 'package:aiba_pos_terminal/core/network/dio_client.dart';
import 'package:aiba_pos_terminal/core/providers/core_providers.dart';
import 'package:aiba_pos_terminal/features/auth/domain/entities/auth_session.dart';
import 'package:aiba_pos_terminal/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiba_pos_terminal/features/auth/presentation/providers/auth_providers.dart';
import 'package:aiba_pos_terminal/features/bozorkom/bozorkom_shell.dart';
import 'package:aiba_pos_terminal/features/bozorkom/repo.dart' show nowProvider;
import 'package:aiba_pos_terminal/features/bozorkom/doc_detail_screen.dart';
import 'package:aiba_pos_terminal/features/bozorkom/doc_editor_screen.dart';
import 'package:aiba_pos_terminal/features/bozorkom/i18n.dart';
import 'package:aiba_pos_terminal/features/bozorkom/models.dart';
import 'package:aiba_pos_terminal/features/bozorkom/product_picker_screen.dart';
import 'package:aiba_pos_terminal/features/bozorkom/settings_screens.dart';
import 'package:aiba_pos_terminal/features/bozorkom/theme.dart';

// ── Soxta server javoblari ──────────────────────────────────────────────────

const _lines = [
  {'id': 'l1', 'name': 'картофель', 'unit': 'kg', 'qty': 50, 'price': 4300, 'status': 'bought'},
  {'id': 'l2', 'name': 'лук', 'unit': 'kg', 'qty': 25, 'price': 2600, 'status': 'bought'},
  {'id': 'l3', 'name': 'морковь', 'unit': 'kg', 'qty': 10, 'price': 6500, 'status': 'bought'},
  {'id': 'l4', 'name': 'капуста', 'unit': 'kg', 'qty': 4, 'price': 3000, 'status': 'bought'},
  {'id': 'l5', 'name': 'светофор перец', 'unit': 'kg', 'qty': 3, 'price': 22000, 'status': 'bought'},
  {'id': 'l6', 'name': 'болг свеж.', 'unit': 'kg', 'qty': 3, 'price': 12000, 'status': 'bought'},
  {'id': 'l7', 'name': 'брокколи', 'unit': 'kg', 'qty': 8, 'price': 22000, 'status': 'bought'},
];

const _preLines = [
  {'id': 'p1', 'name': 'индейка', 'unit': 'kg', 'qty': 4, 'status': 'pending'},
  {'id': 'p2', 'name': 'Буратта шт', 'unit': 'dona', 'qty': 2, 'status': 'pending'},
  {'id': 'p3', 'name': 'брынза', 'unit': 'kg', 'qty': 2, 'status': 'pending'},
  {'id': 'p4', 'name': 'каймак 0,9л', 'unit': 'dona', 'qty': 10, 'status': 'pending'},
  {'id': 'p5', 'name': 'переп.яйцо', 'unit': 'dona', 'qty': 100, 'status': 'pending'},
  {'id': 'p6', 'name': 'помидоры', 'unit': 'kg', 'qty': 25, 'status': 'pending'},
];

const _branches = {
  'date': '2026-09-04',
  'branches': [
    {'restaurant_id': 'r2', 'name': 'Диет Бистро Чилонзор', 'code': 'CH', 'doc_no': 1487,
     'created_by': 'Bozorkom', 'total': 7, 'pending': 0, 'bought': 7, 'accepted': 0, 'sum': 1849000},
    {'restaurant_id': 'r7', 'name': 'Кафе Тонг', 'code': 'KT', 'doc_no': 1478,
     'created_by': 'Kamol', 'total': 9, 'pending': 9, 'bought': 0, 'accepted': 0, 'sum': 0},
    {'restaurant_id': 'r3', 'name': 'Бистро Домбрабад', 'code': 'DB', 'doc_no': 1479,
     'created_by': 'Bozorkom', 'total': 20, 'pending': 0, 'bought': 0, 'accepted': 20, 'sum': 1125640},
    {'restaurant_id': 'r9', 'name': 'Цех 16', 'code': 'C16', 'doc_no': 1477,
     'created_by': 'Azamat', 'total': 12, 'pending': 4, 'bought': 8, 'accepted': 0, 'sum': 2348000},
    {'restaurant_id': 'r5', 'name': 'MCHJ XABIBA BONU SAVDO — Себзор', 'code': 'SB', 'doc_no': 1483,
     'created_by': 'Bozorkom', 'total': 11, 'pending': 0, 'bought': 11, 'accepted': 0, 'sum': 1497580},
  ],
};

const _branchDetail = {
  'restaurant_id': 'r2', 'restaurant': 'Диет Бистро Чилонзор', 'date': '2026-09-04',
  'id': 'req1', 'doc_no': 1487, 'created_by': 'Bozorkom', 'lines': _lines,
};
const _my = {'exists': true, 'id': 'req9', 'doc_no': 1479, 'date': '2026-09-04', 'status': 'submitted', 'created_by': 'Bozorkom', 'lines': _lines};
const _myPre = {'exists': true, 'id': 'req8', 'doc_no': 1478, 'date': '2026-09-04', 'status': 'submitted', 'created_by': 'Kamol', 'lines': _preLines};

const _restaurants = {
  'items': [
    {'id': 'r1', 'name': 'Диет Бистро Мукимий', 'code': 'MQ'},
    {'id': 'r2', 'name': 'Диет Бистро Чилонзор', 'code': 'CH'},
    {'id': 'r3', 'name': 'Бистро Домбрабад', 'code': 'DB'},
    {'id': 'r4', 'name': 'Бистро Бунедкор', 'code': 'BN'},
    {'id': 'r5', 'name': 'Бистро Себзор', 'code': 'SB'},
    {'id': 'r6', 'name': 'Бистро Рабочий', 'code': 'RB'},
    {'id': 'r7', 'name': 'Кафе Тонг', 'code': 'KT'},
    {'id': 'r8', 'name': 'Кафе Ричардс', 'code': 'KR'},
    {'id': 'r9', 'name': 'Цех 16', 'code': 'C16'},
  ],
};

const _items = {
  'items': [
    {'name': 'индейка', 'unit': 'кг', 'qty': 12, 'price': 50000, 'category': 'Мясные продукты'},
    {'name': 'сосиска', 'unit': 'кг', 'qty': 5, 'price': 46000, 'category': 'Мясные продукты'},
    {'name': 'сардельки', 'unit': 'кг', 'qty': 3, 'price': 44500, 'category': 'Мясные продукты'},
    {'name': 'колбаса вар.', 'unit': 'кг', 'qty': 4, 'price': 51000, 'category': 'Мясные продукты'},
    {'name': 'ветчина', 'unit': 'кг', 'qty': 2, 'price': 64000, 'category': 'Мясные продукты'},
    {'name': 'копч.колбаса', 'unit': 'кг', 'qty': 2, 'price': 53000, 'category': 'Мясные продукты'},
    {'name': 'раст.масло', 'unit': 'кг', 'qty': 20, 'price': 25000, 'category': 'Масло'},
    {'name': 'масло сливоч.', 'unit': 'кг', 'qty': 8, 'price': 49000, 'category': 'Масло'},
    {'name': 'маселко марг.', 'unit': 'кг', 'qty': 6, 'price': 22000, 'category': 'Масло'},
    {'name': 'щедрое лето', 'unit': 'кг', 'qty': 6, 'price': 43000, 'category': 'Масло'},
    {'name': 'сомса маргарин', 'unit': 'кг', 'qty': 6, 'price': 26000, 'category': 'Масло'},
    {'name': 'топленое масло', 'unit': 'кг', 'qty': 3, 'price': 25000, 'category': 'Масло'},
    {'name': 'каймак 0,9л', 'unit': 'dona', 'qty': 10, 'price': 18000, 'category': 'Молочные продукты'},
    {'name': 'брынза', 'unit': 'кг', 'qty': 2, 'price': 60000, 'category': 'Молочные продукты'},
  ],
};

class _FakeDio extends DioClient {
  _FakeDio(super.config, {this.preorder = false});
  final bool preorder;
  Response<T> _ok<T>(String path, Object body) =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200, data: body as T);
  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query, bool noAuth = false, bool noLogout = false}) async {
    if (path.endsWith('market/branches')) return _ok<T>(path, _branches);
    if (path.endsWith('market/branch')) return _ok<T>(path, _branchDetail);
    if (path.endsWith('market/my')) return _ok<T>(path, preorder ? _myPre : _my);
    if (path.endsWith('market/items')) return _ok<T>(path, _items);
    if (path.endsWith('market/restaurants')) return _ok<T>(path, _restaurants);
    return _ok<T>(path, const <String, dynamic>{});
  }
  @override
  Future<Response<T>> post<T>(String path, {Object? data, bool noAuth = false, bool noLogout = false}) async =>
      _ok<T>(path, const <String, dynamic>{'ok': true});
}

class _FakeRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

AuthSession _session(String role, String name) => AuthSession(
      accessToken: 'x',
      restaurant: const RestaurantInfo(id: 'r5', name: 'MCHJ XABIBA BONU SAVDO', code: 'SB'),
      terminal: const TerminalInfo(id: 'efaeef2d-f568-44f9-a066-cc660a133db0', name: 'T1', code: 'T1'),
      staff: StaffInfo(id: 's1', name: name, role: role),
    );


Future<void> _loadFonts() async {
  final inter = File('assets/fonts/Inter-Variable.ttf');
  if (inter.existsSync()) {
    final l = FontLoader('Inter')..addFont(Future.value(ByteData.view(inter.readAsBytesSync().buffer)));
    await l.load();
  }
  final dir = Platform.environment['FLUTTER_MATERIAL_FONTS'] ?? '';
  final iconFile = File('$dir/MaterialIcons-Regular.otf');
  if (iconFile.existsSync()) {
    final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(iconFile.readAsBytesSync().buffer)));
    await icons.load();
  }
}


class Dev { final String id; final Size size; const Dev(this.id, this.size); }
// Haqiqiy bozorda uchraydigan qurilmalar: eng kichik iPhone SE dan planshetgacha.
const kDevs = [
  Dev('se320', Size(320, 568)),      // iPhone SE 1 / eski kichik Android
  Dev('a360s', Size(360, 640)),      // Samsung A/J seriya, past
  Dev('a360', Size(360, 780)),       // Samsung A seriya
  Dev('ip390', Size(390, 844)),      // iPhone 12–15
  Dev('px412', Size(412, 915)),      // Pixel / Redmi
  Dev('ipad768p', Size(768, 1024)),  // iPad portret
  Dev('tab800p', Size(800, 1280)),   // Android planshet portret
  Dev('tab1280l', Size(1280, 800)),  // Android planshet landshaft
  Dev('ipad1024l', Size(1024, 768)), // iPad landshaft
];

Future<void> _mx(WidgetTester tester, String name, Dev dev, double scale, Widget child,
    {required List<Override> overrides, bool light = false, Future<void> Function(WidgetTester t)? after}) async {
  tester.view.physicalSize = dev.size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: bzTheme(light),
      darkTheme: bzTheme(light),
      themeMode: light ? ThemeMode.light : ThemeMode.dark,
      home: child,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 500));
  if (after != null) {
    try { await after(tester); } catch (_) { /* kichik ekranda element ko'rinmasa — rasm baribir olinadi */ }
  }
  await tester.pump(const Duration(milliseconds: 300));
  final s = scale == 1.0 ? '' : '_x${scale.toString().replaceAll('.', '')}';
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('matrix/mx_${name}_${dev.id}$s.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late AppConfig cfg;

  setUpAll(() async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({'base_url': 'https://next.aiba.uz', 'terminal_code': 'T1'});
    const status = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(status, (c) async => ['wifi']);
    const events = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(events, (c) async => null);
    prefs = await SharedPreferences.getInstance();
    cfg = AppConfig(prefs, const FlutterSecureStorage());
  });

  List<Override> ov({String role = 'market', String name = 'Rasul', String loc = 'uz', bool preorder = false, bool light = false}) => [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Goldenlar 2026-09-05 da olingan — soat shu kunga qotiriladi.
        nowProvider.overrideWithValue(DateTime(2026, 9, 5, 12)),
        dioClientProvider.overrideWithValue(_FakeDio(cfg, preorder: preorder)),
        appConfigProvider.overrideWithValue(cfg),
        sessionProvider.overrideWith((ref) => SessionNotifier(_FakeRepo())..setSession(_session(role, name))),
        localeProvider.overrideWith((ref) => LocaleCtl(loc, (_) async => true)),
        lightThemeProvider.overrideWith((ref) => ThemeCtl(light, (_) async => true)),
      ];

  final doc = Doc.fromBranch(Map<String, dynamic>.from((_branches['branches'] as List).first as Map), '2026-09-04');
  final preDoc = Doc.fromBranch(Map<String, dynamic>.from((_branches['branches'] as List)[1] as Map), '2026-09-04');
  final full = Doc.fromRequest(Map<String, dynamic>.from(_branchDetail), doc.branch, '2026-09-04');
  final pre = Doc.fromRequest(Map<String, dynamic>.from(_myPre), doc.branch, '2026-09-04');

  Future<void> openDrawer(WidgetTester t) async {
    await t.tap(find.byTooltip('Open navigation menu'));
    await t.pump(const Duration(milliseconds: 500));
  }


  Future<void> pickMaslo(WidgetTester t) async {
    await t.tap(find.text('Масло'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('раст.масло'));
    await t.pump(const Duration(milliseconds: 300));
  }

  // ekran → (widget quruvchi, override quruvchi, after)
  final screens = <String, (Widget Function(), List<Override> Function(String loc), Future<void> Function(WidgetTester)?)>{
    'list_market':    (() => const BozorkomShell(), (l) => ov(loc: l), null),
    'list_manager':   (() => const BozorkomShell(), (l) => ov(role: 'manager', name: 'Manager', loc: l), null),
    'drawer':         (() => const BozorkomShell(), (l) => ov(loc: l), openDrawer),
    'detail_market':  (() => DocDetailScreen(doc: doc), (l) => ov(loc: l), null),
    'detail_manager': (() => DocDetailScreen(doc: doc), (l) => ov(role: 'manager', name: 'Manager', loc: l), null),
    'detail_pre':     (() => DocDetailScreen(doc: preDoc), (l) => ov(role: 'manager', name: 'Kamol', preorder: true, loc: l), null),
    'editor_new':     (() => const DocEditorScreen(date: '2026-09-04'), (l) => ov(loc: l), null),
    'editor_edit':    (() => DocEditorScreen(date: '2026-09-04', existing: full), (l) => ov(loc: l), null),
    'editor_manager': (() => DocEditorScreen(date: '2026-09-04', existing: pre), (l) => ov(role: 'manager', name: 'Kamol', preorder: true, loc: l), null),
    'picker':         (() => const ProductPickerScreen(), (l) => ov(loc: l), pickMaslo),
    'lang':           (() => const LanguageScreen(), (l) => ov(loc: l), null),
    'ip':             (() => const IpSettingsScreen(), (l) => ov(loc: l), null),
    'general':        (() => const GeneralSettingsScreen(), (l) => ov(role: 'manager', name: 'Manager', loc: l), null),
  };

  for (final e in screens.entries) {
    for (final dev in kDevs) {
      for (final loc in const ['uz', 'ru']) {
        for (final scale in const [1.0, 1.3]) {
          testWidgets('${e.key} ${dev.id} $loc x$scale', (t) async {
            await _mx(t, '${e.key}_$loc', dev, scale, e.value.$1(), overrides: e.value.$2(loc), after: e.value.$3);
          });
        }
      }
    }
  }
  // Inglizcha va OQ tema — layout bir xil, bittadan nazorat.
  testWidgets('list_market en ip390', (t) async {
    await _mx(t, 'list_market_en', const Dev('ip390', Size(390, 844)), 1.0, const BozorkomShell(), overrides: ov(loc: 'en'));
  });
  testWidgets('list_market light se320', (t) async {
    await _mx(t, 'list_market_light', const Dev('se320', Size(320, 568)), 1.3, const BozorkomShell(), overrides: ov(light: true), light: true);
  });
}
