// BOZORKOM — backend bilan aloqa (pos_bozor terminal endpointlari) + holat
// provayderlari. Rol: `market` = Bozorkom (hamma filial), boshqa = filial
// menejeri (faqat o'z filiali).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../auth/presentation/providers/auth_providers.dart';
import '../market/market_screen.dart' show isoDay;
import 'models.dart';

const _base = '/api/v2/pos-terminal/market';

/// Ro'yxat sanasi (YYYY-MM-DD).
final docDateProvider = StateProvider<String>((ref) => isoDay(DateTime.now()));

/// Rol: Bozorkom (market) — hamma filial; aks holda filial menejeri.
bool isMarketRole(Ref ref) => ref.read(sessionProvider)?.staff.role == 'market';

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

class BozorkomRepo {
  BozorkomRepo(this._ref);
  final Ref _ref;

  bool get market => isMarketRole(_ref);
  BranchRef get own => ownBranch(_ref);

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? q]) async {
    final res = await _ref.read(dioClientProvider).get<Map<String, dynamic>>(path, query: q);
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await _ref.read(dioClientProvider).post<Map<String, dynamic>>(path, data: body);
    return res.data ?? const {};
  }

  /// Bozorkom: hamma filial (bir qator = bir filial hujjati).
  /// Menejer: faqat o'z filialining shu kundagi hujjati.
  Future<List<Doc>> listForDate(String date) async {
    if (market) {
      final j = await _get('$_base/branches', {'date': date});
      return ((j['branches'] as List?) ?? const [])
          .map((e) => Doc.fromBranch(Map<String, dynamic>.from(e as Map), date))
          .toList();
    }
    final j = await _get('$_base/my', {'date': date});
    if (j['exists'] != true) return const [];
    return [Doc.fromRequest(j, own, date)];
  }

  /// Hujjatni qatorlari bilan.
  Future<Doc> detail(Doc d) async {
    if (market) {
      final j = await _get('$_base/branch', {'date': d.date, 'restaurant_id': d.branch.id});
      return Doc.fromRequest(j, d.branch, d.date);
    }
    final j = await _get('$_base/my', {'date': d.date});
    return Doc.fromRequest(j, own, d.date);
  }

  /// Saqlash — qatorlar TO'LIQ almashadi. Bozorkom `branchId` beradi va
  /// narx bilan yuboradi (yuk xati); menejer faqat miqdor (oldindan buyurtma).
  Future<void> save({
    required String date,
    required String? branchId,
    required List<DocLine> lines,
  }) async {
    await _post('$_base/request', {
      'market_date': date,
      if (market && branchId != null && branchId.isNotEmpty) 'restaurant_id': branchId,
      'items': lines.where((l) => l.qty > 0 && l.name.trim().isNotEmpty)
          .map((l) => l.toItem(withPrice: market)).toList(),
    });
  }

  /// Menejer qabul qiladi → omborga kirim.
  Future<void> accept(String date, List<DocLine> lines) async {
    await _post('$_base/accept', {
      'date': date,
      'lines': lines
          .where((l) => !l.isAccepted && l.id.isNotEmpty)
          .map((l) => {'line_id': l.id, 'accepted_qty': l.acceptedQty ?? l.qty})
          .toList(),
    });
  }

  Future<List<CatalogItem>> items([String q = '']) async {
    final j = await _get('$_base/items', {'q': q});
    return ((j['items'] as List?) ?? const [])
        .map((e) => CatalogItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Barcha filiallar. Endpoint bo'lmasa — bo'sh (UI o'z filiali bilan ishlaydi).
  Future<List<BranchRef>> branches() async {
    try {
      final j = await _get('$_base/restaurants');
      return ((j['items'] as List?) ?? const [])
          .map((e) => BranchRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException {
      return const [];
    }
  }

  /// Xato matni — serverning o'zbekcha `detail`i, bo'lmasa tarmoq xabari.
  static String errText(Object e, String netMsg) {
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
