part of apple_maps_flutter;

/// Padding helpers for native orbit-frame camera positioning.
class MapCameraPadding {
  const MapCameraPadding._();

  /// Vertical screen offset derived from [padding].
  ///
  /// Positive values shift the anchor upward on screen (more bottom inset).
  static double verticalScreenOffset(EdgeInsets padding) =>
      (padding.bottom - padding.top) / 2;
}
