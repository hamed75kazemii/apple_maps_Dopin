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
  String _status = 'Tap on markers';
  ApplePOIDetail? _selectedPoi;
  String? _lastTappedMarkerId;
  static const CameraPosition _losAngeles = CameraPosition(
    target: LatLng(34.0522, -118.2437),
    zoom: 12,
  );

  static const String _demoAvatarUrl = 'https://i.pravatar.cc/150?img=12';

  static const Color _labelColor = Color(0xFF7B2CBF);

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
          _status = 'PNG loaded';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error loading PNG: $e');
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
        imageUrl: _demoAvatarUrl,
        label: 'Me',
        width: 40,
        height: 40,
        borderWidth: 2,
        borderColor: Colors.white,
        borderRadius: 12,
        labelColor: _labelColor,
      ),
    ),

    // Annotation(
    //   annotationId: const AnnotationId('marker_circle'),
    //   position: const LatLng(34.0622, -118.2437),
    //   onTap: () => _onMarkerTap('marker_circle'),
    //   dopinMarker: DopinMarker.withPng(
    //     imagePng: _eventPng ?? Uint8List(0),
    //     width: 40,
    //     height: 40,
    //     borderWidth: 2,
    //     borderColor: Colors.white,
    //   ),
    // ),
    // Annotation(
    //   annotationId: const AnnotationId('marker_dopin'),
    //   position: const LatLng(34.0422, -118.2537),
    //   onTap: () => _onMarkerTap('marker_dopin'),
    //   dopinMarker: const DopinMarker(
    //     imageUrl: _demoAvatarUrl,
    //     width: 43,
    //     height: 43,
    //     borderWidth: 2,
    //     borderColor: Color(0xFFEC30E4),
    //     borderRadius: 12,
    //   ),
    // ),
    // Annotation(
    //   annotationId: const AnnotationId('marker_count'),
    //   position: const LatLng(34.0522, -118.2637),
    //   anchor: const Offset(0.5, 0.5),
    //   onTap: () => _onMarkerTap('marker_count'),

    //   dopinMarker: const DopinMarker(
    //     label: '12',
    //     width: 56,
    //     height: 56,
    //     borderWidth: 3,
    //     borderColor: Color(0xFFEC30E4),
    //     labelFontSize: 22,
    //     badgeHeight: 22,
    //     labelColor: _labelColor,
    //   ),
    // ),
  };

  void _onMarkerTap(String id) {
    log('onMarkerTap: $id');
    setState(() {
      _lastTappedMarkerId = id;
      _status = 'Marker tapped: $id';
      _selectedPoi = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Apple Maps')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This plugin is designed to display Apple Maps on iOS.\n'
              'روی شبیه‌ساز یا دستگاه iOS اجرا کنید.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Maps'),
        actions: [
          IconButton(
            tooltip: 'Center on Los Angeles',
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
              mapType: MapType.standard,
              globeAtMinZoom: true,
              minMaxZoomPreference: const MinMaxZoomPreference(0, 21),
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
                    poi.name ?? 'No name',
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
