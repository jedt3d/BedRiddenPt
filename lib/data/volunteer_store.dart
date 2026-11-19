// The volunteer's name (SPEC §2, §7.1): asked once on first launch, used for
// registered_by. The PIN is a constant, not stored.

import 'package:shared_preferences/shared_preferences.dart';

/// The fixed PIN (SPEC §7.1). It can't be changed.
const appPin = '000000';

class VolunteerStore {
  VolunteerStore(this._prefs);

  static const _nameKey = 'volunteer_name';

  static Future<VolunteerStore> open() async =>
      VolunteerStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  /// Null until the "Your name" screen has saved one.
  String? get name => _prefs.getString(_nameKey);

  Future<void> setName(String name) => _prefs.setString(_nameKey, name.trim());
}
