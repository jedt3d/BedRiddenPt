import 'package:flutter/cupertino.dart';

import '../../app/app_scope.dart';
import '../../data/patient.dart';
import '../../data/patient_repository.dart';
import '../../shared/care_style.dart';
import '../../shared/labels.dart';
import '../../shared/national_id.dart';
import '../../shared/patient_avatar.dart';
import '../../theme/tokens.dart';
import 'detail_actions.dart';
import 'detail_format.dart';
import 'detail_mini_map.dart';

/// Photo diameter in the header (Figma frame 17 "Photo": 104).
const _photoSize = 104.0;

/// Patient detail (SPEC §7.4, Figma frames 17–18), pushed on the root
/// navigator (no tab bar): all fields, dates in the Buddhist era, a small map
/// with the patient's pin, and Call / Navigate / Edit ([DetailActions]).
/// Reloads after every repository change.
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final PatientRepository _repo;
  Patient? _patient;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _repo = AppScope.read(context).patients;
    _repo.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _repo.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final p = await _repo.getById(widget.patientId);
    if (!mounted) return;
    setState(() {
      _patient = p;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrouped,
      navigationBar: const CupertinoNavigationBar(middle: Text('Patient')),
      child: SafeArea(
        child: p != null
            ? _DetailBody(patient: p)
            : Center(
                child: _loaded
                    ? Text(
                        'This patient is no longer in the register.',
                        style: AppText.body.copyWith(
                          color: AppColors.labelSecondary,
                        ),
                      )
                    : const CupertinoActivityIndicator(),
              ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final phones = p.phones;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.s30),
      children: [
        _Header(patient: p),
        DetailActions(patient: p),
        CupertinoListSection.insetGrouped(
          header: const Text('LOCATION'),
          children: [DetailMiniMap(patient: p)],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('PATIENT'),
          children: [
            _Row(
              icon: CupertinoIcons.person_crop_rectangle,
              label: 'National ID',
              value: formatNationalId(p.nationalId),
            ),
            _Row(
              icon: CupertinoIcons.person,
              label: 'Full name',
              value: p.fullName,
            ),
            _Row(
              icon: CupertinoIcons.person,
              label: 'Sex',
              valueWidget: _SexText(sex: p.sex, style: AppText.body),
            ),
            _Row(
              icon: CupertinoIcons.calendar,
              label: 'Born',
              value: bornText(p),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('CONTACT PERSON'),
          footer: const Text('Call dials the first phone number.'),
          children: [
            _Row(
              icon: CupertinoIcons.person,
              label: 'Name',
              value: p.contactName,
            ),
            _Row(
              icon: CupertinoIcons.person_2,
              label: 'Relationship',
              value: p.contactRelation.label,
            ),
            if (phones.isEmpty)
              const _Row(
                icon: CupertinoIcons.phone,
                label: 'Phone',
                value: 'None',
              ),
            for (var i = 0; i < phones.length; i++)
              _Row(
                icon: CupertinoIcons.phone,
                label: phones.length == 1 ? 'Phone' : 'Phone ${i + 1}',
                value: formatPhone(phones[i]),
                valueColor: AppColors.accent,
              ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('ADDRESS'),
          children: [
            _Row(
              icon: CupertinoIcons.map,
              label: 'Subdistrict',
              value: p.subdistrict.replaceFirst(RegExp(r' Subdistrict$'), ''),
            ),
            _Row(
              icon: CupertinoIcons.house,
              label: 'Soi / road',
              value: p.addressNote.isEmpty ? '—' : p.addressNote,
            ),
            _Row(
              icon: CupertinoIcons.location,
              label: 'Coordinates',
              value: coordinatesText(p.lat, p.lng),
            ),
            _Row(
              icon: CupertinoIcons.scope,
              label: 'GPS accuracy',
              value: gpsAccuracyText(p.gpsAccuracyM),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('CARE'),
          children: [
            _Row(
              icon: CupertinoIcons.heart,
              label: 'Care level',
              valueWidget: CareLevelBadge(level: p.careLevel),
            ),
            _Row(
              icon: CupertinoIcons.chart_bar,
              label: 'ADL score',
              value: p.adlScore == null ? '—' : '${p.adlScore} of 20',
            ),
            _Row(
              icon: CupertinoIcons.plus_square,
              label: 'Main condition',
              value: p.mainCondition.label,
            ),
            _Row(
              icon: CupertinoIcons.house_alt,
              label: 'Living situation',
              value: p.livingSituation.label,
            ),
            _Row(
              icon: CupertinoIcons.bandage,
              label: 'Care needs',
              value: p.careNeeds.isEmpty
                  ? 'None'
                  : [
                      for (final n in CareNeed.values)
                        if (p.careNeeds.contains(n)) n.label,
                    ].join('\n'),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('STATUS'),
          children: [
            _Row(
              icon: CupertinoIcons.checkmark_circle,
              label: 'Status',
              value: p.status.label,
            ),
            _Row(
              icon: CupertinoIcons.doc_text,
              label: 'Notes',
              value: p.notes.isEmpty ? '—' : p.notes,
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('REGISTRATION'),
          footer: const Text(
            'Editing replaces this registration; there is no visit history.',
          ),
          children: [
            _Row(
              icon: CupertinoIcons.person_badge_plus,
              label: 'Registered by',
              value: p.registeredBy.isEmpty ? '—' : p.registeredBy,
            ),
            _Row(
              icon: CupertinoIcons.clock,
              label: 'Created',
              value: timestampText(p.createdAt),
            ),
            _Row(
              icon: CupertinoIcons.clock,
              label: 'Updated',
              value: timestampText(p.updatedAt),
            ),
          ],
        ),
      ],
    );
  }
}

/// Photo, name, "♀ Female · Born 2496 (age 73)", care-level badge, status.
class _Header extends StatelessWidget {
  const _Header({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final statusColor = p.status == PatientStatus.inHospital
        ? AppColors.statusInHospital
        : AppColors.labelSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s6,
      ),
      child: Column(
        children: [
          PatientAvatar(patient: p, size: _photoSize),
          const SizedBox(height: AppSpace.s16),
          Text(
            p.fullName,
            textAlign: TextAlign.center,
            style: AppText.detailName.copyWith(color: AppColors.labelPrimary),
          ),
          const SizedBox(height: AppSpace.s6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SexText(sex: p.sex, style: AppText.subheadline),
              Text(
                ' · Born ${bornText(p)}',
                style: AppText.subheadline.copyWith(
                  color: AppColors.labelSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CareLevelBadge(level: p.careLevel),
              const SizedBox(width: AppSpace.s8),
              Text(
                p.status.label,
                style: AppText.footnote.copyWith(color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "♀ Female" with the symbol in the sex colour.
class _SexText extends StatelessWidget {
  const _SexText({required this.sex, required this.style});

  final Sex sex;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final (symbol, color) = switch (sex) {
      Sex.male => ('♂', AppColors.sexMale),
      Sex.female => ('♀', AppColors.sexFemale),
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$symbol ',
            style: style.copyWith(color: color),
          ),
          TextSpan(
            text: sex.label,
            style: style.copyWith(color: AppColors.labelSecondary),
          ),
        ],
      ),
    );
  }
}

/// The tinted care-level badge with a dot, e.g. "● Bedridden".
class CareLevelBadge extends StatelessWidget {
  const CareLevelBadge({super.key, required this.level});

  final CareLevel level;

  @override
  Widget build(BuildContext context) {
    final style = CareStyle.of(level);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.badgeBackground,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: style.dot,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: AppSpace.s6, height: AppSpace.s6),
            ),
            const SizedBox(width: AppSpace.s4),
            Text(
              level.label,
              style: AppText.footnoteEmphasized.copyWith(
                color: style.badgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One field: icon, label, and the value right-aligned (wraps when long).
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor = AppColors.labelSecondary,
  }) : assert((value == null) != (valueWidget == null));

  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s11,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSpace.s20, color: AppColors.iconSecondary),
          const SizedBox(width: AppSpace.s12),
          Text(
            label,
            style: AppText.body.copyWith(color: AppColors.labelPrimary),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Align(
              alignment: Alignment.topRight,
              child:
                  valueWidget ??
                  Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: AppText.body.copyWith(color: valueColor),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
