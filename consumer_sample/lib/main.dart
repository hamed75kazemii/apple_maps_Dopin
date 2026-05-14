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
  String _status = 'در انتظار ساخت نقشه…';
  BitmapDescriptor? _widgetMarkerIcon;

  static const CameraPosition _losAngeles = CameraPosition(
    target: LatLng(34.0522, -118.2437),
    zoom: 11,
  );

  /// هر ویجتی که اینجا برمی‌گردد به PNG تبدیل می‌شود و روی نقشه به‌عنوان مارکر دیده می‌شود.
  Widget _customMarkerWidget() {
    return Container(
      width: 20,
      height: 20,

      // padding: EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple),
    );
  }

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
        marker: _customMarkerWidget(),
        logicalSize: const Size(50, 50),
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
            child: Text(_status, style: Theme.of(context).textTheme.bodyMedium),
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
                        anchor: const Offset(0.5, 0.5),
                        glow: true,
                        glowColor: const Color(0xFFEC30E4),
                        glowIntensity: 1,
                      ),
                    },
              onTap: (LatLng point) {
                setState(() {
                  _status =
                      'ضربه: ${point.latitude.toStringAsFixed(4)}, '
                      '${point.longitude.toStringAsFixed(4)}';
                });
              },
              onPOITap: (ApplePOIDetail poi) {
                setState(() {
                  _status =
                      'POI: ${poi.name ?? "?"}'
                      '${poi.category != null ? " · ${poi.category}" : ""}'
                      ' (${poi.latitude.toStringAsFixed(4)}, '
                      '${poi.longitude.toStringAsFixed(4)})';
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
