import 'package:flutter/foundation.dart';

import '../../core/api/api_error.dart';
import 'post_rfq_controller.dart' show PendingUpload;
import 'rfq_format.dart';
import 'rfq_links.dart' show PickedRfqFile;
import 'rfq_models.dart';
import 'rfq_repository.dart';
import 'rfq_rules.dart';

/// Files attached to something one is writing (a supplier's reply): chosen on the phone, checked (an accepted
/// type, ten megabytes at most, room left), then sent one at a time and kept with a title the person can change.
/// A file the API refused stays in [uploads] with its sentence and can be sent again.
class AttachmentUploader extends ChangeNotifier {
  AttachmentUploader({
    required this.repository,
    required this.purpose,
    this.max = RfqLimits.maxBidAttachments,
    List<RfqFile> initial = const [],
  }) : files = List.of(initial);

  final RfqRepository repository;

  /// The upload purpose: `bid-attachment` (private) for a reply, `rfq-attachment` (public) for a requirement.
  final String purpose;
  final int max;

  /// What is attached, in order.
  List<RfqFile> files;
  final List<PendingUpload> _uploads = [];
  int _sending = 0;
  String? _notice;

  List<PendingUpload> get uploads => List.unmodifiable(_uploads);

  /// A file is on its way up: whatever is sent now would go without it.
  bool get uploading => _sending > 0;

  /// Why the last files chosen were not all taken.
  String? get notice => _notice;

  Future<void> add(List<PickedRfqFile> picked) async {
    if (picked.isEmpty) return;
    final problems = <String>[];
    final room = max - files.length - _uploads.length;
    final accepted = <PendingUpload>[];
    for (final file in picked) {
      if (accepted.length >= room) {
        problems.add(room <= 0 ? 'You have attached the most ($max) files.' : 'Only $room more file${room == 1 ? '' : 's'} fit.');
        break;
      }
      if (mimeTypeFor(file.name) == null) {
        problems.add('${file.name} is not a PDF, Office, text, zip or image file.');
      } else if (file.size > RfqLimits.maxUploadBytes) {
        problems.add('${file.name} is over 10 MB.');
      } else {
        accepted.add(PendingUpload(file));
      }
    }
    _notice = problems.isEmpty ? null : problems.join(' ');
    _uploads.addAll(accepted);
    notifyListeners();
    for (final upload in accepted) {
      await _send(upload);
    }
  }

  Future<void> retry(PendingUpload upload) => _send(upload);

  void dismiss(PendingUpload upload) {
    _uploads.remove(upload);
    notifyListeners();
  }

  void dismissNotice() {
    _notice = null;
    notifyListeners();
  }

  Future<void> _send(PendingUpload upload) async {
    upload.error = null;
    _sending++;
    notifyListeners();
    try {
      final stored = await repository.uploadFile(upload.file, purpose: purpose);
      _uploads.remove(upload);
      files = [...files, stored];
    } catch (e) {
      upload.error = ApiError.from(e).message;
    } finally {
      _sending--;
      notifyListeners();
    }
  }

  void setTitle(int index, String title) {
    final f = files[index];
    final cut = title.length > RfqLimits.attachmentTitle ? title.substring(0, RfqLimits.attachmentTitle) : title;
    files = [...files]..[index] = RfqFile(id: f.id, title: cut, url: f.url, name: f.name, mimeType: f.mimeType, size: f.size);
    notifyListeners();
  }

  void remove(int index) {
    files = [...files]..removeAt(index);
    notifyListeners();
  }
}
