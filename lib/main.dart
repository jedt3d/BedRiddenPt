import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'data/patient_repository.dart';
import 'data/volunteer_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Seeds 5 sample patients on the very first launch only.
  final patients = await PatientRepository.open();
  final volunteer = await VolunteerStore.open();
  runApp(BedriddenPtApp(patients: patients, volunteer: volunteer));
}
