# مارکرهای نیتیو Dopin (iOS)

یک نوع مارکر واحد: تصویر + بردر + لیبل اختیاری پایین.

## استفاده

```dart
Annotation(
  annotationId: AnnotationId('user_1'),
  position: LatLng(lat, lng),
  onTap: () => onTap(),
  dopinMarker: DopinMarker(
    imageUrl: avatarUrl,
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
| `imageUrl` / `imagePng` / `withAssetImage` | — | تصویر |
| `label` | `null` | متن بج پایین؛ اگر نباشد بج رسم نمی‌شود |
| `width` / `height` | `40` | اندازه قاب (بیرون) |
| `borderWidth` | `2` | ضخامت بردر |
| `borderColor` | سفید | رنگ بردر |
| `borderRadius` | `null` → **دایره** | گوشه قاب |
| `labelFontSize` | `10` | اندازه فونت لیبل |
| `badgeHeight` | `18` | ارتفاع بج |
| `labelColor` | بنفش | رنگ متن لیبل |

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
