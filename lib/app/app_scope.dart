// App-wide objects, available to every screen with AppScope.of(context).

import 'package:flutter/widgets.dart';

import '../data/patient_repository.dart';
import '../data/volunteer_store.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.patients,
    required this.volunteer,
    required this.showInactive,
    required super.child,
  });

  /// All patient reads and writes. Listen to it to reload after any change.
  final PatientRepository patients;

  /// The volunteer's name (for registered_by) and the fixed PIN.
  final VolunteerStore volunteer;

  /// The "Show inactive" switch, shared by the List and Map tabs. Off at start.
  final ValueNotifier<bool> showInactive;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      patients != oldWidget.patients ||
      volunteer != oldWidget.volunteer ||
      showInactive != oldWidget.showInactive;
}
