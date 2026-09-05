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

const _phone = Size(390, 844);
const _narrow = Size(360, 740); // kichik Android (Samsung A-seriya)
const _tablet = Size(1280, 800);
const _tabletPortrait = Size(800, 1280);

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

Future<void> _shot(WidgetTester tester, String name, Size size, Widget child,
    {required List<Override> overrides, required bool light, Future<void> Function(WidgetTester t)? after}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
  if (after != null) await after(tester);
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
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

  // ── QORA tema ──
  testWidgets('qora: ro\'yxat Bozorkom planshet', (t) async {
    await _shot(t, 'bk_list_market_tablet', _tablet, const BozorkomShell(), overrides: ov(), light: false);
  });
  testWidgets('qora: ro\'yxat Bozorkom telefon', (t) async {
    await _shot(t, 'bk_list_market_phone', _phone, const BozorkomShell(), overrides: ov(), light: false);
  });
  testWidgets('qora: ro\'yxat TOR telefon (360) ruscha', (t) async {
    await _shot(t, 'bk_list_ru_narrow', _narrow, const BozorkomShell(), overrides: ov(loc: 'ru'), light: false);
  });
  testWidgets('qora: ro\'yxat planshet portret', (t) async {
    await _shot(t, 'bk_list_market_tablet_portrait', _tabletPortrait, const BozorkomShell(), overrides: ov(), light: false);
  });
  testWidgets('qora: ro\'yxat menejer telefon', (t) async {
    await _shot(t, 'bk_list_manager_phone', _phone, const BozorkomShell(), overrides: ov(role: 'manager', name: 'Manager'), light: false);
  });
  testWidgets('qora: filtr ochiq ruscha planshet', (t) async {
    await _shot(t, 'bk_list_ru_filter_tablet', _tablet, const BozorkomShell(), overrides: ov(loc: 'ru'), light: false, after: (t) async {
      await t.tap(find.text('Фильтр'));
      await t.pump(const Duration(milliseconds: 300));
    });
  });
  testWidgets('qora: filtr ochiq inglizcha TOR telefon', (t) async {
    await _shot(t, 'bk_list_en_filter_narrow', _narrow, const BozorkomShell(), overrides: ov(loc: 'en'), light: false, after: (t) async {
      await t.tap(find.text('Filter'));
      await t.pump(const Duration(milliseconds: 300));
    });
  });
  testWidgets('qora: yon menyu Bozorkom', (t) async {
    await _shot(t, 'bk_drawer_market_phone', _phone, const BozorkomShell(), overrides: ov(), light: false, after: openDrawer);
  });
  testWidgets('qora: hujjat Bozorkom (Tahrirlash aktiv) telefon', (t) async {
    await _shot(t, 'bk_detail_market_phone', _phone, DocDetailScreen(doc: doc), overrides: ov(), light: false);
  });
  testWidgets('qora: hujjat menejer (Qabul aktiv) TOR telefon', (t) async {
    await _shot(t, 'bk_detail_manager_narrow', _narrow, DocDetailScreen(doc: doc), overrides: ov(role: 'manager', name: 'Manager'), light: false);
  });
  testWidgets('qora: hujjat planshet', (t) async {
    await _shot(t, 'bk_detail_market_tablet', _tablet, DocDetailScreen(doc: doc), overrides: ov(), light: false);
  });
  testWidgets('qora: oldindan buyurtma (narxsiz) menejer', (t) async {
    await _shot(t, 'bk_detail_preorder_manager_phone', _phone, DocDetailScreen(doc: preDoc), overrides: ov(role: 'manager', name: 'Kamol', preorder: true), light: false);
  });
  testWidgets('qora: yaratish bo\'sh TOR telefon ruscha', (t) async {
    await _shot(t, 'bk_editor_new_ru_narrow', _narrow, const DocEditorScreen(date: '2026-09-04'), overrides: ov(loc: 'ru'), light: false);
  });
  testWidgets('qora: tahrirlash narx bilan planshet', (t) async {
    await _shot(t, 'bk_editor_edit_market_tablet', _tablet, DocEditorScreen(date: '2026-09-04', existing: full), overrides: ov(), light: false);
  });
  testWidgets('qora: tahrirlash narx bilan telefon', (t) async {
    await _shot(t, 'bk_editor_edit_market_phone', _phone, DocEditorScreen(date: '2026-09-04', existing: full), overrides: ov(), light: false);
  });
  testWidgets('qora: menejer faqat miqdor telefon', (t) async {
    await _shot(t, 'bk_editor_manager_phone', _phone, DocEditorScreen(date: '2026-09-04', existing: pre), overrides: ov(role: 'manager', name: 'Kamol', preorder: true), light: false);
  });
  testWidgets('qora: mahsulot tanlash telefon', (t) async {
    await _shot(t, 'bk_picker_phone', _phone, const ProductPickerScreen(), overrides: ov(), light: false, after: (t) async {
      await t.tap(find.text('Масло'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('раст.масло'));
      await t.tap(find.text('масло сливоч.'));
      await t.pump(const Duration(milliseconds: 300));
    });
  });
  testWidgets('qora: mahsulot tanlash planshet', (t) async {
    await _shot(t, 'bk_picker_tablet', _tablet, const ProductPickerScreen(), overrides: ov(), light: false, after: (t) async {
      await t.tap(find.text('Мясные продукты'));
      await t.pump(const Duration(milliseconds: 300));
    });
  });
  testWidgets('qora: til / IP / umumiy', (t) async {
    await _shot(t, 'bk_lang_phone', _phone, const LanguageScreen(), overrides: ov(), light: false);
  });
  testWidgets('qora: IP sozlamalar', (t) async {
    await _shot(t, 'bk_ip_phone', _phone, const IpSettingsScreen(), overrides: ov(), light: false);
  });
  testWidgets('qora: umumiy sozlamalar TOR ruscha', (t) async {
    await _shot(t, 'bk_general_ru_narrow', _narrow, const GeneralSettingsScreen(), overrides: ov(role: 'manager', name: 'Manager', loc: 'ru'), light: false);
  });

  // ── OQ tema ──
  testWidgets('oq: ro\'yxat Bozorkom telefon', (t) async {
    await _shot(t, 'bk_light_list_market_phone', _phone, const BozorkomShell(), overrides: ov(light: true), light: true);
  });
  testWidgets('oq: ro\'yxat planshet ruscha', (t) async {
    await _shot(t, 'bk_light_list_ru_tablet', _tablet, const BozorkomShell(), overrides: ov(loc: 'ru', light: true), light: true);
  });
  testWidgets('oq: yon menyu menejer ruscha', (t) async {
    await _shot(t, 'bk_light_drawer_manager_ru', _phone, const BozorkomShell(), overrides: ov(role: 'manager', name: 'Manager', loc: 'ru', light: true), light: true, after: openDrawer);
  });
  testWidgets('oq: hujjat menejer TOR telefon', (t) async {
    await _shot(t, 'bk_light_detail_manager_narrow', _narrow, DocDetailScreen(doc: doc), overrides: ov(role: 'manager', name: 'Manager', light: true), light: true);
  });
  testWidgets('oq: tahrirlash narx bilan telefon', (t) async {
    await _shot(t, 'bk_light_editor_edit_phone', _phone, DocEditorScreen(date: '2026-09-04', existing: full), overrides: ov(light: true), light: true);
  });
  testWidgets('oq: yaratish bo\'sh TOR ruscha', (t) async {
    await _shot(t, 'bk_light_editor_new_ru_narrow', _narrow, const DocEditorScreen(date: '2026-09-04'), overrides: ov(loc: 'ru', light: true), light: true);
  });
  testWidgets('oq: mahsulot tanlash telefon', (t) async {
    await _shot(t, 'bk_light_picker_phone', _phone, const ProductPickerScreen(), overrides: ov(light: true), light: true, after: (t) async {
      await t.tap(find.text('Масло'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('раст.масло'));
      await t.pump(const Duration(milliseconds: 300));
    });
  });
  testWidgets('oq: umumiy sozlamalar ruscha', (t) async {
    await _shot(t, 'bk_light_general_ru_phone', _phone, const GeneralSettingsScreen(), overrides: ov(role: 'manager', name: 'Manager', loc: 'ru', light: true), light: true);
  });
  testWidgets('oq: IP sozlamalar', (t) async {
    await _shot(t, 'bk_light_ip_phone', _phone, const IpSettingsScreen(), overrides: ov(light: true), light: true);
  });
  testWidgets('oq: til tanlash', (t) async {
    await _shot(t, 'bk_light_lang_phone', _phone, const LanguageScreen(), overrides: ov(loc: 'ru', light: true), light: true);
  });
}
