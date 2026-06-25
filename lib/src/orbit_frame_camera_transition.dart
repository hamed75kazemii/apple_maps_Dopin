part of apple_maps_flutter;

/// Camera parameters for [runOrbitFrameCameraTransition] and orbit focus.
class OrbitFrameCameraTarget {
  const OrbitFrameCameraTarget({
    required this.padding,
    required this.zoom,
    required this.pitch,
    this.bearing = 0,
  });

  final EdgeInsets padding;
  final double zoom;
  final double pitch;
  final double bearing;
}

/// Animates a fly-in using native orbit-frame positioning so the transition
/// ends on the exact same camera math as [AppleMapController.startCameraOrbit].
Future<void> runOrbitFrameCameraTransition({
  required TickerProvider vsync,
  required AppleMapController controller,
  required LatLng anchor,
  required OrbitFrameCameraTarget target,
  CameraPosition? start,
  Duration duration = const Duration(milliseconds: 420),
  Curve curve = Curves.easeInOutCubic,
}) {
  return _runOrbitFrameCameraTransition(
    vsync: vsync,
    applyFrame: ({
      required LatLng center,
      required double zoom,
      required double pitch,
      required double bearing,
      EdgeInsets? padding,
    }) {
      return controller.setOrbitFrame(
        center: center,
        zoom: zoom,
        pitch: pitch,
        bearing: bearing,
        padding: padding,
      );
    },
    anchor: anchor,
    target: target,
    start: start,
    duration: duration,
    curve: curve,
  );
}

/// Lower-level transition helper for app wrappers that route through their own
/// map controller (e.g. a cross-platform facade).
Future<void> runOrbitFrameCameraTransitionWithApplier({
  required TickerProvider vsync,
  required Future<void> Function({
    required LatLng center,
    required double zoom,
    required double pitch,
    required double bearing,
    EdgeInsets? padding,
  }) applyFrame,
  required LatLng anchor,
  required OrbitFrameCameraTarget target,
  CameraPosition? start,
  Duration duration = const Duration(milliseconds: 420),
  Curve curve = Curves.easeInOutCubic,
}) {
  return _runOrbitFrameCameraTransition(
    vsync: vsync,
    applyFrame: applyFrame,
    anchor: anchor,
    target: target,
    start: start,
    duration: duration,
    curve: curve,
  );
}

Future<void> _runOrbitFrameCameraTransition({
  required TickerProvider vsync,
  required Future<void> Function({
    required LatLng center,
    required double zoom,
    required double pitch,
    required double bearing,
    EdgeInsets? padding,
  }) applyFrame,
  required LatLng anchor,
  required OrbitFrameCameraTarget target,
  CameraPosition? start,
  Duration duration = const Duration(milliseconds: 420),
  Curve curve = Curves.easeInOutCubic,
}) async {
  final startZoom = start?.zoom ?? target.zoom;
  final startPitch = start?.pitch ?? 0;
  final startBearing = start?.heading ?? 0;

  final controller = AnimationController(vsync: vsync, duration: duration);
  final animation = CurvedAnimation(parent: controller, curve: curve);

  Future<void> applyTransitionFrame(double t) {
    return applyFrame(
      center: anchor,
      zoom: ui.lerpDouble(startZoom, target.zoom, t)!,
      pitch: ui.lerpDouble(startPitch, target.pitch, t)!,
      bearing: _lerpBearing(startBearing, target.bearing, t),
      padding: target.padding,
    );
  }

  void onTick() {
    unawaited(applyTransitionFrame(animation.value.clamp(0.0, 1.0)));
  }

  try {
    animation.addListener(onTick);
    await applyTransitionFrame(0);
    await controller.forward();
    await applyTransitionFrame(1);
  } finally {
    animation
      ..removeListener(onTick)
      ..dispose();
    controller.dispose();
  }
}

double _lerpBearing(double from, double to, double t) {
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return (from + delta * t + 360) % 360;
}
