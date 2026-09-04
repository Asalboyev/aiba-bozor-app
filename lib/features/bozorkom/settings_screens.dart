// SOZLAMALAR — Tilni tanlash / IP sozlamalar / Umumiy sozlamalar
// (eski Bozorkom ilovasidagi uch ekran, AIBA uslubida).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/widgets/pos_chrome.dart';
import '../auth/presentation/providers/auth_providers.dart';
import 'app_drawer.dart' show kLicenseUntil;
import 'i18n.dart';
import 'repo.dart';
import 'widgets.dart';

const kAppVersion = '1.0.1';

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
      backgroundColor: PosColors.bg,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
      title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
    );

// ── TIL ─────────────────────────────────────────────────────────────────────
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final cur = ref.watch(localeProvider);
    const names = {'ru': 'Русский язык', 'uz': "O'zbek tili", 'en': 'English'};
    return Scaffold(
      backgroundColor: PosColors.bg,
      appBar: _bar(context, tr('lang')),
      body: Column(children: [
        const Spacer(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: [
              for (final code in const ['ru', 'uz', 'en']) ...[
                PrimaryBtn(
                  label: names[code]!,
                  icon: cur == code ? Icons.check_rounded : null,
                  color: cur == code ? PosColors.blue : PosColors.card,
                  height: 56,
                  onTap: () {
                    ref.read(localeProvider.notifier).set(code);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── IP SOZLAMALAR ───────────────────────────────────────────────────────────
class IpSettingsScreen extends ConsumerStatefulWidget {
  const IpSettingsScreen({super.key});
  @override
  ConsumerState<IpSettingsScreen> createState() => _IpSettingsScreenState();
}

class _IpSettingsScreenState extends ConsumerState<IpSettingsScreen> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    // Faqat host ko'rsatiladi (https:// va / siz) — eski ilovadagidek.
    final u = ref.read(appConfigProvider).baseUrl;
    _ctl = TextEditingController(
        text: u.replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), ''));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool get _valid {
    final v = _ctl.text.trim();
    if (v.isEmpty) return false;
    final ip = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d+)?$');
    final host = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)+(:\d+)?$');
    return ip.hasMatch(v) || host.hasMatch(v) || v.startsWith('localhost');
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final v = _ctl.text.trim();
    final ok = _valid;
    return Scaffold(
      backgroundColor: PosColors.bg,
      appBar: _bar(context, tr('ipSettings')),
      body: Column(children: [
        const Spacer(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: AibaCard(
              color: PosColors.panel,
              child: Column(children: [
                Text(tr('ipSettings'),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w400)),
                const SizedBox(height: 14),
                AibaField(
                  controller: _ctl,
                  label: tr('serverAddr'),
                  prefixIcon: Icons.dns_rounded,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Text(
                  '${tr('entered', {'a': v})} (${ok ? tr('valid') : tr('invalid')})',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ok ? PosColors.blue : PosColors.red, fontSize: 13.5),
                ),
                const SizedBox(height: 14),
                PrimaryBtn(
                  label: tr('ok'),
                  enabled: ok,
                  onTap: () async {
                    // IP/localhost → http, domen → https (AppConfig.setBaseUrl o'zi qo'yadi).
                    await ref.read(appConfigProvider).setBaseUrl(v);
                    ref.read(configVersionProvider.notifier).state++;
                    if (!context.mounted) return;
                    toast(context, tr('saved'));
                    Navigator.of(context).pop();
                  },
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── UMUMIY SOZLAMALAR ───────────────────────────────────────────────────────
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final s = ref.watch(sessionProvider);
    final cfg = ref.watch(appConfigProvider);
    final branches = ref.watch(branchesProvider);
    final today = prettyDate(DateTime.now().toIso8601String().substring(0, 10));
    final wide = isWide(context);

    return Scaffold(
      backgroundColor: PosColors.bg,
      appBar: _bar(context, tr('general')),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16, vertical: 8),
        children: [
          SectionLabel(tr('deviceInfo')),
          KV(k: tr('ipDomain'), v: cfg.baseUrl, bold: true),
          KV(k: tr('guid'), v: s?.terminal.id ?? '—', mono: true),
          const Divider(color: PosColors.cardBorder, height: 20),
          SectionLabel(tr('appSettings')),
          KV(k: tr('androidApp'), v: kAppVersion, bold: true),
          KV(k: tr('checkPrint'), v: 'Kuhnya', bold: true),
          const Divider(color: PosColors.cardBorder, height: 20),
          SectionLabel(tr('licenseMode')),
          KV(k: tr('license'), v: kLicenseUntil, bold: true),
          KV(k: tr('dataDate'), v: today, bold: true),
          const Divider(color: PosColors.cardBorder, height: 20),
          SectionLabel(tr('recipients')),
          KV(k: tr('common'), v: 'ID: 0', bold: true),
          branches.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: PosColors.blue))),
            error: (_, _) => KV(k: s?.restaurant.name ?? '—', v: 'ID: 1', bold: true),
            data: (list) => Column(children: [
              for (var i = 0; i < list.length; i++) KV(k: list[i].name, v: 'ID: ${i + 1}', bold: true),
              if (list.isEmpty) KV(k: s?.restaurant.name ?? '—', v: 'ID: 1', bold: true),
            ]),
          ),
          const Divider(color: PosColors.cardBorder, height: 20),
          SectionLabel(tr('suppliers')),
          KV(k: tr('market'), v: 'ID: 1', bold: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
