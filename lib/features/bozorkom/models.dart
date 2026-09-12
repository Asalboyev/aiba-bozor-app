// BOZORKOM modellari — backend `pos_bozor` javoblarini bitta «Hujjat» (Doc)
// ko'rinishiga keltiradi. Eski Bozorkom ilovasidagidek: bitta filial + bitta
// kun = bitta hujjat (№, muallif, qabul qiluvchi, jami, tur, holat).

class BranchRef {
  const BranchRef({required this.id, required this.name, this.code = '', this.manager = '', this.address = ''});
  final String id;
  final String name;
  final String code;
  /// Filialning HOZIRGI faol menejeri (har oy almashadi — server xodimlar
  /// ro'yxatidan jonli beradi). Bo'sh bo'lsa — biriktirilmagan.
  final String manager;
  final String address;

  factory BranchRef.fromJson(Map<String, dynamic> j) => BranchRef(
        id: (j['id'] ?? j['restaurant_id'] ?? '').toString(),
        name: (j['name'] ?? j['restaurant'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        manager: (j['manager'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
      );
}

class CatalogItem {
  const CatalogItem({
    required this.name,
    required this.unit,
    required this.price,
    required this.qty,
    this.category = '',
    this.lastPrice,
    this.lastQty,
    this.lastDate,
    this.lastSource,
    this.lastSupplier,
  });
  final String name;
  final String unit;
  /// Ombordagi o'rtacha tannarx (kartochka).
  final double price;
  final double qty;
  final String category;
  /// OXIRGI marta bozordan/firmadan kelgan narx (null — hali olinmagan).
  final double? lastPrice;
  final double? lastQty;
  final String? lastDate; // YYYY-MM-DD
  final String? lastSource; // bozor | firma
  final String? lastSupplier;

  /// Oxirgi narx omborga nisbatan qancha % o'zgargan (null — solishtirib bo'lmaydi).
  double? get changePct =>
      (lastPrice == null || price <= 0) ? null : ((lastPrice! - price) / price * 100);

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        name: (j['name'] ?? '').toString(),
        unit: (j['unit'] ?? 'kg').toString(),
        price: _d(j['price']),
        qty: _d(j['qty']),
        category: (j['category'] ?? '').toString(),
        lastPrice: j['last_price'] == null ? null : _d(j['last_price']),
        lastQty: j['last_qty'] == null ? null : _d(j['last_qty']),
        lastDate: j['last_date']?.toString(),
        lastSource: j['last_source']?.toString(),
        lastSupplier: j['last_supplier']?.toString(),
      );
}

/// Yetkazuvchi (firma) — Coca-Cola, sex, ferma... Buyurtma bozorchiga EMAS,
/// firmaga yuboriladi; firma o'z akkauntidan narx qo'yadi, filial qabul qiladi.
class SupplierRef {
  const SupplierRef({required this.id, required this.name, this.phone = '', this.hasAccount = false});
  final String id;
  final String name;
  final String phone;
  final bool hasAccount;
  factory SupplierRef.fromJson(Map<String, dynamic> j) => SupplierRef(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        hasAccount: j['has_account'] == true,
      );
}

/// Bitta xarid yozuvi — narx tarixi qatori.
class PriceEntry {
  const PriceEntry({required this.date, required this.qty, required this.unit, required this.price, required this.total, this.source = '', this.supplier = '', this.actor = ''});
  final String date;
  final double qty;
  final String unit;
  final double price;
  final double total;
  final String source;
  final String supplier;
  final String actor;
  factory PriceEntry.fromJson(Map<String, dynamic> j) => PriceEntry(
        date: (j['date'] ?? '').toString(),
        qty: _d(j['qty']),
        unit: (j['unit'] ?? 'kg').toString(),
        price: _d(j['price']),
        total: _d(j['total']),
        source: (j['source'] ?? '').toString(),
        supplier: (j['supplier'] ?? '').toString(),
        actor: (j['actor'] ?? '').toString(),
      );
}

/// GET /market/price-history — mahsulot narx tarixi + ombor + statistika.
class PriceHistory {
  const PriceHistory({required this.name, this.stockQty, this.stockUnit, this.avgCost, this.count = 0, this.last, this.prev, this.changePct, this.min, this.max, this.avg, this.items = const []});
  final String name;
  final double? stockQty;
  final String? stockUnit;
  final double? avgCost;
  final int count;
  final double? last;
  final double? prev;
  final double? changePct;
  final double? min;
  final double? max;
  final double? avg;
  final List<PriceEntry> items;
  factory PriceHistory.fromJson(Map<String, dynamic> j) {
    final st = j['stock'] is Map ? Map<String, dynamic>.from(j['stock'] as Map) : null;
    final s = j['stats'] is Map ? Map<String, dynamic>.from(j['stats'] as Map) : const <String, dynamic>{};
    double? od(Object? v) => v == null ? null : _d(v);
    return PriceHistory(
      name: (j['name'] ?? '').toString(),
      stockQty: st == null ? null : _d(st['qty']),
      stockUnit: st?['unit']?.toString(),
      avgCost: st == null ? null : _d(st['avg_cost']),
      count: _i(s['count']) ?? 0,
      last: od(s['last']), prev: od(s['prev']), changePct: od(s['change_pct']),
      min: od(s['min']), max: od(s['max']), avg: od(s['avg']),
      items: ((j['items'] as List?) ?? const []).map((e) => PriceEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class DocLine {
  DocLine({
    this.id = '',
    this.itemId,
    required this.name,
    this.unit = 'kg',
    required this.qty,
    this.price,
    this.acceptedQty,
    this.status = 'pending',
  });
  final String id;
  final String? itemId;
  String name;
  String unit;
  double qty;
  double? price;
  double? acceptedQty;
  String status;

  double get total => (price ?? 0) * qty;
  bool get isAccepted => status == 'accepted';

  factory DocLine.fromJson(Map<String, dynamic> j) => DocLine(
        id: (j['id'] ?? '').toString(),
        itemId: j['item_id']?.toString(),
        name: (j['name'] ?? '').toString(),
        unit: (j['unit'] ?? 'kg').toString(),
        qty: _d(j['qty']),
        price: j['price'] == null ? null : _d(j['price']),
        acceptedQty: j['accepted_qty'] == null ? null : _d(j['accepted_qty']),
        status: (j['status'] ?? 'pending').toString(),
      );

  Map<String, dynamic> toItem({bool withPrice = false}) => {
        'name': name,
        'unit': unit,
        'qty': qty,
        if (itemId != null && itemId!.isNotEmpty) 'item_id': itemId,
        if (withPrice && price != null && price! > 0) 'price': price,
      };
}

enum DocKind { preorder, invoice }

class Doc {
  Doc({
    this.requestId,
    this.docNo,
    required this.date,
    required this.branch,
    this.createdBy,
    this.lines = const [],
    int? linesCount,
    this.pending = 0,
    this.bought = 0,
    this.accepted = 0,
    double? sum,
    this.source = 'bozor',
    this.supplierId,
    this.supplierName,
  })  : linesCount = linesCount ?? lines.length,
        sum = sum ?? lines.fold(0.0, (a, l) => a + l.total);

  final String? requestId;
  final int? docNo;
  final String date; // YYYY-MM-DD
  final BranchRef branch;
  /// Hujjatni kim yaratgan (o'sha paytdagi menejer/bozorchi — tarix uchun qoladi).
  final String? createdBy;
  /// 'bozor' — bozorchi oladi; 'firma' — yetkazuvchi firmaga buyurtma.
  final String source;
  final String? supplierId;
  final String? supplierName;

  bool get isFirma => source == 'firma';

  /// Filialning hozirgi faol menejeri (BranchRef orqali serverdan).
  String get manager => branch.manager;
  final List<DocLine> lines;
  final int linesCount;
  final int pending;
  final int bought;
  final int accepted;
  final double sum;

  /// Narx kiritilgan bo'lsa — yuk xati, aks holda oldindan buyurtma.
  DocKind get kind =>
      (bought + accepted) > 0 || lines.any((l) => l.price != null && l.price! > 0)
          ? DocKind.invoice
          : DocKind.preorder;

  /// Hamma qator qabul qilingan.
  bool get isAccepted =>
      linesCount > 0 && accepted >= linesCount ||
      (lines.isNotEmpty && lines.every((l) => l.isAccepted));

  String get numberLabel => docNo != null ? '№ $docNo' : '№ —';

  /// GET /market/branches?date — bozorchi ro'yxati (bir qator = bir filial).
  factory Doc.fromBranch(Map<String, dynamic> j, String date) => Doc(
        requestId: j['request_id']?.toString(),
        docNo: _i(j['doc_no']),
        date: date,
        branch: BranchRef.fromJson(j),
        createdBy: j['created_by']?.toString(),
        linesCount: _i(j['total']) ?? 0,
        pending: _i(j['pending']) ?? 0,
        bought: _i(j['bought']) ?? 0,
        accepted: _i(j['accepted']) ?? 0,
        sum: _d(j['sum']),
        source: (j['kind'] ?? 'bozor').toString(),
        supplierId: j['supplier_id']?.toString(),
        supplierName: j['supplier']?.toString(),
      );

  /// GET /market/my?date yoki /market/branch?date&restaurant_id — qatorlar bilan.
  factory Doc.fromRequest(Map<String, dynamic> j, BranchRef branch, String date) {
    final lines = ((j['lines'] as List?) ?? const [])
        .map((e) => DocLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Doc(
      requestId: (j['id'] ?? j['request_id'])?.toString(),
      docNo: _i(j['doc_no']),
      date: (j['date'] ?? date).toString(),
      branch: branch,
      createdBy: j['created_by']?.toString(),
      lines: lines,
      pending: lines.where((l) => l.status == 'pending').length,
      bought: lines.where((l) => l.status == 'bought').length,
      accepted: lines.where((l) => l.status == 'accepted').length,
      source: (j['kind'] ?? 'bozor').toString(),
      supplierId: j['supplier_id']?.toString(),
      supplierName: j['supplier']?.toString(),
    );
  }
}

double _d(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

int? _i(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
