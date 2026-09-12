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
  /// '' — hammasi, 'bozor' — Bozorkom, aks holda firma id.
  String _supplier = '';
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
    final supplierRole = session?.staff.role == 'supplier';
    final own = BranchRef(
        id: session?.restaurant.id ?? '', name: session?.restaurant.name ?? '', code: session?.restaurant.code ?? '');
    final wide = isWide(context);
    final narrow = isNarrow(context);
    final pad = hPad(context);
    final branches = ref.watch(branchesProvider).valueOrNull ?? const <BranchRef>[];
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? const <SupplierRef>[];
    final size = MediaQuery.sizeOf(context);
    final landscape = wide && size.width > size.height;
    // Menejer faqat oldindan buyurtma yaratadi — tugma «Yangi yuk xati» demasin.
    // Firma akkaunti buyurtma YARATMAYDI — unga buyurtma keladi.
    Widget newBtn(double h) => supplierRole
        ? const SizedBox.shrink()
        : PrimaryBtn(
            label: market ? tr('newDoc') : tr('newPreorder'),
            icon: Icons.add_rounded,
            height: h,
            onTap: () async {
              final ok = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(builder: (_) => DocEditorScreen(date: date)));
              if (ok == true) ref.invalidate(docsProvider);
            },
          );

    return RefreshIndicator(
      color: c.blue,
      onRefresh: () async => ref.refresh(docsProvider.future),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
        children: [
          // Landshaft planshetda (800 px balandlik) sarlavha + sana/filtr + tugma
          // ekranning 30% ini yeb, 1.5 qator karta ko'rinardi (planshet QA):
          // katta sarlavha yashiriladi (u AppBar'da bor), uchala boshqaruv bir qatorda.
          if (!landscape)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
              child: Text(supplierRole ? tr('ordersForYou') : tr('docs'),
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
                if (wide) ...[
                  const SizedBox(width: 8),
                  SizedBox(width: 300, child: newBtn(48)),
                ],
              ]),
              if (_filterOpen) ...[const SizedBox(height: 12), _filters(tr, market, own, branches, suppliers, wide)],
            ]),
          ),
          if (!wide && !supplierRole) ...[const SizedBox(height: 12), newBtn(54)],
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
                // Samarali kenglik (px ÷ shrift masshtabi): 768 px × 1.3 = 590 → 1 ustun,
                // aks holda 354 px kartada pill'lar sig'may toshardi (matritsa testi).
                final ew = w / MediaQuery.textScalerOf(context).scale(1.0);
                final cols = ew >= 1100 ? 3 : (ew >= 700 ? 2 : 1);
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

  bool get _hasFilter => _recipient.isNotEmpty || _supplier.isNotEmpty || _acc != _Acc.all || _kind != _Kind.all;

  List<Doc> _apply(List<Doc> list) => list.where((d) {
        if (_recipient.isNotEmpty && d.branch.id != _recipient) return false;
        if (_supplier == 'bozor' && d.isFirma) return false;
        if (_supplier.isNotEmpty && _supplier != 'bozor' && d.supplierId != _supplier) return false;
        if (_acc == _Acc.yes && !d.isAccepted) return false;
        if (_acc == _Acc.no && d.isAccepted) return false;
        if (_kind == _Kind.invoice && d.kind != DocKind.invoice) return false;
        if (_kind == _Kind.preorder && d.kind != DocKind.preorder) return false;
        return true;
      }).toList();

  Widget _filters(Tr tr, bool market, BranchRef own, List<BranchRef> branches, List<SupplierRef> suppliers, bool wide) {
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
    // Yetkazib beruvchi: Hammasi / Bozorkom / firmalar (Coca-Cola, sex...).
    final supOpts = <MapEntry<String, String>>[
      MapEntry('', tr('all')),
      MapEntry('bozor', tr('market')),
      for (final s in suppliers) MapEntry(s.id, s.name),
    ];
    final supplier = ChoicePill<String>(
      label: tr('supplier'),
      value: supOpts.any((e) => e.key == _supplier) ? _supplier : '',
      options: supOpts,
      onChanged: (v) => setState(() => _supplier = v),
    );
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
    final wide = isWide(context);
    // 320 px + OS shrifti 1.3 (samarali kenglik < 330): № va summa bir qatorga
    // sig'maydi («№ 148» xiralashardi), ikki pill ham — ular pastga tushadi.
    final tiny = MediaQuery.sizeOf(context).width / MediaQuery.textScalerOf(context).scale(1.0) < 330;
    final invoice = doc.kind == DocKind.invoice;
    final acc = doc.isAccepted;
    return AibaCard(
      onTap: onTap,
      accent: acc ? c.green : (invoice ? c.blue : c.amber),
      padding: EdgeInsets.all(narrow ? 12 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Builder(builder: (_) {
          final num = Text(doc.numberLabel, maxLines: 1, softWrap: false, overflow: TextOverflow.fade,
              style: TextStyle(color: c.text, fontSize: narrow ? 19 : 22, fontWeight: FontWeight.w800));
          // FitText emas: qo'shni kartalarda summa 20 va 28 px bo'lib chiqardi.
          final sum = Text('${fmtSum(doc.sum)} ${tr('cur')}',
              maxLines: 1, softWrap: false, overflow: TextOverflow.fade,
              style: TextStyle(color: c.blue, fontSize: narrow ? 18 : 20, fontWeight: FontWeight.w800));
          if (tiny) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [num, const SizedBox(height: 2), sum]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: num), const SizedBox(width: 8), sum]);
        }),
        const SizedBox(height: 2),
        // Sana qatori TO'LIQ kenglikda — summa yonida turganda «7 t…» bo'lib qisqarardi.
        Text('${prettyDate(doc.date)}${(doc.createdBy ?? '').isNotEmpty ? '\u00A0•\u00A0${doc.createdBy}' : ''}'
            '\u00A0•\u00A0${tr('lines', {'n': '${doc.linesCount}'})}',
            // Planshetda 1 qator (kartalar teng), telefonda 2 qatorga tushishi mumkin.
            maxLines: wide ? 1 : 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.muted, fontSize: 13)),
        const SizedBox(height: 10),
        // Bozorkom yoki firma nomi (Coca-Cola, Цех Мясо...).
        Row(children: [
          Icon(doc.isFirma ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 14, color: c.label),
          const SizedBox(width: 4),
          Expanded(
            child: Text('${tr('supplier')}: ${doc.isFirma ? (doc.supplierName ?? tr('firma')) : tr('market')}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.label, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 2),
        Text('${tr('recipient')}: ${doc.branch.name}',
            maxLines: wide ? 1 : 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
        // Filialning HOZIRGI menejeri (har oy almashadi — serverdan jonli).
        if (doc.manager.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.person_outline_rounded, size: 14, color: c.label),
            const SizedBox(width: 4),
            Expanded(
              child: Text('${tr('branchManager')}: ${doc.manager}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.label, fontSize: 13)),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        // Planshetda Row — Wrap qatorlarni tekislamagani uchun yonma-yon kartalar
        // 25 px farq qilardi («N ta mahsulot» ba'zan pastga tushib).
        // Bitta qator, ikki pill — «N ta mahsulot» sana qatoriga ko'chdi. Shunda
        // yonma-yon kartalar bir xil balandlikda (Wrap 25 px farq berardi).
        Builder(builder: (_) {
          final p1 = Pill(label: acc ? tr('accepted') : tr('notAccepted'), color: acc ? c.green : c.orange,
              icon: acc ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded);
          final p2 = Pill(label: invoice ? tr('invoiceOne') : tr('preorderOne'), color: invoice ? c.blue : c.amber);
          if (tiny) return Wrap(spacing: 8, runSpacing: 6, children: [p1, p2]);
          return Row(children: [Flexible(child: p1), const SizedBox(width: 8), Flexible(child: p2)]);
        }),
      ]),
    );
  }
}
