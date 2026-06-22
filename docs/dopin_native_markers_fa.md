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

## چیدمان چند تصویر (`imageUrls`)

| تعداد | اندازه قاب | چیدمان |
|------|------------|--------|
| ۱ | `width` × `height` | تک تصویر (دایره یا squircle با بردر) |
| ۲ | `width` × `height / 2` | دو تصویر کنار هم در کپسول افقی |
| ۳ | `width` × `height` | دو تصویر بالا + یکی وسط پایین |
| ۴ | `width` × `height` | گرید ۲×۲ |

عرض همه مارکرها یکسان است؛ فقط تصاویر داخل قاب کوچک‌تر می‌شوند.

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
