// HUJJATNI KO'RISH — «Hisob-faktura shakli / oldindan buyurtma varag'i».
// Sarlavha kartasi + jadval (№, Ovqatlar, Miqdori, [Narxi, Jami]) + Jami.
// Tugmalar rolga qarab: Bozorkom → «Tahrirlash» aktiv, «Qabul qilish» yo'q;
// filial menejeri → «Qabul qilish» aktiv (omborga kirim), «Tahrirlash» yo'q.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/pos_chrome.dart';
import '../auth/presentation/providers/auth_providers.dart';
import 'doc_editor_screen.dart';
import 'i18n.dart';
import 'models.dart';
import 'repo.dart';
import 'widgets.dart';

class DocDetailScreen extends ConsumerStatefulWidget {
  const DocDetailScreen({super.key, required this.doc});
  final Doc doc;
  @override
  ConsumerState<DocDetailScreen> createState() => _DocDetailScreenState();
}

class _DocDetailScreenState extends ConsumerState<DocDetailScreen> {
  Doc? _doc;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await ref.read(bozorkomRepoProvider).detail(widget.doc);
      if (mounted) setState(() => _doc = d);
    } catch (e) {
      if (mounted) setState(() => _error = BozorkomRepo.errText(e, ref.read(trProvider)('errNet')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final session = ref.watch(sessionProvider);
    final market = session?.staff.role == 'market';
    final wide = isWide(context);
    final d = _doc ?? widget.doc;
    final invoice = d.kind == DocKind.invoice;
    final accepted = d.isAccepted;
    final showPrice = invoice;

    return Scaffold(
      backgroundColor: PosColors.bg,
      appBar: AppBar(
        backgroundColor: PosColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: Text(tr('docForm'),
            maxLines: 2,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.2)),
        actions: [
          IconButton(
              tooltip: tr('refresh'),
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: _error!)
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 14, vertical: 8),
                  children: [
                    // Sarlavha kartasi
                    AibaCard(
                      accent: accepted ? PosColors.green : (invoice ? PosColors.blue : const Color(0xFFD97706)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.numberLabel,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                '${prettyDate(d.date)}${(d.createdBy ?? '').isNotEmpty ? ' • ${d.createdBy}' : ''}',
                                style: const TextStyle(color: PosColors.muted, fontSize: 13),
                              ),
                            ]),
                          ),
                          Pill(
                            label: invoice ? tr('invoice') : tr('preorder'),
                            color: invoice ? PosColors.blue : const Color(0xFFD97706),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text('${tr('supplier')}: ${tr('market')}',
                            style: const TextStyle(color: PosColors.label, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('${tr('recipient')}: ${d.branch.name}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Pill(
                            label: accepted ? tr('yes') : tr('no'),
                            color: accepted ? PosColors.green : const Color(0xFFE8863A),
                            icon: accepted ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                          ),
                          const Spacer(),
                          Text(tr('market'), style: const TextStyle(color: PosColors.muted, fontSize: 13)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Text(tr('orderList'),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    // Jadval
                    if (_doc == null)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(color: PosColors.blue)),
                      )
                    else if (d.lines.isEmpty)
                      AibaCard(child: SizedBox(height: 120, child: EmptyState(icon: Icons.list_alt_rounded, title: tr('empty'))))
                    else
                      AibaCard(
                        padding: EdgeInsets.zero,
                        child: _Table(lines: d.lines, showPrice: showPrice, tr: tr, wide: wide),
                      ),
                    const SizedBox(height: 14),
                    if (showPrice)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                            color: PosColors.blue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          Text(tr('total'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text('${fmtSum(d.sum)} ${tr('cur')}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    const SizedBox(height: 90),
                  ],
                ),
        ),
        // Tugmalar — rolga qarab
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 12),
            child: Row(children: [
              Expanded(
                child: GhostBtn(
                  label: tr('edit'),
                  icon: Icons.edit_rounded,
                  enabled: market && !accepted && _doc != null,
                  onTap: () async {
                    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => DocEditorScreen(date: d.date, existing: d),
                    ));
                    if (ok == true) _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryBtn(
                  label: _busy ? tr('accepting') : tr('accept'),
                  icon: Icons.task_alt_rounded,
                  color: PosColors.blue,
                  busy: _busy,
                  enabled: !market && !accepted && _doc != null && d.lines.isNotEmpty,
                  onTap: _accept,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _accept() async {
    final tr = ref.read(trProvider);
    final d = _doc;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PosColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('accept'), style: const TextStyle(color: Colors.white)),
        content: Text(tr('confirmAccept'), style: const TextStyle(color: PosColors.label, fontSize: 15)),
        actions: [
          GhostBtn(label: tr('cancel'), height: 44, onTap: () => Navigator.of(ctx).pop(false)),
          PrimaryBtn(label: tr('accept'), height: 44, onTap: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(bozorkomRepoProvider).accept(d.date, d.lines);
      if (!mounted) return;
      toast(context, tr('acceptedOk'));
      await _load();
    } catch (e) {
      if (!mounted) return;
      toast(context, BozorkomRepo.errText(e, tr('errNet')), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.lines, required this.showPrice, required this.tr, required this.wide});
  final List<DocLine> lines;
  final bool showPrice;
  final Tr tr;
  final bool wide;

  static const _hdr = TextStyle(color: PosColors.label, fontSize: 13, fontWeight: FontWeight.w700);
  static const _cell = TextStyle(color: Colors.white, fontSize: 14);
  static const _bold = TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: PosColors.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          SizedBox(width: wide ? 30 : 26, child: Text(tr('num'), style: _hdr)),
          Expanded(child: Text(tr('foods'), style: _hdr)),
          SizedBox(width: wide ? 90 : 52, child: Text(tr('qty'), textAlign: TextAlign.right, style: _hdr)),
          if (showPrice) ...[
            SizedBox(width: wide ? 110 : 68, child: Text(tr('price'), textAlign: TextAlign.right, style: _hdr)),
            SizedBox(width: wide ? 120 : 82, child: Text(tr('total'), textAlign: TextAlign.right, style: _hdr)),
          ],
        ]),
      ),
      for (var i = 0; i < lines.length; i++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            SizedBox(width: wide ? 30 : 26, child: Text('${i + 1}', style: _cell)),
            Expanded(
              child: Row(children: [
                Flexible(child: Text(lines[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _cell)),
                if (lines[i].isAccepted) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle_rounded, size: 15, color: PosColors.green),
                ],
              ]),
            ),
            SizedBox(
                width: wide ? 90 : 52,
                child: Text(fmtQty(lines[i].acceptedQty ?? lines[i].qty),
                    textAlign: TextAlign.right, style: _cell)),
            if (showPrice) ...[
              SizedBox(
                  width: wide ? 110 : 68,
                  child: Text(lines[i].price == null ? '—' : fmtSum(lines[i].price!),
                      textAlign: TextAlign.right, style: _cell)),
              SizedBox(
                  width: wide ? 120 : 82,
                  child: Text(lines[i].price == null ? '—' : fmtSum(lines[i].total),
                      textAlign: TextAlign.right, style: _bold)),
            ],
          ]),
        ),
        if (i < lines.length - 1) const Divider(height: 1, color: PosColors.cardBorder),
      ],
    ]);
  }
}
