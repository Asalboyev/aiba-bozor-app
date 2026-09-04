// BOZORKOM umumiy vidjetlar — AIBA (Figma POS) qorong'i uslubi.
// Telefon + planshet: `isWide` bilan ustunlar/kenglik moslashadi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/pos_chrome.dart';
import 'i18n.dart';

bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 720;

/// 1849000 → "1 849 000"
String fmtSum(double v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return (v < 0 ? '-' : '') + b.toString();
}

/// 3.0 → "3", 3.9 → "3,9"
String fmtQty(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
}

/// 2026-09-04 → 04.09.2026
String prettyDate(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  return '${p[2]}.${p[1]}.${p[0]}';
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? PosColors.red : const Color(0xFF1C1D22),
    duration: Duration(seconds: error ? 4 : 2),
  ));
}

class AibaCard extends StatelessWidget {
  const AibaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.accent,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  /// Chap chiziq rangi (holat).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? PosColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(children: [
          if (accent != null) Container(width: 4, color: accent),
          Expanded(child: Padding(padding: padding, child: child)),
        ]),
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
    this.icon,
    this.small = false,
  });
  final String label;
  final Color color;
  final bool filled;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: small ? 12 : 14, color: fg),
          const SizedBox(width: 5),
        ],
        Text(label,
            style: TextStyle(
                color: fg, fontSize: small ? 11 : 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class PrimaryBtn extends StatelessWidget {
  const PrimaryBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = PosColors.blue,
    this.enabled = true,
    this.busy = false,
    this.height = 52,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final bool enabled;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final on = enabled && !busy && onTap != null;
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: on ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: on ? color : PosColors.iconChip,
          foregroundColor: on ? Colors.white : PosColors.muted,
          disabledBackgroundColor: PosColors.iconChip,
          disabledForegroundColor: PosColors.muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ]),
      ),
    );
  }
}

class GhostBtn extends StatelessWidget {
  const GhostBtn({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.height = 52,
    this.color = PosColors.blue,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final on = enabled && onTap != null;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: on ? onTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: on ? color : PosColors.muted,
          side: BorderSide(color: on ? color.withValues(alpha: 0.6) : PosColors.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(
                color: PosColors.blue,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );
}

class KV extends StatelessWidget {
  const KV({super.key, required this.k, required this.v, this.bold = false, this.mono = false});
  final String k;
  final String v;
  final bool bold;
  final bool mono;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: PosColors.label, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: mono ? 13 : 15,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ),
        ]),
      );
}

/// Tanlov pilli — bosilsa pastdan ro'yxat chiqadi (filtr/qabul qiluvchi).
class ChoicePill<T> extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.icon,
  });
  final String label;
  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final current = options.where((e) => e.key == value).map((e) => e.value).firstOrNull ?? '—';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(label, style: const TextStyle(color: PosColors.label, fontSize: 13)),
        ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? () => _open(context) : null,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: PosColors.field,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: enabled ? PosColors.blue.withValues(alpha: 0.5) : PosColors.cardBorder),
            ),
            child: Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: enabled ? PosColors.blue : PosColors.muted),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(current,
                    overflow: TextOverflow.ellipsis,
                    textAlign: icon == null ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                        color: enabled ? Colors.white : PosColors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.expand_more_rounded, color: enabled ? PosColors.blue : PosColors.muted),
            ]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _open(BuildContext context) async {
    final r = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: PosColors.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final o in options)
              ListTile(
                title: Text(o.value,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: o.key == value ? FontWeight.w700 : FontWeight.w500)),
                trailing: o.key == value
                    ? const Icon(Icons.check_rounded, color: PosColors.blue)
                    : null,
                onTap: () => Navigator.of(context).pop(o.key),
              ),
          ],
        ),
      ),
    );
    if (r != null) onChanged(r);
  }
}

/// Yozuv maydoni — AIBA uslubi (label ustida, to'ldirilgan fon).
class AibaField extends StatelessWidget {
  const AibaField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
    this.onChanged,
    this.enabled = true,
    this.suffix,
    this.autofocus = false,
    this.prefixIcon,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? suffix;
  final bool autofocus;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
      style: TextStyle(
          color: enabled ? Colors.white : PosColors.muted,
          fontSize: 16,
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, color: PosColors.muted, size: 20),
        labelStyle: const TextStyle(color: PosColors.label, fontSize: 13),
        hintStyle: const TextStyle(color: PosColors.muted),
        suffixStyle: const TextStyle(color: PosColors.label),
        filled: true,
        fillColor: PosColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PosColors.cardBorder)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PosColors.cardBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PosColors.blue, width: 1.5)),
      ),
    );
  }
}

/// Sana tanlash — Yil / Oy / Kun (eski Bozorkom oynasidagidek).
Future<String?> pickIsoDate(BuildContext context, Tr tr, String loc, String current) async {
  final parts = current.split('-').map(int.tryParse).toList();
  var y = parts.length == 3 ? (parts[0] ?? DateTime.now().year) : DateTime.now().year;
  var m = parts.length == 3 ? (parts[1] ?? DateTime.now().month) : DateTime.now().month;
  var d = parts.length == 3 ? (parts[2] ?? DateTime.now().day) : DateTime.now().day;
  final months = kMonths[loc] ?? kMonths['uz']!;
  final now = DateTime.now().year;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final maxD = DateTime(y, m + 1, 0).day;
        if (d > maxD) d = maxD;
        Widget dd<T>(String label, T v, List<MapEntry<T, String>> opts, ValueChanged<T> on) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoicePill<T>(label: label, value: v, options: opts, onChanged: on),
            );
        return AlertDialog(
          backgroundColor: PosColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr('pickDate'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontSize: 22)),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              dd<int>(tr('year'), y,
                  [for (var i = now - 3; i <= now + 1; i++) MapEntry(i, '$i')],
                  (v) => setS(() => y = v)),
              dd<int>(tr('month'), m,
                  [for (var i = 1; i <= 12; i++) MapEntry(i, months[i - 1])],
                  (v) => setS(() => m = v)),
              dd<int>(tr('day'), d,
                  [for (var i = 1; i <= maxD; i++) MapEntry(i, '$i')],
                  (v) => setS(() => d = v)),
            ]),
          ),
          actions: [
            GhostBtn(label: tr('cancel'), height: 44, onTap: () => Navigator.of(ctx).pop()),
            PrimaryBtn(
                label: tr('ok'),
                height: 44,
                onTap: () => Navigator.of(ctx).pop(
                    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}')),
          ],
        );
      },
    ),
  );
}

/// Bo'sh holat.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.note});
  final IconData icon;
  final String title;
  final String? note;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        // Kichik joyda (karta ichida) ixcham: kichik ikon, kam bo'shliq, izohsiz.
        final small = c.maxHeight.isFinite && c.maxHeight < 200;
        final pad = small ? 12.0 : 32.0;
        final box = small ? 44.0 : 72.0;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: box, height: box,
                decoration: BoxDecoration(
                    color: PosColors.iconChip, borderRadius: BorderRadius.circular(small ? 12 : 20)),
                child: Icon(icon, color: PosColors.muted, size: small ? 22 : 34),
              ),
              SizedBox(height: small ? 8 : 16),
              Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white, fontSize: small ? 14 : 17, fontWeight: FontWeight.w700)),
              if (note != null && !small) ...[
                const SizedBox(height: 6),
                Text(note!, textAlign: TextAlign.center,
                    style: const TextStyle(color: PosColors.muted, fontSize: 14)),
              ],
            ]),
          ),
        );
      });
}
