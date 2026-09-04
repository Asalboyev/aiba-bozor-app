// BOZORKOM modellari — backend `pos_bozor` javoblarini bitta «Hujjat» (Doc)
// ko'rinishiga keltiradi. Eski Bozorkom ilovasidagidek: bitta filial + bitta
// kun = bitta hujjat (№, muallif, qabul qiluvchi, jami, tur, holat).

class BranchRef {
  const BranchRef({required this.id, required this.name, this.code = ''});
  final String id;
  final String name;
  final String code;

  factory BranchRef.fromJson(Map<String, dynamic> j) => BranchRef(
        id: (j['id'] ?? j['restaurant_id'] ?? '').toString(),
        name: (j['name'] ?? j['restaurant'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
      );
}

class CatalogItem {
  const CatalogItem({
    required this.name,
    required this.unit,
    required this.price,
    required this.qty,
    this.category = '',
  });
  final String name;
  final String unit;
  final double price;
  final double qty;
  final String category;

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        name: (j['name'] ?? '').toString(),
        unit: (j['unit'] ?? 'kg').toString(),
        price: _d(j['price']),
        qty: _d(j['qty']),
        category: (j['category'] ?? '').toString(),
      );
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
  })  : linesCount = linesCount ?? lines.length,
        sum = sum ?? lines.fold(0.0, (a, l) => a + l.total);

  final String? requestId;
  final int? docNo;
  final String date; // YYYY-MM-DD
  final BranchRef branch;
  final String? createdBy;
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
