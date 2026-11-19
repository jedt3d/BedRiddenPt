import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app_scope.dart';
import '../../data/patient.dart';
import '../../data/patient_repository.dart';
import '../../geo/random_points.dart';
import '../../shared/care_style.dart';
import '../../shared/map_config.dart';
import '../../theme/tokens.dart';
import 'map_legend.dart';
import 'map_pin.dart';

/// The Map tab of Home (SPEC §7.2, Figma frames 14–16): OSM tiles and the
/// district outline and one pin per visible patient at the top, the colour
/// legend below it on scroll. Show inactive is `AppScope.showInactive`,
/// shared with the List.
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

  PatientRepository? _repo;
  ValueNotifier<bool>? _showInactive;

  /// Every patient, inactive included: read once per change, filtered in
  /// memory (the legend counts hidden patients too).
  List<Patient> _patients = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_district.isEmpty) _loadOutlines(DefaultAssetBundle.of(context));
    final scope = AppScope.of(context);
    if (scope.patients != _repo) {
      _repo?.removeListener(_loadPatients);
      _repo = scope.patients..addListener(_loadPatients);
      _loadPatients();
    }
    if (scope.showInactive != _showInactive) {
      _showInactive?.removeListener(_rebuild);
      _showInactive = scope.showInactive..addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _repo?.removeListener(_loadPatients);
    _showInactive?.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _loadPatients() async {
    final patients = await _repo!.list(showInactive: true);
    if (mounted) setState(() => _patients = patients);
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
    final showInactive = _showInactive!;
    final visible = [
      for (final p in _patients)
        if (showInactive.value || !p.status.isInactive) p,
    ];
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
              children: [
                MarkerLayer(
                  markers: [
                    for (final p in visible)
                      Marker(
                        point: LatLng(p.lat, p.lng),
                        width: MapPin.size.width,
                        height: MapPin.size.height,
                        alignment: Alignment.topCenter,
                        child: MapPin(
                          key: ValueKey(p.id),
                          color: CareStyle.pinColorFor(p),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _ShowInactiveCard(showInactive: showInactive),
          MapLegend(patients: _patients, showInactive: showInactive.value),
        ],
      ),
    );
  }
}

/// The "Show inactive" switch and its footer (Figma frame 14).
class _ShowInactiveCard extends StatelessWidget {
  const _ShowInactiveCard({required this.showInactive});

  final ValueNotifier<bool> showInactive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpace.s16,
        top: AppSpace.s20,
        right: AppSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s6,
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.eye_slash,
                    size: AppSpace.s20,
                    color: AppColors.iconSecondary,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      'Show inactive',
                      style: AppText.body.copyWith(
                        color: AppColors.labelPrimary,
                      ),
                    ),
                  ),
                  CupertinoSwitch(
                    value: showInactive.value,
                    onChanged: (v) => showInactive.value = v,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpace.s16,
              top: AppSpace.s8,
              right: AppSpace.s16,
            ),
            child: Text(
              'Shared with the List tab. Pin color shows care level, not age.',
              style: AppText.footnote.copyWith(color: AppColors.labelSecondary),
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
