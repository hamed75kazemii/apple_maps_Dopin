import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/foundation.dart'
    show
        consolidateHttpClientResponseBytes,
        defaultTargetPlatform,
        kIsWeb,
        TargetPlatform;
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
  String _status = 'روی مارکرها بزنید — مارکرهای نیتیو Dopin';
  ApplePOIDetail? _selectedPoi;
  String? _lastTappedMarkerId;

  static const CameraPosition _losAngeles = CameraPosition(
    target: LatLng(34.0522, -118.2437),
    zoom: 12,
  );

  static const String _demoAvatarUrl = 'https://i.pravatar.cc/150?img=12';

  static const Color _primaryColor = Color(0xFF7B2CBF);
  static const Color _secondPrimaryColor = Color(0xFFEC30E4);

  /// PNG برای مارکر event (از URL به‌عنوان نمونه).
  Uint8List? _eventPng;

  @override
  void initState() {
    super.initState();
    _loadEventPng();
  }

  Future<void> _loadEventPng() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final HttpClientRequest request = await HttpClient().getUrl(
        Uri.parse(_demoAvatarUrl),
      );
      final HttpClientResponse response = await request.close();
      final Uint8List bytes = await consolidateHttpClientResponseBytes(
        response,
      );
      if (mounted) {
        setState(() {
          _eventPng = bytes;
          _status = 'مارکر event: تصویر PNG';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'خطا در لود PNG: $e');
      }
    }
  }

  Set<Annotation> get _dopinAnnotations => <Annotation>{
    Annotation(
      annotationId: const AnnotationId('marker_me'),
      position: const LatLng(34.0522, -118.2437),
      onTap: () => _onMarkerTap('marker_me'),

      glow: true,

      dopinMarker: const DopinMarker(
        style: DopinMarkerStyle.me,
        imageUrl: _demoAvatarUrl,
        label: 'Me',
        primaryColor: _primaryColor,
        secondPrimaryColor: _secondPrimaryColor,
      ),
    ),
    Annotation(
      annotationId: const AnnotationId('marker_event'),
      position: const LatLng(34.0622, -118.2437),
      onTap: () => _onMarkerTap('marker_event'),
      dopinMarker: DopinMarker.withPng(
        style: DopinMarkerStyle.event,
        imagePng: _eventPng ?? Uint8List(0),
        borderColor: Colors.white,
      ),
    ),
    Annotation(
      //    visible: false,
      annotationId: const AnnotationId('marker_dopin'),
      position: const LatLng(34.0422, -118.2537),
      onTap: () => _onMarkerTap('marker_dopin'),

      dopinMarker: const DopinMarker(
        style: DopinMarkerStyle.dopin,
        imageUrl: _demoAvatarUrl,
        borderColor: _secondPrimaryColor,
      ),
    ),
    Annotation(
      annotationId: const AnnotationId('marker_cluster'),
      position: const LatLng(34.0522, -118.2637),
      anchor: const Offset(0.5, 0.5),
      onTap: () => _onMarkerTap('marker_cluster'),
      dopinMarker: const DopinMarker(
        style: DopinMarkerStyle.cluster,
        clusterCount: 12,
      ),
    ),
  };

  void _onMarkerTap(String id) {
    log('onMarkerTap: $id');
    setState(() {
      _lastTappedMarkerId = id;
      _status = 'کلیک مارکر: $id';
      _selectedPoi = null;
    });
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
              'روی شبیه‌ساز یا دستگاه iOS اجرا کنید.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Maps — مارکر Dopin'),
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
            child: _selectedPoi != null
                ? _PoiInfoCard(poi: _selectedPoi!)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _status,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_lastTappedMarkerId != null)
                        Text(
                          'annotationId: $_lastTappedMarkerId',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                    ],
                  ),
          ),
          Expanded(
            child: AppleMap(
              initialCameraPosition: _losAngeles,
              onMapCreated: (AppleMapController controller) {
                setState(() => _controller = controller);
              },
              annotations: _dopinAnnotations,
              onPOITap: (ApplePOIDetail poi) {
                setState(() {
                  _selectedPoi = poi;
                  _lastTappedMarkerId = null;
                });
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
