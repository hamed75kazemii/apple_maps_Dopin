# مارکرهای نیتیو Dopin (iOS)

مارکرهای `me`، `event`، `dopin` و `cluster` روی Apple Maps در Swift رسم می‌شوند (بدون تبدیل ویجت به PNG).

## استفاده در Flutter

```dart
// URL
dopinMarker: DopinMarker(
  style: DopinMarkerStyle.me,
  imageUrl: 'https://cdn.example.com/avatar.jpg',
),

// PNG bytes
dopinMarker: DopinMarker.withPng(
  style: DopinMarkerStyle.event,
  imagePng: pngBytes,
),

// PNG از asset
final marker = await DopinMarker.withAssetImage(
  createLocalImageConfiguration(context),
  'assets/logo/event_marker.png',
  style: DopinMarkerStyle.event,
);
```

| فیلد | توضیح |
|------|--------|
| `annotationId` | شناسه یکتا؛ در `annotation#onTap` به Flutter برمی‌گردد |
| `onTap` | همان callback کلیک مارکر |
| `infoWindow.title` | نام / عنوان (اختیاری) |
| `dopinMarker.imageUrl` | URL تصویر |
| `dopinMarker.imagePng` | بایت‌های PNG (`DopinMarker.withPng`) |
| `DopinMarker.withAssetImage` | PNG از asset فلاتر |
| `dopinMarker.style` | `me` \| `event` \| `dopin` \| `cluster` |
| `dopinMarker.clusterCount` | فقط برای `cluster` |
| `dopinMarker.borderColor` | رنگ حاشیه/رینگ (پیش‌فرض سفید) |
| `dopinMarker.primaryColor` / `secondPrimaryColor` | گرادیان بج «Me» و کلاستر |
| `anchor` | برای `cluster` معمولاً `Offset(0.5, 0.5)` |

## انواع

- **me**: قاب گرادیان، آواتار ۴۰×۴۰، بج «Me»
- **event**: دایره ۴۰×۴۰، حاشیه سفید، سایه
- **dopin**: گوشه ۱۲، حاشیه سفید ۳px، سایه نرم
- **cluster**: حلقه گرادیان، عدد (بیش از ۹ → `9+`)

## نمونه

`consumer_sample/lib/main.dart`
