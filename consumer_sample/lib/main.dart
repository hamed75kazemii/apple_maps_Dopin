import 'dart:async';

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
  bool _followMyLocation = false;
  Set<Annotation> _annotations = <Annotation>{};
  Timer? _dialogMarkerTimer;

  static const Duration _dialogMarkerDelay = Duration(seconds: 1);
  static const LatLng _dialogMarkerPosition = LatLng(34.0530, -118.2420);
  static const LatLng _cloudDialogMarkerPosition = LatLng(34.0530, -118.2405);
  static const CameraPosition _losAngeles = CameraPosition(
    target: _dialogMarkerPosition,
    zoom: 16,
    pitch: 60,
  );
  static const MarkerShadow _demoShadow = MarkerShadow();

  @override
  void initState() {
    super.initState();
    _dialogMarkerTimer = Timer(_dialogMarkerDelay, _showDialogMarkers);
  }

  @override
  void dispose() {
    _dialogMarkerTimer?.cancel();
    super.dispose();
  }

  void _showDialogMarkers() {
    if (!mounted) return;
    setState(() {
      _annotations = <Annotation>{
        _dialogDemoMarker(),
        _cloudDialogDemoMarker(),
      };
    });
  }

  Annotation _dialogDemoMarker() => Annotation(
    annotationId: const AnnotationId('dialog_demo'),
    position: _dialogMarkerPosition,
    onTap: () => unawaited(_focusOnMarker(_dialogMarkerPosition)),
    shadow: _demoShadow,
    dopinMarker: const DopinMarker(
      imageUrls: <String>['https://i.pravatar.cc/150?img=12'],
      label: 'dopin',
      width: 46,
      height: 46,
      borderWidth: 3,
      borderColor: Colors.white,
      borderRadius: 12,
      labelColor: Colors.white,
      labelBackgroundGradientColors: <Color>[
        Color(0xFFEC30E4),
        Color(0xFF581DFF),
      ],
    ),
    dialog: const MarkerDialog(
      text: '1 Market Street San Francisco California',
    ),
  );

  Annotation _cloudDialogDemoMarker() => Annotation(
    annotationId: const AnnotationId('cloud_dialog_demo'),
    position: _cloudDialogMarkerPosition,
    onTap: () => unawaited(_focusOnMarker(_cloudDialogMarkerPosition)),
    shadow: _demoShadow,
    dopinMarker: const DopinMarker(
      imageUrls: <String>['https://i.pravatar.cc/150?img=32'],
      width: 46,
      height: 46,
      borderWidth: 3,
      borderColor: Colors.white,
      borderRadius: 12,
      labelColor: Colors.white,
      labelBackgroundGradientColors: <Color>[
        Color(0xFFEC30E4),
        Color(0xFF581DFF),
      ],
    ),
    dialog: const CloudDialogBox(
      text:
          "I'm craving pizza!!!Let's eat together!🍕I'm craving pizza!!!Let's eat together!🍕",
      textColor: Colors.black,
    ),
  );

  /// Moves the camera so [position] uses the offset set in [onMapCreated].
  Future<void> _focusOnMarker(LatLng position) async {
    final controller = _controller;
    if (controller == null) return;

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(position, 17),
      duration: const Duration(milliseconds: 500),
    );
  }

  void _onTrackingModeChanged(TrackingMode mode) {
    final following = mode != TrackingMode.none;
    if (_followMyLocation == following) return;
    setState(() => _followMyLocation = following);
  }

  Future<void> _onGoToMyLocation() async {
    final controller = _controller;
    if (controller == null) return;

    if (_followMyLocation) {
      await controller.stopFollowingMyLocation();
      return;
    }

    await controller.goToMyLocation();
    await controller.followMyLocation();
  }

  Future<void> _onMapCreated(AppleMapController controller) async {
    _controller = controller;
    final size = MediaQuery.sizeOf(context);
    // Set once — all later animateCamera / moveCamera calls reuse this offset.
    await controller.setCameraOffset(
      Offset(size.width * 0.28, size.height * 0.32),
    );
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppleMap(
            initialCameraPosition: _losAngeles,
            mapType: MapType.mutedStandard,
            elevationStyle: ElevationStyle.realistic,
            clusteringEnabled: true,
            showPointsOfInterest: false,
            globeAtMinZoom: true,
            minMaxZoomPreference: const MinMaxZoomPreference(0, 21),
            onMapCreated: _onMapCreated,
            annotations: _annotations,
            onTrackingModeChanged: _onTrackingModeChanged,
            myLocationMarker: const MyLocationMarker(
              label: 'Me',
              imageUrl: 'https://i.pravatar.cc/150?img=12',
              dialog: CloudDialogBox(text: "I'm ", textColor: Colors.red),
            ),
            myLocationButtonEnabled: false,
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: FloatingActionButton.small(
              heroTag: 'go_to_my_location',
              tooltip: _followMyLocation ? 'توقف فالو' : 'فالو موقعیت من',
              backgroundColor: _followMyLocation
                  ? Theme.of(context).colorScheme.primary
                  : null,
              foregroundColor: _followMyLocation
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
              onPressed: _onGoToMyLocation,
              child: Icon(
                _followMyLocation ? Icons.gps_fixed : Icons.my_location,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
