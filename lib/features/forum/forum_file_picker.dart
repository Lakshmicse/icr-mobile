import 'package:file_picker/file_picker.dart';

import 'forum_models.dart';

/// The types a discussion's file may be: the forum's upload takes a photo or a PDF.
const forumFileExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp'];

/// The photos and videos a discussion carries inline (owner, 11 Nov 2026): what phones hold and the forum takes.
const forumMediaExtensions = ['png', 'jpg', 'jpeg', 'webp', 'mp4', 'webm', 'mov'];
const forumVideoExtensions = ['mp4', 'webm', 'mov'];

/// The forum's own caps: a picture 10 MB, a video 50 MB.
const forumImageMaxBytes = 10 * 1024 * 1024;

/// How many photos a post may carry (the forum's `MAX_FORUM_IMAGES`).
const forumMaxPhotos = 10;
const forumVideoMaxBytes = 50 * 1024 * 1024;

bool isForumVideoName(String name) {
  final dot = name.lastIndexOf('.');
  return dot >= 0 && forumVideoExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// Asks the phone for photos and videos (several at once) and reads them. Empty when the reader backed out.
Future<List<ForumFile>> pickForumMedia() async {
  // file_picker 13: `pickFiles` is the multi-pick and answers a (possibly empty) list.
  final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: forumMediaExtensions);
  return [for (final f in picked) ForumFile(bytes: await f.readAsBytes(), name: f.name)];
}

/// Asks the phone for a photo or a PDF and reads it. Null when the reader backed out. The composer is handed a
/// picker (`NewThreadScreen.pickFile`) so a test can stand in for the phone's file chooser.
Future<ForumFile?> pickForumFile() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: forumFileExtensions);
  if (file == null) return null;
  return ForumFile(bytes: await file.readAsBytes(), name: file.name);
}
