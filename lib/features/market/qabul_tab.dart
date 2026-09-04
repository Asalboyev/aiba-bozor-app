// QABUL — filial menejeri bozordan kelgan mahsulotni tekshirib «Qabul
// qildim» bosadi → omborga AVTO-KIRIM (narx bozorchi kiritgani; kirim
// izohida bozorchi nomi + olingan vaqt turadi).
//
// Ro'yxat 3 guruh: QABUL QILINADIGAN (bozorchi olib kelgan) → BOZORCHI HALI
// OLMADI → QABUL QILINGANLAR (bugungi tarix). Telefon va planshetda bir xil
// o'qiladi: pul/miqdor alohida qatorda, ustma-ust tushmaydi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/pos_chrome.dart';
import 'market_screen.dart' show marketDateProvider;
import 'ui_bits.dart';

class _Line {
  _Line(this.j);
  final Map<String, dynamic> j;
  String get id => (j['id'] ?? '') as String;
  String get name => (j['name'] ?? '') as String;
  String get unit => (j['unit'] ?? 'kg') as String;
  double get qty => ((j['qty'] ?? 0) as num).toDouble();
  double? get price => (j['price'] as num?)?.toDouble();
  double? get total => (j['total'] as num?)?.toDouble();
  String get status => (j['status'] ?? 'pending') as String;
  double? get acceptedQty => (j['accepted_qty'] as num?)?.toDouble();
  String? get buyer => j['buyer'] as String?;
  String? get acceptedAt => j['accepted_at'] as String?;
}

class QabulTab extends ConsumerStatefulWidget {
  const QabulTab({super.key});

  @override
  ConsumerState<QabulTab> createState() => _QabulTabState();
}

class _QabulTabState extends ConsumerState<QabulTab> {
  List<_Line> _lines = [];
  final Set<String> _sel = {};
  bool _loading = false;
  bool _accepting = false;
  String? _msg;
  bool _err = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final date = ref.read(marketDateProvider);
    try {
      final res = await ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/my',
        query: {'date': date},
      );
      if (!mounted) return;
      setState(() {
        _lines = ((res.data?['lines'] as List?) ?? const [])
            .map((l) => _Line((l as Map).cast<String, dynamic>()))
            .toList();
        _sel.clear();
        _loading = false;
        _msg = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _msg = 'Yuklab bo\'lmadi — internetni tekshiring';
        _err = true;
      });
    }
  }

  Future<void> _accept() async {
    final date = ref.read(marketDateProvider);
    final lines = [
      for (final id in _sel) {'line_id': id},
    ];
    if (lines.isEmpty) return;
    setState(() => _accepting = true);
    try {
      await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/api/v2/pos-terminal/market/accept',
        data: {'date': date, 'lines': lines},
      );
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _msg = '${lines.length} pozitsiya qabul qilindi — omborga kirim bo\'ldi';
        _err = false;
      });
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _msg = 'Qabul bo\'lmadi — qayta urinib ko\'ring';
        _err = true;
      });
    }
  }

  void _toggle(String id) => setState(() {
        _sel.contains(id) ? _sel.remove(id) : _sel.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(marketDateProvider);
    final ready = _lines.where((l) => l.status == 'bought').toList();
    final allSelected = ready.isNotEmpty && _sel.length == ready.length;
    // Belgilanganlar summasi — menejer nechchi pullik mol qabul qilayotganini
    // tugmani bosishdan oldin ko'radi.
    final selSum = _lines
        .where((l) => _sel.contains(l.id))
        .fold<double>(0, (s, l) => s + (l.total ?? 0));

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
            trailing: ready.isEmpty
                ? null
                : TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: PosColors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => setState(() {
                      _sel.clear();
                      if (!allSelected) _sel.addAll(ready.map((l) => l.id));
                    }),
                    icon: Icon(
                        allSelected
                            ? Icons.remove_done
                            : Icons.done_all,
                        size: 18),
                    label: Text(allSelected ? 'Bekor' : 'Hammasi'),
                  ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading && _lines.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _lines.isEmpty
                    ? const EmptyHint(
                        icon: Icons.inbox_outlined,
                        title: 'Bu kunga zakaz yo\'q',
                        note: 'Zakaz bo\'limida ro\'yxat yuboring — bozorchi '
                            'olib kelgach shu yerda chiqadi.')
                    : _buildGroups(),
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
                backgroundColor: PosColors.green,
                disabledBackgroundColor: const Color(0xFF23262B),
                disabledForegroundColor: PosColors.muted,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sel.isEmpty || _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _sel.isEmpty
                                ? 'Qabul qildim'
                                : 'Qabul qildim · ${_sel.length} ta'
                                    '${selSum > 0 ? ' · ${money(selSum)} so\'m' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroups() {
    final groups = <(String, Color, List<_Line>)>[
      (
        'Qabul qilinadigan',
        PosColors.green,
        _lines.where((l) => l.status == 'bought').toList()
      ),
      (
        'Bozorchi hali olmadi',
        PosColors.muted,
        _lines.where((l) => l.status == 'pending').toList()
      ),
      (
        'Qabul qilinganlar',
        PosColors.blue,
        _lines.where((l) => l.status == 'accepted').toList()
      ),
    ];
    final children = <Widget>[];
    for (final (title, color, list) in groups) {
      if (list.isEmpty) continue;
      children.add(GroupHeader(title: title, count: list.length, color: color));
      for (final l in list) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _LineCard(
            line: l,
            selected: _sel.contains(l.id),
            onTap: l.status == 'bought' ? () => _toggle(l.id) : null,
          ),
        ));
      }
    }
    return ListView(padding: EdgeInsets.zero, children: children);
  }
}

/// Bitta pozitsiya kartochkasi. Miqdor va pul ALOHIDA qatorda — telefonda
/// ham nom bilan ustma-ust tushmaydi.
class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.selected,
    required this.onTap,
  });

  final _Line line;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accepted = line.status == 'accepted';
    final bought = line.status == 'bought';
    final border = selected
        ? PosColors.blue
        : accepted
            ? PosColors.green.withValues(alpha: .35)
            : PosColors.cardBorder;

    final leading = bought
        ? Icon(selected ? Icons.check_box : Icons.check_box_outline_blank,
            color: selected ? PosColors.blue : PosColors.muted, size: 26)
        : accepted
            ? const Icon(Icons.check_circle, color: PosColors.green, size: 26)
            : const Icon(Icons.schedule, color: PosColors.muted, size: 24);

    final sub = accepted
        ? 'Qabul qilindi: ${fmtQty(line.acceptedQty ?? line.qty)} ${unitUz(line.unit)}'
            '${line.acceptedAt != null ? ' · ${prettyStamp(line.acceptedAt!)}' : ''}'
        : bought
            ? 'Bozorchi olib keldi · ${line.buyer ?? 'bozorchi'}'
            : 'Bozorchi hali olmadi';

    return Material(
      color: selected
          ? const Color(0xFF16233A)
          : accepted
              ? const Color(0xFF12211A)
              : PosColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.only(top: 1), child: leading),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(line.name,
                              style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25)),
                        ),
                        const SizedBox(width: 10),
                        Text('${fmtQty(line.qty)} ${unitUz(line.unit)}',
                            style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                height: 1.25)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Izoh va pul: keng ekranda bir qatorda, telefonda pul
                    // pastga tushadi — matnlar ustma-ust sinmaydi.
                    LayoutBuilder(builder: (context, c) {
                      final subText = Text(sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: accepted
                                  ? PosColors.green
                                  : PosColors.muted,
                              fontSize: 12.5));
                      if (line.price == null) return subText;
                      final priceText = Text(
                        '${money(line.price!)} so\'m · jami '
                        '${money(line.total ?? 0)}',
                        style: const TextStyle(
                            color: PosColors.label,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      );
                      if (c.maxWidth < 420) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            subText,
                            const SizedBox(height: 3),
                            priceText,
                          ],
                        );
                      }
                      return Row(children: [
                        Expanded(child: subText),
                        const SizedBox(width: 10),
                        priceText,
                      ]);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
