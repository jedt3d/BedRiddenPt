import 'package:flutter/cupertino.dart';

import '../data/patient_repository.dart';
import '../data/volunteer_store.dart';
import '../theme/tokens.dart';
import 'app_scope.dart';
import 'routes.dart';

/// Root widget. Cupertino only (SPEC §2): no Material widgets in screens.
class BedriddenPtApp extends StatefulWidget {
  const BedriddenPtApp({
    super.key,
    required this.patients,
    required this.volunteer,
  });

  final PatientRepository patients;
  final VolunteerStore volunteer;

  @override
  State<BedriddenPtApp> createState() => _BedriddenPtAppState();
}

class _BedriddenPtAppState extends State<BedriddenPtApp> {
  final _showInactive = ValueNotifier(false);

  @override
  void dispose() {
    _showInactive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      patients: widget.patients,
      volunteer: widget.volunteer,
      showInactive: _showInactive,
      child: CupertinoApp(
        title: 'Bedridden Patient Locator',
        theme: const CupertinoThemeData(
          primaryColor: AppColors.accent,
          scaffoldBackgroundColor: AppColors.bgGrouped,
        ),
        // First launch asks for the volunteer's name once (SPEC §7.1).
        initialRoute: widget.volunteer.name == null ? Routes.name : Routes.pin,
        onGenerateRoute: Routes.onGenerateRoute,
      ),
    );
  }
}
