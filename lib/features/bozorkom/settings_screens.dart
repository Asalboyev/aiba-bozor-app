// SOZLAMALAR — Tilni tanlash / IP sozlamalar / Umumiy sozlamalar.
// To'liq parametrlar: server, terminal kodi, hodim, rol, filial, tenant,
// til, versiya, litsenziya, qabul qiluvchilar, yetkazib beruvchilar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../auth/presentation/providers/auth_providers.dart';
import 'app_drawer.dart' show kLicenseUntil;
import 'i18n.dart';
import 'repo.dart';
import 'theme.dart';
import 'widgets.dart';

const kAppVersion = '1.0.1';

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
      leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).pop()),
      title: FitText(title, style: TextStyle(color: bz(context).text, fontSize: 21, fontWeight: FontWeight.w400)),
    );

// ── TIL ─────────────────────────────────────────────────────────────────────
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final cur = ref.watch(localeProvider);
    const names = {'ru': 'Русский язык', 'uz': "O'zbek tili", 'en': 'English'};
    return Scaffold(
      backgroundColor: c.bg,
      appBar: _bar(context, tr('lang')),
      body: Column(children: [
        const Spacer(),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad(context), 0, hPad(context), 20),
            child: Column(children: [
              for (final code in const ['ru', 'uz', 'en']) ...[
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      ref.read(localeProvider.notifier).set(code);
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cur == code ? c.blue : c.card,
                      foregroundColor: cur == code ? Colors.white : c.text,
                      side: cur == code ? null : BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (cur == code) ...[const Icon(Icons.check_rounded, size: 20), const SizedBox(width: 8)],
                      Text(names[code]!),
                    ]),
                  ),
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

// ── IP SOZLAMALAR: server + terminal kodi ───────────────────────────────────
class IpSettingsScreen extends ConsumerStatefulWidget {
  const IpSettingsScreen({super.key});
  @override
  ConsumerState<IpSettingsScreen> createState() => _IpSettingsScreenState();
}

class _IpSettingsScreenState extends ConsumerState<IpSettingsScreen> {
  late final TextEditingController _host;
  late final TextEditingController _term;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(appConfigProvider);
    _host = TextEditingController(text: cfg.baseUrl.replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), ''));
    _term = TextEditingController(text: cfg.terminalCode);
  }

  @override
  void dispose() {
    _host.dispose();
    _term.dispose();
    super.dispose();
  }

  bool get _valid {
    final v = _host.text.trim();
    if (v.isEmpty) return false;
    final ip = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d+)?$');
    final host = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)+(:\d+)?$');
    return ip.hasMatch(v) || host.hasMatch(v) || v.startsWith('localhost');
  }

  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final v = _host.text.trim();
    final ok = _valid && _term.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: _bar(context, tr('ipSettings')),
      body: ListView(
        padding: EdgeInsets.all(hPad(context)),
        children: [
          AibaCard(
            color: c.panel,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('ipSettings'), style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w400)),
              const SizedBox(height: 14),
              AibaField(controller: _host, label: tr('serverAddr'), prefixIcon: Icons.dns_rounded, onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              Text('${tr('entered', {'a': v})} (${_valid ? tr('valid') : tr('invalid')})',
                  style: TextStyle(color: _valid ? c.blue : c.red, fontSize: 13)),
              const SizedBox(height: 14),
              AibaField(controller: _term, label: tr('terminalCode'), prefixIcon: Icons.point_of_sale_rounded, onChanged: (_) => setState(() {})),
              const SizedBox(height: 16),
              PrimaryBtn(
                label: tr('ok'),
                enabled: ok,
                onTap: () async {
                  final cfg = ref.read(appConfigProvider);
                  await cfg.setBaseUrl(v);
                  await cfg.setTerminalCode(_term.text.trim());
                  ref.read(configVersionProvider.notifier).state++;
                  if (!context.mounted) return;
                  toast(context, tr('saved'));
                  Navigator.of(context).pop();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── UMUMIY SOZLAMALAR ───────────────────────────────────────────────────────
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final loc = ref.watch(localeProvider);
    final light = ref.watch(lightThemeProvider);
    final s = ref.watch(sessionProvider);
    final cfg = ref.watch(appConfigProvider);
    final branches = ref.watch(branchesProvider);
    final today = prettyDate(DateTime.now().toIso8601String().substring(0, 10));
    final market = s?.staff.role == 'market';
    const langName = {'uz': "O'zbek", 'ru': 'Русский', 'en': 'English'};

    Widget div() => Divider(color: c.border, height: 18);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _bar(context, tr('general')),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPad(context), vertical: 6),
        children: [
          SectionLabel(tr('deviceInfo')),
          KV(k: tr('ipDomain'), v: cfg.baseUrl),
          KV(k: tr('terminalCode'), v: (s?.terminal.code.isNotEmpty ?? false) ? s!.terminal.code : cfg.terminalCode),
          KV(k: tr('guid'), v: s?.terminal.id ?? '—', bold: false),
          div(),
          SectionLabel(tr('userInfo')),
          KV(k: tr('staff'), v: s?.staff.name ?? '—'),
          KV(k: tr('role'), v: market ? tr('market') : tr('manager')),
          KV(k: tr('branch'), v: market ? tr('common') : (s?.restaurant.name ?? '—')),
          if ((s?.restaurant.code ?? '').isNotEmpty) KV(k: tr('branchCode'), v: s!.restaurant.code),
          div(),
          SectionLabel(tr('appSettings')),
          KV(k: tr('androidApp'), v: kAppVersion),
          KV(k: tr('lang'), v: langName[loc] ?? loc),
          KV(k: tr('theme'), v: light ? tr('themeLight') : tr('themeDark')),
          KV(k: tr('checkPrint'), v: 'Kuhnya'),
          div(),
          SectionLabel(tr('licenseMode')),
          KV(k: tr('license'), v: kLicenseUntil),
          KV(k: tr('dataDate'), v: today),
          div(),
          SectionLabel(tr('recipients')),
          KV(k: tr('common'), v: 'ID: 0'),
          branches.when(
            loading: () => Padding(padding: const EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: c.blue))),
            error: (_, _) => KV(k: s?.restaurant.name ?? '—', v: 'ID: 1'),
            data: (list) => Column(children: [
              for (var i = 0; i < list.length; i++) KV(k: list[i].name, v: 'ID: ${i + 1}'),
              if (list.isEmpty) KV(k: s?.restaurant.name ?? '—', v: 'ID: 1'),
            ]),
          ),
          div(),
          SectionLabel(tr('suppliers')),
          KV(k: tr('market'), v: 'ID: 1'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
