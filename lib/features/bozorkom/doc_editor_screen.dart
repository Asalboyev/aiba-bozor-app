// HUJJAT YARATISH / TAHRIRLASH. Yetkazib beruvchi doim Bozorkom. Qabul
// qiluvchi: Bozorkom istalgan filial, menejer o'z filiali. Bozorkom narx ham
// kiritadi (yuk xati), menejer faqat miqdor (oldindan buyurtma). Oq/qora tema,
// tor telefonda hech narsa toshmaydi (sarlavha qatori Wrap).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/providers/auth_providers.dart';
import 'i18n.dart';
import 'models.dart';
import 'price_history_screen.dart';
import 'product_picker_screen.dart';
import 'repo.dart';
import 'widgets.dart';

class DocEditorScreen extends ConsumerStatefulWidget {
  const DocEditorScreen({super.key, required this.date, this.existing});
  final String date;
  final Doc? existing;
  @override
  ConsumerState<DocEditorScreen> createState() => _DocEditorScreenState();
}

class _DocEditorScreenState extends ConsumerState<DocEditorScreen> {
  late String _date = widget.existing?.date ?? widget.date;
  late String _branchId = widget.existing?.branch.id ?? '';
  /// '' — Bozorkom (bozorchi oladi); firma id — FIRMAGA buyurtma.
  late String _supplierId = widget.existing?.supplierId ?? '';
  late final List<_Row> _rows = [for (final l in widget.existing?.lines ?? const <DocLine>[]) _Row.from(l)];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    if (_branchId.isEmpty && (s?.staff.role != 'market')) _branchId = s?.restaurant.id ?? '';
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _total => _rows.fold(0.0, (a, r) => a + r.total);

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final loc = ref.watch(localeProvider);
    final session = ref.watch(sessionProvider);
    final market = session?.staff.role == 'market';
    final supplierRole = session?.staff.role == 'supplier';
    // Narx kiritadiganlar: bozorchi (yuk xati) va firma (o'z buyurtmasiga).
    final canPrice = market || supplierRole;
    final wide = isWide(context);
    final narrow = isNarrow(context);
    final pad = hPad(context);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <BranchRef>[];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? const <SupplierRef>[];
    final own = BranchRef(
        id: session?.restaurant.id ?? '', name: session?.restaurant.name ?? '', code: session?.restaurant.code ?? '');
    // Filial yonida HOZIRGI menejeri — bozorchi kimga yuborayotganini ko'radi
    // (menejerlar har oy almashadi, server jonli beradi).
    String bName(BranchRef b) => b.manager.isNotEmpty ? '${b.name} · ${b.manager}' : b.name;
    final recOpts = <MapEntry<String, String>>[
      if (market) ...[
        for (final b in branches) MapEntry(b.id, bName(b)),
        if (branches.isEmpty || !branches.any((b) => b.id == own.id)) MapEntry(own.id, own.name),
      ] else
        MapEntry(own.id, own.name),
    ];
    final editing = widget.existing != null;
    // Tahrirlanayotgan hujjat filiali ro'yxatda bo'lmasa (menejer boshqa filial
    // hujjatini ochdi) — «—» emas, o'sha filial ko'rsatiladi.
    if (editing && !recOpts.any((e) => e.key == widget.existing!.branch.id)) {
      recOpts.insert(0, MapEntry(widget.existing!.branch.id, widget.existing!.branch.name));
    }
    // Bozorchiga sukut bo'yicha filial TANLANMAYDI: filiallar yuklanmaguncha
    // «o'zi» yagona variant bo'lib, hujjat noto'g'ri filialga saqlanib qolardi.
    // Menejer — faqat o'z filiali, avtomatik.
    if (_branchId.isEmpty && !market && recOpts.isNotEmpty) _branchId = recOpts.first.key;
    final ts = MediaQuery.textScalerOf(context).scale(1.0);
    final firma = _supplierId.isNotEmpty;
    final titleKey = editing
        ? (canPrice ? 'editInvoice' : 'editPreorder')
        : (firma ? 'supplierOrder' : (market ? 'newInvoice' : 'newPreorder'));

    // Yetkazib beruvchi: Bozorkom yoki firma. Yangi hujjatda tanlanadi
    // (menejer ham firmaga zayavka yubora oladi); tahrirlashda va firma
    // akkauntida o'zgarmaydi.
    final supOpts = <MapEntry<String, String>>[
      MapEntry('', tr('market')),
      for (final s in suppliers) MapEntry(s.id, s.hasAccount ? s.name : '${s.name} · ${tr('noAccount')}'),
    ];
    if (firma && !supOpts.any((e) => e.key == _supplierId)) {
      supOpts.add(MapEntry(_supplierId, widget.existing?.supplierName ?? tr('firma')));
    }
    final supplierPill = ChoicePill<String>(
      label: tr('supplier'), value: _supplierId, options: supOpts,
      onChanged: (v) => setState(() => _supplierId = v),
      enabled: !editing && !supplierRole,
      icon: firma ? Icons.local_shipping_rounded : Icons.storefront_rounded,
    );
    final recipientPill = ChoicePill<String>(
      label: tr('recipient'), value: _branchId, options: recOpts, placeholder: tr('choose'),
      enabled: market && !editing, icon: Icons.location_on_rounded,
      onChanged: (v) => setState(() => _branchId = v),
    );
    final dateField = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(tr('date'), style: TextStyle(color: c.label, fontSize: 13)),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: editing
              ? null
              : () async {
                  final r = await pickIsoDate(context, tr, loc, _date);
                  if (r != null) setState(() => _date = r);
                },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.field,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: editing ? c.border : c.blue.withValues(alpha: 0.55)),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: editing ? c.muted : c.blue),
              const SizedBox(width: 8),
              Text(prettyDate(_date),
                  style: TextStyle(color: editing ? c.muted : c.text, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    ]);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: BarTitle(editing ? tr(titleKey) : tr('createDoc'), style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w400)),
      ),
      body: ContentWrap(child: Column(children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
            children: [
              // Wrap: «Редактировать накладную» № bilan bir qatorga sig'masa pastga
              // tushadi — ilgari FitText 11 px gacha kichraytirardi.
              Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(tr(titleKey), style: TextStyle(color: c.text, fontSize: 24, fontWeight: FontWeight.w800)),
                if (editing && widget.existing!.docNo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Text(widget.existing!.numberLabel,
                        style: TextStyle(color: c.blue, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const SizedBox(height: 14),
              AibaCard(
                color: c.panel,
                padding: const EdgeInsets.all(14),
                // Planshetda uch maydon BIR qatorda — landshaftda (800 px) forma
                // 270 px olib, mahsulot qatorlariga 2 qator joy qolardi (planshet QA).
                child: wide && ts < 1.3
                    ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(child: supplierPill),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: recipientPill),
                        const SizedBox(width: 12),
                        Expanded(child: dateField),
                      ])
                    : Column(children: [supplierPill, const SizedBox(height: 12), recipientPill, const SizedBox(height: 12), dateField]),
              ),
              // Firmaga buyurtma — kim narx qo'yadi, kim qabul qiladi (bir qator izoh).
              if (firma && !editing) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: c.blue),
                  const SizedBox(width: 6),
                  Expanded(child: Text(tr('fromSupplier'), style: TextStyle(color: c.muted, fontSize: 12.5))),
                ]),
              ],
              const SizedBox(height: 16),
              // Sarlavha + qo'shish tugmasi — tor ekranda pastga tushadi, toshmaydi.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                spacing: 8,
                children: [
                  Text(tr('foods'), style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w800)),
                  // Firma akkaunti buyurtma tarkibini O'ZGARTIRMAYDI — faqat narx qo'yadi.
                  if (!supplierRole) SizedBox(
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: _addProducts,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.blue.withValues(alpha: 0.14),
                        foregroundColor: c.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('addProduct'), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_rows.isEmpty)
                AibaCard(child: SizedBox(height: 150, child: EmptyState(icon: Icons.shopping_basket_outlined, title: tr('needLines'))))
              else
                AibaCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < _rows.length; i++) ...[
                      _LineEditor(
                        row: _rows[i], market: canPrice, tr: tr, wide: wide,
                        onChanged: () => setState(() {}),
                        onDelete: () => setState(() => _rows.removeAt(i).dispose()),
                      ),
                      if (i < _rows.length - 1) Divider(height: 1, color: c.border),
                    ],
                  ]),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
            child: Builder(builder: (_) {
              final totalBox = Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Text(tr('totalUpper'), style: TextStyle(color: c.label, fontSize: 14)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FitText('${fmtSum(_total)} ${tr('cur')}',
                        align: Alignment.centerRight,
                        style: TextStyle(color: c.text, fontSize: narrow ? 20 : 24, fontWeight: FontWeight.w800)),
                  ),
                ]),
              );
              final saveBtn = PrimaryBtn(
                label: tr('save'), icon: Icons.save_rounded, busy: _busy,
                enabled: _rows.isNotEmpty && _branchId.isNotEmpty, onTap: _save,
              );
              // Planshetda JAMI va Saqlash yonma-yon — 60 px vertikal joy tejaladi.
              if (canPrice && wide) {
                return Row(children: [Expanded(child: totalBox), const SizedBox(width: 12), SizedBox(width: 300, child: saveBtn)]);
              }
              return Column(children: [if (canPrice) ...[totalBox, const SizedBox(height: 10)], saveBtn]);
            }),
          ),
        ),
      ])),
    );
  }

  Future<void> _addProducts() async {
    final role = ref.read(sessionProvider)?.staff.role;
    final market = role == 'market' || role == 'supplier';
    final picked = await Navigator.of(context)
        .push<List<CatalogItem>>(MaterialPageRoute(builder: (_) => const ProductPickerScreen()));
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final it in picked) {
        if (_rows.any((r) => r.name.toLowerCase() == it.name.toLowerCase())) continue;
        // Narx maydoni OXIRGI KELGAN narx bilan to'ladi (bozorchi bugun boshqa
        // narxda olsa — ustidan yozadi); oxirgisi yo'q bo'lsa ombor tannarxi.
        final prefill = it.lastPrice ?? (it.price > 0 ? it.price : null);
        _rows.add(_Row(
          name: it.name, unit: it.unit, qty: 1,
          price: market ? prefill : null,
          stockPrice: it.price, lastPrice: it.lastPrice, lastDate: it.lastDate,
        ));
      }
    });
  }

  Future<void> _save() async {
    final tr = ref.read(trProvider);
    final lines = _rows.where((r) => r.qty > 0).map((r) => r.toLine()).toList();
    if (lines.isEmpty) return toast(context, tr('needLines'), error: true);
    if (_branchId.isEmpty) return toast(context, tr('needRecipient'), error: true);
    setState(() => _busy = true);
    try {
      final repo = ref.read(bozorkomRepoProvider);
      if (repo.supplier && widget.existing != null) {
        // Firma akkaunti buyurtmani QAYTA YOZMAYDI — faqat qatorlarga narx qo'yadi.
        for (final l in lines) {
          await repo.setLinePrice(_date, l);
        }
      } else {
        await repo.save(date: _date, branchId: _branchId, lines: lines, supplierId: _supplierId);
      }
      if (!mounted) return;
      toast(context, tr('saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, BozorkomRepo.errText(e, tr('errNet')), error: true);
    }
  }
}

class _Row {
  _Row({
    required this.name,
    required this.unit,
    required double qty,
    double? price,
    this.id = '',
    this.itemId,
    this.stockPrice = 0,
    this.lastPrice,
    this.lastDate,
  })  : qtyCtl = TextEditingController(text: fmtQty(qty)),
        priceCtl = TextEditingController(text: price == null || price == 0 ? '' : fmtSum(price));
  factory _Row.from(DocLine l) => _Row(name: l.name, unit: l.unit, qty: l.qty, price: l.price, id: l.id, itemId: l.itemId);
  final String id;
  final String? itemId;
  final String name;
  final String unit;
  /// Ombordagi o'rtacha tannarx va oxirgi kelgan narx — qator ostida ko'rsatiladi.
  final double stockPrice;
  final double? lastPrice;
  final String? lastDate;
  final TextEditingController qtyCtl;
  final TextEditingController priceCtl;
  double get qty => double.tryParse(qtyCtl.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;
  double? get price {
    final v = double.tryParse(priceCtl.text.replaceAll(',', '.').replaceAll(' ', ''));
    return (v == null || v <= 0) ? null : v;
  }
  double get total => (price ?? 0) * qty;
  DocLine toLine() => DocLine(id: id, itemId: itemId, name: name, unit: unit, qty: qty, price: price);
  void dispose() {
    qtyCtl.dispose();
    priceCtl.dispose();
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({required this.row, required this.market, required this.tr, required this.wide, required this.onChanged, required this.onDelete});
  final _Row row;
  final bool market;
  final Tr tr;
  final bool wide;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final qty = SizedBox(
      width: wide ? 130 : 110,
      child: AibaField(controller: row.qtyCtl, label: tr('qty'), numeric: true, suffix: unitLabel(row.unit, tr), onChanged: (_) => onChanged()),
    );
    final price = market
        ? SizedBox(width: wide ? 150 : 130, child: AibaField(controller: row.priceCtl, label: tr('price'), numeric: true, onChanged: (_) => onChanged()))
        : null;
    final del = IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline_rounded, color: c.red), tooltip: tr('delete'));
    // Nom ostida IKKI NARX: «Omborda 10 000 · Oxirgi 12 000 (03.09)». Nomga
    // bosilsa — narx tarixi. Faqat bozorchiga (narx kiritadigan) ko'rinadi.
    final hint = market && (row.stockPrice > 0 || row.lastPrice != null)
        ? Text(
            [
              if (row.stockPrice > 0) '${tr('inStock')} ${fmtSum(row.stockPrice)}',
              if (row.lastPrice != null)
                '${tr('lastBought')} ${fmtSum(row.lastPrice!)}${row.lastDate != null && row.lastDate!.isNotEmpty ? ' (${prettyDate(row.lastDate!).substring(0, 5)})' : ''}',
            ].join('  ·  '),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600))
        : null;
    final name = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PriceHistoryScreen(name: row.name))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Flexible(
            child: Text(row.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.history_rounded, size: 15, color: c.muted),
        ]),
        if (hint != null) ...[const SizedBox(height: 2), hint],
      ]),
    );

    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Expanded(child: name),
          const SizedBox(width: 12),
          qty,
          if (price != null) ...[const SizedBox(width: 10), price],
          if (market) ...[
            const SizedBox(width: 14),
            SizedBox(
              width: 120,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(tr('total'), style: TextStyle(color: c.label, fontSize: 12)),
                Text(fmtSum(row.total), style: TextStyle(color: c.blue, fontSize: 17, fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
          del,
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: name), del]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: qty),
          if (price != null) ...[const SizedBox(width: 10), Expanded(child: price)],
        ]),
        if (market) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Spacer(),
            Text('${tr('total')}  ', style: TextStyle(color: c.label, fontSize: 13)),
            Text(fmtSum(row.total), style: TextStyle(color: c.blue, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
          ]),
        ],
      ]),
    );
  }
}
