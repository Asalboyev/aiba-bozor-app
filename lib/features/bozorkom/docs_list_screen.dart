// YUK XATLARI VA OLDINDAN BUYURTMALAR — asosiy ro'yxat.
// Sana + Filtr paneli + «Yangi yuk xati qo'shish» + kartalar.
// Telefon: bitta ustun; planshet: 2–3 ustun (Wrap). Oq/qora tema.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/providers/auth_providers.dart';
import 'doc_detail_screen.dart';
import 'doc_editor_screen.dart';
import 'i18n.dart';
import 'models.dart';
import 'repo.dart';
import 'widgets.dart';

enum _Acc { all, yes, no }
enum _Kind { all, invoice, preorder }

class DocsListBody extends ConsumerStatefulWidget {
  const DocsListBody({super.key});
  @override
  ConsumerState<DocsListBody> createState() => _DocsListBodyState();
}

class _DocsListBodyState extends ConsumerState<DocsListBody> {
  bool _filterOpen = false;
  String _recipient = '';
  _Acc _acc = _Acc.all;
  _Kind _kind = _Kind.all;

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final loc = ref.watch(localeProvider);
    final date = ref.watch(docDateProvider);
    final docs = ref.watch(docsProvider);
    final session = ref.watch(sessionProvider);
    final market = session?.staff.role == 'market';
    final own = BranchRef(
        id: session?.restaurant.id ?? '', name: session?.restaurant.name ?? '', code: session?.restaurant.code ?? '');
    final wide = isWide(context);
    final narrow = isNarrow(context);
    final pad = hPad(context);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <BranchRef>[];

    return RefreshIndicator(
      color: c.blue,
      onRefresh: () async => ref.refresh(docsProvider.future),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
            child: Text(tr('docs'),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text, fontSize: wide ? 26 : (narrow ? 20 : 22), fontWeight: FontWeight.w800, height: 1.15)),
          ),
          AibaCard(
            color: c.panel,
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: _PillBtn(
                    icon: Icons.calendar_today_rounded,
                    label: prettyDate(date),
                    onTap: () async {
                      final r = await pickIsoDate(context, tr, loc, date);
                      if (r != null) ref.read(docDateProvider.notifier).state = r;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PillBtn(
                    icon: Icons.tune_rounded,
                    label: _filterOpen ? tr('hide') : tr('filter'),
                    active: _filterOpen || _hasFilter,
                    onTap: () => setState(() => _filterOpen = !_filterOpen),
                  ),
                ),
              ]),
              if (_filterOpen) ...[const SizedBox(height: 12), _filters(tr, market, own, branches, wide)],
            ]),
          ),
          const SizedBox(height: 12),
          PrimaryBtn(
            label: tr('newDoc'),
            icon: Icons.add_rounded,
            height: 54,
            onTap: () async {
              final ok = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(builder: (_) => DocEditorScreen(date: date)));
              if (ok == true) ref.invalidate(docsProvider);
            },
          ),
          const SizedBox(height: 14),
          docs.when(
            loading: () => Padding(
                padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: c.blue))),
            error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: BozorkomRepo.errText(e, tr('errNet'))),
            data: (list) {
              final shown = _apply(list);
              if (shown.isEmpty) {
                return EmptyState(icon: Icons.inventory_2_outlined, title: tr('empty'), note: tr('emptyNote'));
              }
              final cards = [
                for (final d in shown)
                  _DocCard(
                    doc: d,
                    tr: tr,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocDetailScreen(doc: d)));
                      ref.invalidate(docsProvider);
                    },
                  ),
              ];
              if (wide) {
                final w = MediaQuery.sizeOf(context).width;
                final cols = w >= 1100 ? 3 : 2;
                const gap = 12.0;
                final colW = (w - pad * 2 - gap * (cols - 1)) / cols;
                return Wrap(spacing: gap, runSpacing: gap, children: [for (final k in cards) SizedBox(width: colW, child: k)]);
              }
              return Column(children: [for (final k in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: k)]);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool get _hasFilter => _recipient.isNotEmpty || _acc != _Acc.all || _kind != _Kind.all;

  List<Doc> _apply(List<Doc> list) => list.where((d) {
        if (_recipient.isNotEmpty && d.branch.id != _recipient) return false;
        if (_acc == _Acc.yes && !d.isAccepted) return false;
        if (_acc == _Acc.no && d.isAccepted) return false;
        if (_kind == _Kind.invoice && d.kind != DocKind.invoice) return false;
        if (_kind == _Kind.preorder && d.kind != DocKind.preorder) return false;
        return true;
      }).toList();

  Widget _filters(Tr tr, bool market, BranchRef own, List<BranchRef> branches, bool wide) {
    final recOpts = <MapEntry<String, String>>[
      MapEntry('', tr('all')),
      if (market) for (final b in branches) MapEntry(b.id, b.name) else MapEntry(own.id, own.name),
    ];
    final recipient = ChoicePill<String>(
      label: tr('recipient'),
      value: recOpts.any((e) => e.key == _recipient) ? _recipient : '',
      options: recOpts,
      onChanged: (v) => setState(() => _recipient = v),
    );
    final supplier = ChoicePill<int>(label: tr('supplier'), value: 1, options: [MapEntry(1, tr('market'))], onChanged: (_) {});
    final acc = ChoicePill<_Acc>(
      label: tr('accepted'),
      value: _acc,
      options: [MapEntry(_Acc.all, tr('all')), MapEntry(_Acc.yes, tr('accepted')), MapEntry(_Acc.no, tr('notAccepted'))],
      onChanged: (v) => setState(() => _acc = v),
    );
    final kind = ChoicePill<_Kind>(
      label: tr('type'),
      value: _kind,
      options: [MapEntry(_Kind.all, tr('all')), MapEntry(_Kind.invoice, tr('invoice')), MapEntry(_Kind.preorder, tr('preorder'))],
      onChanged: (v) => setState(() => _kind = v),
    );
    if (wide) {
      return Column(children: [
        Row(children: [Expanded(child: recipient), const SizedBox(width: 12), Expanded(child: supplier)]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: acc), const SizedBox(width: 12), Expanded(child: kind)]),
      ]);
    }
    return Column(children: [
      recipient,
      const SizedBox(height: 12),
      supplier,
      const SizedBox(height: 12),
      Row(children: [Expanded(child: acc), const SizedBox(width: 10), Expanded(child: kind)]),
    ]);
  }
}

class _PillBtn extends StatelessWidget {
  const _PillBtn({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? c.blue.withValues(alpha: 0.14) : c.field,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.blue.withValues(alpha: active ? 0.9 : 0.5)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: c.blue),
            const SizedBox(width: 6),
            Flexible(child: FitText(label, style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.tr, required this.onTap});
  final Doc doc;
  final Tr tr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final narrow = isNarrow(context);
    final invoice = doc.kind == DocKind.invoice;
    final acc = doc.isAccepted;
    return AibaCard(
      onTap: onTap,
      accent: acc ? c.green : (invoice ? c.blue : c.amber),
      padding: EdgeInsets.all(narrow ? 12 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.numberLabel, style: TextStyle(color: c.text, fontSize: narrow ? 19 : 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${prettyDate(doc.date)}${(doc.createdBy ?? '').isNotEmpty ? ' • ${doc.createdBy}' : ''}',
                  style: TextStyle(color: c.muted, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FitText('${fmtSum(doc.sum)} ${tr('cur')}',
                align: Alignment.centerRight,
                style: TextStyle(color: c.blue, fontSize: narrow ? 18 : 21, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        Text('${tr('supplier')}: ${tr('market')}', style: TextStyle(color: c.label, fontSize: 13)),
        const SizedBox(height: 2),
        Text('${tr('recipient')}: ${doc.branch.name}',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Pill(
            label: acc ? tr('yes') : tr('notAccepted'),
            color: acc ? c.green : c.orange,
            icon: acc ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
          ),
          Pill(label: invoice ? tr('invoice') : tr('preorder'), color: invoice ? c.blue : c.amber),
          Text(tr('lines', {'n': '${doc.linesCount}'}), style: TextStyle(color: c.muted, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}
