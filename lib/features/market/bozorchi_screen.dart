// BOZORCHI EKRANI — jamlangan ro'yxat.
//
// Bozorchi bozorda turib 6–7 filialning zakazini ALOHIDA aylanmaydi: bitta
// ro'yxat — «Kartoshka · 25 kg (Chilonzor 10 · Yunusobod 15)». Narxni BIR
// MARTA kiritadi (katta raqam paneli), server hamma filialga tarqatadi.
// Olingan pozitsiya pastga tushadi va yashil bo'ladi; jami xarajat tepada.
//
// Backend: GET /pos-terminal/market/aggregate?date=  → items[]
//          POST /pos-terminal/market/buy {date, items:[{name, unit, qty, price}]}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/pos_chrome.dart';
import 'market_screen.dart';
import 'ui_bits.dart';

class AggItem {
  AggItem(this.j);
  final Map<String, dynamic> j;
  String get name => (j['name'] ?? '') as String;
  String get unit => (j['unit'] ?? 'kg') as String;
  double get totalQty => ((j['total_qty'] ?? 0) as num).toDouble();
  double? get price => (j['price'] as num?)?.toDouble();
  double? get boughtQty => (j['bought_qty'] as num?)?.toDouble();
  double? get boughtTotal => (j['bought_total'] as num?)?.toDouble();
  bool get bought => price != null;
  List<(String, double)> get branches {
    final b = j['branches'];
    if (b is! List) return const [];
    return b
        .map((e) => ((e['restaurant'] ?? '') as String, ((e['qty'] ?? 0) as num).toDouble()))
        .toList();
  }
}

enum _Filter { todo, done, all }

class BozorchiScreen extends ConsumerStatefulWidget {
  const BozorchiScreen({super.key});

  @override
  ConsumerState<BozorchiScreen> createState() => _BozorchiScreenState();
}

class _BozorchiScreenState extends ConsumerState<BozorchiScreen> {
  List<AggItem> _items = [];
  int _positions = 0;
  int _bought = 0;
  double _total = 0;
  bool _loading = true;
  String? _error;
  String _q = '';
  _Filter _filter = _Filter.todo;
  final Set<String> _saving = {};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // Menejerlar zakazni to'g'rilab turishi mumkin — 20 s da yangilanadi.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final date = ref.read(marketDateProvider);
    try {
      final res = await ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/aggregate',
        query: {'date': date},
      );
      if (!mounted) return;
      final sm = (res.data?['summary'] as Map?) ?? const {};
      setState(() {
        _items = ((res.data?['items'] as List?) ?? const [])
            .map((e) => AggItem((e as Map).cast<String, dynamic>()))
            .toList();
        _positions = ((sm['positions'] ?? _items.length) as num).toInt();
        _bought = ((sm['bought'] ?? 0) as num).toInt();
        _total = ((sm['total'] ?? 0) as num).toDouble();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Internet yo\'q — ro\'yxat yangilanmadi';
      });
    }
  }

  Future<void> _buy(AggItem it) async {
    final res = await showModalBottomSheet<(double, double)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceSheet(item: it),
    );
    if (res == null || !mounted) return;
    final (price, qty) = res;
    setState(() => _saving.add(it.name));
    try {
      await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/buy',
        data: {
          'date': ref.read(marketDateProvider),
          'items': [
            {'name': it.name, 'unit': it.unit, 'qty': qty, 'price': price}
          ],
        },
      );
      if (!mounted) return;
      _toast('${it.name} — olindi · ${money(price * qty)} so\'m');
      await _load(quiet: true);
    } catch (_) {
      if (!mounted) return;
      _toast('Yuborilmadi — internetni tekshiring', bad: true);
    } finally {
      if (mounted) setState(() => _saving.remove(it.name));
    }
  }

  void _toast(String text, {bool bad = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      backgroundColor: bad ? PosColors.red : PosColors.green,
      content: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(marketDateProvider);
    final q = _q.trim().toLowerCase();
    final visible = _items.where((it) {
      if (q.isNotEmpty && !it.name.toLowerCase().contains(q)) return false;
      switch (_filter) {
        case _Filter.todo:
          return !it.bought;
        case _Filter.done:
          return it.bought;
        case _Filter.all:
          return true;
      }
    }).toList();
    final todoN = _items.where((i) => !i.bought).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DayBar(
            date: date,
            onShift: (d) {
              ref.read(marketDateProvider.notifier).state = shiftDay(date, d);
              _load();
            },
            onRefresh: _load,
          ),
          const SizedBox(height: 10),
          // ── Jami: nechta olish kerak, nechtasi olindi, qancha ketdi ──
          _Summary(todo: todoN, bought: _bought, total: _total),
          const SizedBox(height: 10),
          Row(children: [
            _Chip(
              label: 'Olinmagan',
              n: todoN,
              on: _filter == _Filter.todo,
              color: PosColors.blue,
              onTap: () => setState(() => _filter = _Filter.todo),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Olingan',
              n: _bought,
              on: _filter == _Filter.done,
              color: PosColors.green,
              onTap: () => setState(() => _filter = _Filter.done),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Hammasi',
              n: _positions,
              on: _filter == _Filter.all,
              color: PosColors.label,
              onTap: () => setState(() => _filter = _Filter.all),
            ),
          ]),
          const SizedBox(height: 10),
          SearchField(
            hint: 'Mahsulot qidirish…',
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                    ? const EmptyHint(
                        icon: Icons.wifi_off,
                        title: 'Internet yo\'q',
                        note: 'Aloqani tekshirib «yangilash»ni bosing.')
                    : _items.isEmpty
                        ? const EmptyHint(
                            icon: Icons.shopping_basket_outlined,
                            title: 'Bu kunga zakaz yo\'q',
                            note: 'Filial menejerlari zakaz yuborgach shu yerda chiqadi.')
                        : visible.isEmpty
                            ? EmptyHint(
                                icon: Icons.task_alt,
                                title: _filter == _Filter.todo
                                    ? 'Hammasi olindi 🎉'
                                    : 'Topilmadi',
                                note: _filter == _Filter.todo
                                    ? 'Bugungi bozor tugadi — jami ${money(_total)} so\'m.'
                                    : 'Qidiruvni o\'zgartiring.')
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: visible.length,
                                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                                  itemBuilder: (c, i) => _ItemCard(
                                    item: visible[i],
                                    saving: _saving.contains(visible[i].name),
                                    onBuy: () => _buy(visible[i]),
                                  ),
                                ),
                              ),
          ),
          if (_error != null && _items.isNotEmpty) ...[
            const SizedBox(height: 8),
            MsgLine(text: _error!, error: true),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.todo, required this.bought, required this.total});
  final int todo;
  final int bought;
  final double total;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, String value, Color color) => Expanded(
          child: Column(children: [
            Text(value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: PosColors.label, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: PosColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosColors.cardBorder),
      ),
      child: Row(children: [
        cell('Olish kerak', '$todo', todo == 0 ? PosColors.green : Colors.white),
        cell('Olindi', '$bought', PosColors.green),
        cell('Xarajat', '${money(total)} so\'m', Colors.white),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.n, required this.on, required this.color, required this.onTap});
  final String label;
  final int n;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: 0.18) : PosColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? color : PosColors.cardBorder, width: on ? 1.5 : 1),
          ),
          child: Text('$label · $n',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: on ? Colors.white : PosColors.label)),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.saving, required this.onBuy});
  final AggItem item;
  final bool saving;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final it = item;
    final branches = it.branches;
    return Material(
      color: it.bought ? PosColors.green.withValues(alpha: 0.10) : PosColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: saving ? null : onBuy,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: it.bought ? PosColors.green.withValues(alpha: 0.5) : PosColors.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(it.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Text('${fmtQty(it.boughtQty ?? it.totalQty)} ${unitUz(it.unit)}',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: it.bought ? PosColors.green : Colors.white)),
                    ]),
                    const SizedBox(height: 6),
                    // Qaysi filialga qancha — bozorchi bo'lib berishni biladi
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: branches
                          .map((b) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: PosColors.iconChip,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${_short(b.$1)} ${fmtQty(b.$2)}',
                                    style: const TextStyle(color: PosColors.label, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ))
                          .toList(),
                    ),
                    if (it.bought) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${money(it.price!)} so\'m × ${fmtQty(it.boughtQty ?? it.totalQty)} = ${money(it.boughtTotal ?? it.price! * (it.boughtQty ?? it.totalQty))} so\'m',
                        style: const TextStyle(color: PosColors.green, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              saving
                  ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : it.bought
                      ? const Icon(Icons.check_circle, color: PosColors.green, size: 34)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: PosColors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Narx',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  /// «DIET BISTRO — Chilonzor» → «Chilonzor» (chip'da joy tor).
  static String _short(String name) {
    final i = name.lastIndexOf('—');
    return (i >= 0 ? name.substring(i + 1) : name).trim();
  }
}

/// Narx kiritish — KATTA raqam paneli (planshetda barmoq bilan).
class _PriceSheet extends StatefulWidget {
  const _PriceSheet({required this.item});
  final AggItem item;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  String _price = '';
  late String _qty = fmtQty(widget.item.boughtQty ?? widget.item.totalQty).replaceAll(' ', '');
  bool _editQty = false;

  double get _p => double.tryParse(_price) ?? 0;
  double get _qv => double.tryParse(_qty.replaceAll(',', '.')) ?? widget.item.totalQty;

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      var s = _editQty ? _qty : _price;
      if (k == '⌫') {
        s = s.isEmpty ? s : s.substring(0, s.length - 1);
      } else if (k == '.') {
        if (_editQty && !s.contains('.')) s = s.isEmpty ? '0.' : '$s.';
      } else if (k == '000') {
        if (s.isNotEmpty && s.length < 9) s = '${s}000';
      } else if (s.length < 9) {
        s = (s == '0') ? k : '$s$k';
      }
      if (_editQty) {
        _qty = s;
      } else {
        _price = s;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final keys = _editQty
        ? ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫']
        : ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', '⌫'];
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: PosColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PosColors.cardBorder),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(it.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              it.branches.map((b) => '${_ItemCard._short(b.$1)} ${fmtQty(b.$2)}').join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: PosColors.label, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _Field(
                  label: 'Narxi (1 ${unitUz(it.unit)})',
                  value: _price.isEmpty ? '0' : money(_p),
                  suffix: 'so\'m',
                  active: !_editQty,
                  onTap: () => setState(() => _editQty = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'Miqdor',
                  value: _qty.isEmpty ? '0' : _qty,
                  suffix: unitUz(it.unit),
                  active: _editQty,
                  onTap: () => setState(() => _editQty = true),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text('Jami: ${money(_p * _qv)} so\'m',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: PosColors.green)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: keys
                  .map((k) => Material(
                        color: k == '⌫' ? PosColors.iconChip : PosColors.card,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _key(k),
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: k == '⌫'
                                ? const Icon(Icons.backspace_outlined, size: 24)
                                : Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
                  child: const Text('Bekor', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _p > 0 && _qv > 0 ? () => Navigator.of(context).pop((_p, _qv)) : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: PosColors.green, minimumSize: const Size(0, 54)),
                  child: const Text('✓ Olindi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.suffix, required this.active, required this.onTap});
  final String label;
  final String value;
  final String suffix;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PosColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? PosColors.blue : PosColors.cardBorder, width: active ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: PosColors.label, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$value $suffix',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
