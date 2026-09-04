// BOZORCHI — BITTA FILIAL RO'YXATI (2-ekran).
//
// Faqat shu filialga kerak bo'lgan mahsulotlar. Har qatorda: nom, kerakli
// miqdor, olingan miqdor va narx. «Oldim» bosilganda FAQAT shu filialning
// shu qatori yopiladi — boshqa filiallar tegilmaydi (bozorchi adashmasin).
//
// Narx maslahati: shu mahsulot bugun boshqa filial uchun allaqachon olingan
// bo'lsa, narx maydoniga o'sha narx oldindan qo'yiladi (bitta bozor — bitta
// narx), lekin bozorchi uni o'zgartira oladi.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/pos_chrome.dart';
import 'market_screen.dart';
import 'ui_bits.dart';

class BranchMarketScreen extends ConsumerStatefulWidget {
  const BranchMarketScreen({
    super.key,
    required this.branchId,
    required this.branchName,
  });

  final String branchId;
  final String branchName;

  @override
  ConsumerState<BranchMarketScreen> createState() => _BranchMarketScreenState();
}

class _BranchMarketScreenState extends ConsumerState<BranchMarketScreen> {
  List<MarketLine> _lines = [];
  bool _loading = true;
  String? _error;
  final _qtyCtl = <String, TextEditingController>{};
  final _priceCtl = <String, TextEditingController>{};
  final _saving = <String>{};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 25), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in _qtyCtl.values) {
      c.dispose();
    }
    for (final c in _priceCtl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final date = ref.read(marketDateProvider);
    try {
      final res = await ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/branch',
        query: {'date': date, 'restaurant_id': widget.branchId},
      );
      if (!mounted) return;
      final lines = ((res.data?['lines'] as List?) ?? const [])
          .map((l) => MarketLine((l as Map).cast<String, dynamic>()))
          .toList();
      setState(() {
        _lines = lines;
        _loading = false;
        _error = null;
      });
      // Maydonlarni to'ldiramiz: miqdor — so'ralgani, narx — kiritilgani
      // yoki boshqa filialdan qolgan narx maslahati.
      for (final l in lines) {
        final qc = _qtyCtl.putIfAbsent(l.id, () => TextEditingController());
        if (qc.text.isEmpty || l.isAccepted) qc.text = fmtQty(l.qty);
        final p = l.price ?? l.hintPrice;
        final ctl = _priceCtl.putIfAbsent(l.id, () => TextEditingController());
        if (ctl.text.isEmpty && p != null && p > 0) ctl.text = money(p);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Internet yo\'q — ro\'yxatni yuklab bo\'lmadi';
      });
    }
  }

  double? _num(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.').replaceAll(' ', ''));

  Future<void> _buy(MarketLine l) async {
    final price = _num(_priceCtl[l.id]?.text ?? '');
    if (price == null || price <= 0) {
      _toast('Avval narxni kiriting', bad: true);
      return;
    }
    final qty = _num(_qtyCtl[l.id]?.text ?? '') ?? l.qty;
    setState(() => _saving.add(l.id));
    try {
      await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/buy-line',
        data: {
          'date': ref.read(marketDateProvider),
          'line_id': l.id,
          'qty': qty,
          'price': price,
        },
      );
      if (!mounted) return;
      setState(() => _saving.remove(l.id));
      _toast('${l.name} — olindi (${widget.branchName})');
      await _load(quiet: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving.remove(l.id));
      _toast('Yuborilmadi — internetni tekshiring', bad: true);
    }
  }

  void _toast(String text, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      backgroundColor: bad ? PosColors.red : PosColors.green,
      content: Text(text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final todo = _lines.where((l) => l.isPending).toList();
    final done = _lines.where((l) => !l.isPending).toList();
    final sum = _lines.fold<double>(
        0, (s, l) => s + (l.price ?? 0) * l.qty);

    return Scaffold(
      backgroundColor: PosColors.bg,
      body: AppBackground(
        child: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xCC06090B)),
            child: Column(children: [
              // Sarlavha: FILIAL NOMI doim ko'rinib turadi — bozorchi kimga
              // olayotganini bir qarashda biladi.
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 12, 6),
                child: Row(children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 24),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.branchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800)),
                        Text(
                            todo.isEmpty
                                ? 'Hammasi olindi'
                                : '${todo.length} ta olinmagan',
                            style: TextStyle(
                                color: todo.isEmpty
                                    ? PosColors.green
                                    : PosColors.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (sum > 0)
                    Text('${money(sum)} so\'m',
                        style: const TextStyle(
                            color: PosColors.green,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800)),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 22),
                  ),
                ]),
              ),
              Expanded(
                child: _loading && _lines.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _lines.isEmpty
                        ? EmptyHint(
                            icon: Icons.wifi_off,
                            title: 'Internet yo\'q',
                            note: 'Bozor ilovasi faqat onlayn ishlaydi.')
                        : _lines.isEmpty
                            ? const EmptyHint(
                                icon: Icons.inbox_outlined,
                                title: 'Bu filialga zakaz yo\'q')
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                  children: [
                                    if (todo.isNotEmpty) ...[
                                      GroupHeader(
                                          title: 'Olish kerak',
                                          count: todo.length,
                                          color: PosColors.blue),
                                      for (final l in todo) _row(l),
                                    ],
                                    if (done.isNotEmpty) ...[
                                      GroupHeader(
                                          title: 'Olindi',
                                          count: done.length,
                                          color: PosColors.green),
                                      for (final l in done) _row(l),
                                    ],
                                  ],
                                ),
                              ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _row(MarketLine l) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _LineCard(
          line: l,
          qtyCtl: _qtyCtl.putIfAbsent(l.id, () => TextEditingController()),
          priceCtl: _priceCtl.putIfAbsent(l.id, () => TextEditingController()),
          saving: _saving.contains(l.id),
          onBuy: () => _buy(l),
          onChanged: () => setState(() {}),
        ),
      );
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.qtyCtl,
    required this.priceCtl,
    required this.saving,
    required this.onBuy,
    required this.onChanged,
  });

  final MarketLine line;
  final TextEditingController qtyCtl;
  final TextEditingController priceCtl;
  final bool saving;
  final VoidCallback onBuy;
  final VoidCallback onChanged;

  double? _n(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.').replaceAll(' ', ''));

  @override
  Widget build(BuildContext context) {
    final done = !line.isPending;
    final q = _n(qtyCtl.text) ?? line.qty;
    final p = _n(priceCtl.text);
    final sum = (p ?? 0) * q;

    final head = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(
          line.isAccepted
              ? Icons.inventory_2
              : done
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
          size: 20,
          color: done ? PosColors.green : PosColors.muted),
      const SizedBox(width: 9),
      Expanded(
        child: Text(line.name,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, height: 1.25)),
      ),
      const SizedBox(width: 10),
      Text('${fmtQty(line.qty)} ${unitUz(line.unit)}',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, height: 1.2)),
    ]);

    if (line.isAccepted) {
      // Filial qabul qilib bo'lgan — tahrir yopiq.
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF12211A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosColors.green.withValues(alpha: .3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          const SizedBox(height: 6),
          Text(
              'Filial qabul qildi'
              '${line.price != null ? ' · ${money(line.price!)} so\'m' : ''}',
              style: const TextStyle(color: PosColors.green, fontSize: 12.5)),
        ]),
      );
    }

    final qtyField = NumField(
      controller: qtyCtl,
      label: 'Olindi',
      suffix: unitUz(line.unit),
      onChanged: (_) => onChanged(),
    );
    final priceField = NumField(
      controller: priceCtl,
      label: 'Narxi (1 ${unitUz(line.unit)})',
      suffix: 'so\'m',
      hint: '0',
      group: true,
      onChanged: (_) => onChanged(),
    );
    final btn = SizedBox(
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: done ? const Color(0xFF1B3A2B) : PosColors.green,
          foregroundColor: done ? PosColors.green : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(
                color: done
                    ? PosColors.green.withValues(alpha: .45)
                    : Colors.transparent),
          ),
        ),
        onPressed: saving ? null : onBuy,
        child: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(done ? Icons.edit : Icons.add_shopping_cart, size: 18),
                const SizedBox(width: 7),
                Text(done ? 'O\'zgartirish' : 'Oldim',
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800)),
              ]),
      ),
    );
    final sumLine = sum > 0
        ? Text('Jami: ${money(sum)} so\'m',
            style: const TextStyle(
                color: PosColors.green,
                fontSize: 13,
                fontWeight: FontWeight.w700))
        : Text(
            line.hintPrice != null && line.hintPrice! > 0
                ? 'Boshqa filialga ${money(line.hintPrice!)} so\'mdan olingan'
                : 'Narxni kiriting',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: PosColors.muted, fontSize: 12.5));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFF12211A) : PosColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: done
                ? PosColors.green.withValues(alpha: .35)
                : PosColors.cardBorder),
      ),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                head,
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  SizedBox(width: 108, child: qtyField),
                  const SizedBox(width: 10),
                  Expanded(child: priceField),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: sumLine),
                  const SizedBox(width: 10),
                  btn,
                ]),
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: head),
          const SizedBox(width: 16),
          SizedBox(width: 116, child: qtyField),
          const SizedBox(width: 10),
          SizedBox(width: 168, child: priceField),
          const SizedBox(width: 14),
          SizedBox(
            width: 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Center(child: sumLine),
                ),
                btn,
              ],
            ),
          ),
        ]);
      }),
    );
  }
}
