// TARIX — menejer o'tgan kunlardagi zakazlarini ko'radi: qaysi kuni nechta
// pozitsiya so'ralgan, nechtasi olingan/qabul qilingan va jami qancha pulga.
// Kunni bossa — o'sha kunning to'liq ro'yxati (nom, miqdor, narx, holat).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/pos_chrome.dart';
import 'ui_bits.dart';

class _Day {
  _Day(this.j);
  final Map<String, dynamic> j;
  String get date => (j['date'] ?? '') as String;
  int get lines => ((j['lines'] ?? 0) as num).toInt();
  int get accepted => ((j['accepted'] ?? 0) as num).toInt();
  int get bought => ((j['bought'] ?? 0) as num).toInt();
  int get pending => ((j['pending'] ?? 0) as num).toInt();
  double get total => ((j['total'] ?? 0) as num).toDouble();
  String? get by => j['created_by'] as String?;
}

class TarixTab extends ConsumerStatefulWidget {
  const TarixTab({super.key});

  @override
  ConsumerState<TarixTab> createState() => _TarixTabState();
}

class _TarixTabState extends ConsumerState<TarixTab> {
  List<_Day> _days = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/history',
        query: {'limit': 60},
      );
      if (!mounted) return;
      setState(() {
        _days = ((res.data?['items'] as List?) ?? const [])
            .map((d) => _Day((d as Map).cast<String, dynamic>()))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Internet yo\'q — tarixni yuklab bo\'lmadi';
      });
    }
  }

  Future<void> _open(_Day d) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _DayDetail(date: d.date),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final spent = _days.fold<double>(0, (s, d) => s + d.total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: PosColors.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PosColors.cardBorder),
            ),
            child: Row(children: [
              const Icon(Icons.history, size: 20, color: PosColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Oxirgi ${_days.length} kun',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Text('${money(spent)} so\'m',
                  style: const TextStyle(
                      color: PosColors.green,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              IconButton(
                  onPressed: _load,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh, size: 20)),
            ]),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading && _days.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _days.isEmpty
                    ? EmptyHint(
                        icon: Icons.wifi_off,
                        title: 'Internet yo\'q',
                        note: 'Bozor ilovasi faqat onlayn ishlaydi.')
                    : _days.isEmpty
                        ? const EmptyHint(
                            icon: Icons.history,
                            title: 'Tarix bo\'sh',
                            note: 'Yuborilgan zakazlar shu yerda saqlanadi.')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: _days.length,
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (c, i) =>
                                  _DayCard(day: _days[i], onTap: () => _open(_days[i])),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onTap});
  final _Day day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final full = day.pending == 0 && day.bought == 0;
    final word = dayWord(day.date);
    return Material(
      color: PosColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosColors.cardBorder),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(prettyDay(day.date),
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w800)),
                    if (word.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: PosColors.iconChip,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(word,
                            style: const TextStyle(
                                color: PosColors.label,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 5),
                  Text(
                    '${day.lines} pozitsiya · qabul qilindi ${day.accepted}'
                    '${day.pending > 0 ? ' · olinmagan ${day.pending}' : ''}',
                    style: TextStyle(
                        color: full ? PosColors.green : PosColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text('${money(day.total)} so\'m',
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800)),
            const Icon(Icons.chevron_right, color: PosColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// Bir kunning to'liq ro'yxati (faqat ko'rish).
class _DayDetail extends ConsumerStatefulWidget {
  const _DayDetail({required this.date});
  final String date;

  @override
  ConsumerState<_DayDetail> createState() => _DayDetailState();
}

class _DayDetailState extends ConsumerState<_DayDetail> {
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/my',
        query: {'date': widget.date},
      );
      if (!mounted) return;
      setState(() {
        _lines = ((res.data?['lines'] as List?) ?? const [])
            .map((l) => (l as Map).cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _statusUz(String s) => switch (s) {
        'accepted' => 'Qabul qilindi',
        'bought' => 'Bozorchi oldi',
        _ => 'Olinmadi',
      };

  Color _statusColor(String s) => switch (s) {
        'accepted' => PosColors.green,
        'bought' => PosColors.blue,
        _ => PosColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<double>(
        0,
        (s, l) =>
            s +
            (((l['price'] ?? 0) as num).toDouble()) *
                (((l['accepted_qty'] ?? l['qty'] ?? 0) as num).toDouble()));
    return Scaffold(
      backgroundColor: PosColors.bg,
      appBar: AppBar(
        backgroundColor: PosColors.panel,
        title: Text(prettyDay(widget.date),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty
              ? const EmptyHint(icon: Icons.inbox_outlined, title: 'Zakaz yo\'q')
              : Column(children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _lines.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final l = _lines[i];
                        final st = (l['status'] ?? 'pending') as String;
                        final price = (l['price'] as num?)?.toDouble();
                        final qty =
                            ((l['accepted_qty'] ?? l['qty'] ?? 0) as num)
                                .toDouble();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: PosColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PosColors.cardBorder),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${l['name']}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(_statusUz(st),
                                      style: TextStyle(
                                          color: _statusColor(st),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    '${fmtQty(qty)} ${unitUz((l['unit'] ?? 'kg') as String)}',
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800)),
                                if (price != null && price > 0)
                                  Text(
                                      '${money(price)} so\'m · '
                                      '${money(price * qty)}',
                                      style: const TextStyle(
                                          color: PosColors.label,
                                          fontSize: 12)),
                              ],
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    color: PosColors.panel,
                    child: Row(children: [
                      const Expanded(
                        child: Text('Jami',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      Text('${money(total)} so\'m',
                          style: const TextStyle(
                              color: PosColors.green,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
    );
  }
}
