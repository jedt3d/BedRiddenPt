// Display labels for the stored enum values (SPEC §7.3, Figma frames 19–25).
// Screens show these, never the enum names.

import '../data/patient.dart';

extension SexLabel on Sex {
  String get label => switch (this) {
    Sex.male => 'Male',
    Sex.female => 'Female',
  };
}

extension ContactRelationLabel on ContactRelation {
  String get label => switch (this) {
    ContactRelation.self => 'Self',
    ContactRelation.spouse => 'Spouse',
    ContactRelation.child => 'Child',
    ContactRelation.grandchild => 'Grandchild',
    ContactRelation.sibling => 'Sibling',
    ContactRelation.otherRelative => 'Other relative',
    ContactRelation.neighbour => 'Neighbour',
    ContactRelation.other => 'Other',
  };
}

extension CareLevelLabel on CareLevel {
  String get label => switch (this) {
    CareLevel.bedridden => 'Bedridden',
    CareLevel.homebound => 'Homebound',
    CareLevel.social => 'Social',
  };
}

extension MainConditionLabel on MainCondition {
  String get label => switch (this) {
    MainCondition.stroke => 'Stroke',
    MainCondition.dementia => 'Dementia',
    MainCondition.frailty => 'Frailty',
    MainCondition.spinalInjury => 'Spinal injury',
    MainCondition.cancer => 'Cancer',
    MainCondition.other => 'Other',
  };
}

extension LivingSituationLabel on LivingSituation {
  String get label => switch (this) {
    LivingSituation.withCaregiver => 'With caregiver',
    LivingSituation.livesAlone => 'Lives alone',
    LivingSituation.elderlyCaregiver => 'Elderly caregiver',
  };
}

extension PatientStatusLabel on PatientStatus {
  String get label => switch (this) {
    PatientStatus.active => 'Active',
    PatientStatus.inHospital => 'In hospital',
    PatientStatus.moved => 'Moved',
    PatientStatus.deceased => 'Deceased',
  };
}

extension CareNeedLabel on CareNeed {
  String get label => switch (this) {
    CareNeed.bedsore => 'Bedsore',
    CareNeed.feedingTube => 'Feeding tube',
    CareNeed.catheter => 'Catheter',
    CareNeed.oxygen => 'Oxygen',
    CareNeed.needsAirMattress => 'Air mattress',
    CareNeed.needsWheelchair => 'Wheelchair',
  };
}
