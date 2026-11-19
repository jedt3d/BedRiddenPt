// "Use my location" (SPEC §2, §7.3): the current position at best accuracy,
// and the subdistrict polygon it falls in.

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../geo/random_points.dart';
import '../../shared/map_config.dart';

/// A position fix; [accuracyM] is the radius in metres (`Position.accuracy`).
typedef LocationFix = ({double lat, double lng, double accuracyM});

/// The position couldn't be read; [message] is shown under the button.
class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads the current position. Replaceable in tests.
Future<LocationFix> Function() formLocate = _geolocatorFix;

/// The subdistrict polygons. Replaceable in tests.
Future<NamedAreas> Function() formSubdistricts = _loadSubdistricts;

Future<LocationFix> _geolocatorFix() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationUnavailable('Location services are off.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const LocationUnavailable(
      'Location permission is off. Allow it in Settings.',
    );
  }
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return (lat: p.latitude, lng: p.longitude, accuracyM: p.accuracy);
  } on Exception catch (e) {
    throw LocationUnavailable("Couldn't get your location ($e).");
  }
}

Future<NamedAreas>? _subdistricts;

Future<NamedAreas> _loadSubdistricts() => _subdistricts ??= rootBundle
    .loadString(MapConfig.subdistrictsAsset)
    .then(NamedAreas.fromGeoJson);

/// "±5 m".
String accuracyText(double metres) => '±${metres.round()} m';
