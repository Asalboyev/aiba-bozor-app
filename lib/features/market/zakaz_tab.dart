// ZAKAZ — filial menejeri ertangi bozor ro'yxatini yuboradi.
// Qatorlar erkin: nom + miqdor + birlik. Yuborilgach bozorchining jamlangan
// ro'yxatiga tushadi; qayta yuborilsa (qabul qilinmaganlari) almashtiriladi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/pos_chrome.dart';
import 'market_screen.dart' show marketDateProvider;
import 'ui_bits.dart';

class _Row {
  _Row({String name = '', String qty = '', this.unit = 'kg'})
      : nameCtl = TextEditingController(text: name),
        qtyCtl = TextEditingController(text: qty);
  final TextEditingController nameCtl;
  final TextEditingController qtyCtl;
  String unit;

  /// Tanlangan kartochkaning OMBORDAGI joriy qoldig'i — menejer «hozir
  /// qancha bor» ko'rib, qancha zakaz qilishini biladi.
  double? stockQty;
}

/// Ombordagi kartochka (tanlash oynasi uchun). [isNew] — omborda yo'q,
/// menejer qidiruv qatoriga qo'lda yozgan nom.
class _StockItem {
  const _StockItem(this.name, this.unit, this.qty, {this.isNew = false});
  final String name;
  final String unit;
  final double qty;
  final bool isNew;
}

class ZakazTab extends ConsumerStatefulWidget {
  const ZakazTab({super.key});

  @override
  ConsumerState<ZakazTab> createState() => _ZakazTabState();
}

class _ZakazTabState extends ConsumerState<ZakazTab> {
  final List<_Row> _rows = [_Row()];
  bool _sending = false;
  String? _msg;
  bool _err = false;
  int _sentCount = 0;

  static const _units = ['kg', 'dona', 'l', 'quti'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExisting();
      _loadStock();
    });
  }

  /// Shu kunga avval yuborilgan zakaz bo'lsa — tahrirga yuklaymiz.
  Future<void> _loadExisting() async {
    final date = ref.read(marketDateProvider);
    try {
      final res = await ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/my',
        query: {'date': date},
      );
      final lines = (res.data?['lines'] as List?) ?? const [];
      if (!mounted || lines.isEmpty) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(lines.where((l) => l['status'] != 'accepted').map((l) => _Row(
                name: (l['name'] ?? '') as String,
                qty: '${l['qty'] ?? ''}'.replaceAll(RegExp(r'\.0$'), ''),
                unit: (l['unit'] ?? 'kg') as String,
              )));
        if (_rows.isEmpty) _rows.add(_Row());
        _sentCount = lines.length;
      });
    } catch (_) {/* oflayn — bo'sh formadan boshlanadi */}
  }

  List<_StockItem> _stock = [];
  bool _stockLoaded = false;

  /// Ombor kartochkalari — bir marta yuklab, keshda ushlanadi.
  Future<void> _loadStock() async {
    if (_stockLoaded) return;
    try {
      final res = await ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/items',
      );
      if (!mounted) return;
      setState(() {
        _stock = ((res.data?['items'] as List?) ?? const [])
            .map((j) => _StockItem(
                  (j['name'] ?? '') as String,
                  (j['unit'] ?? 'kg') as String,
                  ((j['qty'] ?? 0) as num).toDouble(),
                ))
            .toList();
        _stockLoaded = true;
      });
    } catch (_) {/* oflayn — nomni qo'lda yozadi */}
  }

  /// Mahsulot tanlash oynasi: qidiruv + ombordagi qoldiq ko'rinadi.
  Future<void> _pickItem(_Row row) async {
    await _loadStock();
    if (!mounted) return;
    final picked = await showModalBottomSheet<_StockItem>(
      context: context,
      backgroundColor: PosColors.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _ItemPicker(items: _stock),
    );
    if (picked == null) return;
    setState(() {
      row.nameCtl.text = picked.name;
      row.unit = _units.contains(picked.unit) ? picked.unit : 'kg';
      // Omborda yo'q yangi nom uchun qoldiq ko'rsatilmaydi.
      row.stockQty = picked.isNew ? null : picked.qty;
    });
  }

  Future<void> _send() async {
    final date = ref.read(marketDateProvider);
    final items = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final name = r.nameCtl.text.trim();
      final qty =
          double.tryParse(r.qtyCtl.text.trim().replaceAll(',', '.')) ?? 0;
      if (name.isNotEmpty && qty > 0) {
        items.add({'name': name, 'qty': qty, 'unit': r.unit});
      }
    }
    if (items.isEmpty) {
      setState(() {
        _msg = 'Kamida bitta qator (nom + miqdor) kiriting';
        _err = true;
      });
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/request',
        data: {'market_date': date, 'items': items},
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _msg = 'Zakaz yuborildi — ${items.length} pozitsiya. '
            'Bozorchining ro\'yxatiga tushdi.';
        _err = false;
        _sentCount = items.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _msg = 'Yuborib bo\'lmadi — internetni tekshirib qayta urinib ko\'ring';
        _err = true;
      });
    }
  }

  /// Ombordagi joriy qoldiq — qator nomiga qarab topiladi (qayta yuklangan
  /// zakazda ham «omborda: X» ko'rinsin).
  double? _stockFor(String name) {
    if (name.isEmpty) return null;
    final k = name.toLowerCase().trim();
    for (final it in _stock) {
      if (it.name.toLowerCase().trim() == k) return it.qty;
    }
    return null;
  }

  int get _filled => _rows
      .where((r) =>
          r.nameCtl.text.trim().isNotEmpty &&
          (double.tryParse(r.qtyCtl.text.trim().replaceAll(',', '.')) ?? 0) > 0)
      .length;

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(marketDateProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DayBar(
            date: date,
            onShift: (d) {
              ref.read(marketDateProvider.notifier).state = shiftDay(date, d);
              _msg = null;
              _loadExisting();
            },
            trailing: _sentCount > 0
                ? Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: PosColors.green.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: PosColors.green.withValues(alpha: .35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.send_rounded,
                          size: 14, color: PosColors.green),
                      const SizedBox(width: 6),
                      Text('Yuborilgan: $_sentCount',
                          style: const TextStyle(
                              color: PosColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          // Ustun sarlavhalari — faqat keng ekranda (telefonda qator ikki
          // satr bo'lgani uchun keraksiz).
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 640) return const SizedBox.shrink();
            const st = TextStyle(
                color: PosColors.label,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .6);
            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Row(children: const [
                Expanded(child: Text('MAHSULOT', style: st)),
                SizedBox(width: 10),
                SizedBox(
                    width: 104,
                    child: Text('MIQDOR', textAlign: TextAlign.right, style: st)),
                SizedBox(width: 8),
                SizedBox(width: 96, child: Text('BIRLIK', style: st)),
                SizedBox(width: 12),
                SizedBox(width: 150, child: Text('OMBORDA', style: st)),
                SizedBox(width: 40),
              ]),
            );
          }),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: PosColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PosColors.cardBorder),
              ),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _rows.length + 1,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (c, i) {
                  if (i == _rows.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: PosColors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onPressed: () => setState(() => _rows.add(_Row())),
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text('Qator qo\'shish',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    );
                  }
                  return _buildRow(i);
                },
              ),
            ),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 8),
            MsgLine(text: _msg!, error: _err),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PosColors.blue,
                disabledBackgroundColor: const Color(0xFF23262B),
                disabledForegroundColor: PosColors.muted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sending || _filled == 0 ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 19),
                        const SizedBox(width: 9),
                        Text(
                            _filled == 0
                                ? 'Zakazni yuborish'
                                : 'Zakazni yuborish · $_filled pozitsiya',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bitta zakaz qatori. PLANSHETda bitta satr (nom | miqdor | birlik |
  /// omborda | o'chirish), TELEFONda ikki satr.
  Widget _buildRow(int i) {
    final r = _rows[i];
    final name = r.nameCtl.text.trim();
    final stock = r.stockQty ?? _stockFor(name);

    final picker = InkWell(
      onTap: () => _pickItem(r),
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: PosColors.field,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: PosColors.cardBorder),
        ),
        child: Row(children: [
          Icon(name.isEmpty ? Icons.search : Icons.inventory_2_outlined,
              size: 18, color: PosColors.muted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name.isEmpty ? 'Mahsulot tanlash (ombordan)' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: name.isEmpty ? FontWeight.w400 : FontWeight.w700,
                  color: name.isEmpty ? const Color(0xFF6B7178) : Colors.white),
            ),
          ),
          const Icon(Icons.expand_more, size: 20, color: PosColors.muted),
        ]),
      ),
    );

    final qty = SizedBox(
      height: 46,
      child: TextField(
        controller: r.qtyCtl,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        decoration: _dec('0'),
      ),
    );

    final unit = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: PosColors.field,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: PosColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: r.unit,
          isDense: true,
          isExpanded: true,
          dropdownColor: PosColors.panel,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.expand_more, size: 18, color: PosColors.muted),
          // Shrift mavzudan olinadi (Inter) — o'z TextStyle'ini berish
          // standart shriftga tushirib yuborardi.
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          items: [
            for (final u in _units)
              DropdownMenuItem(value: u, child: Text(unitUz(u))),
          ],
          onChanged: (v) => setState(() => r.unit = v ?? 'kg'),
        ),
      ),
    );

    // Ombordagi qoldiq — kam qolgani sariq/qizil bo'lib ko'zga tashlanadi.
    // Telefonda joy tor: «omborda:» yozuvi o'rniga ombor ikonkasi turadi.
    Widget stockChip({required bool compact}) {
      if (stock == null) return const SizedBox.shrink();
      final c = stock <= 0
          ? PosColors.red
          : (stock < 2 ? const Color(0xFFF5A623) : PosColors.label);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: PosColors.iconChip,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warehouse_outlined, size: 13, color: c),
          const SizedBox(width: 5),
          Text(
              compact
                  ? '${fmtQty(stock)} ${unitUz(r.unit)}'
                  : 'omborda: ${fmtQty(stock)} ${unitUz(r.unit)}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    final del = IconButton(
      onPressed: () => setState(() {
        _rows.removeAt(i);
        if (_rows.isEmpty) _rows.add(_Row());
      }),
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.close, size: 19, color: PosColors.muted),
      tooltip: 'Qatorni o\'chirish',
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: PosColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.cardBorder),
      ),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 620) {
          // PLANSHET — bitta satr.
          return Row(children: [
            Expanded(child: picker),
            const SizedBox(width: 10),
            SizedBox(width: 104, child: qty),
            const SizedBox(width: 8),
            SizedBox(width: 96, child: unit),
            const SizedBox(width: 12),
            SizedBox(
                width: 150,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: stockChip(compact: false))),
            del,
          ]);
        }
        // TELEFON — ikki satr.
        return Column(children: [
          Row(children: [Expanded(child: picker), del]),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(width: 104, child: qty),
            const SizedBox(width: 8),
            SizedBox(width: 96, child: unit),
            const SizedBox(width: 10),
            Expanded(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: stockChip(compact: true))),
          ]),
        ]);
      }),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7178)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        filled: true,
        fillColor: PosColors.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: PosColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: PosColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: PosColors.blue, width: 1.4),
        ),
      );
}


/// OMBOR KARTOCHKALARI ro'yxati — qidiruv bilan; har qatorda joriy qoldiq
/// (kam qolgani rangda ajralib turadi). Omborda yo'q nomni qidiruv qatoriga
/// yozib, «yangi nom bilan qo'shish» orqali ham zakaz qilish mumkin.
class _ItemPicker extends StatefulWidget {
  const _ItemPicker({required this.items});
  final List<_StockItem> items;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.items
        .where((i) => q.isEmpty || i.name.toLowerCase().contains(q))
        .toList();
    final exact =
        widget.items.any((i) => i.name.toLowerCase().trim() == q);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .8,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 20, color: PosColors.muted),
              const SizedBox(width: 9),
              const Expanded(
                child: Text('Mahsulot tanlash',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20, color: PosColors.muted),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SearchField(
              autofocus: true,
              hint: 'Nomi bo\'yicha qidirish…',
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: (list.isEmpty && q.isEmpty)
                ? const EmptyHint(
                    icon: Icons.inventory_2_outlined,
                    title: 'Ombor kartochkalari yuklanmadi',
                    note: 'Internet qaytgach qayta oching yoki nomni '
                        'qidiruvga yozib qo\'shing.')
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: list.length + (q.isNotEmpty && !exact ? 1 : 0),
                    separatorBuilder: (c, i) =>
                        const Divider(height: 1, color: PosColors.cardBorder),
                    itemBuilder: (c, i) {
                      // Oxirgi qator — «qidirilgan nomni qo'shish».
                      if (i == list.length) {
                        return ListTile(
                          leading: const Icon(Icons.add_circle_outline,
                              color: PosColors.blue),
                          title: Text('«${_q.trim()}» — yangi nom bilan qo\'shish',
                              style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: PosColors.blue)),
                          subtitle: const Text(
                              'Omborda bunday kartochka yo\'q — qabul qilinganda '
                              'yangisi ochiladi',
                              style: TextStyle(
                                  color: PosColors.muted, fontSize: 12)),
                          onTap: () => Navigator.of(context)
                              .pop(_StockItem(_q.trim(), 'kg', 0, isNew: true)),
                        );
                      }
                      final it = list[i];
                      final low = it.qty <= 0
                          ? PosColors.red
                          : (it.qty < 2
                              ? const Color(0xFFF5A623)
                              : PosColors.label);
                      return ListTile(
                        title: Text(it.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            it.qty <= 0
                                ? 'Omborda tugagan'
                                : 'Omborda: ${fmtQty(it.qty)} ${unitUz(it.unit)}',
                            style: TextStyle(color: low, fontSize: 12.5)),
                        trailing: const Icon(Icons.add_circle_outline,
                            color: PosColors.green),
                        onTap: () => Navigator.of(context).pop(it),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
