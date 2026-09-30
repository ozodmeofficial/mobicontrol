# MobiControl

Telefoningizdagi ilovalardan **faqat belgilangan vaqtlarda** foydalanish imkonini
beruvchi Flutter ilovasi. Masalan: Instagram faqat 12:00–13:00 va 20:00–21:00
oralig'ida ochiladi, qolgan vaqtda uni ochishga urinsangiz, bloklash ekrani chiqadi.

> Platforma: **Android** (API 24+). iOS'da boshqa ilovalarni bloklash faqat
> Apple'ning Screen Time (FamilyControls) API'si orqali, maxsus ruxsat
> (entitlement) bilan mumkin, shuning uchun hozircha faqat Android qo'llab-quvvatlanadi.

## Imkoniyatlar

- O'rnatilgan ilovalar ro'yxatidan (qidiruv bilan) ilovani tanlash.
- Har bir ilova uchun bir nechta **ruxsat berilgan vaqt oraliqlari**
  (yarim tundan o'tuvchi oraliqlar ham, masalan 22:00–02:00).
- **Cheklov kunlari**: masalan, faqat ish kunlari cheklash, dam olish kunlari erkin.
- Oraliq qo'shilmasa — ilova tanlangan kunlarda **butunlay bloklanadi**.
- Har bir cheklovni tezda yoqish/o'chirish.
- Ilova ochiq turgan paytda ruxsat vaqti tugasa ham (~15 soniya ichida) bloklanadi.
- Bosh ekranda har bir ilovaning hozirgi holati: "ruxsat berilgan" / "bloklangan".

## Qanday ishlaydi

| Qism | Fayl | Vazifasi |
|---|---|---|
| Flutter UI | `lib/screens/` | Ilovalarni tanlash, jadvalni tahrirlash |
| Jadval mantiqi | `lib/models/app_rule.dart` | Vaqt oraliqlari, JSON, `isAllowedAt()` |
| Aloqa | `lib/services/native_bridge.dart` | `MethodChannel` (`uz.mobicontrol/native`) |
| Saqlash | `android/.../RuleStore.kt` | Qoidalar Android `SharedPreferences`'da |
| Bloklovchi | `android/.../AppBlockerService.kt` | `AccessibilityService`: oldinga chiqqan ilovani aniqlab, kerak bo'lsa bloklaydi |
| Bloklash ekrani | `android/.../BlockActivity.kt` | "Ilova hozir bloklangan" ekrani |

Bloklash uchun Android'ning **Maxsus imkoniyatlar (Accessibility)** xizmati
ishlatiladi: u faqat qaysi ilova oynasi ochilganini (paket nomini) biladi,
ekrandagi matnlarni o'qimaydi (`canRetrieveWindowContent="false"`) va hech
qanday ma'lumotni tarmoqqa yubormaydi. Xizmat MobiControl yopiq bo'lsa ham va
telefon qayta yoqilgandan keyin ham ishlayveradi.

## Ishga tushirish

```bash
flutter pub get
flutter run            # telefon USB orqali ulangan bo'lsin
# yoki
flutter build apk --release
```

Ilk ishga tushirishda:

1. Bosh ekrandagi **"Sozlamalarni ochish"** tugmasini bosing.
2. *Maxsus imkoniyatlar → O'rnatilgan ilovalar → MobiControl ilova bloklagichi*
   bo'limida xizmatni yoqing.
   Android 13+ da, agar ilova Play Market'dan emas, APK orqali o'rnatilgan
   bo'lsa, avval *Sozlamalar → Ilovalar → MobiControl → ⋮ → Cheklangan
   sozlamalarga ruxsat berish* ni bosish kerak bo'lishi mumkin.
3. **"Ilova qo'shish"** → ilovani tanlang → vaqt oraliqlari va kunlarni belgilang → **Saqlash**.

Ba'zi ishlab chiqaruvchilar (Xiaomi, Huawei, Samsung va b.) fon xizmatlarini
o'chirib qo'yishi mumkin — MobiControl uchun batareya optimallashtirishni
o'chirib qo'yish tavsiya etiladi.

## Testlar

```bash
flutter test
```

## Cheklovlar

- Foydalanuvchi Accessibility xizmatini sozlamalardan o'zi o'chirib qo'yishi
  yoki MobiControl'ni o'chirib yuborishi mumkin — ilova o'z-o'zini nazorat
  qilish uchun mo'ljallangan, ota-ona nazorati darajasidagi himoya emas.
