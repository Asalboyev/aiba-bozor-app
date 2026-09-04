// YUK XATLARI VA OLDINDAN BUYURTMALAR — asosiy ro'yxat (eski Bozorkom
// «Yuk tushirish varog'i»). Sana + Filtr paneli + «Yangi yuk xati qo'shish»
// + hujjat kartalari. Telefonda bitta ustun, planshetda ikkita.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/pos_chrome.dart';
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
  String _recipient = ''; // '' = hammasi
  _Acc _acc = _Acc.all;
  _Kind _kind = _Kind.all;

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final loc = ref.watch(localeProvider);
    final date = ref.watch(docDateProvider);
    final docs = ref.watch(docsProvider);
    final compact = ref.watch(compactProvider);
    final session = ref.watch(sessionProvider);
    final market = session?.staff.role == 'market';
    final own = BranchRef(
        id: session?.restaurant.id ?? '',
        name: session?.restaurant.name ?? '',
        code: session?.restaurant.code ?? '');
    final wide = isWide(context);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <BranchRef>[];

    return RefreshIndicator(
      color: PosColors.blue,
      onRefresh: () async => ref.refresh(docsProvider.future),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 14, vertical: 12),
        children: [
          // Sarlavha
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
            child: Text(tr('docs'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: wide ? 26 : 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15)),
          ),
          // Sana + Filtr paneli
          AibaCard(
            color: PosColors.panel,
            padding: const EdgeInsets.all(12),
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
                const SizedBox(width: 10),
                Expanded(
                  child: _PillBtn(
                    icon: Icons.tune_rounded,
                    label: _filterOpen ? tr('hide') : tr('filter'),
                    active: _filterOpen || _hasFilter,
                    onTap: () => setState(() => _filterOpen = !_filterOpen),
                  ),
                ),
              ]),
              if (_filterOpen) ...[
                const SizedBox(height: 14),
                _filters(tr, market, own, branches, wide),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          // Yangi hujjat
          PrimaryBtn(
            label: tr('newDoc'),
            icon: Icons.add_rounded,
            height: 54,
            onTap: () async {
              final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => DocEditorScreen(date: date),
              ));
              if (ok == true) ref.invalidate(docsProvider);
            },
          ),
          const SizedBox(height: 14),
          // Ro'yxat
          docs.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: PosColors.blue)),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: BozorkomRepo.errText(e, tr('errNet')),
            ),
            data: (list) {
              final shown = _apply(list);
              if (shown.isEmpty) {
                return EmptyState(
                    icon: Icons.inventory_2_outlined, title: tr('empty'), note: tr('emptyNote'));
              }
              final cards = [
                for (final d in shown)
                  _DocCard(
                    doc: d,
                    tr: tr,
                    compact: compact,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DocDetailScreen(doc: d),
                      ));
                      ref.invalidate(docsProvider);
                    },
                  ),
              ];
              if (wide && !compact) {
                // Planshet: 2–3 ustun. Karta o'z balandligini oladi (Wrap) —
                // uzun filial nomi yoki 2 qatorli matn hech qachon toshmaydi.
                final w = MediaQuery.sizeOf(context).width;
                final cols = w >= 1100 ? 3 : 2;
                const gap = 12.0;
                final colW = (w - 24 * 2 - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [for (final c in cards) SizedBox(width: colW, child: c)],
                );
              }
              return Column(children: [
                for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
              ]);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool get _hasFilter => _recipient.isNotEmpty || _acc != _Acc.all || _kind != _Kind.all;

  List<Doc> _apply(List<Doc> list) {
    return list.where((d) {
      if (_recipient.isNotEmpty && d.branch.id != _recipient) return false;
      if (_acc == _Acc.yes && !d.isAccepted) return false;
      if (_acc == _Acc.no && d.isAccepted) return false;
      if (_kind == _Kind.invoice && d.kind != DocKind.invoice) return false;
      if (_kind == _Kind.preorder && d.kind != DocKind.preorder) return false;
      return true;
    }).toList();
  }

  Widget _filters(Tr tr, bool market, BranchRef own, List<BranchRef> branches, bool wide) {
    final recOpts = <MapEntry<String, String>>[
      MapEntry('', tr('all')),
      if (market)
        for (final b in branches) MapEntry(b.id, b.name)
      else
        MapEntry(own.id, own.name),
    ];
    final recipient = ChoicePill<String>(
      label: tr('recipient'),
      value: recOpts.any((e) => e.key == _recipient) ? _recipient : '',
      options: recOpts,
      onChanged: (v) => setState(() => _recipient = v),
    );
    final supplier = ChoicePill<int>(
      label: tr('supplier'),
      value: 1,
      options: [MapEntry(1, tr('market'))],
      onChanged: (_) {},
    );
    final acc = ChoicePill<_Acc>(
      label: tr('accepted'),
      value: _acc,
      options: [
        MapEntry(_Acc.all, tr('all')),
        MapEntry(_Acc.yes, tr('accepted')),
        MapEntry(_Acc.no, tr('notAccepted')),
      ],
      onChanged: (v) => setState(() => _acc = v),
    );
    final kind = ChoicePill<_Kind>(
      label: tr('type'),
      value: _kind,
      options: [
        MapEntry(_Kind.all, tr('all')),
        MapEntry(_Kind.invoice, tr('invoice')),
        MapEntry(_Kind.preorder, tr('preorder')),
      ],
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
      Row(children: [Expanded(child: acc), const SizedBox(width: 12), Expanded(child: kind)]),
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
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: active ? PosColors.blue.withValues(alpha: 0.16) : PosColors.field,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PosColors.blue.withValues(alpha: active ? 0.9 : 0.5)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: PosColors.blue),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

/// Hujjat kartasi — №, sana • muallif, jami, yetkazib beruvchi/qabul qiluvchi,
/// tur va holat belgilari.
class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.tr, required this.onTap, this.compact = false});
  final Doc doc;
  final Tr tr;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final invoice = doc.kind == DocKind.invoice;
    final acc = doc.isAccepted;
    return AibaCard(
      onTap: onTap,
      accent: acc ? PosColors.green : (invoice ? PosColors.blue : const Color(0xFFD97706)),
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.numberLabel,
                  style: TextStyle(
                      color: Colors.white, fontSize: compact ? 18 : 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                '${prettyDate(doc.date)}${(doc.createdBy ?? '').isNotEmpty ? ' • ${doc.createdBy}' : ''}',
                style: const TextStyle(color: PosColors.muted, fontSize: 13),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${fmtSum(doc.sum)} ${tr('cur')}',
              style: TextStyle(
                  color: PosColors.blue, fontSize: compact ? 17 : 21, fontWeight: FontWeight.w800)),
        ]),
        SizedBox(height: compact ? 8 : 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr('supplier')}: ${tr('market')}',
                  style: const TextStyle(color: PosColors.label, fontSize: 13)),
              const SizedBox(height: 2),
              Text('${tr('recipient')}: ${doc.branch.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          Pill(
            label: invoice ? tr('invoice') : tr('preorder'),
            color: invoice ? PosColors.blue : const Color(0xFFD97706),
            small: compact,
          ),
        ]),
        SizedBox(height: compact ? 8 : 12),
        Row(children: [
          Pill(
            label: acc ? tr('yes') : tr('notAccepted'),
            color: acc ? PosColors.green : const Color(0xFFE8863A),
            icon: acc ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
            small: compact,
          ),
          const Spacer(),
          Text(tr('lines', {'n': '${doc.linesCount}'}),
              style: const TextStyle(color: PosColors.muted, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}
