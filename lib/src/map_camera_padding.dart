part of apple_maps_flutter;

/// Helpers to derive a view-center [Offset] from chrome/sheet edge insets.
///
/// These are **not** move-padding APIs — they convert inset asymmetry into the
/// same numbers [AppleMapController.setCameraOffset] expects.
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
