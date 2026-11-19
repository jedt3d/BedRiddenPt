import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'geo/random_points.dart';

/// Khlong San District centroid (see assets/geo/README.md).
const kCenter = LatLng(13.7228, 100.5023);
const kZoom = 14.5;

void main() => runApp(const MaterialApp(home: MapSpike()));

enum Dependency { bedridden, homebound, social, inactive }

const depColors = {
  Dependency.bedridden: Colors.red,
  Dependency.homebound: Colors.orange,
  Dependency.social: Colors.green,
  Dependency.inactive: Colors.grey, // deceased / moved
};

class Pin {
  Pin(this.point, this.subdistrict, this.dep, this.name);
  final LatLng point;
  final String subdistrict;
  final Dependency dep;
  final String name;
}

class MapSpike extends StatefulWidget {
  const MapSpike({super.key});
  @override
  State<MapSpike> createState() => _MapSpikeState();
}

class _MapSpikeState extends State<MapSpike> {
  List<LatLng> _outline = [];
  List<List<LatLng>> _subOutlines = [];
  List<Pin> _pins = [];
  int get _bad => _pins
      .where(
        (p) =>
            _subs?.nameAt(p.point.latitude, p.point.longitude) != p.subdistrict,
      )
      .length;
  NamedAreas? _subs;
  Position? _me;
  String? _status;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final area = GeoArea.fromGeoJson(
      await rootBundle.loadString('assets/geo/khlong_san_boundary.geojson'),
      exclude: [
        await rootBundle.loadString('assets/geo/khlong_san_water.geojson'),
      ],
    );
    final subs = NamedAreas.fromGeoJson(
      await rootBundle.loadString('assets/geo/khlong_san_subdistricts.geojson'),
    );
    // The 50 sample patients (same rows as data/seed.sql), not random points.
    final records = jsonDecode(
      await rootBundle.loadString('assets/bootstrap.json'),
    ) as List;
    setState(() {
      _subs = subs;
      _outline = [for (final p in area.outline) LatLng(p.lat, p.lng)];
      _subOutlines = [
        for (final o in subs.outlines.values)
          [for (final p in o) LatLng(p.lat, p.lng)],
      ];
      _pins = [
        for (final r in records)
          Pin(
            LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
            r['subdistrict'] as String,
            r['status'] == 'deceased' || r['status'] == 'moved'
                ? Dependency.inactive
                : Dependency.values.byName(r['dependency'] as String),
            r['fullName'] as String,
          ),
      ];
    });
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _status = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _status = 'Location services are off';
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _status = 'Location permission denied';
        return;
      }
      _me = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      _status = 'Error: $e';
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me == null ? null : LatLng(_me!.latitude, _me!.longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('Khlong San District · map spike')),
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: kCenter,
              initialZoom: kZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.map_geo',
              ),
              if (_outline.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    for (final o in _subOutlines)
                      Polygon(
                        points: o,
                        borderColor: Colors.purple.shade200,
                        borderStrokeWidth: 1.5,
                      ),
                    Polygon(
                      points: _outline,
                      color: Colors.purple.withValues(alpha: 0.08),
                      borderColor: Colors.purple,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              if (me != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: me,
                      radius: _me!.accuracy,
                      useRadiusInMeter: true,
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final p in _pins)
                    Marker(
                      point: p.point,
                      width: 32,
                      height: 32,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${p.name} · ${p.subdistrict} · ${p.dep.name} · '
                              '${p.point.latitude.toStringAsFixed(5)}, ${p.point.longitude.toStringAsFixed(5)}',
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.location_pin,
                          size: 32,
                          color: depColors[p.dep],
                        ),
                      ),
                    ),
                  if (me != null)
                    Marker(
                      point: me,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors (ODbL)'),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _status ??
                      (_me == null
                          ? '${_pins.length} patients from the database, '
                                '$_bad outside their subdistrict\nTap "Use my location"'
                          : 'Lat ${_me!.latitude.toStringAsFixed(6)}, '
                                'Lng ${_me!.longitude.toStringAsFixed(6)}\n'
                                'Accuracy ±${_me!.accuracy.toStringAsFixed(0)} m'),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _locating ? null : _locate,
        icon: _locating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
        label: const Text('Use my location'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
