import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppleMapsConsumerApp());
}

class AppleMapsConsumerApp extends StatelessWidget {
  const AppleMapsConsumerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Maps (fork test)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MapSmokeTestScreen(),
    );
  }
}

class MapSmokeTestScreen extends StatefulWidget {
  const MapSmokeTestScreen({super.key});

  @override
  State<MapSmokeTestScreen> createState() => _MapSmokeTestScreenState();
}

class _MapSmokeTestScreenState extends State<MapSmokeTestScreen> {
  AppleMapController? _controller;
  String _status = 'روی یک مکان روی نقشه بزنید (POI — iOS 17+)';
  ApplePOIDetail? _selectedPoi;
  BitmapDescriptor? _widgetMarkerIcon;

  static const CameraPosition _losAngeles = CameraPosition(
    target: LatLng(34.0522, -118.2437),
    zoom: 11,
  );

  /// هر ویجتی که اینجا برمی‌گردد به PNG تبدیل می‌شود و روی نقشه به‌عنوان مارکر دیده می‌شود.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _buildWidgetMarkerIcon(),
    );
  }

  Future<void> _buildWidgetMarkerIcon() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!mounted) return;
    try {
      final BitmapDescriptor icon = await WidgetMarker.toBitmapDescriptor(
        context,
        marker: Icon(Icons.person),
        logicalSize: const Size(40, 40),
        pixelRatio: MediaQuery.devicePixelRatioOf(context).clamp(1.0, 4.0),
      );
      if (mounted) {
        setState(() {
          _widgetMarkerIcon = icon;
          _status =
              'نقشه + مارکر ویجتی با هالهٔ تکرارشونده تا وقتی glow روشن است.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'خطا در ساخت مارکر از ویجت: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Apple Maps — تست فورک')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'این پلاگین برای نمایش Apple Map روی iOS طراحی شده است.\n'
              'روی شبی‌ساز یا دستگاه iOS اجرا کنید.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Maps — تست فورک'),
        actions: [
          IconButton(
            tooltip: 'مرکز روی لس‌آنجلس',
            onPressed: _controller == null
                ? null
                : () async {
                    await _controller!.moveCamera(
                      CameraUpdate.newCameraPosition(_losAngeles),
                    );
                  },
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _selectedPoi == null
                ? Text(_status, style: Theme.of(context).textTheme.bodyMedium)
                : _PoiInfoCard(poi: _selectedPoi!),
          ),
          Expanded(
            child: AppleMap(
              initialCameraPosition: _losAngeles,
              onMapCreated: (AppleMapController controller) {
                setState(() {
                  _controller = controller;
                  if (_widgetMarkerIcon == null) {
                    _status = 'نقشه آماده است؛ در حال ساخت مارکر ویجتی…';
                  }
                });
              },
              annotations: _widgetMarkerIcon == null
                  ? null
                  : <Annotation>{
                      Annotation(
                        annotationId: const AnnotationId('widget_marker'),
                        position: _losAngeles.target,
                        icon: _widgetMarkerIcon!,
                        //   anchor: const Offset(0.5, 0.5),
                        glow: true,
                        glowColor: const Color(0xFFEC30E4),
                        glowIntensity: 1,
                      ),
                    },
              // onTap: (LatLng point) {
              //   setState(() {
              //     _status =
              //         'ضربه: ${point.latitude.toStringAsFixed(4)}, '
              //         '${point.longitude.toStringAsFixed(4)}';
              //   });
              // },
              onPOITap: (ApplePOIDetail poi) {
                setState(() => _selectedPoi = poi);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت نمایش POI انتخاب‌شده همراه با آیکون MapKit.
class _PoiInfoCard extends StatelessWidget {
  const _PoiInfoCard({required this.poi});

  final ApplePOIDetail poi;

  Color? get _iconBackground {
    final int? argb = poi.iconColor;
    if (argb == null) return null;
    return Color(argb);
  }

  IconData _fallbackIcon() {
    switch (poi.icon ?? poi.category?.toLowerCase()) {
      case 'cafe':
        return Icons.local_cafe;
      case 'restaurant':
        return Icons.restaurant;
      case 'store':
      case 'foodmarket':
        return Icons.store;
      case 'museum':
        return Icons.museum;
      case 'park':
        return Icons.park;
      case 'hotel':
        return Icons.hotel;
      case 'gasstation':
        return Icons.local_gas_station;
      case 'hospital':
        return Icons.local_hospital;
      case 'school':
      case 'university':
        return Icons.school;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color? bg = _iconBackground;
    final png = poi.iconPng;

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bg ?? Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: png != null
                  ? Image.memory(
                      png,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    )
                  : Icon(
                      _fallbackIcon(),
                      size: 28,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poi.name ?? 'بدون نام',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (poi.category != null)
                    Text(
                      poi.category!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${poi.latitude.toStringAsFixed(5)}, '
                    '${poi.longitude.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
