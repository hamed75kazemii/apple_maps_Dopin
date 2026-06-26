// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Controller for a single AppleMap instance running on the host platform.
class AppleMapController {
  AppleMapController._(
    this.channel,
    CameraPosition initialCameraPosition,
    this._appleMapState,
  ) {
    channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<AppleMapController> init(
    int id,
    CameraPosition initialCameraPosition,
    _AppleMapState appleMapState,
  ) async {
    final MethodChannel channel =
        MethodChannel('apple_maps_plugin.luisthein.de/apple_maps_$id');
    // await channel.invokeMethod<void>('map#waitForMap');
    return AppleMapController._(
      channel,
      initialCameraPosition,
      appleMapState,
    );
  }

  @visibleForTesting
  final MethodChannel channel;

  final _AppleMapState _appleMapState;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'camera#onMoveStarted':
        _appleMapState.widget.onCameraMoveStarted?.call();
        break;
      case 'camera#onMove':
        _appleMapState.widget.onCameraMove?.call(
          CameraPosition.fromMap(call.arguments['position'])!,
        );
        break;
      case 'camera#onIdle':
        _appleMapState.widget.onCameraIdle?.call();
        break;
      case 'annotation#onTap':
        _appleMapState.onAnnotationTap(call.arguments['annotationId']);
        break;
      case 'polyline#onTap':
        _appleMapState.onPolylineTap(call.arguments['polylineId']);
        break;
      case 'polygon#onTap':
        _appleMapState.onPolygonTap(call.arguments['polygonId']);
        break;
      case 'circle#onTap':
        _appleMapState.onCircleTap(call.arguments['circleId']);
        break;
      case 'annotation#onDragEnd':
        _appleMapState.onAnnotationDragEnd(call.arguments['annotationId'],
            LatLng._fromJson(call.arguments['position'])!);
        break;
      case 'infoWindow#onTap':
        _appleMapState.onInfoWindowTap(call.arguments['annotationId']);
        break;
      case 'annotation#onZIndexChanged':
        _appleMapState.onAnnotationZIndexChanged(
            call.arguments['annotationId'], call.arguments['zIndex']);
        break;
      case 'map#onTap':
        _appleMapState.onTap(LatLng._fromJson(call.arguments['position'])!);
        break;
      case 'map#onLongPress':
        _appleMapState
            .onLongPress(LatLng._fromJson(call.arguments['position'])!);
        break;
      case 'map#onPOITap':
        final ApplePOIDetail? poi = ApplePOIDetail._fromMap(call.arguments);
        if (poi != null) {
          _appleMapState.onPOITap(poi);
        }
        break;
      default:
        throw MissingPluginException();
    }
  }

  /// Updates configuration options of the map user interface.
  ///
  /// Change listeners are notified once the update has been made on the
  /// platform side.
  ///
  /// The returned [Future] completes after listeners have been notified.
  Future<void> _updateMapOptions(Map<String, dynamic> optionsUpdate) async {
    await channel.invokeMethod<void>(
      'map#update',
      <String, dynamic>{
        'options': optionsUpdate,
      },
    );
  }

  /// Updates annotation configuration.
  ///
  /// Change listeners are notified once the update has been made on the
  /// platform side.
  ///
  /// The returned [Future] completes after listeners have been notified.
  Future<void> _updateAnnotations(_AnnotationUpdates annotationUpdates) async {
    await channel.invokeMethod<void>(
      'annotations#update',
      annotationUpdates._toMap(),
    );
  }

  /// Updates polyline configuration.
  ///
  /// Change listeners are notified once the update has been made on the
  /// platform side.
  ///
  /// The returned [Future] completes after listeners have been notified.
  Future<void> _updatePolylines(_PolylineUpdates polylineUpdates) async {
    await channel.invokeMethod<void>(
      'polylines#update',
      polylineUpdates._toMap(),
    );
  }

  /// Updates polygon configuration.
  ///
  /// Change listeners are notified once the update has been made on the
  /// platform side.
  ///
  /// The returned [Future] completes after listeners have been notified.
  Future<void> _updatePolygons(_PolygonUpdates polygonUpdates) async {
    await channel.invokeMethod<void>(
      'polygons#update',
      polygonUpdates._toMap(),
    );
  }

  /// Updates circle configuration.
  ///
  /// Change listeners are notified once the update has been made on the
  /// platform side.
  ///
  /// The returned [Future] completes after listeners have been notified.
  Future<void> _updateCircles(_CircleUpdates circleUpdates) async {
    await channel.invokeMethod<void>(
      'circles#update',
      circleUpdates._toMap(),
    );
  }

  /// Starts an animated change of the map camera position.
  ///
  /// When [duration] is provided, the platform animates over that interval;
  /// otherwise the system default animation timing is used.
  ///
  /// The returned [Future] completes after the change has been started on the
  /// platform side.
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    await channel.invokeMethod<void>('camera#animate', <String, dynamic>{
      'cameraUpdate': cameraUpdate._toJson(),
      if (duration != null) 'duration': duration.inMilliseconds,
    });
  }

  /// Programmatically show the Info Window for a [Marker].
  ///
  /// The `markerId` must match one of the markers on the map.
  /// An invalid `markerId` triggers an "Invalid markerId" error.
  ///
  /// * See also:
  ///   * [hideMarkerInfoWindow] to hide the Info Window.
  ///   * [isMarkerInfoWindowShown] to check if the Info Window is showing.
  Future<void> showMarkerInfoWindow(AnnotationId annotationId) {
    return channel.invokeMethod<void>('annotations#showInfoWindow',
        <String, String>{'annotationId': annotationId.value});
  }

  /// Programmatically hide the Info Window for a [Marker].
  ///
  /// The `markerId` must match one of the markers on the map.
  /// An invalid `markerId` triggers an "Invalid markerId" error.
  ///
  /// * See also:
  ///   * [showMarkerInfoWindow] to show the Info Window.
  ///   * [isMarkerInfoWindowShown] to check if the Info Window is showing.
  Future<void> hideMarkerInfoWindow(AnnotationId annotationId) {
    return channel.invokeMethod<void>('annotations#hideInfoWindow',
        <String, String>{'annotationId': annotationId.value});
  }

  /// Returns `true` when the [InfoWindow] is showing, `false` otherwise.
  ///
  /// The `markerId` must match one of the markers on the map.
  /// An invalid `markerId` triggers an "Invalid markerId" error.
  ///
  /// * See also:
  ///   * [showMarkerInfoWindow] to show the Info Window.
  ///   * [hideMarkerInfoWindow] to hide the Info Window.
  Future<bool?> isMarkerInfoWindowShown(AnnotationId annotationId) {
    return channel.invokeMethod<bool>('annotations#isInfoWindowShown',
        <String, String>{'annotationId': annotationId.value});
  }

  /// Changes the map camera position without animating the transition.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> moveCamera(CameraUpdate cameraUpdate) async {
    await channel.invokeMethod<void>('camera#move', <String, dynamic>{
      'cameraUpdate': cameraUpdate._toJson(),
    });
  }

  /// Starts a native, frame-rate-driven camera orbit around [center].
  ///
  /// The camera heading is swept by [degreesPerSecond] (positive = clockwise)
  /// while [zoom] and [pitch] stay fixed, producing a smooth cinematic rotation
  /// around the point. The sweep is driven by a `CADisplayLink` on the platform
  /// side, so it does not round-trip through the method channel on every frame.
  ///
  /// [verticalScreenOffset] (in screen points) shifts the camera target opposite
  /// the heading so that [center] appears that many points above the screen
  /// center — useful when a bottom sheet or top bar covers part of the map and
  /// the focused point should sit in the visible area.
  ///
  /// [startBearing] overrides the initial heading; when omitted the map's
  /// current heading is used.
  ///
  /// When [pitchMin], [pitchMax] and [pitchPeriodSeconds] are provided (with
  /// `pitchMax > pitchMin` and a positive period), the camera pitch oscillates
  /// sinusoidally between the two angles over [pitchPeriodSeconds] while the
  /// orbit runs, starting at [pitchMin]. Otherwise [pitch] stays fixed.
  ///
  /// Call [stopCameraOrbit] to end the orbit.
  Future<void> setOrbitFrame({
    required LatLng center,
    required double zoom,
    required double pitch,
    required double bearing,
    EdgeInsets? padding,
    double verticalScreenOffset = 0.0,
  }) async {
    final offset = padding != null
        ? MapCameraPadding.verticalScreenOffset(padding)
        : verticalScreenOffset;
    await channel.invokeMethod<void>('camera#setOrbitFrame', <String, dynamic>{
      'center': <double>[center.latitude, center.longitude],
      'zoom': zoom,
      'pitch': pitch,
      'bearing': bearing,
      'verticalScreenOffset': offset,
    });
  }

  Future<void> startCameraOrbit({
    required LatLng center,
    required double zoom,
    required double pitch,
    double degreesPerSecond = 12.0,
    double verticalScreenOffset = 0.0,
    double? startBearing,
    double? pitchMin,
    double? pitchMax,
    double? pitchPeriodSeconds,
  }) async {
    await channel.invokeMethod<void>('camera#startOrbit', <String, dynamic>{
      'center': <double>[center.latitude, center.longitude],
      'zoom': zoom,
      'pitch': pitch,
      'degreesPerSecond': degreesPerSecond,
      'verticalScreenOffset': verticalScreenOffset,
      if (startBearing != null) 'startBearing': startBearing,
      if (pitchMin != null) 'pitchMin': pitchMin,
      if (pitchMax != null) 'pitchMax': pitchMax,
      if (pitchPeriodSeconds != null) 'pitchPeriodSeconds': pitchPeriodSeconds,
    });
  }

  /// Stops a camera orbit previously started with [startCameraOrbit].
  ///
  /// A final `camera#onMove`/`camera#onIdle` event is emitted so the resting
  /// camera position is reported back to Flutter.
  Future<void> stopCameraOrbit() async {
    await channel.invokeMethod<void>('camera#stopOrbit');
  }

  /// Returns the current zoomLevel.
  Future<double?> getZoomLevel() async {
    return channel.invokeMethod<double>('camera#getZoomLevel');
  }

  /// Return [LatLngBounds] defining the region that is visible in a map.
  Future<LatLngBounds> getVisibleRegion() async {
    final Map<String, dynamic>? latLngBounds =
        await channel.invokeMapMethod<String, dynamic>('map#getVisibleRegion');
    final LatLng southwest = LatLng._fromJson(latLngBounds?['southwest'])!;
    final LatLng northeast = LatLng._fromJson(latLngBounds?['northeast'])!;

    return LatLngBounds(northeast: northeast, southwest: southwest);
  }

  /// A projection is used to translate between on screen location and geographic coordinates.
  /// Screen location is in screen pixels (not display pixels) with respect to the top left corner
  /// of the map, not necessarily of the whole screen.
  Future<Offset?> getScreenCoordinate(LatLng latLng) async {
    final point = await channel
        .invokeMapMethod<String, dynamic>('camera#convert', <String, dynamic>{
      'annotation': [latLng.latitude, latLng.longitude]
    });
    if (point != null && !point.containsKey('point')) {
      return null;
    }
    final doubles = List<double>.from(point?['point']);
    return Offset(doubles.first, doubles.last);
  }

  /// Returns the image bytes of the map
  Future<Uint8List?> takeSnapshot(
      [SnapshotOptions snapshotOptions = const SnapshotOptions()]) {
    return channel.invokeMethod<Uint8List>(
        'map#takeSnapshot', snapshotOptions._toMap());
  }
}
