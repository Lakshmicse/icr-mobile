import 'library_models.dart';

/// Where the Digital Library screens get their documents: the API, or the sample content.
abstract class LibraryRepository {
  /// One page of the library, narrowed and sorted as [query] says (`GET /documents`).
  Future<LibraryPage> documents(LibraryQuery query);

  /// The categories in use, most used first (`GET /documents/categories`).
  Future<List<String>> categories();

  /// The formats the library holds, with how many documents each (`GET /documents/file-types`).
  Future<List<FileTypeFacet>> fileTypes();

  /// How many documents the signed-in person shared; 0 signed out.
  Future<int> myUploadCount();

  /// One document by id. The API has no `GET /documents/:id`, so a screen opened by id alone has the
  /// library read for it; throws a 404-style `ApiError` when it is no longer there.
  Future<LibraryDocument> document(String id);

  /// The platform's three-level category tree, for the upload form's pickers (`GET /categories/tree`).
  Future<List<TaxonomyNode>> taxonomy();

  /// The signed-in person, to tell their own documents; null signed out.
  Future<LibraryViewer?> viewer();

  /// One file's bytes for the in-app viewer (`GET /documents/:id/download?fileId=&preview=true`), which the
  /// API does not count as a download. **This is the only way the app reads a file: it has no download.**
  /// The bytes are drawn by the viewer and dropped with it; nothing saves them. Signed-in only: the API
  /// answers 401 otherwise, and a plan that does not open the document gets its own refusal sentence.
  Future<DocumentBytes> previewFile(LibraryDocument document, LibraryFile file);

  /// Counts one opening of the document (`POST /documents/:id/view`); the new count.
  Future<int> recordView(String id);

  /// Stores one file (`POST /uploads?purpose=document-hub`); [onProgress] is 0 to 1 for this file.
  Future<StoredFile> upload(PickedFile file, {void Function(double)? onProgress});

  /// Files the stored files under a title (`POST /documents`).
  Future<LibraryDocument> create(DocumentDraft draft, List<StoredFile> files);

  /// Adds stored files to a document the person shared (`POST /documents/:id/files`).
  Future<LibraryDocument> addFiles(String id, List<StoredFile> files);

  /// Drops one file of a pack (`DELETE /documents/:id/files/:fileId`); the API refuses the last one.
  Future<void> removeFile(String documentId, String fileId);

  /// Retires a document (`DELETE /documents/:id`): its uploader, or a SUPER_ADMIN.
  Future<void> delete(String id);

  /// Flags a document for the ICR admin team (`POST /documents/:id/report`).
  Future<void> report(String id, DocumentReportReason reason, {String? note});

  Future<int> unreadNotifications();

  /// The library's page on the website, to share.
  Uri link();
}
