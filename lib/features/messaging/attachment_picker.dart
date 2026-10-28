import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import 'messaging_models.dart';
import 'messaging_styles.dart';

/// Where a file the person chose comes from: its name, its size when the
/// phone already knows it, and a way to read it. The seam between the app and
/// the phone's file picker, so a test hands in a file without a platform.
class DeviceFile {
  const DeviceFile({required this.name, required this.read, this.length});

  final String name;

  /// Known without reading, when the picker reported it.
  final int? length;
  final Future<Uint8List> Function() read;
}

/// What the picker offers: photos, or a document (PDF, Office, text, zip).
enum AttachmentSource { photo, file }

/// Opens the phone's picker for [source]; null when the person chose nothing.
typedef DevicePicker = Future<DeviceFile?> Function(AttachmentSource source);

/// The phone's own picker (`file_picker`): images from the gallery, or any of
/// the types a message may carry ([attachmentTypes]).
Future<DeviceFile?> pickFromDevice(AttachmentSource source) async {
  final file = switch (source) {
    AttachmentSource.photo => await FilePicker.pickFile(type: FileType.image),
    AttachmentSource.file => await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: attachmentTypes.keys.toList(),
    ),
  };
  if (file == null) return null;
  return DeviceFile(name: file.name, length: file.lengthSync(), read: file.readAsBytes);
}

/// Where [pickDeviceAttachment] gets its file: the phone's picker, replaced by a test.
class AttachmentPicking {
  AttachmentPicking._();

  static DevicePicker picker = pickFromDevice;
}

/// The message composer's paperclip: asks "Photo or File", opens the phone's
/// picker and reads the file; null when the person chose nothing.
///
///     MessagingLauncher.attachmentPicker = pickDeviceAttachment;   // the default
Future<PickedAttachment?> pickDeviceAttachment(BuildContext context) async {
  final source = await showModalBottomSheet<AttachmentSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('attach-photo'),
            leading: const Icon(LucideIcons.image, color: AppColors.slate600),
            title: Text('Photo', style: ChatText.label.copyWith(fontSize: 14)),
            subtitle: Text('Pick an image from your gallery', style: ChatText.hint),
            onTap: () => Navigator.pop(context, AttachmentSource.photo),
          ),
          ListTile(
            key: const ValueKey('attach-file'),
            leading: const Icon(LucideIcons.fileText, color: AppColors.slate600),
            title: Text('File', style: ChatText.label.copyWith(fontSize: 14)),
            subtitle: Text('A PDF, an Office document, a text file or a zip', style: ChatText.hint),
            onTap: () => Navigator.pop(context, AttachmentSource.file),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  return readAttachment(await AttachmentPicking.picker(source));
}

/// A file as the composer sends it, or null for none. A file over the limit
/// is not read into memory: it comes back with its size only, and the
/// composer's own check ([attachmentMaxBytes]) words the refusal.
Future<PickedAttachment?> readAttachment(DeviceFile? file) async {
  if (file == null) return null;
  final length = file.length;
  if (length != null && length > attachmentMaxBytes) {
    // Not read: the composer refuses it by size ("That file is over 10 MB.").
    return PickedAttachment(
      name: file.name,
      bytes: Uint8List(0),
      mimeType: attachmentMimeFor(file.name),
      declaredSize: length,
    );
  }
  final bytes = await file.read();
  return PickedAttachment(name: file.name, bytes: bytes, mimeType: attachmentMimeFor(file.name));
}
