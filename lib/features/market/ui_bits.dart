// BOZOR ilovasining umumiy UI bo'laklari — uch ekran (Zakaz / Bozor / Qabul)
// bir xil ko'rinsin uchun bitta joyda: sana paneli, guruh sarlavhasi, bo'sh
// ro'yxat holati, xabar qatori, sonli maydon va formatlash yordamchilari.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/pos_chrome.dart';

// ── Formatlash ───────────────────────────────────────────────────────────────

/// 2.500 → «2.5», 80.000 → «80» (ortiqcha nollar tashlanadi).
String fmtQty(double v) =>
    v.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');

/// 1334000 → «1 334 000».
String money(double v) => v
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

/// Birlik ko'rinishi: bazada «dona», ekranda «ta».
String unitUz(String u) => u == 'dona' ? 'ta' : u;

/// «2026-09-02» → «02.09.2026».
String prettyDay(String iso) {
  final d = DateTime.parse(iso);
  return '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Sanani kun bo'yicha suradi (ISO ichida qaytadi).
String shiftDay(String iso, int days) {
  final d = DateTime.parse(iso).add(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// «2026-09-02T10:12:00» → «02.09 10:12».
String prettyStamp(String iso) {
  try {
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

/// Bugun / Ertaga / Kecha — sana panelida ko'rsatiladi.
String dayWord(String iso) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime.parse(iso);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  return switch (diff) {
    0 => 'Bugun',
    1 => 'Ertaga',
    -1 => 'Kecha',
    _ => '',
  };
}

// ── Sana paneli ──────────────────────────────────────────────────────────────

/// Uch ekranda bir xil: ‹ sana › ⟳ … (o'ngda ixtiyoriy tugma).
class DayBar extends StatelessWidget {
  const DayBar({
    super.key,
    required this.date,
    required this.onShift,
    this.onRefresh,
    this.trailing,
  });

  final String date;
  final ValueChanged<int> onShift;
  final VoidCallback? onRefresh;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final word = dayWord(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: PosColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PosColors.cardBorder),
      ),
      child: Row(children: [
        _RoundBtn(icon: Icons.chevron_left, onTap: () => onShift(-1)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prettyDay(date),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, height: 1.15)),
            if (word.isNotEmpty)
              Text(word,
                  style: const TextStyle(
                      color: PosColors.muted, fontSize: 11, height: 1.2)),
          ],
        ),
        _RoundBtn(icon: Icons.chevron_right, onTap: () => onShift(1)),
        if (onRefresh != null)
          _RoundBtn(icon: Icons.refresh, size: 20, onTap: onRefresh!),
        const Spacer(),
        ?trailing,
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.size = 26});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: Colors.white70),
      ),
    );
  }
}

// ── Ro'yxat bo'laklari ───────────────────────────────────────────────────────

/// «Qabul qilinadigan · 2» — guruh sarlavhasi rangli nuqta bilan.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.title,
    required this.count,
    required this.color,
  });
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(title.toUpperCase(),
            style: const TextStyle(
                color: PosColors.label,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .7)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: PosColors.cardBorder, height: 1)),
      ]),
    );
  }
}

/// Bo'sh ro'yxat — nima qilish kerakligini aytadigan holat.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.note,
  });
  final IconData icon;
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: PosColors.iconChip, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: PosColors.muted),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            if (note != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(note!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: PosColors.muted, fontSize: 13.5, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Amal natijasi — yashil (bo'ldi) yoki qizil (xato) qator.
class MsgLine extends StatelessWidget {
  const MsgLine({super.key, required this.text, required this.error});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = error ? PosColors.red : PosColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: .35)),
      ),
      child: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: c, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(color: c, fontSize: 13.5, height: 1.35)),
        ),
      ]),
    );
  }
}

/// Narx maydonida raqamlarni terilayotgan payti 92000 → «92 000» qilib
/// guruhlaydi (bozorchi nol sonini adashtirmasin). Kursor o'z joyida qoladi.
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(' ', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    // Kursordan keyingi «haqiqiy» belgilar soni — formatlashdan keyin ham
    // shuncha belgi qolsin.
    final tail = newValue.text
        .substring(newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(' ', '')
        .length;
    final dot = raw.indexOf(RegExp(r'[.,]'));
    final intPart = dot < 0 ? raw : raw.substring(0, dot);
    final rest = dot < 0 ? '' : raw.substring(dot);
    final grouped = intPart.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    final text = grouped + rest;
    var pos = text.length;
    var seen = 0;
    while (pos > 0 && seen < tail) {
      pos--;
      if (text[pos] != ' ') seen++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

// ── Maydonlar ────────────────────────────────────────────────────────────────

/// Sonli maydon: ustida DOIM ko'rinadigan yozuv (labelText suzib yurganda
/// bo'sh/to'la maydonlar bir-biriga nisbatan qiyshayib ketardi) va ichida
/// birlik ko'rsatkichi.
class NumField extends StatelessWidget {
  const NumField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.hint,
    this.onChanged,
    this.group = false,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? hint;
  final ValueChanged<String>? onChanged;

  /// true — minglar bo'sh joy bilan ajratiladi (narx maydoni).
  final bool group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: PosColors.label,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5)),
        ),
        SizedBox(
          height: 46,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: group ? const [ThousandsFormatter()] : null,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                  color: Color(0xFF565C64), fontWeight: FontWeight.w400),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              suffixText: suffix,
              suffixStyle:
                  const TextStyle(color: PosColors.muted, fontSize: 13),
              filled: true,
              fillColor: PosColors.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: PosColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: PosColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: PosColors.blue, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Qidiruv maydoni — foni va ramkasi ko'rinib turadi (avval fonda «yo'qolib»
/// ketardi).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Qidirish…',
    this.autofocus = false,
  });
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        onChanged: onChanged,
        autofocus: autofocus,
        style: const TextStyle(fontSize: 15.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6B7178)),
          prefixIcon: const Icon(Icons.search, size: 20, color: PosColors.muted),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: PosColors.field,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: PosColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: PosColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: PosColors.blue, width: 1.4),
          ),
        ),
      ),
    );
  }
}
