// Stable route names (SPEC §7). Feature screens navigate only through these.

import 'package:flutter/cupertino.dart';

import '../features/detail/detail_screen.dart';
import '../features/form/patient_form_screen.dart';
import '../features/launch/name_screen.dart';
import '../features/launch/pin_screen.dart';
import 'home_screen.dart';

abstract final class Routes {
  /// First launch only: "Your name". No arguments.
  static const name = '/name';

  /// PIN entry, every launch. No arguments.
  static const pin = '/pin';

  /// Home with the List | Map tabs. No arguments.
  static const home = '/home';

  /// Patient detail. Argument: the patient id (String).
  static const detail = '/detail';

  /// Add patient form. No arguments.
  static const add = '/add';

  /// Edit patient form. Argument: the patient id (String).
  static const edit = '/edit';

  static Route<void>? onGenerateRoute(RouteSettings settings) {
    final Widget? page = switch (settings.name) {
      name => const NameScreen(),
      pin => const PinScreen(),
      home => const HomeScreen(),
      detail => DetailScreen(patientId: settings.arguments! as String),
      add => const PatientFormScreen(),
      edit => PatientFormScreen(patientId: settings.arguments! as String),
      _ => null,
    };
    return page == null
        ? null
        : CupertinoPageRoute<void>(
            settings: settings,
            // The next screen's back button shows this title (Figma 17:
            // "< Patients" on Detail, "< Patient" on Edit).
            title: switch (settings.name) {
              home => 'Patients',
              detail => 'Patient',
              _ => null,
            },
            builder: (_) => page,
          );
  }

  // Detail, Add and Edit are pushed on the root navigator, above the tab bar
  // (SPEC §7: no tab bar on those screens). Use these, not Navigator.of.

  static Future<void> openDetail(BuildContext context, String patientId) =>
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed(detail, arguments: patientId);

  static Future<void> openAdd(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).pushNamed(add);

  static Future<void> openEdit(BuildContext context, String patientId) =>
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed(edit, arguments: patientId);

  /// Replaces the whole stack, e.g. name → PIN → Home.
  static Future<void> replaceAllWith(BuildContext context, String route) =>
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(route, (_) => false);
}
