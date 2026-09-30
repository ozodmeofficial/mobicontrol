# MobiControl

Telefoningizdagi ilovalardan **faqat belgilangan vaqtda** foydalanish imkonini
beruvchi Flutter ilovasi. Siz **bitta umumiy jadval** belgilaysiz (masalan,
12:00–13:00 va 20:00–21:00), tanlagan **barcha ilovalar** shu jadvalga bo'ysunadi:
boshqa vaqtda ularni ochishga urinsangiz, bloklash ekrani chiqadi.

> Platforma: **Android** (API 24+). iOS'da boshqa ilovalarni bloklash faqat
> Apple'ning Screen Time (FamilyControls) API'si orqali, maxsus ruxsat
> (entitlement) bilan mumkin, shuning uchun hozircha faqat Android qo'llab-quvvatlanadi.

## Yuklab olish

Tayyor APK: [Releases](../../releases) sahifasidan `MobiControl.apk` ni yuklab,
telefonga o'rnating ("Noma'lum manbalardan o'rnatish"ga ruxsat berish kerak bo'ladi).

## Imkoniyatlar

- **Umumiy jadval**: bir nechta ruxsat berilgan vaqt oraliqlari, har birining
  "Dan" va "Gacha" vaqtini o'zingiz tanlaysiz (yarim tundan o'tuvchi oraliqlar
  ham mumkin, masalan 22:00–02:00).
- **Cheklov kunlari**: masalan, faqat ish kunlari cheklash, dam olish kunlari erkin.
- Oraliq qo'shilmasa — tanlangan ilovalar o'sha kunlari **butunlay bloklanadi**.
- **Istalgan ilovani** tanlash: telefondagi barcha ilovalar ro'yxati, qidiruv
  va **"Hammasini tanlash"** tugmasi.
- Jadvalni bitta tugma bilan yoqish/o'chirish.
- Ilova ochiq turgan paytda ruxsat vaqti tugasa ham (~15 soniya ichida) bloklanadi.
- Bosh ekran (launcher) va qo'ng'iroq ilovasi hech qachon bloklanmaydi —
  favqulodda qo'ng'iroq har doim mumkin.

## Qanday ishlaydi

| Qism | Fayl | Vazifasi |
|---|---|---|
| Flutter UI | `lib/screens/` | Jadvalni sozlash, ilovalarni tanlash |
| Jadval mantiqi | `lib/models/schedule.dart` | Vaqt oraliqlari, JSON, `isAllowedAt()` |
| Aloqa | `lib/services/native_bridge.dart` | `MethodChannel` (`uz.mobicontrol/native`) |
| Saqlash | `android/.../RuleStore.kt` | Jadval va ilovalar Android `SharedPreferences`'da |
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
3. **Umumiy jadval**da "Dan"/"Gacha" vaqtlarini va kunlarni belgilang.
4. **"Tanlash"** → jadvalga bo'ysunadigan ilovalarni belgilang → **Saqlash**.

Ba'zi ishlab chiqaruvchilar (Xiaomi, Huawei, Samsung va b.) fon xizmatlarini
o'chirib qo'yishi mumkin — MobiControl uchun batareya optimallashtirishni
o'chirib qo'yish tavsiya etiladi.

## Release chiqarish (GitHub Actions)

`.github/workflows/build.yml` har bir push'da testlarni ishga tushirib, APK
yig'adi (Actions → artifact `MobiControl-apk`). `v` bilan boshlanuvchi teg
qo'yilganda Release yaratilib, APK unga biriktiriladi:

```bash
git tag v1.0.1
git push origin v1.0.1
```

Standart holatda APK **debug kaliti** bilan imzolanadi. Yangilanishlar eski
versiya ustiga o'rnatilishi uchun o'z kalitingizni yarating va repo
sozlamalariga (*Settings → Secrets and variables → Actions*) qo'shing:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias mobicontrol
base64 -w0 release.jks   # natijani KEYSTORE_BASE64 ga qo'ying
```

Secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

## Testlar

```bash
flutter test
```

## Cheklovlar

- Foydalanuvchi Accessibility xizmatini sozlamalardan o'zi o'chirib qo'yishi
  yoki MobiControl'ni o'chirib yuborishi mumkin — ilova o'z-o'zini nazorat
  qilish uchun mo'ljallangan, ota-ona nazorati darajasidagi himoya emas.
