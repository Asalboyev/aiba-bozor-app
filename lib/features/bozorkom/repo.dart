// BOZORKOM — backend bilan aloqa (pos_bozor terminal endpointlari) + holat
// provayderlari. Rol: `market` = Bozorkom (hamma filial), boshqa = filial
// menejeri (faqat o'z filiali).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../auth/presentation/providers/auth_providers.dart';
import '../market/market_screen.dart' show isoDay;
import '../../core/errors/failure.dart';
import 'models.dart';

const _base = '/api/v2/pos-terminal/market';

/// «Hozir». Bitta joydan olinadi, shunda golden testlarda soatni qotirib
/// bo'ladi — aks holda ro'yxat sarlavhasi va sozlamalardagi «bugun» har kuni
/// o'zgarib, 10 golden sana farqi bilan yiqilardi (2026-09-07 da shunday bo'ldi).
final nowProvider = Provider<DateTime>((_) => DateTime.now());

/// Ro'yxat sanasi (YYYY-MM-DD).
final docDateProvider = StateProvider<String>((ref) => isoDay(ref.read(nowProvider)));

/// Rol: Bozorkom (market) — hamma filial; aks holda filial menejeri.
bool isMarketRole(Ref ref) => ref.read(sessionProvider)?.staff.role == 'market';

/// Firma akkaunti — faqat o'ziga yuborilgan buyurtmalar, narx qo'yadi.
bool isSupplierRole(Ref ref) => ref.read(sessionProvider)?.staff.role == 'supplier';

BranchRef ownBranch(Ref ref) {
  final s = ref.read(sessionProvider);
  return BranchRef(
    id: s?.restaurant.id ?? '',
    name: s?.restaurant.name ?? '',
    code: s?.restaurant.code ?? '',
  );
}

final bozorkomRepoProvider = Provider<BozorkomRepo>((ref) => BozorkomRepo(ref));

/// Tanlangan sanadagi hujjatlar.
final docsProvider = FutureProvider.autoDispose<List<Doc>>((ref) async {
  final date = ref.watch(docDateProvider);
  ref.watch(sessionProvider);
  return ref.read(bozorkomRepoProvider).listForDate(date);
});

/// Barcha filiallar (qabul qiluvchi tanlash + Umumiy sozlamalar).
final branchesProvider = FutureProvider<List<BranchRef>>((ref) async {
  ref.watch(sessionProvider);
  return ref.read(bozorkomRepoProvider).branches();
});

/// Korxona firmalari (yetkazuvchilar) — «Yetkazib beruvchi» tanlagichi.
final suppliersProvider = FutureProvider<List<SupplierRef>>((ref) async {
  ref.watch(sessionProvider);
  return ref.read(bozorkomRepoProvider).suppliers();
});

class BozorkomRepo {
  BozorkomRepo(this._ref);
  final Ref _ref;

  bool get market => isMarketRole(_ref);
  bool get supplier => isSupplierRole(_ref);
  /// Narx kiritadiganlar: bozorchi (yuk xati) va firma (o'z buyurtmasiga).
  bool get canPrice => market || supplier;
  BranchRef get own => ownBranch(_ref);

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? q]) async {
    final res = await _ref.read(dioClientProvider).get<Map<String, dynamic>>(path, query: q);
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await _ref.read(dioClientProvider).post<Map<String, dynamic>>(path, data: body);
    return res.data ?? const {};
  }

  /// Shu kundagi hujjatlar — hammasi `/branches` dan (bir qator = bir hujjat:
  /// filial × bozor/firma). Bozorkom hamma filialni ko'radi, firma akkaunti
  /// serverda o'z buyurtmalariga filtrlanadi, menejer — faqat o'z filiali.
  Future<List<Doc>> listForDate(String date) async {
    final j = await _get('$_base/branches', {'date': date});
    final all = ((j['branches'] as List?) ?? const [])
        .map((e) => Doc.fromBranch(Map<String, dynamic>.from(e as Map), date))
        .toList();
    if (market || supplier) return all;
    return all.where((d) => d.branch.id == own.id).toList();
  }

  /// Hujjatni qatorlari bilan (firma buyurtmasi — `supplier_id` bilan).
  Future<Doc> detail(Doc d) async {
    final j = await _get('$_base/branch', {
      'date': d.date,
      'restaurant_id': d.branch.id,
      if (d.supplierId != null && d.supplierId!.isNotEmpty) 'supplier_id': d.supplierId,
    });
    final b = d.branch.id.isEmpty ? own : d.branch;
    return Doc.fromRequest(j, b, d.date);
  }

  /// Saqlash — qatorlar TO'LIQ almashadi. Bozorkom `branchId` beradi va
  /// narx bilan yuboradi (yuk xati); menejer faqat miqdor (oldindan buyurtma).
  /// `supplierId` — FIRMAGA buyurtma: narxni firma o'z akkauntidan qo'yadi.
  Future<void> save({
    required String date,
    required String? branchId,
    required List<DocLine> lines,
    String? supplierId,
  }) async {
    await _post('$_base/request', {
      'market_date': date,
      if (market && branchId != null && branchId.isNotEmpty) 'restaurant_id': branchId,
      if (supplierId != null && supplierId.isNotEmpty) 'supplier_id': supplierId,
      'items': lines.where((l) => l.qty > 0 && l.name.trim().isNotEmpty)
          .map((l) => l.toItem(withPrice: canPrice)).toList(),
    });
  }

  /// Firma o'z buyurtmasiga narx qo'yadi — qator-qator (`buy-line`).
  Future<void> setLinePrice(String date, DocLine l) async {
    if (l.id.isEmpty || l.price == null || l.price! <= 0) return;
    await _post('$_base/buy-line', {'date': date, 'line_id': l.id, 'qty': l.qty, 'price': l.price});
  }

  /// Korxona firmalari. Endpoint bo'lmasa — bo'sh.
  Future<List<SupplierRef>> suppliers() async {
    try {
      final j = await _get('$_base/suppliers');
      return ((j['items'] as List?) ?? const [])
          .map((e) => SupplierRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException {
      return const [];
    }
  }

  /// Menejer qabul qiladi → omborga kirim.
  Future<void> accept(String date, List<DocLine> lines) async {
    await _post('$_base/accept', {
      'date': date,
      'lines': lines
          .where((l) => !l.isAccepted && l.id.isNotEmpty)
          // Backend `qty`ni o'qiydi (pos_bozor.rs accept); `accepted_qty` — moslik uchun.
          .map((l) => {'line_id': l.id, 'qty': l.acceptedQty ?? l.qty, 'accepted_qty': l.acceptedQty ?? l.qty})
          .toList(),
    });
  }

  Future<List<CatalogItem>> items([String q = '']) async {
    final j = await _get('$_base/items', {'q': q});
    return ((j['items'] as List?) ?? const [])
        .map((e) => CatalogItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Bitta mahsulot bozordan/firmadan QANCHAGA kelgani tarixi (korxona
  /// bo'yicha, yangisi tepada) + ombor holati + statistika.
  Future<PriceHistory> priceHistory(String name, {int limit = 30}) async {
    final j = await _get('$_base/price-history', {'name': name, 'limit': '$limit'});
    return PriceHistory.fromJson(j);
  }

  /// Barcha filiallar. Endpoint bo'lmasa — bo'sh (UI o'z filiali bilan ishlaydi).
  Future<List<BranchRef>> branches() async {
    try {
      final j = await _get('$_base/restaurants');
      return ((j['items'] as List?) ?? const [])
          .map((e) => BranchRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on Failure {
      // _wrap DioException'ni Failure qiladi — `on DioException` hech qachon tushmasdi.
      return const [];
    }
  }

  /// Xato matni — serverning o'zbekcha `detail`i, bo'lmasa tarmoq xabari.
  ///
  /// `DioClient._wrap` DioException'ni allaqachon `Failure`ga aylantiradi
  /// (message'da server `detail`i bor). Ilgari bu yerda faqat DioException
  /// tekshirilgani uchun ekranga sinf nomi — «ServerFailure», «NetworkFailure» —
  /// chiqardi (release'da `Equatable.stringify=false`), QA topdi 2026-09-08.
  static String errText(Object e, String netMsg) {
    if (e is NetworkFailure) return netMsg;
    if (e is Failure) return e.message;
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map) {
        final m = d['detail'] ?? d['message'] ?? d['error'];
        if (m is String && m.trim().isNotEmpty) return m;
      }
      if (e.response == null) return netMsg;
      return 'HTTP ${e.response?.statusCode}';
    }
    return e.toString();
  }
}
