// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of apple_maps_flutter;

/// Renders a Flutter [Widget] off-screen and turns it into a PNG so it can be
/// used as a map [Annotation] icon ([BitmapDescriptor.fromBytes] on iOS).
///
/// MapKit only draws static images on annotations; true embedded Flutter views
/// on the map surface are not supported. This is the standard workaround.
abstract final class WidgetMarker {
  /// Rasterizes [marker] to PNG bytes.
  ///
  /// [context] must have an [Overlay] ancestor (e.g. under [MaterialApp]).
  /// Prefer calling after the first frame ([WidgetsBinding.addPostFrameCallback]
  /// or [initState] + post-frame) so the overlay is ready.
  ///
  /// [logicalSize] is the layout size of [marker] in logical pixels.
  /// [pixelRatio] controls output resolution (`toImage` scale).
  /// [settleTime] waits extra time before capture (e.g. for async images/fonts).
  static Future<Uint8List> capturePng(
    BuildContext context, {
    required Widget marker,
    required Size logicalSize,
    double pixelRatio = 3.0,
    Duration settleTime = Duration.zero,
  }) async {
    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      throw StateError(
        'WidgetMarker.capturePng needs an Overlay (e.g. MaterialApp / Navigator).',
      );
    }
    final GlobalKey key = GlobalKey();
    final Completer<Uint8List> completer = Completer<Uint8List>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Positioned(
          left: -8000 - logicalSize.width,
          top: -8000 - logicalSize.height,
          child: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: logicalSize,
                textScaler: MediaQuery.textScalerOf(context),
              ),
              child: Theme(
                data: Theme.of(context),
                child: IconTheme.merge(
                  data: IconTheme.of(context),
                  child: DefaultTextStyle.merge(
                    style: DefaultTextStyle.of(context).style,
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: Material(
                        type: MaterialType.transparency,
                        child: SizedBox(
                          width: logicalSize.width,
                          height: logicalSize.height,
                          child: marker,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    void finish() {
      entry.remove();
    }

    void capture() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (settleTime > Duration.zero) {
            await Future<void>.delayed(settleTime);
          }
          final BuildContext? keyContext = key.currentContext;
          if (keyContext == null) {
            throw StateError('WidgetMarker: RepaintBoundary has no context.');
          }
          final RenderObject? ro = keyContext.findRenderObject();
          if (ro is! RenderRepaintBoundary) {
            throw StateError('WidgetMarker: Expected RenderRepaintBoundary.');
          }
          final RenderRepaintBoundary boundary = ro;
          // Do not use [RenderRepaintBoundary.debugNeedsPaint] here: in profile/release
          // its assert body is stripped and reading it throws LateInitializationError
          // ("local result has not been initialized").
          await WidgetsBinding.instance.endOfFrame;
          await WidgetsBinding.instance.endOfFrame;
          final ui.Image raster =
              await boundary.toImage(pixelRatio: pixelRatio);
          final ByteData? bd =
              await raster.toByteData(format: ui.ImageByteFormat.png);
          raster.dispose();
          if (bd == null) {
            throw StateError('WidgetMarker: toByteData returned null.');
          }
          completer.complete(bd.buffer.asUint8List());
        } catch (e, st) {
          if (!completer.isCompleted) {
            completer.completeError(e, st);
          }
        } finally {
          finish();
        }
      });
    }

    capture();
    return completer.future;
  }

  /// Same as [capturePng] but returns a [BitmapDescriptor] for [Annotation.icon].
  static Future<BitmapDescriptor> toBitmapDescriptor(
    BuildContext context, {
    required Widget marker,
    required Size logicalSize,
    double pixelRatio = 3.0,
    Duration settleTime = Duration.zero,
  }) async {
    final Uint8List png = await capturePng(
      context,
      marker: marker,
      logicalSize: logicalSize,
      pixelRatio: pixelRatio,
      settleTime: settleTime,
    );
    return BitmapDescriptor.fromBytes(png);
  }
}
