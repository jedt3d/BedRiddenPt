// The small map on Detail (SPEC §7.4, Figma frame 17 "Small map"): the
// district outline and the patient's pin at the centre. Not interactive.

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/patient.dart';
import '../../geo/random_points.dart';
import '../../shared/care_style.dart';
import '../../shared/map_config.dart';
import '../../theme/tokens.dart';

/// Height of the small map (Figma frame 17 "Small map": 361 × 150).
const miniMapHeight = 150.0;

/// Zoom close enough to see the street around the pin.
const miniMapZoom = 16.0;

/// Whether to load OSM tiles. Widget tests turn it off (no network).
bool miniMapShowTiles = true;

class DetailMiniMap extends StatefulWidget {
  const DetailMiniMap({super.key, required this.patient});

  final Patient patient;

  @override
  State<DetailMiniMap> createState() => _DetailMiniMapState();
}

class _DetailMiniMapState extends State<DetailMiniMap> {
  List<Rings> _district = const [];
  List<Rings> _subdistricts = const [];

  @override
  void initState() {
    super.initState();
    _loadOutlines();
  }

  Future<void> _loadOutlines() async {
    try {
      final district = await rootBundle.loadString(MapConfig.boundaryAsset);
      final subs = await rootBundle.loadString(MapConfig.subdistrictsAsset);
      if (!mounted) return;
      setState(() {
        _district = GeoArea.fromGeoJson(district).polygons;
        _subdistricts = GeoArea.fromGeoJson(subs).polygons;
      });
    } on FlutterError {
      // No outline if an asset is missing; the pin still shows.
    }
  }

  static List<LatLng> _outer(Rings rings) => [
    for (final c in rings.first) LatLng(c[1], c[0]),
  ];

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final point = LatLng(p.lat, p.lng);
    return SizedBox(
      height: miniMapHeight,
      child: FlutterMap(
        // A new map when the patient moves, so the centre follows an edit.
        key: ValueKey(point),
        options: MapOptions(
          initialCenter: point,
          initialZoom: miniMapZoom,
          backgroundColor: AppColors.mapLand,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          if (miniMapShowTiles)
            TileLayer(
              urlTemplate: MapConfig.tileUrl,
              userAgentPackageName: MapConfig.userAgentPackageName,
            ),
          PolygonLayer(
            polygons: [
              for (final s in _subdistricts)
                Polygon(
                  points: _outer(s),
                  borderColor: AppColors.mapSubdistrict,
                  borderStrokeWidth: AppSpace.s1,
                  pattern: StrokePattern.dashed(
                    segments: const [AppSpace.s4, AppSpace.s4],
                  ),
                ),
              for (final d in _district)
                Polygon(
                  points: _outer(d),
                  color: AppColors.mapDistrict.withValues(
                    alpha: AppColors.mapDistrictOpacity,
                  ),
                  borderColor: AppColors.mapDistrict,
                  borderStrokeWidth: AppSpace.s2,
                ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: AppSpace.s40,
                height: AppSpace.s40,
                alignment: Alignment.topCenter,
                child: Icon(
                  CupertinoIcons.location_solid,
                  size: AppSpace.s40,
                  color: CareStyle.pinColorFor(p),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: ColoredBox(
              color: AppColors.bgSurface.withValues(
                alpha: AppColors.bgChromeOpacity,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s5,
                  vertical: AppSpace.s1,
                ),
                child: Text(
                  MapConfig.attribution,
                  style: AppText.attributionSmall.copyWith(
                    color: AppColors.labelSecondaryStrong,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
