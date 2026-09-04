// HUJJAT YARATISH / TAHRIRLASH — «Hisob-faktura/oldindan buyurtma yarating».
// Yetkazib beruvchi doim Bozorkom (o'zgarmaydi). Qabul qiluvchi: Bozorkom
// istalgan filialni tanlaydi, menejer faqat o'z filiali. Bozorkom narx ham
// kiritadi (yuk xati), menejer faqat miqdor (oldindan buyurtma).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/pos_chrome.dart';
import '../auth/presentation/providers/auth_providers.dart';
import 'i18n.dart';
import 'models.dart';
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
  late final List<_Row> _rows = [
    for (final l in widget.existing?.lines ?? const <DocLine>[]) _Row.from(l),
  ];
  bool _busy = false;

  bool get _market => ref.read(sessionProvider)?.staff.role == 'market';

  @override
  void initState() {
    super.initState();
    // Menejer — qabul qiluvchi doim o'z filiali.
    final s = ref.read(sessionProvider);
    if (_branchId.isEmpty && (s?.staff.role != 'market')) {
      _branchId = s?.restaurant.id ?? '';
    }
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
    final tr = ref.watch(trProvider);
    final loc = ref.watch(localeProvider);
    final session = ref.watch(sessionProvider);
    final market = session?.staff.role == 'market';
    final wide = isWide(context);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <BranchRef>[];
    final own = BranchRef(
        id: session?.restaurant.id ?? '',
        name: session?.restaurant.name ?? '',
        code: session?.restaurant.code ?? '');
    final recOpts = <MapEntry<String, String>>[
      if (market) ...[
        for (final b in branches) MapEntry(b.id, b.name),
        if (branches.isEmpty || !branches.any((b) => b.id == own.id)) MapEntry(own.id, own.name),
      ] else
        MapEntry(own.id, own.name),
    ];
    if (_branchId.isEmpty && recOpts.isNotEmpty) _branchId = recOpts.first.key;
    final editing = widget.existing != null;

    return Scaffold(
      backgroundColor: PosColors.bg,
      appBar: AppBar(
        backgroundColor: PosColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: Text(tr('createDoc'),
            maxLines: 2,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.2)),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 14, vertical: 8),
            children: [
              Row(children: [
                Expanded(
                  child: Text(editing ? tr('editInvoice') : tr('newInvoice'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                if (editing && widget.existing!.docNo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: PosColors.blue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(widget.existing!.numberLabel,
                        style: const TextStyle(
                            color: PosColors.blue, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 14),
              // Sarlavha maydonlari
              AibaCard(
                color: PosColors.panel,
                child: Column(children: [
                  ChoicePill<int>(
                    label: tr('supplier'),
                    value: 1,
                    options: [MapEntry(1, tr('market'))],
                    onChanged: (_) {},
                    enabled: false,
                    icon: Icons.storefront_rounded,
                  ),
                  const SizedBox(height: 12),
                  ChoicePill<String>(
                    label: tr('recipient'),
                    value: _branchId,
                    options: recOpts,
                    enabled: market && !editing,
                    icon: Icons.location_on_rounded,
                    onChanged: (v) => setState(() => _branchId = v),
                  ),
                  const SizedBox(height: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 2),
                      child: Text(tr('date'),
                          style: const TextStyle(color: PosColors.label, fontSize: 13)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: PosColors.field,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: editing ? PosColors.cardBorder : PosColors.blue.withValues(alpha: 0.5)),
                          ),
                          child: Row(children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 18, color: editing ? PosColors.muted : PosColors.blue),
                            const SizedBox(width: 8),
                            Text(prettyDate(_date),
                                style: TextStyle(
                                    color: editing ? PosColors.muted : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 18),
              // Ovqatlar sarlavhasi + qo'shish
              Row(children: [
                Text(tr('foods'),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                SizedBox(
                  height: 46,
                  child: FilledButton.tonalIcon(
                    onPressed: _addProducts,
                    style: FilledButton.styleFrom(
                      backgroundColor: PosColors.blue.withValues(alpha: 0.16),
                      foregroundColor: PosColors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('addProduct'),
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (_rows.isEmpty)
                AibaCard(
                  child: SizedBox(
                    height: 160,
                    child: EmptyState(icon: Icons.shopping_basket_outlined, title: tr('needLines')),
                  ),
                )
              else
                AibaCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < _rows.length; i++) ...[
                      _LineEditor(
                        row: _rows[i],
                        market: market,
                        tr: tr,
                        wide: wide,
                        onChanged: () => setState(() {}),
                        onDelete: () => setState(() => _rows.removeAt(i).dispose()),
                      ),
                      if (i < _rows.length - 1)
                        const Divider(height: 1, color: PosColors.cardBorder),
                    ],
                  ]),
                ),
              const SizedBox(height: 90),
            ],
          ),
        ),
        // Pastki: JAMI + Saqlash
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 12),
            child: Column(children: [
              if (market)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: PosColors.blue.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Text(tr('totalUpper'),
                        style: const TextStyle(color: PosColors.label, fontSize: 14)),
                    const Spacer(),
                    Text('${fmtSum(_total)} ${tr('cur')}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  ]),
                ),
              if (market) const SizedBox(height: 10),
              PrimaryBtn(
                label: tr('save'),
                icon: Icons.save_rounded,
                busy: _busy,
                enabled: _rows.isNotEmpty && _branchId.isNotEmpty,
                onTap: _save,
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _addProducts() async {
    final picked = await Navigator.of(context).push<List<CatalogItem>>(
      MaterialPageRoute(builder: (_) => const ProductPickerScreen()),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final it in picked) {
        final exists = _rows.any((r) => r.name.toLowerCase() == it.name.toLowerCase());
        if (exists) continue;
        _rows.add(_Row(
          name: it.name,
          unit: it.unit,
          qty: 1,
          price: _market && it.price > 0 ? it.price : null,
        ));
      }
    });
  }

  Future<void> _save() async {
    final tr = ref.read(trProvider);
    final lines = _rows.where((r) => r.qty > 0).map((r) => r.toLine()).toList();
    if (lines.isEmpty) {
      toast(context, tr('needLines'), error: true);
      return;
    }
    if (_branchId.isEmpty) {
      toast(context, tr('needRecipient'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(bozorkomRepoProvider).save(date: _date, branchId: _branchId, lines: lines);
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

/// Tahrirlanadigan qator (controller'lar bilan).
class _Row {
  _Row({required this.name, required this.unit, required double qty, double? price, this.id = '', this.itemId})
      : qtyCtl = TextEditingController(text: fmtQty(qty)),
        priceCtl = TextEditingController(text: price == null || price == 0 ? '' : fmtSum(price));
  factory _Row.from(DocLine l) =>
      _Row(name: l.name, unit: l.unit, qty: l.qty, price: l.price, id: l.id, itemId: l.itemId);

  final String id;
  final String? itemId;
  final String name;
  final String unit;
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
  const _LineEditor({
    required this.row,
    required this.market,
    required this.tr,
    required this.wide,
    required this.onChanged,
    required this.onDelete,
  });
  final _Row row;
  final bool market;
  final Tr tr;
  final bool wide;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final qty = SizedBox(
      width: wide ? 130 : 110,
      child: AibaField(controller: row.qtyCtl, label: tr('qty'), numeric: true, suffix: row.unit, onChanged: (_) => onChanged()),
    );
    final price = market
        ? SizedBox(
            width: wide ? 150 : 130,
            child: AibaField(controller: row.priceCtl, label: tr('price'), numeric: true, onChanged: (_) => onChanged()),
          )
        : null;
    final del = IconButton(
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline_rounded, color: PosColors.red),
      tooltip: tr('delete'),
    );
    final name = Text(row.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700));

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
                Text(tr('total'), style: const TextStyle(color: PosColors.label, fontSize: 12)),
                Text(fmtSum(row.total),
                    style: const TextStyle(color: PosColors.blue, fontSize: 17, fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
          del,
        ]),
      );
    }
    // Telefon: nom + o'chirish, pastda miqdor / narx / jami
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
            Text('${tr('total')}  ', style: const TextStyle(color: PosColors.label, fontSize: 13)),
            Text(fmtSum(row.total),
                style: const TextStyle(color: PosColors.blue, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
          ]),
        ],
      ]),
    );
  }
}
