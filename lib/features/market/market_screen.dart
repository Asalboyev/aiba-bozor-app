// BOZORCHI EKRANI — FAQAT ONLAYN.
//
// Oqim (TZ): 6-7 filial menejeri kechqurun zakaz yuboradi → bozorchi ertalab
// ilovaga kiradi va AVVAL FILIALLAR RO'YXATINI ko'radi (har birida nechta
// pozitsiya bor) → filialni tanlaydi → FAQAT o'sha filialning ro'yxati
// ochiladi → har pozitsiyani olib «Oldim» bosadi (miqdor + narx).
//
// Nega filial bo'yicha: bitta jamlangan ro'yxatda 7 filialning mahsuloti
// aralashib ketardi — kimga qancha olganini bozorchi adashtirardi. Endi har
// filial alohida: olinganda faqat SHU filial qatori yopiladi.
//
// OFLAYN YO'Q: ro'yxat bir vaqtda bir necha odamda o'zgaradi (menejer zakazni
// tahrirlaydi, boshqa bozorchi oladi) — mahalliy nusxa bilan ishlash
// chalkashlikka olib keladi. Internet yo'q bo'lsa ekran shuni aniq aytadi.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/pos_chrome.dart';
import 'branch_market_screen.dart';
import 'ui_bits.dart';

// ── Model ────────────────────────────────────────────────────────────────────

String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final marketDateProvider = StateProvider<String>((ref) => isoDay(DateTime.now()));

class BranchRow {
  BranchRow(this.j);
  final Map<String, dynamic> j;
  String get id => (j['restaurant_id'] ?? '') as String;
  String get name => (j['name'] ?? '') as String;
  int get total => ((j['total'] ?? 0) as num).toInt();
  int get pending => ((j['pending'] ?? 0) as num).toInt();
  int get bought => ((j['bought'] ?? 0) as num).toInt();
  int get accepted => ((j['accepted'] ?? 0) as num).toInt();
  double get sum => ((j['sum'] ?? 0) as num).toDouble();
  bool get done => pending == 0;
}

class MarketLine {
  MarketLine(this.j);
  final Map<String, dynamic> j;
  String get id => (j['id'] ?? '') as String;
  String get name => (j['name'] ?? '') as String;
  String get unit => (j['unit'] ?? 'kg') as String;
  double get qty => ((j['qty'] ?? 0) as num).toDouble();
  double? get price => (j['price'] as num?)?.toDouble();
  String get status => (j['status'] ?? 'pending') as String;
  double? get hintPrice => (j['hint_price'] as num?)?.toDouble();
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}

// ── 1-EKRAN: FILIALLAR ───────────────────────────────────────────────────────

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  List<BranchRow> _rows = [];
  bool _loading = true;
  String? _error;
  int _pending = 0;
  double _sum = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // Menejer zakazni to'g'rilashi mumkin — ro'yxat o'zi yangilanib turadi.
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
        '/api/v2/pos-terminal/market/branches',
        query: {'date': date},
      );
      if (!mounted) return;
      setState(() {
        _rows = ((res.data?['branches'] as List?) ?? const [])
            .map((b) => BranchRow((b as Map).cast<String, dynamic>()))
            .toList();
        _pending = ((res.data?['total_pending'] ?? 0) as num).toInt();
        _sum = ((res.data?['total_sum'] ?? 0) as num).toDouble();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Internet yo\'q — ro\'yxatni yuklab bo\'lmadi';
      });
    }
  }

  Future<void> _openBranch(BranchRow b) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BranchMarketScreen(branchId: b.id, branchName: b.name),
    ));
    if (mounted) _load(quiet: true);
  }

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
              _load();
            },
            onRefresh: _load,
          ),
          const SizedBox(height: 10),
          if (_rows.isNotEmpty) _Summary(pending: _pending, sum: _sum),
          if (_rows.isNotEmpty) const SizedBox(height: 10),
          Expanded(
            child: _loading && _rows.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _rows.isEmpty
                    ? EmptyHint(
                        icon: Icons.wifi_off,
                        title: 'Internet yo\'q',
                        note: 'Bozor ilovasi faqat onlayn ishlaydi — '
                            'aloqani tekshirib «yangilash»ni bosing.')
                    : _rows.isEmpty
                        ? const EmptyHint(
                            icon: Icons.store_mall_directory_outlined,
                            title: 'Bu kunga zakaz yo\'q',
                            note: 'Filial menejerlari zakaz yuborgach shu '
                                'yerda chiqadi.')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: _rows.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (c, i) => _BranchCard(
                                row: _rows[i],
                                onTap: () => _openBranch(_rows[i]),
                              ),
                            ),
                          ),
          ),
          if (_error != null && _rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            MsgLine(text: _error!, error: true),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.pending, required this.sum});
  final int pending;
  final double sum;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: PosColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosColors.cardBorder),
      ),
      child: Row(children: [
        Icon(pending > 0 ? Icons.shopping_basket : Icons.check_circle,
            size: 20, color: pending > 0 ? PosColors.blue : PosColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            pending > 0 ? 'Olinishi kerak: $pending ta' : 'Hammasi olindi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text('${money(sum)} so\'m',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: PosColors.green,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// Filial kartochkasi — nom, qolgan/olingan soni va progress chizig'i.
class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.row, required this.onTap});
  final BranchRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final doneN = row.bought + row.accepted;
    final progress = row.total == 0 ? 0.0 : doneN / row.total;
    return Material(
      color: PosColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: row.done
                    ? PosColors.green.withValues(alpha: .35)
                    : PosColors.cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: row.done
                    ? PosColors.green.withValues(alpha: .15)
                    : PosColors.blue.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(row.done ? Icons.check : Icons.storefront,
                  color: row.done ? PosColors.green : PosColors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  // Chapda holat, o'ngda summa: matn qisqarsa ham summa
                  // butun ko'rinadi (bozorchiga eng kerakli raqam).
                  Row(children: [
                    Expanded(
                      child: Text(
                        row.done
                            ? '${row.total} pozitsiya · olindi'
                            : '${row.pending} ta olinmagan · jami ${row.total}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color:
                                row.done ? PosColors.green : PosColors.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (row.sum > 0) ...[
                      const SizedBox(width: 8),
                      Text('${money(row.sum)} so\'m',
                          style: const TextStyle(
                              color: PosColors.label,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: PosColors.iconChip,
                      valueColor: AlwaysStoppedAnimation(
                          row.done ? PosColors.green : PosColors.blue),
                    ),
                  ),
                ],
              ),
            ),
            // Qolgan pozitsiyalar soni — katta va ko'zga tashlanadigan.
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 42),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: row.done
                    ? PosColors.green.withValues(alpha: .16)
                    : PosColors.blue.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(row.done ? '✓' : '${row.pending}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: row.done ? PosColors.green : PosColors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
            const Icon(Icons.chevron_right, color: PosColors.muted),
          ]),
        ),
      ),
    );
  }
}
