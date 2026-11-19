import 'package:flutter/cupertino.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../data/patient.dart';
import '../../data/patient_repository.dart';
import '../../theme/tokens.dart';
import '../../shared/labels.dart';
import 'patient_row.dart';
import 'status_filter_sheet.dart';
import 'swipe_row.dart';

/// The List tab of Home (SPEC §7.2, Figma frames 07–13): search by name or
/// national ID, care-level and status filters, the Show inactive switch
/// (`AppScope.showInactive`, shared with the Map tab), and the patient rows
/// under a count header. Swipe a row left to mark the patient deceased, or
/// to restore a deceased one ([SwipeRow]). A row opens [Routes.openDetail]; + opens
/// [Routes.openAdd].
class ListTab extends StatefulWidget {
  const ListTab({super.key});

  @override
  State<ListTab> createState() => _ListTabState();
}

/// "8 PATIENTS · 1 INACTIVE HIDDEN" / "9 PATIENTS · INCLUDING 1 INACTIVE"
/// (SPEC §7.2). [all] is every patient, inactive ones included.
String listHeader(List<Patient> all, {required bool showInactive}) {
  final inactive = all.where((p) => p.status.isInactive).length;
  if (showInactive) {
    return '${all.length} PATIENTS · INCLUDING $inactive INACTIVE';
  }
  return '${all.length - inactive} PATIENTS · $inactive INACTIVE HIDDEN';
}

class _ListTabState extends State<ListTab> {
  PatientRepository? _repo;
  ValueNotifier<bool>? _showInactive;

  /// Every patient (one `list(showInactive: true)`), for the header counts.
  List<Patient> _all = const [];

  /// The rows shown: [_all] narrowed by the search and filters.
  List<Patient> _rows = const [];

  String _query = '';
  CareLevel? _careLevel;
  PatientStatus? _status;
  bool _loaded = false;

  /// Drops the result of a reload that a newer one has overtaken.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (scope.patients != _repo || scope.showInactive != _showInactive) {
      _repo?.removeListener(_reload);
      _showInactive?.removeListener(_onShowInactiveChanged);
      _repo = scope.patients..addListener(_reload);
      _showInactive = scope.showInactive..addListener(_onShowInactiveChanged);
      _reload();
    }
  }

  @override
  void dispose() {
    _repo?.removeListener(_reload);
    _showInactive?.removeListener(_onShowInactiveChanged);
    super.dispose();
  }

  /// Turning Show inactive off also clears a Moved / Deceased status filter,
  /// which would otherwise match nothing.
  void _onShowInactiveChanged() {
    setState(() {
      if (!_showInactive!.value && (_status?.isInactive ?? false)) {
        _status = null;
      }
    });
    _reload();
  }

  Future<void> _reload() async {
    final repo = _repo!;
    final generation = ++_generation;
    final all = await repo.list(showInactive: true);
    final rows = await repo.list(
      query: _query,
      careLevel: _careLevel,
      status: _status,
      showInactive: _showInactive!.value,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _all = all;
      _rows = rows;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showInactive = _showInactive!.value;
    final year = DateTime.now().year;
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Patients'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Routes.openAdd(context),
              child: const Icon(
                CupertinoIcons.add,
                semanticLabel: 'Add patient',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            sliver: SliverToBoxAdapter(child: _controls(showInactive)),
          ),
          if (_loaded) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16 + AppSpace.s16,
                AppSpace.s12,
                AppSpace.s16,
                AppSpace.s12,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  listHeader(_all, showInactive: showInactive),
                  style: AppText.footnote.copyWith(
                    color: AppColors.labelSecondary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(
                left: AppSpace.s16,
                right: AppSpace.s16,
                bottom: AppSpace.s30,
              ),
              sliver: SliverToBoxAdapter(
                child: _rows.isEmpty
                    ? Text(
                        'No patients match.',
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(
                          color: AppColors.labelSecondary,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Column(
                          children: [
                            for (final p in _rows)
                              SwipeRow(
                                patient: p,
                                repository: _repo!,
                                child: PatientRow(
                                  key: ValueKey(p.id),
                                  patient: p,
                                  currentYear: year,
                                  onTap: () => Routes.openDetail(context, p.id),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controls(bool showInactive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s12),
        CupertinoSearchTextField(
          placeholder: 'Search name or national ID',
          onChanged: (text) {
            _query = text;
            _reload();
          },
        ),
        const SizedBox(height: AppSpace.s12),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: _careLevel == null ? 0 : _careLevel!.index + 1,
          children: {
            0: const Text('All'),
            for (final level in CareLevel.values)
              level.index + 1: Text(level.label),
          },
          onValueChanged: (i) {
            setState(
              () => _careLevel = i == null || i == 0
                  ? null
                  : CareLevel.values[i - 1],
            );
            _reload();
          },
        ),
        const SizedBox(height: AppSpace.s12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ColoredBox(
            color: AppColors.bgSurface,
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 0,
                        color: AppColors.separatorDefault.withValues(
                          alpha: AppColors.separatorDefaultOpacity,
                        ),
                      ),
                    ),
                  ),
                  child: _statusRow(showInactive),
                ),
                _SettingRow(
                  icon: CupertinoIcons.eye_slash,
                  label: 'Show inactive',
                  onTap: () => _showInactive!.value = !showInactive,
                  trailing: CupertinoSwitch(
                    value: showInactive,
                    activeTrackColor: AppColors.actionPositive,
                    inactiveTrackColor: AppColors.fillSwitchOff,
                    onChanged: (on) => _showInactive!.value = on,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusRow(bool showInactive) {
    return _SettingRow(
      icon: CupertinoIcons.line_horizontal_3_decrease,
      label: 'Status',
      onTap: () => showStatusFilterSheet(
        context,
        selected: _status,
        showInactive: showInactive,
        onSelected: (status) {
          setState(() => _status = status);
          _reload();
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _status?.label ?? 'All',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(color: AppColors.labelTertiary),
            ),
          ),
          const SizedBox(width: AppSpace.s6),
          const Icon(
            CupertinoIcons.chevron_up_chevron_down,
            size: AppSpace.s14,
            color: AppColors.labelTertiary,
          ),
        ],
      ),
    );
  }
}

/// A 44-pt row of the filter card: icon, label, and a trailing control.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppSpace.s40 + AppSpace.s4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: Row(
            children: [
              Icon(icon, size: AppSpace.s20, color: AppColors.iconSecondary),
              const SizedBox(width: AppSpace.s8),
              Text(
                label,
                style: AppText.body.copyWith(color: AppColors.labelPrimary),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
