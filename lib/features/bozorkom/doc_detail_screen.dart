// HUJJATNI KO'RISH — sarlavha kartasi + jadval + Jami. Tugmalar rolga qarab:
// Bozorkom → «Tahrirlash» aktiv; filial menejeri → «Qabul qilish» aktiv.
// Oq/qora tema; tor telefonda jadval ustunlari ixcham.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final session = ref.watch(sessionProvider);
    final market = session?.staff.role == 'market';
    final wide = isWide(context);
    final pad = hPad(context);
    final d = _doc ?? widget.doc;
    final invoice = d.kind == DocKind.invoice;
    final accepted = d.isAccepted;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: FitText(tr('docForm'), style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w400)),
        actions: [IconButton(tooltip: tr('refresh'), icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: Column(children: [
        Expanded(
          child: _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: _error!)
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                  children: [
                    AibaCard(
                      accent: accepted ? c.green : (invoice ? c.blue : c.amber),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.numberLabel, style: TextStyle(color: c.text, fontSize: 26, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text('${prettyDate(d.date)}${(d.createdBy ?? '').isNotEmpty ? ' • ${d.createdBy}' : ''}',
                                  style: TextStyle(color: c.muted, fontSize: 13)),
                            ]),
                          ),
                          Pill(label: invoice ? tr('invoice') : tr('preorder'), color: invoice ? c.blue : c.amber),
                        ]),
                        const SizedBox(height: 12),
                        Text('${tr('supplier')}: ${tr('market')}', style: TextStyle(color: c.label, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('${tr('recipient')}: ${d.branch.name}',
                            style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Pill(
                            label: accepted ? tr('yes') : tr('no'),
                            color: accepted ? c.green : c.orange,
                            icon: accepted ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                          ),
                          const Spacer(),
                          Text(tr('market'), style: TextStyle(color: c.muted, fontSize: 13)),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Text(tr('orderList'), style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (_doc == null)
                      Padding(padding: const EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: c.blue)))
                    else if (d.lines.isEmpty)
                      AibaCard(child: SizedBox(height: 120, child: EmptyState(icon: Icons.list_alt_rounded, title: tr('empty'))))
                    else
                      AibaCard(padding: EdgeInsets.zero, child: _Table(lines: d.lines, showPrice: invoice, tr: tr, wide: wide)),
                    const SizedBox(height: 14),
                    if (invoice)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          Text(tr('total'), style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FitText('${fmtSum(d.sum)} ${tr('cur')}',
                                align: Alignment.centerRight,
                                style: TextStyle(color: c.text, fontSize: 24, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 90),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
            child: Row(children: [
              Expanded(
                child: GhostBtn(
                  label: tr('edit'),
                  icon: Icons.edit_rounded,
                  enabled: market && !accepted && _doc != null,
                  onTap: () async {
                    final ok = await Navigator.of(context)
                        .push<bool>(MaterialPageRoute(builder: (_) => DocEditorScreen(date: d.date, existing: d)));
                    if (ok == true) _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryBtn(
                  label: _busy ? tr('accepting') : tr('accept'),
                  icon: Icons.task_alt_rounded,
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
    final c = bz(context);
    final d = _doc;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('accept'), style: TextStyle(color: c.text)),
        content: Text(tr('confirmAccept'), style: TextStyle(color: c.label, fontSize: 15)),
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

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final narrow = isNarrow(context);
    final hdr = TextStyle(color: c.label, fontSize: 13, fontWeight: FontWeight.w700);
    final cell = TextStyle(color: c.text, fontSize: narrow ? 13.5 : 14);
    final bold = TextStyle(color: c.text, fontSize: narrow ? 13.5 : 14, fontWeight: FontWeight.w700);
    final wNum = wide ? 30.0 : 24.0;
    final wQty = wide ? 90.0 : (narrow ? 46.0 : 52.0);
    final wPrice = wide ? 110.0 : (narrow ? 62.0 : 68.0);
    final wTotal = wide ? 120.0 : (narrow ? 76.0 : 82.0);
    final hp = narrow ? 10.0 : 14.0;

    return Column(children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: hp, vertical: 12),
        decoration: BoxDecoration(color: c.panel, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Row(children: [
          SizedBox(width: wNum, child: Text(tr('num'), style: hdr)),
          Expanded(child: Text(tr('foods'), style: hdr)),
          SizedBox(width: wQty, child: Text(tr('qty'), textAlign: TextAlign.right, style: hdr)),
          if (showPrice) ...[
            SizedBox(width: wPrice, child: Text(tr('price'), textAlign: TextAlign.right, style: hdr)),
            SizedBox(width: wTotal, child: Text(tr('total'), textAlign: TextAlign.right, style: hdr)),
          ],
        ]),
      ),
      for (var i = 0; i < lines.length; i++) ...[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hp, vertical: 13),
          child: Row(children: [
            SizedBox(width: wNum, child: Text('${i + 1}', style: cell)),
            Expanded(
              child: Row(children: [
                Flexible(child: Text(lines[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: cell)),
                if (lines[i].isAccepted) ...[const SizedBox(width: 6), Icon(Icons.check_circle_rounded, size: 15, color: c.green)],
              ]),
            ),
            SizedBox(width: wQty, child: Text(fmtQty(lines[i].acceptedQty ?? lines[i].qty), textAlign: TextAlign.right, style: cell)),
            if (showPrice) ...[
              SizedBox(width: wPrice, child: Text(lines[i].price == null ? '—' : fmtSum(lines[i].price!), textAlign: TextAlign.right, style: cell)),
              SizedBox(width: wTotal, child: Text(lines[i].price == null ? '—' : fmtSum(lines[i].total), textAlign: TextAlign.right, style: bold)),
            ],
          ]),
        ),
        if (i < lines.length - 1) Divider(height: 1, color: c.border),
      ],
    ]);
  }
}
