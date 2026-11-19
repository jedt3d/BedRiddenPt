// The values being edited in the Add / Edit form (SPEC §5, §7.3), turned
// into a Patient on Save.

import 'package:flutter/widgets.dart';

import '../../data/patient.dart';
import '../../shared/national_id.dart';

/// The current time. Replaceable in tests so ages don't depend on the clock.
DateTime Function() formClock = DateTime.now;

/// The four subdistricts, in SPEC §3 order, as stored (OSM `name:en`).
const khlongSanSubdistricts = [
  'Somdet Chao Phraya Subdistrict',
  'Khlong San Subdistrict',
  'Khlong Ton Sai Subdistrict',
  'Bang Lamphu Lang Subdistrict',
];

/// "Bang Lamphu Lang" for "Bang Lamphu Lang Subdistrict".
String subdistrictLabel(String name) =>
    name.replaceFirst(RegExp(r' Subdistrict$'), '');

/// "092-835-7619" while typing up to 10 digits; non-digits are dropped.
String formatPhoneInput(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length > 10) d = d.substring(0, 10);
  if (d.length <= 3) return d;
  if (d.length <= 6) return '${d.substring(0, 3)}-${d.substring(3)}';
  return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
}

/// Ages the app accepts (SPEC §5).
const minAge = 60;
const maxAge = 110;

/// The fields that can show a validation message.
enum DraftField {
  nationalId,
  fullName,
  sex,
  born,
  subdistrict,
  coordinates,
  contactName,
  relation,
  phones,
  adlScore,
  mainCondition,
  livingSituation,
}

String phoneDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

class FormDraft {
  /// An empty Add form.
  FormDraft.empty() : base = null {
    phones.add(TextEditingController());
  }

  /// Edit [p], or Add prefilled from a pool record [p].
  FormDraft.fromPatient(Patient p) : base = p {
    nationalId.text = formatNationalId(p.nationalId);
    fullName.text = p.fullName;
    sex = p.sex;
    bornBE.text = '${p.birthYearBE}';
    photoPath = p.photoPath;
    subdistrict = p.subdistrict;
    addressNote.text = p.addressNote;
    lat = p.lat;
    lng = p.lng;
    gpsAccuracyM = p.gpsAccuracyM;
    contactName.text = p.contactName;
    relation = p.contactRelation;
    for (final phone in p.phones) {
      phones.add(TextEditingController(text: formatPhoneInput(phone)));
    }
    if (phones.isEmpty) phones.add(TextEditingController());
    adlScore = p.adlScore;
    storedCareLevel = p.careLevel;
    mainCondition = p.mainCondition;
    livingSituation = p.livingSituation;
    careNeeds = {...p.careNeeds};
    status = p.status;
    notes.text = p.notes;
  }

  /// The patient being edited, or the pool record Add was prefilled from.
  /// Its id, registered_by and timestamps carry over.
  final Patient? base;

  final nationalId = TextEditingController();
  final fullName = TextEditingController();

  /// The birth year as typed, in the Buddhist era.
  final bornBE = TextEditingController();
  final addressNote = TextEditingController();
  final contactName = TextEditingController();
  final phones = <TextEditingController>[];
  final notes = TextEditingController();

  Sex? sex;
  String? photoPath;
  String? subdistrict;
  double? lat;
  double? lng;
  double? gpsAccuracyM;
  ContactRelation? relation;
  int? adlScore;

  /// The stored care level, used only while there is no ADL score.
  CareLevel? storedCareLevel;
  MainCondition? mainCondition;
  LivingSituation? livingSituation;
  Set<CareNeed> careNeeds = {};
  PatientStatus status = PatientStatus.active;

  List<TextEditingController> get _controllers => [
    nationalId,
    fullName,
    bornBE,
    addressNote,
    contactName,
    notes,
    ...phones,
  ];

  /// Calls [listener] whenever any text field changes.
  void addTextListener(VoidCallback listener) {
    for (final c in _controllers) {
      c.addListener(listener);
    }
  }

  TextEditingController addPhone(VoidCallback listener) {
    final c = TextEditingController()..addListener(listener);
    phones.add(c);
    return c;
  }

  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
  }

  /// Care level from the ADL score (SPEC §5 bands), else the stored one.
  CareLevel? get careLevel {
    final adl = adlScore;
    return adl == null ? storedCareLevel : CareLevel.fromAdl(adl);
  }

  /// Gregorian birth year from the typed B.E. year, or null.
  int? get birthYear {
    final be = int.tryParse(bornBE.text.trim());
    return be == null ? null : be - 543;
  }

  /// Steps the ADL score by [delta] within 0–20 (no score yet counts as 0).
  void stepAdl(int delta) => adlScore = ((adlScore ?? 0) + delta).clamp(0, 20);

  /// The 10-digit phones typed so far, in order; empty fields are left out.
  List<String> get phoneNumbers => [
    for (final c in phones)
      if (phoneDigits(c.text).isNotEmpty) phoneDigits(c.text),
  ];

  /// Validation messages by field (SPEC §5, §7.3); empty when the draft can
  /// be saved. Duplicate national IDs are found by the repository on Save.
  Map<DraftField, String> errors() {
    final e = <DraftField, String>{};
    final id = nationalIdDigits(nationalId.text);
    if (id.length != 13) {
      e[DraftField.nationalId] = 'Enter the 13-digit national ID.';
    } else if (!isValidNationalId(id)) {
      e[DraftField.nationalId] = invalidNationalIdMessage;
    }
    if (fullName.text.trim().isEmpty) {
      e[DraftField.fullName] = 'Enter the patient’s full name.';
    }
    if (sex == null) e[DraftField.sex] = 'Choose male or female.';
    final year = formClock().year;
    final born = birthYear;
    if (born == null) {
      e[DraftField.born] = 'Enter the birth year in B.E.';
    } else if (year - born < minAge || year - born > maxAge) {
      e[DraftField.born] =
          'Age must be $minAge–$maxAge: born '
          '${year - maxAge + 543}–${year - minAge + 543} B.E.';
    }
    if (subdistrict == null) {
      e[DraftField.subdistrict] = 'Choose a subdistrict.';
    }
    if (lat == null || lng == null) {
      e[DraftField.coordinates] = 'Tap Use my location.';
    }
    if (contactName.text.trim().isEmpty) {
      e[DraftField.contactName] = 'Enter the contact person’s name.';
    }
    if (relation == null) e[DraftField.relation] = 'Choose a relationship.';
    if (phones.any((c) {
      final n = phoneDigits(c.text).length;
      return n != 0 && n != 10;
    })) {
      e[DraftField.phones] = 'Phone numbers have 10 digits.';
    }
    if (careLevel == null) e[DraftField.adlScore] = 'Set the ADL score.';
    if (mainCondition == null) {
      e[DraftField.mainCondition] = 'Choose a main condition.';
    }
    if (livingSituation == null) {
      e[DraftField.livingSituation] = 'Choose a living situation.';
    }
    return e;
  }

  /// The patient to save. Call only when [errors] is empty.
  Patient toPatient() {
    final b = base;
    return Patient(
      id: b?.id ?? '',
      nationalId: nationalIdDigits(nationalId.text),
      fullName: fullName.text.trim(),
      sex: sex!,
      birthYear: birthYear!,
      photoPath: photoPath,
      contactName: contactName.text.trim(),
      contactRelation: relation!,
      phones: phoneNumbers,
      subdistrict: subdistrict!,
      addressNote: addressNote.text.trim(),
      lat: lat!,
      lng: lng!,
      gpsAccuracyM: gpsAccuracyM,
      careLevel: careLevel!,
      adlScore: adlScore,
      mainCondition: mainCondition!,
      careNeeds: careNeeds,
      livingSituation: livingSituation!,
      status: status,
      notes: notes.text.trim(),
      registeredBy: b?.registeredBy ?? '',
      createdAt: b?.createdAt ?? '',
      updatedAt: b?.updatedAt ?? '',
    );
  }
}
