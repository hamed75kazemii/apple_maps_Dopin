// Copyright 2024 Apple Maps Flutter contributors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Details of a built-in Apple Maps Point Of Interest (POI) that was tapped
/// by the user.
///
/// POI tap detection requires iOS 17+ at runtime; on older iOS versions the
/// plugin silently does nothing and [AppleMap.onPOITap] will never fire.
///
/// This mirrors `TapInteraction(StandardPOIs())` from Mapbox: it surfaces the
/// taps the user makes on Apple Maps' own labelled points of interest (cafes,
/// shops, landmarks, etc.) - it does **not** report taps on Flutter-managed
/// [Annotation]s, which continue to use [Annotation.onTap].
@immutable
class ApplePOIDetail {
  const ApplePOIDetail({
    required this.latitude,
    required this.longitude,
    this.name,
    this.category,
  });

  /// Human-readable POI name as shown on the map (e.g. "Blue Bottle Coffee").
  ///
  /// May be `null` when MapKit didn't supply a title for the selected feature.
  final String? name;

  /// Latitude of the POI in degrees.
  final double latitude;

  /// Longitude of the POI in degrees.
  final double longitude;

  /// Optional POI category identifier derived from `MKPointOfInterestCategory`
  /// (e.g. `"Cafe"`, `"Restaurant"`, `"Museum"`). The `MKPOICategory` prefix is
  /// stripped on the native side before being sent over the channel.
  final String? category;

  /// Convenience accessor returning [latitude] / [longitude] as a [LatLng].
  LatLng get position => LatLng(latitude, longitude);

  /// Parses an [ApplePOIDetail] from the platform channel payload.
  ///
  /// Returns `null` when the payload is missing required coordinates.
  static ApplePOIDetail? _fromMap(dynamic raw) {
    if (raw == null) return null;
    final Map<dynamic, dynamic> map = raw as Map<dynamic, dynamic>;
    final dynamic lat = map['latitude'];
    final dynamic lng = map['longitude'];
    if (lat is! num || lng is! num) {
      return null;
    }
    return ApplePOIDetail(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      name: map['name'] as String?,
      category: map['category'] as String?,
    );
  }

  @override
  String toString() =>
      'ApplePOIDetail(name: $name, latitude: $latitude, longitude: $longitude, category: $category)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApplePOIDetail &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(name, latitude, longitude, category);
}
