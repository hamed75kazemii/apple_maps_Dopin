// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Optional custom style for the user-location indicator (iOS).
///
/// * With a non-empty [imageUrl]: native [DopinMarker] (avatar, glow, label, …).
/// * Without [imageUrl]: Apple Maps default blue-dot indicator.
@immutable
class MyLocationMarker {
  const MyLocationMarker({
    this.imageUrl,
    this.label = 'Me',
    this.glow = true,
    this.shadow = const MarkerShadow(),
    this.dialog,
  });

  /// Avatar image URL. When `null` or empty, the default map location dot is used.
  final String? imageUrl;

  /// Bottom badge text. Pass `null` or empty to hide the badge.
  final String? label;

  /// Pulsing glow behind the avatar (custom avatar only).
  final bool glow;

  /// Drop shadow under the marker (custom avatar only).
  final MarkerShadow shadow;

  /// Optional dialog above the avatar ([MarkerDialog] or [CloudDialogBox]).
  final MarkerDialog? dialog;

  /// Whether a custom Dopin avatar should replace the default blue dot.
  bool get hasCustomAvatar {
    final String? url = imageUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  static const double _width = 46;
  static const double _height = 46;
  static const double _badgeHeight = 18;
  static const double _badgeOverlap = 8;
  static const double _pillTailHeight = 10;
  static const double _cloudDesignWidth = 68;
  static const double _cloudDesignHeight = 49;
  static const double _cloudDotDesignSize = 10;
  static const double _cloudDotGapDesign = 1;

  bool get _hasLabel {
    final String? trimmed = label?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  double get _markerContentHeight =>
      _hasLabel ? _height + _badgeHeight - _badgeOverlap : _height;

  /// Native bubble height above the marker (body + tail / thought-dot).
  static double _dialogBubbleHeight(MarkerDialog dialog) {
    if (dialog.style == MarkerDialogStyle.cloud) {
      final Size body = dialog.width > 0 && dialog.height > 0
          ? Size(dialog.width, dialog.height)
          : MarkerDialog.estimateCloudBodySize(
              text: dialog.text,
              fontSize: dialog.fontSize,
              horizontalPadding: dialog.horizontalPadding,
              verticalPadding: dialog.verticalPadding,
            );
      final double sx = body.width / _cloudDesignWidth;
      final double sy = body.height / _cloudDesignHeight;
      final double scale = sx < sy ? sx : sy;
      return body.height +
          _cloudDotGapDesign * scale +
          _cloudDotDesignSize * scale;
    }
    return dialog.height + _pillTailHeight;
  }

  /// Geographic anchor at the avatar center (accounts for an optional dialog).
  Offset get _anchor {
    final MarkerDialog? bubble = dialog;
    if (bubble == null) {
      return Offset(0.5, _height / 2 / _markerContentHeight);
    }
    final double bubbleH = _dialogBubbleHeight(bubble);
    final double gap = bubble.gapAboveMarker;
    final double totalH = bubbleH + gap + _markerContentHeight;
    final double avatarCenterY = bubbleH + gap + _height / 2;
    return Offset(0.5, avatarCenterY / totalH);
  }

  DopinMarker get _dopinMarker => DopinMarker(
        imageUrls: <String>[imageUrl!],
        label: label,
        width: _width,
        height: _height,
        borderWidth: 3,
        borderColor: Colors.white,
        borderRadius: 12,
        labelColor: const Color(0xFF7B2CBF),
        labelGradientColors: const <Color>[
          Color(0xFFEC30E4),
          Color(0xFF581DFF),
        ],
      );

  Map<String, dynamic> _toJson() {
    assert(hasCustomAvatar);
    final Offset anchor = _anchor;
    return <String, dynamic>{
      'dopinMarker': _dopinMarker._toJson(),
      'anchor': <double>[anchor.dx, anchor.dy],
      if (glow) ...<String, dynamic>{
        'glow': true,
        'glowAnchor': <double>[anchor.dx, anchor.dy],
      },
      'shadow': shadow._toJson(),
      if (dialog != null) 'dialog': dialog!._toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MyLocationMarker) return false;
    final MyLocationMarker o = other;
    return imageUrl == o.imageUrl &&
        label == o.label &&
        glow == o.glow &&
        shadow == o.shadow &&
        dialog == o.dialog;
  }

  @override
  int get hashCode => Object.hash(imageUrl, label, glow, shadow, dialog);
}
