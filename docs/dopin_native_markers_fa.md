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
| غیرفعال | `clusteringEnabled: false` |
| لمس کلاستر | زوم خودکار (بدون `onTap` تک‌مارکر) |
| مارکر موقعیت من | در کلاستر شرکت نمی‌کند |

