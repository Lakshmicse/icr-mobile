import 'dart:typed_data';

import 'package:icr_mobile/features/chapters/chapter_models.dart';
import 'package:icr_mobile/features/chapters/resource_download.dart';
import 'package:icr_mobile/features/library/library_models.dart';

/// A [ResourceDownloader] that reads nothing from the network and saves nothing to the phone: it records what a
/// Download asked for and answers from [answers].
class FakeResourceDownloader extends ResourceDownloader {
  /// The resources fetched, in order.
  final fetched = <ChapterResource>[];

  /// The files handed to the "Save as" sheet, in order.
  final saved = <DocumentBytes>[];

  /// By resource id: a [ResourceOutcome] to answer, or an exception to throw. The default is a small PDF named
  /// after the resource.
  final answers = <String, Object>{};

  /// What the "Save as" sheet answers: false is the person cancelling it.
  bool saves = true;

  /// Fetches wait on this when set (to see the busy state).
  Future<void>? gate;

  @override
  Future<ResourceOutcome> fetch(ChapterResource resource) async {
    fetched.add(resource);
    if (gate != null) await gate;
    final answer = answers[resource.id];
    if (answer is ResourceOutcome) return answer;
    if (answer != null) throw answer;
    return ResourceFileOutcome(
      DocumentBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: '${resource.title}.pdf',
        mimeType: 'application/pdf',
      ),
    );
  }

  @override
  Future<bool> save(DocumentBytes file) async {
    saved.add(file);
    return saves;
  }
}
