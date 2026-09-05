// BOZORKOM QOBIG'I — asosiy ekran (hujjatlar ro'yxati) + yon menyu.
// Bozorkom va filial menejeri uchun BIR XIL UI; oq/qora tema.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_drawer.dart';
import 'docs_list_screen.dart';
import 'i18n.dart';
import 'repo.dart';
import 'widgets.dart';

class BozorkomShell extends ConsumerWidget {
  const BozorkomShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    return Scaffold(
      backgroundColor: c.bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: false,
        title: FitText(tr('docsTitle'), style: TextStyle(color: c.text, fontSize: 21, fontWeight: FontWeight.w400)),
        actions: [
          IconButton(tooltip: tr('refresh'), icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(docsProvider)),
        ],
      ),
      body: const DocsListBody(),
    );
  }
}
