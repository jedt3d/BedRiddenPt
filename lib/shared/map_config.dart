// Map settings (SPEC §2, §3), verified in spikes/map_geo/.

import 'package:latlong2/latlong.dart';

abstract final class MapConfig {
  /// OpenStreetMap tiles. Not the old {s}.tile subdomain URL.
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Sent as the User-Agent, required by the OSM tile policy. The iOS
  /// bundle id from flutter create.
  static const userAgentPackageName = 'com.example.bedriddenPt';

  /// Khlong San district centroid (on land, in Khlong Ton Sai).
  static const center = LatLng(13.7228, 100.5023);

  /// Fits the whole district on a portrait phone screen.
  static const initialZoom = 14.5;

  /// Shown on the map, required by the ODbL.
  static const attribution = '© OpenStreetMap contributors';

  static const boundaryAsset = 'assets/geo/khlong_san_boundary.geojson';
  static const subdistrictsAsset = 'assets/geo/khlong_san_subdistricts.geojson';
  static const waterAsset = 'assets/geo/khlong_san_water.geojson';
}
