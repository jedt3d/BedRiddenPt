// The patient's photo (SPEC §6): a bundled asset, a picked photo in the app
// documents folder, or an initials avatar.
//
// Storing photo_path: a bundled photo keeps its asset path
// ("assets/avatars/…"). A picked photo is copied into the app documents
// folder and photo_path stores only its FILE NAME (e.g. "photo_<id>.jpg"),
// because the iOS container path changes on reinstall. [documentsPhotoFile]
// turns it back into a file; an older value holding a full path is read by
// its last segment.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../data/patient.dart';
import '../theme/tokens.dart';

/// Where picked photos live. Replaceable in tests.
Future<Directory> Function() photoDirectory = getApplicationDocumentsDirectory;

bool isBundledPhoto(String photoPath) => photoPath.startsWith('assets/');

/// The documents file for a stored (non-asset) photo_path.
File documentsPhotoFile(Directory documents, String photoPath) =>
    File('${documents.path}/${photoPath.split('/').last}');

/// Up to two initials from the full name, e.g. "Somchit Bunyuen" → "SB".
String initialsOf(String fullName) {
  final words = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

class PatientAvatar extends StatelessWidget {
  const PatientAvatar({super.key, required this.patient, required this.size});

  final Patient patient;

  /// Diameter in logical pixels (use an [AppSpace] value).
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = patient.photoPath;
    final Widget content;
    if (path == null || path.isEmpty) {
      content = _initials();
    } else if (isBundledPhoto(path)) {
      content = Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initials(),
      );
    } else {
      // One documents-folder lookup per run, so rebuilds don't flicker.
      content = FutureBuilder(
        future: _documents(),
        builder: (context, snapshot) {
          final file = snapshot.hasData
              ? documentsPhotoFile(snapshot.data!, path)
              : null;
          return file == null || !file.existsSync()
              ? _initials()
              : Image.file(
                  file,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _initials(),
                );
        },
      );
    }
    return ClipOval(
      child: SizedBox(width: size, height: size, child: content),
    );
  }

  static (Future<Directory> Function(), Future<Directory>)? _cache;

  static Future<Directory> _documents() {
    final cached = _cache;
    if (cached != null && cached.$1 == photoDirectory) return cached.$2;
    final future = photoDirectory();
    _cache = (photoDirectory, future);
    return future;
  }

  Widget _initials() => ColoredBox(
    color: AppColors.fillPhotoPlaceholder,
    child: Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s8),
          child: Text(
            initialsOf(patient.fullName),
            style: AppText.initials.copyWith(color: AppColors.labelInverse),
          ),
        ),
      ),
    ),
  );
}
