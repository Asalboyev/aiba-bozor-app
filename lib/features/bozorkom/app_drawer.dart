// YON MENYU — profil (ism, rol, ID, filial), «Ekranni o'zgartirish» toggle,
// Tilni tanlash / IP sozlamalar / Umumiy sozlamalar, litsenziya, Chiqish.
// Eski Bozorkom ilovasidagi menyu tartibi, AIBA uslubida.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/pos_chrome.dart';
import '../auth/presentation/providers/auth_providers.dart';
import 'i18n.dart';
import 'repo.dart';
import 'settings_screens.dart';
import 'widgets.dart';

/// Litsenziya muddati (ko'rsatish uchun) — eski ilovadagidek.
const kLicenseUntil = '31.12.2026';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final s = ref.watch(sessionProvider);
    final compact = ref.watch(compactProvider);
    final market = s?.staff.role == 'market';
    final name = s?.staff.name ?? '';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Drawer(
      backgroundColor: PosColors.panel,
      width: 320,
      child: SafeArea(
        child: Column(children: [
          // Profil
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PosColors.blue.withValues(alpha: 0.16),
                  border: Border.all(color: PosColors.blue, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: const TextStyle(color: PosColors.blue, fontSize: 36, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Pill(label: market ? tr('market') : tr('manager'), color: PosColors.blue),
              const SizedBox(height: 8),
              Text('ID: ${s?.terminal.id ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PosColors.muted, fontSize: 11.5)),
              const SizedBox(height: 4),
              Text(market ? tr('common') : (s?.restaurant.name ?? ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PosColors.blue, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
          // Ekranni o'zgartirish
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(children: [
              Expanded(
                child: Text(tr('switchScreen'),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Switch(
                value: compact,
                activeThumbColor: PosColors.blue,
                onChanged: (_) => ref.read(compactProvider.notifier).toggle(),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: PosColors.cardBorder),
          // Menyu
          _Tile(icon: Icons.language_rounded, label: tr('lang'), onTap: () => _go(context, const LanguageScreen())),
          _Tile(icon: Icons.settings_ethernet_rounded, label: tr('ipSettings'), onTap: () => _go(context, const IpSettingsScreen())),
          _Tile(icon: Icons.tune_rounded, label: tr('general'), onTap: () => _go(context, const GeneralSettingsScreen())),
          const Spacer(),
          // Litsenziya + Chiqish
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(children: [
              Text(tr('licenseTill', {'d': kLicenseUntil}),
                  style: const TextStyle(color: PosColors.muted, fontSize: 13)),
              const SizedBox(height: 10),
              PrimaryBtn(
                label: tr('logout'),
                icon: Icons.logout_rounded,
                color: PosColors.blue,
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
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: PosColors.iconChip, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Icon(icon, color: PosColors.blue, size: 22),
        ),
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right_rounded, color: PosColors.muted),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      );
}
