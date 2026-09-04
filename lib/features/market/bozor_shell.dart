// BOZOR ILOVASI QOBIG'I — 3 ekran (Figma POS uslubida, planshet/telefon mos):
//   • ZAKAZ  — filial menejeri ertangi bozor ro'yxatini yuboradi
//   • BOZOR  — bozorchi HAMMA filial jamlanmasini ko'rib narx kiritadi
//   • QABUL  — menejer kelgan mahsulotni tekshirib «Qabul qildim» bosadi →
//     omborga avto-kirim (izohda bozorchi nomi + vaqti).
//
// Hamma filial zakazlari BITTA bozorchi akkauntiga (Bozor ekrani) yig'iladi;
// har filial menejeri esa faqat O'Z zakaz/qabulini ko'radi (terminal tokeni
// filialga bog'langan).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/pos_chrome.dart';
import '../auth/presentation/providers/auth_providers.dart';
import 'bozorchi_screen.dart';
import 'market_screen.dart';
import 'qabul_tab.dart';
import 'tarix_tab.dart';
import 'zakaz_tab.dart';

class BozorShell extends ConsumerStatefulWidget {
  const BozorShell({super.key});

  @override
  ConsumerState<BozorShell> createState() => _BozorShellState();
}

class _BozorShellState extends ConsumerState<BozorShell> {
  // ROLga qarab EKRANLAR:
  //   • Menejer — Zakaz + Qabul + Tarix (faqat O'Z filiali).
  //   • Bozorchi (qolgan hamma) — IKKI tab: «Jamlangan» (bir xil mahsulot
  //     hamma filial bo'yicha: shakar = Chilonzor 10 + Yunusobod 15) va
  //     «Filiallar» (har filialni alohida ochib olish).
  bool get _isManager =>
      ref.read(sessionProvider)?.staff.role == 'manager';
  late int _tab = 0;

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BozorSetupScreen(inApp: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final manager = _isManager;
    // Telefonda uchta tab tor joyga sig'ishi kerak — yozuvlar kichrayadi.
    final compact = MediaQuery.of(context).size.width < 440;
    return Scaffold(
      backgroundColor: PosColors.bg,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Yuqori panel: chapda tablar/sarlavha, o'ngda PROFIL menyusi
              //    (hodim nomi, sozlamalar, chiqish — hammasi menyu ichida).
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    if (manager)
                      Expanded(
                        child: Row(children: [
                          Flexible(child: _TabChip(label: 'Zakaz', compact: compact,
                              icon: Icons.edit_note, selected: _tab == 0,
                              onTap: () => setState(() => _tab = 0))),
                          const SizedBox(width: 8),
                          Flexible(child: _TabChip(label: 'Qabul', compact: compact,
                              icon: Icons.task_alt, selected: _tab == 1,
                              onTap: () => setState(() => _tab = 1))),
                          const SizedBox(width: 8),
                          Flexible(child: _TabChip(label: 'Tarix', compact: compact,
                              icon: Icons.history, selected: _tab == 2,
                              onTap: () => setState(() => _tab = 2))),
                        ]),
                      )
                    else
                      // BOZORCHI: 2 tab — Jamlangan / Filiallar.
                      Expanded(
                        child: Row(children: [
                          Flexible(child: _TabChip(label: 'Jamlangan', compact: compact,
                              icon: Icons.summarize_outlined, selected: _tab == 0,
                              onTap: () => setState(() => _tab = 0))),
                          const SizedBox(width: 8),
                          Flexible(child: _TabChip(label: 'Filiallar', compact: compact,
                              icon: Icons.store_mall_directory_outlined, selected: _tab == 1,
                              onTap: () => setState(() => _tab = 1))),
                        ]),
                      ),
                    const SizedBox(width: 8),
                    // PROFIL MENYUSI — nom/sozlamalar/chiqish shu yerda,
                    // yuqori panel toza qoladi.
                    PopupMenuButton<String>(
                      color: PosColors.panel,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'logout') {
                          ref.read(sessionProvider.notifier).logout();
                        } else if (v == 'settings') {
                          _openSettings();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          enabled: false,
                          child: Text(
                            '${session?.staff.name ?? ''}\n${manager ? 'Menejer' : 'Bozorchi'}',
                            style: const TextStyle(
                                color: PosColors.label, fontSize: 13),
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(children: [
                            Icon(Icons.settings, size: 18, color: PosColors.label),
                            SizedBox(width: 10),
                            Text('Sozlamalar'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(children: [
                            Icon(Icons.logout, size: 18, color: PosColors.red),
                            SizedBox(width: 10),
                            Text('Chiqish',
                                style: TextStyle(color: PosColors.red)),
                          ]),
                        ),
                      ],
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                            color: PosColors.green, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            (session?.staff.name ?? 'A')
                                .trim()
                                .split(' ')
                                .map((w) => w.isEmpty ? '' : w[0])
                                .take(2)
                                .join()
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // Suv teksturasi ustidan mayin to'q parda: kartalar va matn
                // ajralib turadi (avval fon naqshi ro'yxat ichidan ko'rinib,
                // hammasi yuvilib ketardi).
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xCC06090B)),
                  child: manager
                      ? IndexedStack(
                          index: _tab,
                          children: const [ZakazTab(), QabulTab(), TarixTab()],
                        )
                      : IndexedStack(
                          index: _tab,
                          children: const [BozorchiScreen(), MarketScreen()],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// Tor ekran — kichikroq yozuv va ichki bo'shliq (uchala tab sig'sin).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16, vertical: compact ? 10 : 9),
        decoration: BoxDecoration(
          color: selected ? PosColors.blue : PosColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? PosColors.blue : PosColors.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: compact ? 17 : 18,
              color: selected ? Colors.white : PosColors.label),
          SizedBox(width: compact ? 5 : 7),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: compact ? 13.5 : 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : PosColors.label)),
          ),
        ]),
      ),
    );
  }
}

/// BIRINCHI SOZLASH — faqat server manzili (kassaning katta sozlamalari
/// bozor ilovasida keraksiz edi; telefonda ham to'g'ri ko'rinadi).
class BozorSetupScreen extends ConsumerStatefulWidget {
  const BozorSetupScreen({super.key, this.inApp = false});

  /// true — ilova ichidan (profil menyusi) ochilgan: orqaga tugmasi chiqadi.
  final bool inApp;

  @override
  ConsumerState<BozorSetupScreen> createState() => _BozorSetupScreenState();
}

class _BozorSetupScreenState extends ConsumerState<BozorSetupScreen> {
  late final TextEditingController _url =
      TextEditingController(text: ref.read(appConfigProvider).baseUrl);
  late final TextEditingController _code =
      TextEditingController(text: ref.read(appConfigProvider).terminalCode);
  bool _saving = false;

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7178)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        filled: true,
        fillColor: PosColors.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PosColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PosColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PosColors.blue, width: 1.4),
        ),
      );

  Widget _label(String text, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 7, left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.toUpperCase(),
                style: const TextStyle(
                    color: PosColors.label,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6)),
            if (hint != null) ...[
              const SizedBox(height: 3),
              Text(hint,
                  style: const TextStyle(
                      color: PosColors.muted, fontSize: 12, height: 1.35)),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.bg,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xF2111113),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PosColors.cardBorder),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 30,
                          offset: Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.inApp)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: PosColors.label,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Orqaga'),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF22C55E), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.storefront,
                              color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('AIBA Bozor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text('Filial zakazlari va bozor ilovasi',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: PosColors.muted, fontSize: 13.5)),
                      const SizedBox(height: 22),
                      _label('Server manzili',
                          hint: 'Kassa bilan bir xil manzil.'),
                      TextField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        style: const TextStyle(fontSize: 16),
                        decoration: _dec('https://next.aiba.uz'),
                      ),
                      const SizedBox(height: 16),
                      _label('Filial (terminal) kodi',
                          hint: 'Kassa terminalining kodi — adminkada '
                              'ko\'rsatilgan (masalan T1).'),
                      TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        decoration: _dec('T1'),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: PosColors.blue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          onPressed: _saving
                              ? null
                              : () async {
                                  final v = _url.text.trim();
                                  final c = _code.text.trim();
                                  if (v.isEmpty || c.isEmpty) return;
                                  setState(() => _saving = true);
                                  final cfg = ref.read(appConfigProvider);
                                  await cfg.setBaseUrl(v);
                                  await cfg.setTerminalCode(c);
                                  await cfg.markSetupDone();
                                  // main.dart qayta baholaydi → Login ochiladi.
                                  ref
                                      .read(configVersionProvider.notifier)
                                      .state++;
                                  if (mounted) setState(() => _saving = false);
                                },
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : const Text('Saqlash va davom etish',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
