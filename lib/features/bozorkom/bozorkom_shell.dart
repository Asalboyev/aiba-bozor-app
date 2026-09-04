// BOZORKOM QOBIG'I — bitta asosiy ekran (hujjatlar ro'yxati) + yon menyu.
// Bozorkom va filial menejeri uchun BIR XIL UI; faqat hujjat ichidagi
// tugmalar rolga qarab farq qiladi (Tahrirlash / Qabul qilish).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/pos_chrome.dart';
import 'app_drawer.dart';
import 'docs_list_screen.dart';
import 'i18n.dart';
import 'repo.dart';

class BozorkomShell extends ConsumerWidget {
  const BozorkomShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    return Scaffold(
      backgroundColor: PosColors.bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: PosColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(tr('docsTitle'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
        actions: [
          IconButton(
            tooltip: tr('refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(docsProvider),
          ),
        ],
      ),
      body: const DocsListBody(),
    );
  }
}
