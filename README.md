# AIBA BOZOR — bozorchi planshet ilovasi

Restoranlar tarmog'i uchun bozor (xarid) ilovasi. Flutter (Android planshet).
AIBA POS backend'ining terminal `market` endpointlariga ulanadi.

## Kim nima qiladi
- **Menejer** (filial) — *Zakaz / Qabul / Tarix*: o'z filialiga kerak
  mahsulotlarni yozadi, bozordan kelganini qabul qiladi (omborga avto-kirim).
- **Bozorchi** — 2 tab:
  - **Jamlangan** — bir xil mahsulot hamma filial bo'yicha (masalan
    «Shakar · 25 kg — Chilonzor 10 + Yunusobod 15»), narxni bir marta yozadi,
    server hamma filialga tarqatadi.
  - **Filiallar** — har filialni alohida ochib oladi.

## Kirish
Terminal kodi (bir marta Sozlamalarda) + xodim kodi + parol (3–4 raqam).
Xodim panelda (**Boshqaruv → Xodimlar**) yaratiladi: rol «Bozorchi» yoki «Menejer».

## Build
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```
Har `main`ga push — GitHub Actions APK'ni quradi va `releases/tag/latest`ga qo'yadi.
