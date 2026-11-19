import 'package:flutter/cupertino.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../data/patient.dart';
import '../../data/patient_repository.dart';
import '../../theme/tokens.dart';
import 'patient_row.dart';

/// The List tab of Home (SPEC §7.2, Figma frames 07–13): the patient rows
/// under a count header. A row opens [Routes.openDetail]; + opens
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

  /// The rows shown.
  List<Patient> _rows = const [];
  bool _loaded = false;

  /// Drops the result of a reload that a newer one has overtaken.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (scope.patients != _repo || scope.showInactive != _showInactive) {
      _repo?.removeListener(_reload);
      _showInactive?.removeListener(_reload);
      _repo = scope.patients..addListener(_reload);
      _showInactive = scope.showInactive..addListener(_reload);
      _reload();
    }
  }

  @override
  void dispose() {
    _repo?.removeListener(_reload);
    _showInactive?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final repo = _repo!;
    final generation = ++_generation;
    final all = await repo.list(showInactive: true);
    final rows = await repo.list(showInactive: _showInactive!.value);
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Column(
                    children: [
                      for (final p in _rows)
                        PatientRow(
                          key: ValueKey(p.id),
                          patient: p,
                          currentYear: year,
                          onTap: () => Routes.openDetail(context, p.id),
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
}
