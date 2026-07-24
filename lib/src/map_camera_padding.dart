part of apple_maps_flutter;

/// Padding helpers for camera focus / orbit-frame positioning.
class MapCameraPadding {
  const MapCameraPadding._();

  /// Vertical screen offset derived from [padding].
  ///
  /// Positive values shift the anchor upward on screen (more bottom inset).
  static double verticalScreenOffset(EdgeInsets padding) =>
      (padding.bottom - padding.top) / 2;

  /// Horizontal screen offset derived from [padding].
  ///
  /// Positive values shift the anchor leftward on screen (more right inset).
  static double horizontalScreenOffset(EdgeInsets padding) =>
      (padding.right - padding.left) / 2;
}
