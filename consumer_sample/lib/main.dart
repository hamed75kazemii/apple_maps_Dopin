import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
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
  String _status = 'Tap a POI on the map to enter focus mode';
  ApplePOIDetail? _focusedPoi;
  String? _lastTappedMarkerId;
  CameraPosition? _cameraBeforeFocus;
  CameraPosition? _lastCameraPosition;
  double? _focusZoom;
  double _verticalScreenOffset = 0;

  int _focusGeneration = 0;
  bool _focusTransitionActive = false;
  bool _gesturesLocked = false;
  Completer<void>? _cameraIdleCompleter;

  static const Duration _focusFlyDuration = Duration(milliseconds: 420);

  static const CameraPosition _losAngeles = CameraPosition(
    target: LatLng(34.0522, -118.2437),
    zoom: 12,
  );

  static const List<String> _demoGroupUrls = <String>[
    'https://i.pravatar.cc/150?img=1',
    'https://i.pravatar.cc/150?img=2',
    'https://i.pravatar.cc/150?img=3',
    'https://i.pravatar.cc/150?img=4',
  ];
  static const List<String> _demoDualUrls = <String>[
    'https://i.pravatar.cc/150?img=1',
    'https://i.pravatar.cc/150?img=2',
  ];
  static const List<String> _demoTripleUrls = <String>[
    'https://i.pravatar.cc/150?img=1',
    'https://i.pravatar.cc/150?img=2',
    'https://i.pravatar.cc/150?img=3',
  ];
  static const Color _labelColor = Color(0xFF7B2CBF);
  static const MarkerShadow _demoShadow = MarkerShadow(
    color: Color(0x40000000),
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  static const DopinMarker _singleImageMarker = DopinMarker(
    imageUrls: <String>['https://i.pravatar.cc/150?img=12'],
    // count: 12,
    // label: '1',
    width: 46,
    height: 46,
    borderWidth: 3,
    borderColor: Colors.white,
    borderRadius: 12,
    labelColor: _labelColor,
  );

  static const DopinMarker _dualImageMarker = DopinMarker(
    imageUrls: _demoDualUrls,
    // count: 3,
    //   label: '2',
    width: 46,
    height: 46,
    borderWidth: 3,
    borderColor: Colors.white,
    borderRadius: 12,
    labelColor: _labelColor,
  );

  static const DopinMarker _tripleImageMarker = DopinMarker(
    imageUrls: _demoTripleUrls,
    // label: '3',
    width: 46,
    height: 46,
    borderWidth: 3,
    borderColor: Colors.white,
    borderRadius: 12,
    labelColor: _labelColor,
  );

  static const DopinMarker _quadImageMarker = DopinMarker(
    imageUrls: _demoGroupUrls,
    // label: '4',
    width: 46,
    height: 46,
    borderWidth: 3,
    borderColor: Colors.white,
    borderRadius: 12,
    labelColor: _labelColor,
  );

  static const double _focusPitchMin = 50;
  static const double _focusPitchMax = 60;
  static const double _focusPitchPeriodSeconds = 10;
  static const double _focusOrbitDegreesPerSecond = 10;
  static const double _minFocusZoom = 17;

  bool get _isFocused => _focusedPoi != null;

  late final Set<Annotation> _annotations = <Annotation>{
    Annotation(
      annotationId: const AnnotationId('marker_single'),
      position: const LatLng(34.0522, -118.2437),
      onTap: () => _onMarkerTap('marker_single'),
      shadow: _demoShadow,
      dopinMarker: _singleImageMarker,
    ),
    Annotation(
      annotationId: const AnnotationId('marker_dual'),
      position: const LatLng(34.056, -118.2437),
      onTap: () => _onMarkerTap('marker_dual'),
      shadow: _demoShadow,
      dopinMarker: _dualImageMarker,
    ),
    Annotation(
      annotationId: const AnnotationId('marker_triple'),
      position: const LatLng(34.0522, -118.238),
      onTap: () => _onMarkerTap('marker_triple'),
      shadow: _demoShadow,
      dopinMarker: _tripleImageMarker,
    ),
    Annotation(
      annotationId: const AnnotationId('marker_quad'),
      position: const LatLng(34.048, -118.2437),
      onTap: () => _onMarkerTap('marker_quad'),
      shadow: _demoShadow,
      dopinMarker: _quadImageMarker,
    ),
    Annotation(
      annotationId: const AnnotationId('marker_multi_image_event'),
      position: const LatLng(34.057, -118.247),
      anchor: const Offset(0.5, 1.0),
      onTap: () => _onMarkerTap('marker_event'),
      // glow: true,
      shadow: _demoShadow,
      dopinMarker: DopinMarker(
        count: 12,
        imageUrls: <String>['https://i.pravatar.cc/150?img=12'],
        width: 46,
        height: 46,
        borderWidth: 3,
        borderColor: Colors.white,
        borderRadius: 22,
        labelColor: _labelColor,
      ),
    ),
    Annotation(
      annotationId: const AnnotationId('marker_multi_image_event2'),
      position: const LatLng(34.057, -118.248),
      anchor: const Offset(0.5, 1.0),
      onTap: () => _onMarkerTap('marker_event'),
      // glow: true,
      shadow: _demoShadow,
      dopinMarker: DopinMarker(
        //   count: 12,
        imageUrls: <String>['https://i.pravatar.cc/150?img=3'],
        width: 46,
        height: 46,
        borderWidth: 3,
        borderColor: Colors.white,
        borderRadius: 22,
        labelColor: _labelColor,
      ),
    ),
    Annotation(
      annotationId: const AnnotationId('marker_event'),
      position: const LatLng(34.054, -118.245),
      anchor: const Offset(0.5, 1.0),
      onTap: () => _onMarkerTap('marker_event'),
      // glow: true,
      shadow: _demoShadow,
      svgMarker: const SvgMarker(imageUrl: 'https://i.pravatar.cc/150?img=8'),
    ),
  };

  @override
  void initState() {
    super.initState();
    _lastCameraPosition = _losAngeles;
  }

  @override
  void dispose() {
    _stopFocusOrbit();
    super.dispose();
  }

  void _onCameraIdle() {
    _cameraIdleCompleter?.complete();
    _cameraIdleCompleter = null;
  }

  void _onCameraMove(CameraPosition position) {
    // Ignore orbit/focus-driven moves so the pre-focus bearing/pitch are preserved.
    if (_isFocused || _focusTransitionActive) return;
    _lastCameraPosition = position;
  }

  Future<void> _waitForCameraIdle() async {
    final completer = Completer<void>();
    _cameraIdleCompleter = completer;
    await completer.future.timeout(
      _focusFlyDuration + const Duration(milliseconds: 380),
      onTimeout: () {},
    );
  }

  EdgeInsets _focusPadding(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return EdgeInsets.only(top: height * 0.05, bottom: height * 0.52);
  }

  LatLng _offsetCenterForPadding(
    LatLng center,
    EdgeInsets padding,
    double zoom,
  ) {
    final verticalPixelOffset = (padding.bottom - padding.top) / 2;
    if (verticalPixelOffset.abs() <= 0.5) return center;

    final metersPerPixel =
        156543.03392 *
        math.cos(center.latitude * math.pi / 180) /
        math.pow(2, zoom);
    final latitudeDelta = (verticalPixelOffset * metersPerPixel) / 111320;
    return LatLng(
      (center.latitude - latitudeDelta).clamp(-85.0, 85.0),
      center.longitude,
    );
  }

  Future<void> _startFocusOrbit(ApplePOIDetail poi) async {
    final controller = _controller;
    if (controller == null || !_isFocused) return;

    final center = LatLng(poi.latitude, poi.longitude);
    final zoom = _focusZoom ?? _minFocusZoom;

    await controller.startCameraOrbit(
      center: center,
      zoom: zoom,
      pitch: _focusPitchMin,
      degreesPerSecond: _focusOrbitDegreesPerSecond,
      verticalScreenOffset: _verticalScreenOffset,
      startBearing: 0,
      pitchMin: _focusPitchMin,
      pitchMax: _focusPitchMax,
      pitchPeriodSeconds: _focusPitchPeriodSeconds,
    );
  }

  Future<void> _stopFocusOrbit() async {
    await _controller?.stopCameraOrbit();
  }

  Future<void> _focusOnPoi(ApplePOIDetail poi) async {
    final controller = _controller;
    if (controller == null) return;

    final generation = ++_focusGeneration;
    final location = LatLng(poi.latitude, poi.longitude);

    if (!_isFocused) {
      if (_lastCameraPosition != null) {
        _cameraBeforeFocus = _lastCameraPosition;
      } else {
        final zoom = await controller.getZoomLevel();
        final region = await controller.getVisibleRegion();
        final center = LatLng(
          (region.southwest.latitude + region.northeast.latitude) / 2,
          (region.southwest.longitude + region.northeast.longitude) / 2,
        );
        _cameraBeforeFocus = CameraPosition(
          target: center,
          zoom: zoom ?? _losAngeles.zoom,
        );
      }
    }

    final padding = _focusPadding(context);
    _verticalScreenOffset = (padding.bottom - padding.top) / 2;

    final currentZoom = await controller.getZoomLevel();
    final focusZoom = (currentZoom ?? _minFocusZoom)
        .clamp(_minFocusZoom, 20)
        .toDouble();
    _focusZoom = focusZoom;

    // ── Phase 1: pre-focus fly ──────────────────────────────────────────────
    // Lock gestures and fly the camera. The focus sheet stays hidden until the
    // camera settles (same two-phase sequence as Dopin home_map).
    await _stopFocusOrbit();
    setState(() {
      _focusTransitionActive = true;
      _gesturesLocked = true;
      _lastTappedMarkerId = null;
    });

    final flyTarget = _offsetCenterForPadding(location, padding, focusZoom);
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: flyTarget,
            zoom: focusZoom,
            pitch: _focusPitchMin,
            heading: 0,
          ),
        ),
      );
      await _waitForCameraIdle();
    } finally {
      if (mounted) {
        setState(() => _focusTransitionActive = false);
      }
    }

    if (generation != _focusGeneration || !mounted) return;

    // ── Phase 2: activate focus mode ────────────────────────────────────────
    // Camera is at the focus position — show the sheet, then start orbit.
    setState(() {
      _focusedPoi = poi;
      _status = 'Focus mode — camera orbiting POI';
    });
    await _startFocusOrbit(poi);
  }

  Future<void> _clearFocus() async {
    _focusGeneration++;
    await _stopFocusOrbit();

    final savedCamera = _cameraBeforeFocus;
    _cameraBeforeFocus = null;
    _focusZoom = null;
    _verticalScreenOffset = 0;

    setState(() {
      _focusedPoi = null;
      _gesturesLocked = true;
      _focusTransitionActive = true;
      _status = 'Tap a POI on the map to enter focus mode';
    });

    final controller = _controller;
    if (controller != null && savedCamera != null) {
      try {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(savedCamera),
        );
        await _waitForCameraIdle();
      } finally {
        if (mounted) {
          setState(() {
            _focusTransitionActive = false;
            _gesturesLocked = false;
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _focusTransitionActive = false;
        _gesturesLocked = false;
      });
    }
  }

  void _onMarkerTap(String id) {
    log('onMarkerTap: $id');
    if (_isFocused) {
      unawaited(_clearFocus());
    }
    setState(() {
      _lastTappedMarkerId = id;
      _status = 'Marker tapped: $id';
    });
  }

  void _onPoiTap(ApplePOIDetail poi) {
    log('onPOITap: ${poi.name}');
    unawaited(_focusOnPoi(poi));
  }

  void _onMapTap(LatLng _) {
    if (_isFocused) {
      unawaited(_clearFocus());
    }
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

    final gesturesEnabled = !_gesturesLocked && !_focusTransitionActive;

    return PopScope(
      canPop: !_isFocused && !_focusTransitionActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFocused) {
          unawaited(_clearFocus());
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            AppleMap(
              initialCameraPosition: _losAngeles,
              mapType: MapType.standard,
              globeAtMinZoom: true,
              minMaxZoomPreference: const MinMaxZoomPreference(0, 21),
              scrollGesturesEnabled: gesturesEnabled,
              rotateGesturesEnabled: gesturesEnabled,
              zoomGesturesEnabled: gesturesEnabled,
              pitchGesturesEnabled: gesturesEnabled,
              onMapCreated: (AppleMapController controller) {
                _controller = controller;
              },
              annotations: _annotations,
              onPOITap: _onPoiTap,
              onTap: _onMapTap,
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
            ),

            _FocusSheetSwitcher(
              poi: _focusedPoi,
              onClose: () => unawaited(_clearFocus()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides the focus sheet up after the pre-focus camera fly (mirrors Dopin [FocusSheet]).
class _FocusSheetSwitcher extends StatelessWidget {
  const _FocusSheetSwitcher({required this.poi, required this.onClose});

  final ApplePOIDetail? poi;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: poi != null
          ? _PoiFocusSheet(
              key: ValueKey(
                'focus-${poi!.latitude}-${poi!.longitude}-${poi!.name}',
              ),
              poi: poi!,
              onClose: onClose,
            )
          : const SizedBox.shrink(key: ValueKey('focus-sheet-empty')),
    );
  }
}

class _PoiFocusSheet extends StatelessWidget {
  const _PoiFocusSheet({required this.poi, required this.onClose, super.key});

  final ApplePOIDetail poi;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Focus mode',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Exit focus',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              _PoiInfoCard(poi: poi),
            ],
          ),
        ),
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
