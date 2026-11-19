import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled sample pool loads with rootBundle', () async {
    final pool = jsonDecode(await rootBundle.loadString('assets/bootstrap.json')) as List;
    expect(pool, hasLength(50));
  });

  test('geo and avatar assets are bundled', () async {
    final boundary = await rootBundle.loadString('assets/geo/khlong_san_boundary.geojson');
    expect(boundary, isNotEmpty);

    final first = (jsonDecode(await rootBundle.loadString('assets/bootstrap.json')) as List).first;
    final photo = await rootBundle.load((first as Map)['photoPath'] as String);
    expect(photo.lengthInBytes, greaterThan(0));
  });
}
