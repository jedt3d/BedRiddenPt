import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../data/patient.dart';
import '../../data/patient_repository.dart';
import '../../shared/labels.dart';
import '../../shared/national_id.dart';
import '../../shared/patient_avatar.dart';
import '../../theme/tokens.dart';
import '../detail/detail_screen.dart' show CareLevelBadge;
import 'form_draft.dart';
import 'form_location.dart';
import 'form_photo.dart';
import 'form_widgets.dart';

/// Photo diameter (Figma frame 19 "Photo": 88).
const _photoSize = 88.0;

/// Banner when Add is prefilled from an unused sample-pool record.
const prefilledBanner =
    'Prefilled from the sample pool (a patient not yet registered). '
    'Edit any field before saving.';

/// Banner when all 50 pool records are registered (SPEC §7.3).
const poolUsedUpBanner =
    'All 50 sample-pool patients are already registered, so this form '
    'starts empty.';

/// Add / Edit form (SPEC §7.3, Figma frames 19–25), pushed on the root
/// navigator (no tab bar). [patientId] null = Add, prefilled from a random
/// unused pool record (empty with a banner when all 50 are registered);
/// otherwise Edit that patient. Save inserts (registered by the volunteer) or updates, then
/// closes the form.
class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, this.patientId});

  final String? patientId;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  late final AppScope _scope;
  FormDraft? _draft;
  bool _saving = false;

  /// Whether Save was tapped once: from then on, errors show as you type.
  bool _submitted = false;

  /// The national ID the repository rejected as a duplicate on Save.
  String? _duplicateId;

  var _location = const _LocationState();

  /// The note at the top of Add (SPEC §6, §7.3); null for Edit.
  String? _banner;

  bool get _isAdd => widget.patientId == null;

  @override
  void initState() {
    super.initState();
    _scope = AppScope.read(context);
    _load();
  }

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final FormDraft draft;
    if (_isAdd) {
      final pool = await _scope.patients.nextUnusedPoolRecord();
      if (!mounted) return;
      draft = pool == null ? FormDraft.empty() : FormDraft.fromPatient(pool);
      _banner = pool == null ? poolUsedUpBanner : prefilledBanner;
    } else {
      final p = await _scope.patients.getById(widget.patientId!);
      if (!mounted) return;
      if (p == null) {
        Navigator.of(context).pop();
        return;
      }
      draft = FormDraft.fromPatient(p);
    }
    draft.addTextListener(_changed);
    setState(() => _draft = draft);
  }

  void _changed() => setState(() {});

  /// Use my location (SPEC §7.3): overwrites lat/lng and the accuracy, and
  /// sets the subdistrict from its polygon. Outside the district the
  /// subdistrict is left as it was and a note says so.
  Future<void> _useMyLocation() async {
    final draft = _draft!;
    setState(() => _location = const _LocationState(locating: true));
    try {
      final fix = await formLocate();
      final name = (await formSubdistricts()).nameAt(fix.lat, fix.lng);
      if (!mounted) return;
      setState(() {
        draft
          ..lat = fix.lat
          ..lng = fix.lng
          ..gpsAccuracyM = fix.accuracyM;
        if (name != null) draft.subdistrict = name;
        _location = _LocationState(
          used: true,
          message: name == null ? outsideDistrictMessage : null,
        );
      });
    } on LocationUnavailable catch (e) {
      if (mounted) {
        setState(
          () => _location = _LocationState(
            used: _location.used,
            message: e.message,
          ),
        );
      }
    }
  }

  /// Change photo (SPEC §7.3): camera or library, copied into documents.
  Future<void> _changePhoto() async {
    FocusScope.of(context).unfocus();
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final picked = await formPickImage(source);
      if (picked == null) return;
      final name = await copyPhotoToDocuments(picked);
      if (mounted) setState(() => _draft!.photoPath = name);
    } on Exception catch (e) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("Couldn't use a photo"),
          content: Text(
            source == PhotoSource.camera
                ? 'The camera isn’t available. Choose from library instead.'
                : '$e',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Field messages to show: none until the first Save, then live.
  Map<DraftField, String> _errors() {
    final draft = _draft;
    if (draft == null || !_submitted) return const {};
    final errors = draft.errors();
    if (_duplicateId != null &&
        _duplicateId == nationalIdDigits(draft.nationalId.text)) {
      errors[DraftField.nationalId] ??= DuplicateNationalIdException.message;
    }
    return errors;
  }

  Future<void> _save() async {
    final draft = _draft!;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (_errors().isNotEmpty) return;
    setState(() => _saving = true);
    final patient = draft.toPatient();
    try {
      final repo = _scope.patients;
      if (_isAdd) {
        await repo.insert(patient, registeredBy: _scope.volunteer.name ?? '');
      } else {
        await repo.update(patient);
      }
      if (mounted) Navigator.of(context).pop();
    } on DuplicateNationalIdException {
      // Shown under the National ID field; nothing was saved (SPEC §6).
      if (mounted) {
        setState(() {
          _saving = false;
          _duplicateId = patient.nationalId;
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("Couldn't save"),
          content: Text(
            e is InvalidNationalIdException
                ? InvalidNationalIdException.message
                : '$e',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final canSave = draft != null && !_saving;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrouped,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        middle: Text(_isAdd ? 'New patient' : 'Edit patient'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: canSave ? _save : null,
          child: Text(
            'Save',
            style: AppText.headline.copyWith(
              color: canSave ? AppColors.accent : AppColors.labelQuaternary,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: draft == null
            ? const Center(child: CupertinoActivityIndicator())
            : _FormBody(
                draft: draft,
                isAdd: _isAdd,
                banner: _banner,
                errors: _errors(),
                location: _location,
                onUseLocation: _useMyLocation,
                onChangePhoto: _changePhoto,
                onChanged: _changed,
              ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.draft,
    required this.isAdd,
    required this.banner,
    required this.errors,
    required this.location,
    required this.onUseLocation,
    required this.onChangePhoto,
    required this.onChanged,
  });

  final FormDraft draft;
  final bool isAdd;
  final String? banner;
  final Map<DraftField, String> errors;
  final _LocationState location;
  final VoidCallback onUseLocation;
  final VoidCallback onChangePhoto;

  /// Rebuild after a non-text value changed.
  final VoidCallback onChanged;

  void _set(VoidCallback change) {
    change();
    onChanged();
  }

  Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) label,
    required T? selected,
    required void Function(T) onPicked,
  }) async {
    FocusScope.of(context).unfocus();
    final picked = await showChoicePicker<T>(
      context,
      title: title,
      options: options,
      label: label,
      selected: selected,
    );
    if (picked != null) _set(() => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final year = formClock().year;
    final birthYear = d.birthYear;
    final deceased = d.status == PatientStatus.deceased;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppSpace.s30),
      children: [
        if (banner != null) FormBanner(text: banner!),
        _PhotoHeader(draft: d, onChangePhoto: onChangePhoto),
        CupertinoListSection.insetGrouped(
          header: const Text('PATIENT'),
          children: [
            FieldRow(
              icon: CupertinoIcons.person_crop_rectangle,
              label: 'National ID',
              error: errors[DraftField.nationalId],
              child: FieldText(
                controller: d.nationalId,
                placeholder: '13 digits',
                color: errors.containsKey(DraftField.nationalId)
                    ? AppColors.actionDestructive
                    : AppColors.labelPrimary,
                keyboardType: TextInputType.number,
                inputFormatters: [ReformatInput(formatNationalId)],
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.person,
              label: 'Full name',
              error: errors[DraftField.fullName],
              child: FieldText(
                controller: d.fullName,
                placeholder: 'Required',
                maxLines: null,
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.person,
              label: 'Sex',
              error: errors[DraftField.sex],
              child: Align(
                alignment: Alignment.centerRight,
                child: CupertinoSlidingSegmentedControl<Sex>(
                  groupValue: d.sex,
                  onValueChanged: (v) => _set(() => d.sex = v),
                  children: const {
                    Sex.male: _SexSegment(Sex.male),
                    Sex.female: _SexSegment(Sex.female),
                  },
                ),
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.calendar,
              label: 'Born (B.E.)',
              error: errors[DraftField.born],
              child: Row(
                children: [
                  Expanded(
                    child: FieldText(
                      controller: d.bornBE,
                      placeholder: 'Year, e.g. 2500',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                    ),
                  ),
                  if (birthYear != null && d.bornBE.text.length == 4)
                    Text(
                      '(age ${year - birthYear})',
                      style: AppText.body.copyWith(
                        color: AppColors.labelSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('LOCATION'),
          footer: Text(
            location.used
                ? 'Use my location replaced the '
                      '${isAdd ? 'prefilled' : 'saved'} coordinates.'
                : 'Stand at the patient’s home and tap Use my location.',
          ),
          children: [
            FieldRow(
              icon: CupertinoIcons.map,
              label: 'Subdistrict',
              error: errors[DraftField.subdistrict],
              child: PickerValue(
                text: d.subdistrict == null
                    ? null
                    : subdistrictLabel(d.subdistrict!),
                onTap: () => _pick<String>(
                  context,
                  title: 'Subdistrict',
                  options: khlongSanSubdistricts,
                  label: subdistrictLabel,
                  selected: d.subdistrict,
                  onPicked: (v) => d.subdistrict = v,
                ),
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.house,
              label: 'Soi / road',
              child: FieldText(
                controller: d.addressNote,
                placeholder: 'Soi, road, landmark',
                maxLines: null,
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.location,
              label: 'Coordinates',
              error: errors[DraftField.coordinates],
              child: Text(
                d.lat == null || d.lng == null
                    ? 'Required: tap Use my location'
                    : '${d.lat!.toStringAsFixed(6)}, '
                          '${d.lng!.toStringAsFixed(6)}',
                style: AppText.body.copyWith(
                  color: d.lat == null
                      ? AppColors.labelQuaternary
                      : AppColors.labelSecondary,
                ),
              ),
            ),
            _UseMyLocationRow(
              locating: location.locating,
              accuracyM: d.lat == null ? null : d.gpsAccuracyM,
              hasCoordinates: d.lat != null,
              message: location.message,
              onPressed: location.locating ? null : onUseLocation,
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('CONTACT PERSON'),
          footer: const Text('Call dials Phone 1.'),
          children: [
            FieldRow(
              icon: CupertinoIcons.person,
              label: 'Name',
              error: errors[DraftField.contactName],
              child: FieldText(
                controller: d.contactName,
                placeholder: 'Required',
                maxLines: null,
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.person_2,
              label: 'Relationship',
              error: errors[DraftField.relation],
              child: PickerValue(
                text: d.relation?.label,
                onTap: () => _pick<ContactRelation>(
                  context,
                  title: 'Relationship',
                  options: ContactRelation.values,
                  label: (v) => v.label,
                  selected: d.relation,
                  onPicked: (v) => d.relation = v,
                ),
              ),
            ),
            for (var i = 0; i < d.phones.length; i++)
              FieldRow(
                icon: CupertinoIcons.phone,
                label: 'Phone ${i + 1}',
                error: i == d.phones.length - 1
                    ? errors[DraftField.phones]
                    : null,
                child: FieldText(
                  controller: d.phones[i],
                  placeholder: '10 digits',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [ReformatInput(formatPhoneInput)],
                ),
              ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              alignment: Alignment.centerLeft,
              onPressed: () => _set(() => d.addPhone(onChanged)),
              child: const Text('+ Add phone'),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('CARE'),
          footer: const Text(
            'Care level follows the ADL score: bedridden 0–4, '
            'homebound 5–11, social 12–20.',
          ),
          children: [
            FieldRow(
              icon: CupertinoIcons.chart_bar,
              label: 'ADL score',
              error: errors[DraftField.adlScore],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${d.adlScore ?? 0}',
                      style: AppText.body.copyWith(
                        color: d.adlScore == null
                            ? AppColors.labelQuaternary
                            : AppColors.labelPrimary,
                      ),
                    ),
                  ),
                  AdlStepper(
                    onMinus: d.adlScore == 0
                        ? null
                        : () => _set(() => d.stepAdl(-1)),
                    onPlus: d.adlScore == 20
                        ? null
                        : () => _set(() => d.stepAdl(1)),
                  ),
                ],
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.heart,
              label: 'Care level',
              child: Align(
                alignment: Alignment.centerRight,
                child: d.careLevel == null
                    ? Text(
                        'Set by ADL score',
                        style: AppText.body.copyWith(
                          color: AppColors.labelQuaternary,
                        ),
                      )
                    : CareLevelBadge(level: d.careLevel!),
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.plus_square,
              label: 'Main condition',
              error: errors[DraftField.mainCondition],
              child: PickerValue(
                text: d.mainCondition?.label,
                onTap: () => _pick<MainCondition>(
                  context,
                  title: 'Main condition',
                  options: MainCondition.values,
                  label: (v) => v.label,
                  selected: d.mainCondition,
                  onPicked: (v) => d.mainCondition = v,
                ),
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.house_alt,
              label: 'Living situation',
              error: errors[DraftField.livingSituation],
              child: PickerValue(
                text: d.livingSituation?.label,
                onTap: () => _pick<LivingSituation>(
                  context,
                  title: 'Living situation',
                  options: LivingSituation.values,
                  label: (v) => v.label,
                  selected: d.livingSituation,
                  onPicked: (v) => d.livingSituation = v,
                ),
              ),
            ),
            FieldRow(
              icon: CupertinoIcons.bandage,
              label: 'Care needs',
              below: Padding(
                padding: const EdgeInsets.only(top: AppSpace.s10),
                child: Wrap(
                  spacing: AppSpace.s6,
                  runSpacing: AppSpace.s6,
                  children: [
                    for (final n in CareNeed.values)
                      NeedChip(
                        label: n.label,
                        selected: d.careNeeds.contains(n),
                        onTap: () => _set(() {
                          if (!d.careNeeds.remove(n)) d.careNeeds.add(n);
                        }),
                      ),
                  ],
                ),
              ),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('STATUS'),
          footer: Text(
            deceased
                ? deceasedStatusHint
                : 'To mark a patient deceased, swipe left on the list.',
          ),
          children: [
            if (deceased)
              // Read-only with a lock (SPEC §7.3, Figma frame 25): restore is
              // by swipe in the list, never from the form.
              FieldRow(
                icon: CupertinoIcons.checkmark_circle,
                label: 'Status',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        PatientStatus.deceased.label,
                        style: AppText.body.copyWith(
                          color: AppColors.labelTertiary,
                        ),
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.lock_fill,
                      size: AppSpace.s16,
                      color: AppColors.iconSecondary,
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpace.s8),
                child: CupertinoSlidingSegmentedControl<PatientStatus>(
                  groupValue: d.status,
                  onValueChanged: (v) {
                    if (v != null) _set(() => d.status = v);
                  },
                  children: {
                    for (final s in formStatuses) s: _Segment(s.label),
                  },
                ),
              ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('NOTES'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s11,
              ),
              child: FieldText(
                controller: d.notes,
                placeholder: 'Optional',
                maxLines: null,
              ),
            ),
          ],
        ),
        if (!isAdd)
          CupertinoListSection.insetGrouped(
            header: const Text('REGISTRATION'),
            footer: const Text(
              'Set when the patient was first saved; edits never change it.',
            ),
            children: [
              FieldRow(
                icon: CupertinoIcons.person_badge_plus,
                label: 'Registered by',
                child: Text(
                  d.base!.registeredBy.isEmpty ? '—' : d.base!.registeredBy,
                  style: AppText.body.copyWith(color: AppColors.labelSecondary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Shown when Use my location lands outside every subdistrict (SPEC §7.3).
const outsideDistrictMessage = 'Outside Khlong San district';

/// Progress and outcome of Use my location.
class _LocationState {
  const _LocationState({
    this.locating = false,
    this.used = false,
    this.message,
  });

  final bool locating;

  /// Whether a fix replaced the coordinates on this form.
  final bool used;

  /// "Outside Khlong San district", or why there's no fix.
  final String? message;
}

/// "➤ Use my location" with the accuracy pill (Figma frames 19, 25).
class _UseMyLocationRow extends StatelessWidget {
  const _UseMyLocationRow({
    required this.locating,
    required this.accuracyM,
    required this.hasCoordinates,
    required this.message,
    required this.onPressed,
  });

  final bool locating;
  final double? accuracyM;
  final bool hasCoordinates;
  final String? message;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final acc = accuracyM;
    final color = onPressed == null
        ? AppColors.labelQuaternary
        : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  enabled: onPressed != null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.location_fill,
                            size: AppSpace.s20,
                            color: color,
                          ),
                          const SizedBox(width: AppSpace.s12),
                          Flexible(
                            child: Text(
                              'Use my location',
                              style: AppText.body.copyWith(color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (locating)
                const CupertinoActivityIndicator()
              else if (hasCoordinates)
                _AccuracyPill(
                  text: acc == null ? 'Not recorded' : accuracyText(acc),
                  good: acc != null,
                ),
            ],
          ),
          if (message != null) FieldError(text: message!),
        ],
      ),
    );
  }
}

class _AccuracyPill extends StatelessWidget {
  const _AccuracyPill({required this.text, required this.good});

  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: good
            ? AppColors.careSocial.withValues(
                alpha: AppColors.careSocialOpacityTintBg,
              )
            : AppColors.fillTertiary.withValues(
                alpha: AppColors.fillTertiaryOpacity,
              ),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s2,
        ),
        child: Text(
          text,
          style: AppText.footnoteEmphasized.copyWith(
            color: good ? AppColors.careSocialText : AppColors.labelSecondary,
          ),
        ),
      ),
    );
  }
}

/// Footer under the read-only Deceased status (Figma frame 25).
const deceasedStatusHint =
    'Read-only. To restore, turn on Show inactive in the list and swipe '
    'this patient’s row left.';

/// The statuses the form's picker offers (SPEC §7.3): never Deceased.
const formStatuses = [
  PatientStatus.active,
  PatientStatus.inHospital,
  PatientStatus.moved,
];

/// The photo with "Change photo" / "Add photo" under it (Figma 19, 23).
class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.draft, required this.onChangePhoto});

  final FormDraft draft;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final b = draft.base;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16),
      child: Column(
        children: [
          PatientAvatar(
            // Only the name and photo are read.
            patient: Patient(
              id: b?.id ?? '',
              nationalId: '',
              fullName: draft.fullName.text,
              sex: draft.sex ?? Sex.male,
              birthYear: 0,
              photoPath: draft.photoPath,
              contactName: '',
              contactRelation: ContactRelation.self,
              subdistrict: '',
              lat: 0,
              lng: 0,
              careLevel: CareLevel.social,
              mainCondition: MainCondition.other,
              livingSituation: LivingSituation.withCaregiver,
            ),
            size: _photoSize,
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
            minimumSize: Size.zero,
            onPressed: onChangePhoto,
            child: Text(
              draft.photoPath == null ? 'Add photo' : 'Change photo',
              style: AppText.subheadline.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SexSegment extends StatelessWidget {
  const _SexSegment(this.sex);

  final Sex sex;

  @override
  Widget build(BuildContext context) {
    final (symbol, color) = switch (sex) {
      Sex.male => ('♂', AppColors.sexMale),
      Sex.female => ('♀', AppColors.sexFemale),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$symbol ',
              style: AppText.segmentLabel.copyWith(color: color),
            ),
            TextSpan(
              text: sex.label,
              style: AppText.segmentLabel.copyWith(
                color: AppColors.labelPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.segmentLabel.copyWith(color: AppColors.labelPrimary),
  );
}
