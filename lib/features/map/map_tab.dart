import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../data/patient.dart';
import '../../data/patient_repository.dart';
import '../../geo/random_points.dart';
import '../../shared/care_style.dart';
import '../../shared/map_config.dart';
import '../../theme/tokens.dart';
import 'map_callout.dart';
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

  /// The patient whose name callout is open. None when the map opens.
  String? _selectedId;

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
    // A pin that was hidden (e.g. marked deceased) takes its callout with it.
    final selected = visible.where((p) => p.id == _selectedId).firstOrNull;
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
              onTap: () => setState(() => _selectedId = null),
              children: [
                MarkerLayer(
                  markers: [
                    for (final p in visible)
                      Marker(
                        point: LatLng(p.lat, p.lng),
                        width: MapPin.size.width,
                        height: MapPin.size.height,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedId = p.id),
                          child: MapPin(
                            key: ValueKey(p.id),
                            color: CareStyle.pinColorFor(p),
                          ),
                        ),
                      ),
                  ],
                ),
                if (selected != null)
                  _CalloutLayer(
                    patient: selected,
                    onTap: () => Routes.openDetail(context, selected.id),
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

/// The name callout of the selected pin, kept inside the map: above the pin
/// as in Figma frame 15, or below its tip when there's no room above; moved
/// sideways near the left and right edges, but always over the pin.
class _CalloutLayer extends StatelessWidget {
  const _CalloutLayer({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tip = MapCamera.of(context)
        .latLngToScreenOffset(LatLng(patient.lat, patient.lng));
    return CustomSingleChildLayout(
      delegate: CalloutLayout(tip),
      child: MapCallout(patient: patient, onTap: onTap),
    );
  }
}

/// Places a callout of any size for a pin whose tip is at [tip] in a map of
/// the layout's size. Empty space around the callout isn't hit-tested.
class CalloutLayout extends SingleChildLayoutDelegate {
  const CalloutLayout(this.tip);

  /// The pin's tip, in map coordinates.
  final Offset tip;

  /// Widest callout (long names ellipsize).
  static const maxWidth = 260.0;

  /// Space between the pin and the callout.
  static const gap = AppSpace.s7;

  /// Least space between the callout and the map's left and right edges.
  static const margin = AppSpace.s8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: (constraints.maxWidth - 2 * margin).clamp(0, maxWidth),
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final aboveTop = tip.dy - MapPin.size.height - gap - childSize.height;
    final top = aboveTop >= 0 ? aboveTop : tip.dy + gap;
    final maxLeft = size.width - margin - childSize.width;
    final left = maxLeft < margin
        ? margin
        : (tip.dx - childSize.width / 2).clamp(margin, maxLeft);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(CalloutLayout old) => old.tip != tip;
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
    this.onTap,
  });

  final List<LatLng> district;
  final List<List<LatLng>> subdistricts;

  /// Layers drawn above the outlines (pins, callout).
  final List<Widget> children;

  /// A tap on the map itself, not on a pin.
  final VoidCallback? onTap;

  // Stroke widths from Figma frame 14 ("Khlong San district" vectors).
  static const _districtStroke = 3.0;
  static const _subdistrictStroke = 1.0;
  static final _subdistrictDash = StrokePattern.dashed(segments: [4, 3]);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      // Rebuilt once when the outline arrives, so the camera can fit it.
      key: ValueKey(district.isEmpty),
      options: MapOptions(
        onTap: (_, _) => onTap?.call(),
        initialCenter: MapConfig.center,
        initialZoom: MapConfig.initialZoom,
        // MapConfig's zoom 14.5 fits the district on a full portrait screen,
        // not in this shorter map (Simulator check), so fit the outline.
        initialCameraFit: district.isEmpty
            ? null
            : CameraFit.coordinates(
                coordinates: district,
                padding: const EdgeInsets.all(AppSpace.s8),
              ),
        backgroundColor: AppColors.mapLand,
        interactionOptions: const InteractionOptions(
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
