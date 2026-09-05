// YON MENYU — profil (ism, rol, ID, filial), «Ekranni o'zgartirish» = OQ/QORA
// tema, Til / IP / Umumiy sozlamalar, litsenziya, Chiqish.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/providers/auth_providers.dart';
import 'i18n.dart';
import 'settings_screens.dart';
import 'theme.dart';
import 'widgets.dart';

/// Litsenziya muddati (ko'rsatish uchun).
const kLicenseUntil = '31.12.2026';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = bz(context);
    final tr = ref.watch(trProvider);
    final s = ref.watch(sessionProvider);
    final light = ref.watch(lightThemeProvider);
    final market = s?.staff.role == 'market';
    final name = s?.staff.name ?? '';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final w = MediaQuery.sizeOf(context).width;

    return Drawer(
      backgroundColor: c.panel,
      width: (w * 0.84).clamp(260.0, 320.0),
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Column(children: [
              Container(
                width: 84, height: 84,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.blue.withValues(alpha: 0.14), border: Border.all(color: c.blue, width: 2)),
                alignment: Alignment.center,
                child: Text(initial, style: TextStyle(color: c.blue, fontSize: 34, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              FitText(name, align: Alignment.center, style: TextStyle(color: c.text, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Pill(label: market ? tr('market') : tr('manager'), color: c.blue),
              const SizedBox(height: 8),
              Text('ID: ${s?.terminal.id ?? ''}', textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 11.5)),
              const SizedBox(height: 4),
              Text(market ? tr('common') : (s?.restaurant.name ?? ''), textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.blue, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
          // OQ / QORA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Icon(light ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: c.blue, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('switchScreen'), style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700))),
              Switch(value: light, onChanged: (_) => ref.read(lightThemeProvider.notifier).toggle()),
            ]),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: c.border),
          _Tile(icon: Icons.language_rounded, label: tr('lang'), onTap: () => _go(context, const LanguageScreen())),
          _Tile(icon: Icons.settings_ethernet_rounded, label: tr('ipSettings'), onTap: () => _go(context, const IpSettingsScreen())),
          _Tile(icon: Icons.tune_rounded, label: tr('general'), onTap: () => _go(context, const GeneralSettingsScreen())),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(children: [
              Text(tr('licenseTill', {'d': kLicenseUntil}), style: TextStyle(color: c.muted, fontSize: 13)),
              const SizedBox(height: 10),
              PrimaryBtn(
                label: tr('logout'),
                icon: Icons.logout_rounded,
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(sessionProvider.notifier).logout();
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = bz(context);
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Icon(icon, color: c.blue, size: 22),
      ),
      title: Text(label, style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
