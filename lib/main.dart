import 'package:flutter/cupertino.dart';

import 'data/patient_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Seeds 5 sample patients on the very first launch only.
  final patients = await PatientRepository.open();
  runApp(BedriddenPtApp(patients: patients));
}

/// Root widget. Cupertino only (SPEC §2): no Material widgets in screens.
class BedriddenPtApp extends StatelessWidget {
  const BedriddenPtApp({super.key, required this.patients});

  final PatientRepository patients;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Bedridden Patient Locator',
      home: PlaceholderHome(patients: patients),
    );
  }
}

/// Temporary home screen until the app shell lands.
class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key, required this.patients});

  final PatientRepository patients;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bedridden Patient Locator'),
      ),
      child: Center(
        child: FutureBuilder(
          future: patients.list(showInactive: true),
          builder: (context, snapshot) => Text(
            snapshot.hasData ? '${snapshot.data!.length} patients' : 'Loading…',
          ),
        ),
      ),
    );
  }
}
