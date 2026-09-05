// MAHSULOT TANLASH — qidiruv + kategoriya chiplari + karta gridi.
// Telefonda 2, planshetda 3–4 ustun. Oq/qora tema.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'i18n.dart';
import 'models.dart';
import 'repo.dart';
import 'widgets.dart';

class ProductPickerScreen extends ConsumerStatefulWidget {
  const ProductPickerScreen({super.key});
  @override
  ConsumerState<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends ConsumerState<ProductPickerScreen> {
  final _searchCtl = TextEditingController();
  Timer? _debounce;
  List<CatalogItem> _all = const [];
  bool _loading = true;
  String? _error;
  String _cat = '';
  final Set<String> _picked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(bozorkomRepoProvider).items();
      if (!mounted) return;
      setState(() {
        _all = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = BozorkomRepo.errText(e, ref.read(trProvider)('errNet'));
        _loading = false;
      });
    }
  }

  List<String> get _cats {
    final s = <String>{for (final i in _all) if (i.category.trim().isNotEmpty) i.category.trim()};
    return s.toList()..sort();
  }

  List<CatalogItem> get _shown {
    final q = _searchCtl.text.trim().toLowerCase();
    return _all.where((i) {
      if (_cat.isNotEmpty && i.category.trim() != _cat) return false;
      if (q.isNotEmpty && !i.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final pad = hPad(context);
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1100 ? 4 : (w >= 720 ? 3 : 2);
    final cats = _cats;
    final shown = _shown;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
        title: FitText(tr('createDoc'), style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w400)),
      ),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
          child: AibaField(
            controller: _searchCtl,
            label: '',
            hint: tr('searchProduct'),
            prefixIcon: Icons.search_rounded,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 150), () => setState(() {}));
            },
          ),
        ),
        if (cats.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              children: [
                _CatChip(label: tr('all'), selected: _cat.isEmpty, onTap: () => setState(() => _cat = '')),
                for (final k in cats) _CatChip(label: k, selected: _cat == k, onTap: () => setState(() => _cat = k)),
              ],
            ),
          ),
        Divider(height: 1, color: c.border),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.blue))
              : _error != null
                  ? EmptyState(icon: Icons.cloud_off_rounded, title: _error!)
                  : shown.isEmpty
                      ? EmptyState(icon: Icons.search_off_rounded, title: tr('noProducts'))
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(pad, 14, pad, 100),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.45),
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final it = shown[i];
                            final on = _picked.contains(it.name);
                            return _ProductCard(
                              item: it,
                              selected: on,
                              onTap: () => setState(() => on ? _picked.remove(it.name) : _picked.add(it.name)),
                            );
                          },
                        ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
          child: PrimaryBtn(
            label: _picked.isEmpty ? tr('done') : '${tr('done')}  •  ${_picked.length}',
            icon: Icons.check_rounded,
            onTap: () => Navigator.of(context).pop(_all.where((i) => _picked.contains(i.name)).toList()),
          ),
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.blue.withValues(alpha: 0.16) : c.field,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? c.blue : c.border),
            ),
            child: Text(label, style: TextStyle(color: selected ? c.text : c.label, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.selected, required this.onTap});
  final CatalogItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? c.blue.withValues(alpha: 0.14) : c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? c.blue : c.border, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: c.blue, size: 20),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(item.unit, style: TextStyle(color: c.blue, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Flexible(
                child: FitText(item.price > 0 ? fmtSum(item.price) : '—',
                    align: Alignment.centerRight,
                    style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
