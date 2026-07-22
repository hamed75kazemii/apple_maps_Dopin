# مارکرهای نیتیو Dopin (iOS)

یک نوع مارکر واحد: تصویر + بردر + لیبل اختیاری پایین.

## استفاده

```dart
Annotation(
  annotationId: AnnotationId('user_1'),
  position: LatLng(lat, lng),
  onTap: () => onTap(),
  dopinMarker: DopinMarker(
    imageUrls: [avatarUrl],           // یا چند URL تا ۴ تا
    count: 12,                        // null = بدون بج شمارنده
    label: 'Me',              // null یا خالی = بدون بج
    width: 40,
    height: 40,
    borderWidth: 2,
    borderColor: Colors.white,
    borderRadius: 12,         // null = دایره
    labelFontSize: 10,
    labelColor: AppConstants.primaryColor,
    labelBackgroundColor: Colors.white,
  ),
),
```

## فیلدها

| فیلد | پیش‌فرض | توضیح |
|------|---------|--------|
| `imageUrls` / `imagePng` / `withAssetImage` | — | تصویر (۱ تا ۴ URL) |
| `label` | `null` | متن بج پایین؛ اگر نباشد بج رسم نمی‌شود |
| `count` | `null` | بج شمارنده گوشه بالا-راست؛ بالای ۹ → `9+` |
| `width` / `height` | `40` | اندازه قاب بیرونی (ثابت برای همه چیدمان‌ها) |
| `borderWidth` | `2` | ضخامت بردر |
| `borderColor` | سفید | رنگ بردر |
| `borderRadius` | `null` → **دایره** | گوشه قاب |
| `labelFontSize` | `10` | اندازه فونت لیبل |
| `badgeHeight` | `18` | ارتفاع بج |
| `labelColor` | بنفش | رنگ متن لیبل |
| `labelBackgroundColor` | سفید | رنگ پس‌زمینه بج لیبل |
| `labelBackgroundGradientColors` | `null` | گرادیان قطری پس‌زمینه بج از بالا-چپ به پایین-راست (۲+ رنگ؛ جایگزین `labelBackgroundColor`) |

## سایه (`shadow` روی [Annotation])

```dart
Annotation(
  annotationId: AnnotationId('user_1'),
  position: LatLng(lat, lng),
  shadow: const MarkerShadow(),
  dopinMarker: DopinMarker(imageUrls: [avatarUrl]),
),
```

| فیلد | پیش‌فرض | توضیح |
|------|---------|--------|
| `color` | `0x4D000000` | رنگ سایه (alpha = شدت، ۳۰٪ مشکی) |
| `blurRadius` | `18` | میزان بلور |
| `offset` | `(0, 4)` | جابه‌جایی سایه |

## چیدمان چند تصویر (`imageUrls`) — چند Dopin در یک لوکیشن

| تعداد | چیدمان |
|------|--------|
| ۱ | تک آواتار (دایره یا squircle با بردر) |
| ۲ | stack چرخیده (مثل کلاستر) — ۲ آواتار |
| ۳ | stack چرخیده — ۳ آواتار |
| ۴+ | stack — ۳ آواتار + متن `N more` / `N+ more` زیر |

اگر `count` بزرگ‌تر از تعداد `imageUrls` باشد، همان stack با متن باقی‌مانده نمایش داده می‌شود (مثلاً ۳ URL + `count: 10` → `7+ more`).

```dart
DopinMarker(
  imageUrls: [url1, url2, url3], // تا ۴ URL
  count: 10,                     // اختیاری: تعداد کل
)
```

## PNG / asset

```dart
DopinMarker.withPng(imagePng: bytes, borderRadius: null) // دایره

await DopinMarker.withAssetImage(
  createLocalImageConfiguration(context),
  'assets/icon.png',
  label: '12',
  width: 72,
  height: 72,
);
```

نمونه: `consumer_sample/lib/main.dart`

## دیالوگ بالای مارکر

### پیل تیره (`MarkerDialog`)

```dart
Annotation(
  annotationId: AnnotationId('user_1'),
  position: LatLng(lat, lng),
  dopinMarker: DopinMarker(imageUrls: [avatarUrl]),
  dialog: const MarkerDialog(
    text: '1 Market Street San Francisco California',
  ),
)
```

عرض ثابت؛ متن بلند با مارکی راست‌به‌چپ اسکرول می‌شود.

### کلاد دیالوگ باکس (`CloudDialogBox`)

حباب فکر ابری با پس‌زمینه **گلس** (بلور نقشه + تینت نیمه‌شفاف)، مطابق طرح Figma.

```dart
Annotation(
  annotationId: AnnotationId('craving'),
  position: LatLng(lat, lng),
  dopinMarker: DopinMarker(imageUrls: [avatarUrl]),
  dialog: const CloudDialogBox(
    text: "I'm craving pizza.🍕",
  ),
)
```

| فیلد | پیش‌فرض Cloud | توضیح |
|------|---------------|--------|
| `text` | — | حداکثر ۴۰ کاراکتر؛ هر خط ۲۰ کاراکتر (سخت‌شکسته) |
| `width` / `height` | `0` = **auto** | اندازه بدنه؛ `0` یعنی متناسب با متن |
| `backgroundColor` | `0x28FFFFFF` | تینت گلس (سفید شفاف روی بلور) |
| `textColor` | مشکی (`Colors.black`) | رنگ فونت متن داخل ابر |
| `fontSize` | `12` | اندازه فونت |
| `horizontalPadding` | `4` | پدینگ افقی متن |
| `gapAboveMarker` | `-5` | هم‌پوشانی کم دم با مارکر (دایره کوچک نزدیک آواتار) |

```dart
dialog: const CloudDialogBox(
  text: "I'm craving pizza!!!Let's eat together!🍕",
  textColor: Colors.black, // پیش‌فرض
),
```

دیالوگ قبلی (`MarkerDialog`) همچنان در دسترس است؛ هر دو از `Annotation.dialog` استفاده می‌کنند. روی مارکر موقعیت من هم با `MyLocationMarker.dialog` قابل استفاده‌اند:

```dart
AppleMap(
  myLocationMarker: MyLocationMarker(
    imageUrl: avatarUrl,
    dialog: const CloudDialogBox(
      text: "I'm craving pizza.🍕",
      textColor: Colors.black,
    ),
  ),
)
```

لمس مارکر: برای `Annotation` با `onTap`، کلیک روی مارکر (و خود دیالوگ) همان `onTap` را صدا می‌زند — ساب‌ویوهای دیالوگ `userInteraction` ندارند و تپ را بلاک نمی‌کنند. `MyLocationMarker` فعلاً `onTap` جدا ندارد.

## کلاسترینگ نیتیو (iOS 11+)

وقتی مارکرها در یک سطح زوم روی هم می‌افتند، MapKit آن‌ها را در یک **مارکر کلاستر** ادغام می‌کند (پیش‌نمایش چند آواتار چرخیده + متن `N+ more`). با زوم یا پَن، کلاستر با **fade** به مارکرهای تکی تبدیل می‌شود. لمس کلاستر نقشه را روی ناحیه اعضا زوم می‌کند.

```dart
AppleMap(
  clusteringEnabled: true, // پیش‌فرض: true
  annotations: markers,
)
```

| رفتار | توضیح |
|--------|--------|
| انواع مارکر | `DopinMarker`، `SvgMarker`، `CardMarker`، bitmap و pin |
| دیالوگ بالای مارکر | `Annotation.dialog` با `MarkerDialog` (پیل تیره) یا `CloudDialogBox` (ابر گلس) |
| غیرفعال | `clusteringEnabled: false` |
| لمس کلاستر | زوم خودکار (بدون `onTap` تک‌مارکر) |
| مارکر موقعیت من | در کلاستر شرکت نمی‌کند |

