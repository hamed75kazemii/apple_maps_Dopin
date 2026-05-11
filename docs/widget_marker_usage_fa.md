# استفاده از ویجت به‌عنوان مارکر نقشه (`WidgetMarker`)

این فورک با کلاس **`WidgetMarker`** اجازه می‌دهد هر **`Widget`** فلاتری را به تصویر PNG تبدیل کنید و همان را به‌عنوان **`BitmapDescriptor`** روی **`Annotation`** اپل مپ قرار دهید.

## نکتهٔ مهم (محدودیت MapKit)

روی iOS، مارکرهای **`MKMapView`** با **تصویر ثابت** (`UIImage`) رسم می‌شوند، نه با ویجت زندهٔ فلاتر.  
`WidgetMarker` ویجت را **یک‌بار رَستریزه** می‌کند؛ اگر محتوای ویجت عوض شود، باید دوباره `toBitmapDescriptor` را صدا بزنید و `Annotation` را به‌روز کنید.

## پیش‌نیازها

1. **`BuildContext`** باید زیر **`Overlay`** باشد (معمولاً داخل **`MaterialApp`** / **`Navigator`**).
2. ترجیحاً **`WidgetMarker`** را بعد از اولین فریم صدا بزنید تا `Overlay` آماده باشد، مثلاً با **`WidgetsBinding.instance.addPostFrameCallback`** یا بعد از **`build`** اول.
3. برای **نمایش روی نقشه**، اپ را روی **iOS** اجرا کنید؛ خود پلاگین فقط پلتفرم iOS را ثبت کرده است.

## API

### `WidgetMarker.toBitmapDescriptor`

```dart
Future<BitmapDescriptor> WidgetMarker.toBitmapDescriptor(
  BuildContext context, {
  required Widget marker,
  required Size logicalSize,
  double pixelRatio = 3.0,
  Duration settleTime = Duration.zero,
})
```

| پارامتر | توضیح |
|--------|--------|
| `context` | برای دسترسی به `Overlay`، `Theme`، `MediaQuery` و … |
| `marker` | همان ویجتی که می‌خواهید شکل مارکر باشد |
| `logicalSize` | اندازهٔ **منطقی** (dp) بوم رندر؛ باید با محتوای ویجت هم‌خوان باشد |
| `pixelRatio` | وضوح خروجی PNG (مثلاً `MediaQuery.of(context).devicePixelRatio`) |
| `settleTime` | تأخیر اختیاری قبل از عکس‌برداری؛ برای فونت/تصویر شبکه مفید است |

### `WidgetMarker.capturePng`

اگر فقط **`Uint8List`** PNG لاز دارید (مثلاً ذخیره یا پردازش):

```dart
Future<Uint8List> WidgetMarker.capturePng(
  BuildContext context, {
  required Widget marker,
  required Size logicalSize,
  double pixelRatio = 3.0,
  Duration settleTime = Duration.zero,
})
```

## مثال حداقلی

```dart
class _PageState extends State<Page> {
  BitmapDescriptor? _icon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _makeIcon());
  }

  Future<void> _makeIcon() async {
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 4.0);
    final icon = await WidgetMarker.toBitmapDescriptor(
      context,
      marker: MyMarkerChip(label: 'فروشگاه'),
      logicalSize: const Size(180, 44),
      pixelRatio: dpr,
    );
    if (mounted) setState(() => _icon = icon);
  }

  @override
  Widget build(BuildContext context) {
    return AppleMap(
      initialCameraPosition: /* ... */,
      annotations: _icon == null
          ? null
          : {
              Annotation(
                annotationId: AnnotationId('shop'),
                position: LatLng(35.6892, 51.3890),
                icon: _icon!,
                anchor: const Offset(0.5, 1.0),
              ),
            },
    );
  }
}
```

- **`anchor`**: نقطهٔ تصویر که روی مختصات جغرافیایی می‌نشیند؛ برای مارکر پایه‌دار معمولاً `Offset(0.5, 1.0)` (وسط پایین) مناسب است.

## نکات عملی

1. **اندازه (`logicalSize`)**  
   اگر کوچک‌تر از محتوا باشد، overflow می‌گیرید؛ اگر خیلی بزرگ باشد، PNG بی‌جهت بزرگ می‌شود.

2. **ویجت‌های وابسته به `Material`**  
   داخل `WidgetMarker` دور ویجت، **`Material` شفاف** گذاشته شده تا `InkWell`، `Chip` و … درست کار کنند.

3. **تصویر شبکه / آیکن با تاخیر**  
   اگر PNG خالی یا ناقص دیدید، `settleTime` را کمی زیاد کنید (مثلاً `Duration(milliseconds: 100)`).

4. **به‌روزرسانی مارکر**  
   بعد از تغییر ویجت، دوباره `toBitmapDescriptor` بگیرید و با `setState` همان `Annotation` را با `icon` جدید بسازید تا `AppleMap` به‌روز شود.

## ارجاع کد

- پیاده‌سازی: `lib/src/widget_marker.dart`
- نمونهٔ اجرایی: `consumer_sample/lib/main.dart` (تابع `_customMarkerWidget` و `_buildWidgetMarkerIcon`)
