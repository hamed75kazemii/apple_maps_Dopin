// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Native event pin marker (iOS).
///
/// The pin shape is the bundled SVG. The center of the pin head shows one of
/// (priority order): an [emoji] string, [imagePng] bytes, or a remote
/// [imageUrl]. When [emoji] is provided it is drawn centered on a circular
/// placeholder tinted with the emoji's average color. For pin-shaped icons, use
/// `anchor: Offset(0.5, 1.0)` on the parent [Annotation].
@immutable
class SvgMarker {
  const SvgMarker({
    this.width = 38,
    this.height = 50,
    this.imageUrl,
    this.imagePng,
    this.emoji,
  });

  /// Logical width in points.
  final double width;

  /// Logical height in points.
  final double height;

  /// Center image URL (remote).
  final String? imageUrl;

  /// Center image bytes (local).
  final Uint8List? imagePng;

  /// Center emoji (text). Takes precedence over [imageUrl] / [imagePng]. The
  /// emoji is drawn on a circle filled with the emoji's average color.
  final String? emoji;

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'width': width,
      'height': height,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      if (imagePng != null) 'imagePng': imagePng,
      if (emoji != null && emoji!.isNotEmpty) 'emoji': emoji,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SvgMarker) return false;
    final SvgMarker o = other;
    return width == o.width &&
        height == o.height &&
        imageUrl == o.imageUrl &&
        emoji == o.emoji &&
        _bytesEqual(imagePng, o.imagePng);
  }

  @override
  int get hashCode => Object.hash(
        width,
        height,
        imageUrl,
        imagePng?.length,
        emoji,
      );

  static bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
