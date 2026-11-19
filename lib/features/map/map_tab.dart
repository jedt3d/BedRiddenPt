import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../geo/random_points.dart';
import '../../shared/map_config.dart';
import '../../theme/tokens.dart';

/// The Map tab of Home (SPEC §7.2, Figma frames 14–16): OSM tiles and the
/// district outline at the top, the colour legend below it on scroll.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  /// Map height in the scroll view (Figma frame 14).
  static const mapHeight = 520.0;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  List<LatLng> _district = const [];
  List<List<LatLng>> _subdistricts = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_district.isEmpty) _loadOutlines(DefaultAssetBundle.of(context));
  }

  Future<void> _loadOutlines(AssetBundle bundle) async {
    final boundary = await bundle.loadString(MapConfig.boundaryAsset);
    final subdistricts = await bundle.loadString(MapConfig.subdistrictsAsset);
    if (!mounted) return;
    List<LatLng> toLatLng(List<GeoPoint> ring) => [
      for (final p in ring) LatLng(p.lat, p.lng),
    ];
    setState(() {
      _district = toLatLng(GeoArea.fromGeoJson(boundary).outline);
      _subdistricts = [
        for (final o in NamedAreas.fromGeoJson(subdistricts).outlines.values)
          toLatLng(o),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrouped,
      navigationBar: const CupertinoNavigationBar(middle: Text('Map')),
      child: ListView(
        children: [
          SizedBox(
            height: MapTab.mapHeight,
            child: DistrictMap(
              district: _district,
              subdistricts: _subdistricts,
            ),
          ),
        ],
      ),
    );
  }
}

/// OSM tiles with the district and subdistrict outlines.
class DistrictMap extends StatelessWidget {
  const DistrictMap({
    super.key,
    required this.district,
    required this.subdistricts,
    this.children = const [],
  });

  final List<LatLng> district;
  final List<List<LatLng>> subdistricts;

  /// Layers drawn above the outlines (pins, callout).
  final List<Widget> children;

  // Stroke widths from Figma frame 14 ("Khlong San district" vectors).
  static const _districtStroke = 3.0;
  static const _subdistrictStroke = 1.0;
  static final _subdistrictDash = StrokePattern.dashed(segments: [4, 3]);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: MapConfig.center,
        initialZoom: MapConfig.initialZoom,
        backgroundColor: AppColors.mapLand,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrl,
          userAgentPackageName: MapConfig.userAgentPackageName,
        ),
        if (district.isNotEmpty)
          PolygonLayer(
            polygons: [
              for (final o in subdistricts)
                Polygon(
                  points: o,
                  borderColor: AppColors.mapSubdistrict,
                  borderStrokeWidth: _subdistrictStroke,
                  pattern: _subdistrictDash,
                ),
              Polygon(
                points: district,
                color: AppColors.mapDistrict.withValues(
                  alpha: AppColors.mapDistrictOpacity,
                ),
                borderColor: AppColors.mapDistrict,
                borderStrokeWidth: _districtStroke,
              ),
            ],
          ),
        ...children,
        const OsmAttribution(),
      ],
    );
  }
}

/// "© OpenStreetMap contributors (ODbL)", bottom right (Figma frame 14),
/// required by the OSM tile policy wherever tiles are shown. Not flutter_map's
/// SimpleAttributionWidget: that adds "flutter_map | " and reads the Material
/// theme.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: ColoredBox(
        color: AppColors.bgSurface.withValues(alpha: AppColors.bgChromeOpacity),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s6,
            vertical: AppSpace.s2,
          ),
          child: Text(
            '${MapConfig.attribution} (ODbL)',
            style: AppText.attribution.copyWith(
              color: AppColors.labelSecondaryStrong,
            ),
          ),
        ),
      ),
    );
  }
}
