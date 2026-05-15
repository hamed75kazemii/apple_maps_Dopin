// Copyright 2024 Apple Maps Flutter contributors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apple_maps_flutter/apple_maps_flutter.dart';
import 'package:flutter/material.dart';

import 'page.dart';

const CameraPosition _kInitialPosition = CameraPosition(
  target: LatLng(34.0522, -118.2437), // Downtown Los Angeles.
  zoom: 14,
);

/// Example demonstrating Apple Maps native POI tap detection (iOS 17+).
///
/// Tap any built-in POI (store, restaurant, transit stop, etc.) and the most
/// recent selection is displayed below the map. This mirrors the
/// `TapInteraction(StandardPOIs())` flow Mapbox provides.
class POITapPage extends ExamplePage {
  POITapPage() : super(const Icon(Icons.place), 'POI tap (iOS 17+)');

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: _POITapBody());
  }
}

class _POITapBody extends StatefulWidget {
  const _POITapBody();

  @override
  State<_POITapBody> createState() => _POITapBodyState();
}

class _POITapBodyState extends State<_POITapBody> {
  ApplePOIDetail? _lastPOI;

  @override
  Widget build(BuildContext context) {
    final AppleMap appleMap = AppleMap(
      initialCameraPosition: _kInitialPosition,
      onPOITap: (ApplePOIDetail poi) {
        setState(() => _lastPOI = poi);
      },
    );

    final ApplePOIDetail? poi = _lastPOI;
    return Column(
      children: <Widget>[
        Expanded(child: appleMap),
        Padding(
          padding: const EdgeInsets.all(12),
          child: poi == null
              ? const Text(
                  'Tap a labelled POI on the map (requires iOS 17+).',
                  textAlign: TextAlign.center,
                )
              : Column(
                  children: <Widget>[
                    Text(
                      poi.name ?? '<no name>',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (poi.category != null) Text('Category: ${poi.category}'),
                    if (poi.icon != null) Text('Icon: ${poi.icon}'),
                    if (poi.iconPng != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Image.memory(
                          poi.iconPng!,
                          width: 32,
                          height: 32,
                        ),
                      ),
                    Text(
                      '${poi.latitude.toStringAsFixed(5)}, '
                      '${poi.longitude.toStringAsFixed(5)}',
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
