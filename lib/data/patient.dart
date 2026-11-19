// The patient registration (SPEC §5, GLOSSARY.md). Enum value names are the
// exact strings stored in SQLite and in assets/bootstrap.json.

import 'dart:math';

enum Sex { male, female }

enum ContactRelation {
  self,
  spouse,
  child,
  grandchild,
  sibling,
  otherRelative,
  neighbour,
  other,
}

/// Care level (stored in the `dependency` column), derived from the ADL score.
enum CareLevel {
  bedridden,
  homebound,
  social;

  /// Bands from SPEC §5: bedridden 0–4, homebound 5–11, social 12–20.
  static CareLevel fromAdl(int score) {
    if (score < 0 || score > 20) throw RangeError.range(score, 0, 20, 'score');
    if (score <= 4) return bedridden;
    if (score <= 11) return homebound;
    return social;
  }
}

enum MainCondition { stroke, dementia, frailty, spinalInjury, cancer, other }

enum LivingSituation { withCaregiver, livesAlone, elderlyCaregiver }

enum PatientStatus {
  active,
  inHospital,
  moved,
  deceased;

  /// Inactive = moved or deceased (GLOSSARY.md).
  bool get isInactive => this == moved || this == deceased;
}

enum CareNeed {
  bedsore,
  feedingTube,
  catheter,
  oxygen,
  needsAirMattress,
  needsWheelchair,
}

class Patient {
  const Patient({
    required this.id,
    required this.nationalId,
    required this.fullName,
    required this.sex,
    required this.birthYear,
    this.photoPath,
    required this.contactName,
    required this.contactRelation,
    this.phones = const [],
    required this.subdistrict,
    this.addressNote = '',
    required this.lat,
    required this.lng,
    this.gpsAccuracyM,
    required this.careLevel,
    this.adlScore,
    required this.mainCondition,
    this.careNeeds = const {},
    required this.livingSituation,
    this.status = PatientStatus.active,
    this.notes = '',
    this.registeredBy = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;

  /// 13 digits, no dashes.
  final String nationalId;
  final String fullName;
  final Sex sex;

  /// Gregorian. The UI shows the Buddhist era, [birthYearBE].
  final int birthYear;

  /// A bundled asset path (`assets/…`) or a file in app documents.
  final String? photoPath;
  final String contactName;
  final ContactRelation contactRelation;

  /// The contact person's phones, 10 digits each; the first is the one Call dials.
  final List<String> phones;

  /// OSM `name:en`, e.g. `Khlong San Subdistrict`.
  final String subdistrict;
  final String addressNote;
  final double lat;
  final double lng;
  final double? gpsAccuracyM;
  final CareLevel careLevel;
  final int? adlScore;
  final MainCondition mainCondition;
  final Set<CareNeed> careNeeds;
  final LivingSituation livingSituation;
  final PatientStatus status;
  final String notes;

  /// Set once by [PatientRepository.insert]; edits never change it.
  final String registeredBy;

  /// ISO 8601, set by the repository.
  final String createdAt;
  final String updatedAt;

  int get birthYearBE => birthYear + 543;

  int ageIn(int year) => year - birthYear;

  /// A new random UUID v4 for [id].
  static String newId([Random? random]) {
    final r = random ?? Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// From a record of `assets/bootstrap.json` (camelCase keys).
  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    id: j['id'] as String,
    nationalId: j['nationalId'] as String,
    fullName: j['fullName'] as String,
    sex: Sex.values.byName(j['sex'] as String),
    birthYear: j['birthYear'] as int,
    photoPath: j['photoPath'] as String?,
    contactName: j['contactName'] as String,
    contactRelation: ContactRelation.values.byName(
      j['contactRelation'] as String,
    ),
    phones: [for (final p in j['phones'] as List) p as String],
    subdistrict: j['subdistrict'] as String,
    addressNote: j['addressNote'] as String? ?? '',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    gpsAccuracyM: (j['gpsAccuracyM'] as num?)?.toDouble(),
    careLevel: CareLevel.values.byName(j['dependency'] as String),
    adlScore: j['adlScore'] as int?,
    mainCondition: MainCondition.values.byName(j['mainCondition'] as String),
    careNeeds: {
      for (final n in j['careNeeds'] as List)
        CareNeed.values.byName(n as String),
    },
    livingSituation: LivingSituation.values.byName(
      j['livingSituation'] as String,
    ),
    status: PatientStatus.values.byName(j['status'] as String),
    notes: j['notes'] as String? ?? '',
    registeredBy: j['registeredBy'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? '',
    updatedAt: j['updatedAt'] as String? ?? '',
  );

  /// From a `patients` row plus its child-table values.
  factory Patient.fromRow(
    Map<String, Object?> r, {
    List<String> phones = const [],
    Set<CareNeed> careNeeds = const {},
  }) => Patient(
    id: r['id'] as String,
    nationalId: r['national_id'] as String,
    fullName: r['full_name'] as String,
    sex: Sex.values.byName(r['sex'] as String),
    birthYear: r['birth_year'] as int,
    photoPath: r['photo_path'] as String?,
    contactName: r['contact_name'] as String,
    contactRelation: ContactRelation.values.byName(
      r['contact_relation'] as String,
    ),
    phones: phones,
    subdistrict: r['subdistrict'] as String,
    addressNote: r['address_note'] as String,
    lat: (r['lat'] as num).toDouble(),
    lng: (r['lng'] as num).toDouble(),
    gpsAccuracyM: (r['gps_accuracy_m'] as num?)?.toDouble(),
    careLevel: CareLevel.values.byName(r['dependency'] as String),
    adlScore: r['adl_score'] as int?,
    mainCondition: MainCondition.values.byName(r['main_condition'] as String),
    careNeeds: careNeeds,
    livingSituation: LivingSituation.values.byName(
      r['living_situation'] as String,
    ),
    status: PatientStatus.values.byName(r['status'] as String),
    notes: r['notes'] as String,
    registeredBy: r['registered_by'] as String,
    createdAt: r['created_at'] as String,
    updatedAt: r['updated_at'] as String,
  );

  /// The `patients` columns that an edit may change (not id, registered_by, created_at).
  Map<String, Object?> editableColumns() => {
    'national_id': nationalId,
    'full_name': fullName,
    'sex': sex.name,
    'birth_year': birthYear,
    'photo_path': photoPath,
    'contact_name': contactName,
    'contact_relation': contactRelation.name,
    'subdistrict': subdistrict,
    'address_note': addressNote,
    'lat': lat,
    'lng': lng,
    'gps_accuracy_m': gpsAccuracyM,
    'dependency': careLevel.name,
    'adl_score': adlScore,
    'main_condition': mainCondition.name,
    'living_situation': livingSituation.name,
    'status': status.name,
    'notes': notes,
  };

  Patient copyWith({
    String? id,
    String? nationalId,
    String? fullName,
    Sex? sex,
    int? birthYear,
    String? Function()? photoPath,
    String? contactName,
    ContactRelation? contactRelation,
    List<String>? phones,
    String? subdistrict,
    String? addressNote,
    double? lat,
    double? lng,
    double? Function()? gpsAccuracyM,
    CareLevel? careLevel,
    int? Function()? adlScore,
    MainCondition? mainCondition,
    Set<CareNeed>? careNeeds,
    LivingSituation? livingSituation,
    PatientStatus? status,
    String? notes,
    String? registeredBy,
    String? createdAt,
    String? updatedAt,
  }) => Patient(
    id: id ?? this.id,
    nationalId: nationalId ?? this.nationalId,
    fullName: fullName ?? this.fullName,
    sex: sex ?? this.sex,
    birthYear: birthYear ?? this.birthYear,
    photoPath: photoPath != null ? photoPath() : this.photoPath,
    contactName: contactName ?? this.contactName,
    contactRelation: contactRelation ?? this.contactRelation,
    phones: phones ?? this.phones,
    subdistrict: subdistrict ?? this.subdistrict,
    addressNote: addressNote ?? this.addressNote,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    gpsAccuracyM: gpsAccuracyM != null ? gpsAccuracyM() : this.gpsAccuracyM,
    careLevel: careLevel ?? this.careLevel,
    adlScore: adlScore != null ? adlScore() : this.adlScore,
    mainCondition: mainCondition ?? this.mainCondition,
    careNeeds: careNeeds ?? this.careNeeds,
    livingSituation: livingSituation ?? this.livingSituation,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    registeredBy: registeredBy ?? this.registeredBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
