# MobiControl

Telefoningizdagi ilovalardan **faqat belgilangan vaqtda** foydalanish imkonini
beruvchi Flutter ilovasi. Siz **bitta umumiy jadval** belgilaysiz (masalan,
12:00–13:00 va 20:00–21:00), tanlagan **barcha ilovalar** shu jadvalga bo'ysunadi:
boshqa vaqtda ularni ochishga urinsangiz, bloklash ekrani chiqadi.

> Platforma: **Android** (API 24+). iOS'da boshqa ilovalarni bloklash faqat
> Apple'ning Screen Time (FamilyControls) API'si orqali, maxsus ruxsat
> (entitlement) bilan mumkin, shuning uchun hozircha faqat Android qo'llab-quvvatlanadi.

## Yuklab olish va o'rnatish

Tayyor APK: [Releases](../../releases) sahifasidan `MobiControl.apk` ni yuklab,
telefonga o'rnating ("Noma'lum manbalardan o'rnatish"ga ruxsat berish kerak bo'ladi).

### Play Protect ogohlantirsa

Play Market'dan tashqarida tarqatilgan, Accessibility ishlatadigan ilovalarni
Google Play Protect ba'zan «tekshirilmagan» deb belgilaydi va o'rnatishni
to'xtatadi. Bu — ilova yomon degani emas, balki sideload + Accessibility
naqshiga qo'yilgan ehtiyot chorasi. **O'z telefoningizda** o'rnatish uchun:

- Ogohlantirishda **"Batafsil" (More details) → "Baribir o'rnatish"
  (Install anyway)** ni tanlang.
- Yoki *Sozlamalar → Xavfsizlik → Google Play Protect* da tekshiruvni
  vaqtincha o'chirib, o'rnatgandan so'ng qayta yoqing.

**Ogohlantirishsiz, «toza» tarqatishning to'g'ri yo'li** — ilovani Google Play
Console orqali chiqarish (hatto yopiq/ichki test — *internal testing* —
kanalida ham). Bunda ilova imzolanadi va ro'yxatdan o'tadi, Play Protect uni
ishonchli deb biladi. Buning uchun avval o'z imzo kalitingizni sozlang
(pastdagi "Release chiqarish" bo'limiga qarang).

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
- **PIN himoyasi** (ixtiyoriy): sozlamalarni o'zgartirish yoki cheklovni
  o'chirish uchun PIN so'raladi — o'zingizni bir zumda yumshatib yuborishdan
  ushlab turadi.
- **Sovish davri** (ixtiyoriy): cheklovni o'chirishdan oldin belgilangan vaqt
  (5–180 daqiqa) kutiladi, impulsni jilovlaydi.

> **Muhim:** bu himoyalar faqat _ilova ichidagi sozlamalarni_ himoyalaydi.
> Telefon egasi ilovani baribir oddiy yo'l bilan (Sozlamalar → Ilovalar →
> O'chirish) olib tashlay oladi — bu ataylab shunday. MobiControl o'zini
> o'chirilishdan himoya qilmaydi va boshqa odam telefoniga yashirincha
> o'rnatish uchun mo'ljallanmagan.

## Qanday ishlaydi

| Qism | Fayl | Vazifasi |
|---|---|---|
| Flutter UI | `lib/screens/` | Jadvalni sozlash, ilovalarni tanlash |
| Jadval mantiqi | `lib/models/schedule.dart` | Vaqt oraliqlari, PIN/cooldown, JSON, `isAllowedAt()` |
| PIN | `lib/services/pin.dart` | Tuzli (salted) SHA-256 hash |
| PIN/cooldown UI | `lib/screens/pin_flow.dart` | PIN so'rash va sovish davri dialoglari |
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
yig'adi (Actions → artifact `MobiControl-apk`). Release chiqarish uchun ikki yo'l bor:

- GitHub'da *Actions → Build APK → Run workflow* ni bosib, `version` maydoniga
  masalan `1.0.1` yozing — `v1.0.1` tegi va Release avtomatik yaratiladi.
- Yoki teg push qiling: `git tag v1.0.1 && git push origin v1.0.1`.

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
