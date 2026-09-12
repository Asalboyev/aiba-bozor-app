// NARX TARIXI — bitta mahsulot bozordan/firmadan QANCHAGA kelgani.
// Tepada: ombor qoldig'i + o'rtacha tannarx, oxirgi narx (o'zgarish % bilan),
// eng past / eng yuqori / o'rtacha. Pastda: xaridlar ro'yxati (yangisi tepada),
// har qatorda oldingisiga nisbatan ▲/▼. Oq/qora tema, tor telefonda toshmaydi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'i18n.dart';
import 'models.dart';
import 'repo.dart';
import 'widgets.dart';

class PriceHistoryScreen extends ConsumerStatefulWidget {
  const PriceHistoryScreen({super.key, required this.name});
  final String name;
  @override
  ConsumerState<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  PriceHistory? _h;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _h = null;
    });
    try {
      final h = await ref.read(bozorkomRepoProvider).priceHistory(widget.name);
      if (mounted) setState(() => _h = h);
    } catch (e) {
      if (mounted) setState(() => _error = BozorkomRepo.errText(e, ref.read(trProvider)('errNet')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final pad = hPad(context);
    final narrow = isNarrow(context);
    final h = _h;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: BarTitle(h?.name ?? widget.name, style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [IconButton(tooltip: tr('refresh'), icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: ContentWrap(
        child: _error != null
            ? EmptyState(icon: Icons.cloud_off_rounded, title: _error!)
            : h == null
                ? Center(child: CircularProgressIndicator(color: c.blue))
                : ListView(
                    padding: EdgeInsets.symmetric(horizontal: pad, vertical: 10),
                    children: [
                      Text(tr('priceHistory'), style: TextStyle(color: c.text, fontSize: narrow ? 20 : 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(tr('priceHistoryHint'), style: TextStyle(color: c.muted, fontSize: 13)),
                      const SizedBox(height: 14),
                      _Summary(h: h, tr: tr),
                      const SizedBox(height: 16),
                      if (h.items.isEmpty)
                        AibaCard(child: SizedBox(height: 140, child: EmptyState(icon: Icons.history_rounded, title: tr('noHistory'))))
                      else
                        AibaCard(padding: EdgeInsets.zero, child: _List(items: h.items, tr: tr)),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }
}

/// Yuqori blok: ombor (chap) va oxirgi narx (o'ng) — ikki narx yonma-yon,
/// pastda eng past / eng yuqori / o'rtacha / xaridlar soni.
class _Summary extends StatelessWidget {
  const _Summary({required this.h, required this.tr});
  final PriceHistory h;
  final Tr tr;

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final narrow = isNarrow(context);
    final unit = unitLabel(h.stockUnit ?? 'kg', tr);
    final avgCost = h.avgCost ?? 0;
    final last = h.last;
    // Oxirgi narx omborga nisbatan: yashil — arzonroq, qizil — qimmatroq.
    final delta = (last != null && avgCost > 0) ? (last - avgCost) / avgCost * 100 : null;
    final deltaColor = delta == null ? c.muted : (delta.abs() < 0.5 ? c.muted : (delta < 0 ? c.green : c.red));
    final deltaText = delta == null
        ? ''
        : delta.abs() < 0.5
            ? tr('same')
            : '${delta > 0 ? '+' : '−'}${delta.abs().toStringAsFixed(delta.abs() >= 10 ? 0 : 1)}% ${delta < 0 ? tr('cheaper') : tr('dearer')}';

    Widget box(String label, String value, {Color? color, String? sub, Color? subColor}) => Container(
          padding: EdgeInsets.all(narrow ? 12 : 14),
          decoration: BoxDecoration(color: c.field, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: c.label, fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            FitText(value, style: TextStyle(color: color ?? c.text, fontSize: narrow ? 20 : 24, fontWeight: FontWeight.w800)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              FitText(sub, style: TextStyle(color: subColor ?? c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ]),
        );

    final stockBox = box(
      tr('inStock'),
      avgCost > 0 ? '${fmtSum(avgCost)} ${tr('cur')}' : '—',
      sub: h.stockQty == null ? null : '${tr('stockNow')}: ${fmtQty(h.stockQty!)} $unit',
    );
    final lastBox = box(
      tr('lastBought'),
      last != null ? '${fmtSum(last)} ${tr('cur')}' : tr('neverBought'),
      color: last == null ? c.muted : c.blue,
      sub: last == null ? null : (deltaText.isEmpty ? null : '$deltaText ${tr('vsStock')}'),
      subColor: deltaColor,
    );

    Widget chip(String k, double? v) => Expanded(
          child: Column(children: [
            Text(k, style: TextStyle(color: c.label, fontSize: 12)),
            const SizedBox(height: 2),
            FitText(v == null ? '—' : fmtSum(v), style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        );

    return AibaCard(
      color: c.panel,
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [Expanded(child: stockBox), const SizedBox(width: 10), Expanded(child: lastBox)]),
        const SizedBox(height: 12),
        Row(children: [
          chip(tr('minPrice'), h.min),
          chip(tr('avgPrice'), h.avg),
          chip(tr('maxPrice'), h.max),
          Expanded(
            child: Column(children: [
              Text(tr('prevPrice'), style: TextStyle(color: c.label, fontSize: 12)),
              const SizedBox(height: 2),
              FitText(h.prev == null ? '—' : fmtSum(h.prev!), style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Pill(label: tr('buys', {'n': '${h.count}'}), color: c.blue, small: true, icon: Icons.receipt_long_rounded),
        ),
      ]),
    );
  }
}

/// Xaridlar ro'yxati — yangisi tepada; har qatorda oldingisiga nisbatan ▲/▼.
class _List extends StatelessWidget {
  const _List({required this.items, required this.tr});
  final List<PriceEntry> items;
  final Tr tr;

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final narrow = isNarrow(context);
    return Column(children: [
      for (var i = 0; i < items.length; i++) ...[
        Builder(builder: (_) {
          final e = items[i];
          final prev = i + 1 < items.length ? items[i + 1].price : null;
          final d = (prev != null && prev > 0) ? (e.price - prev) / prev * 100 : null;
          final up = d != null && d > 0.5;
          final down = d != null && d < -0.5;
          // Miqdor BIRINCHI — tor ekranda qisqarsa ham «50 kg» ko'rinib qoladi.
          final who = [
            '${fmtQty(e.qty)} ${unitLabel(e.unit, tr)}',
            if (e.supplier.isNotEmpty) e.supplier else if (e.source == 'firma') tr('supplier') else tr('market'),
            if (e.actor.isNotEmpty) e.actor,
          ].join(' • ');
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: (up ? c.red : down ? c.green : c.blue).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  up ? Icons.arrow_upward_rounded : down ? Icons.arrow_downward_rounded : Icons.remove_rounded,
                  size: 20, color: up ? c.red : down ? c.green : c.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(prettyDate(e.date), style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
                ]),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${fmtSum(e.price)} ${tr('cur')}', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  d == null ? fmtSum(e.total) : '${d > 0 ? '+' : ''}${d.toStringAsFixed(d.abs() >= 10 ? 0 : 1)}%  •  ${fmtSum(e.total)}',
                  style: TextStyle(color: up ? c.red : down ? c.green : c.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ]),
            ]),
          );
        }),
        if (i < items.length - 1) Divider(height: 1, color: c.border),
      ],
    ]);
  }
}
