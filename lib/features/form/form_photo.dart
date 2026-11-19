// The patient photo (SPEC §2, §6, §7.3): "Change photo" → Take photo /
// Choose from library; the picked file is copied into the app documents
// folder and photo_path stores only its file name (see patient_avatar.dart).

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/patient.dart';
import '../../shared/patient_avatar.dart';

/// Where a photo comes from.
enum PhotoSource { camera, library }

/// Longest edge of a picked photo; the list and detail show it at ≤ 104 pt.
const _maxPhotoEdge = 1024.0;

/// Opens the system picker and returns the picked file's path, or null when
/// the volunteer cancels. Replaceable in tests.
Future<String?> Function(PhotoSource) formPickImage = _pickWithImagePicker;

Future<String?> _pickWithImagePicker(PhotoSource source) async {
  final file = await ImagePicker().pickImage(
    source: switch (source) {
      PhotoSource.camera => ImageSource.camera,
      PhotoSource.library => ImageSource.gallery,
    },
    maxWidth: _maxPhotoEdge,
    maxHeight: _maxPhotoEdge,
  );
  return file?.path;
}

/// Copies the picked file at [pickedPath] into the documents folder as
/// `photo_<uuid>.<ext>` and returns that file name (the photo_path value).
Future<String> copyPhotoToDocuments(String pickedPath) async {
  final dot = pickedPath.lastIndexOf('.');
  final ext = dot > pickedPath.lastIndexOf('/')
      ? pickedPath.substring(dot).toLowerCase()
      : '.jpg';
  final name = 'photo_${Patient.newId()}$ext';
  final documents = await photoDirectory();
  await File(pickedPath).copy(documentsPhotoFile(documents, name).path);
  return name;
}

/// The "Patient photo" action sheet (Figma frame 20). Returns the choice,
/// or null for Cancel.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) =>
    showCupertinoModalPopup<PhotoSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Patient photo'),
        message: const Text(
          'The Simulator has no camera; use the photo library there.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(PhotoSource.camera),
            child: const Text('Take photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(PhotoSource.library),
            child: const Text('Choose from library'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
