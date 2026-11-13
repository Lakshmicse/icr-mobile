/// Saving a chapter's or a council's resource to the phone: the website's "Download" button, in the app.
///
/// The website's button is a plain link that opens the file's address in a new tab. In the app the file is read
/// here and handed to the phone's "Save as" sheet, the way the Digital Library saves a document
/// ([SystemLibraryDevice.save]), so the member is not sent to the browser. An address that is not a file (a web
/// page, a missing file, an unreachable host) is said so in the app, in words, rather than shown as a dead page.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../library/library_device.dart' show SystemLibraryDevice;
import '../library/library_models.dart' show DocumentBytes;
import 'chapter_links.dart';
import 'chapter_models.dart';

/// A download that could not complete, with the sentence to show.
class ResourceDownloadException implements Exception {
  const ResourceDownloadException(this.message, {this.openInstead});

  final String message;

  /// The address, when the browser can do what the app cannot (a file too big to hold in memory): the message
  /// then carries an "Open" action.
  final Uri? openInstead;

  @override
  String toString() => message;
}

/// What a resource's address turned out to be.
sealed class ResourceOutcome {
  const ResourceOutcome();
}

/// A file, read in full, ready to save.
final class ResourceFileOutcome extends ResourceOutcome {
  const ResourceFileOutcome(this.file);

  final DocumentBytes file;
}

/// A web page, not a file (a hosted recording, a shared folder). Nothing was saved.
final class ResourcePageOutcome extends ResourceOutcome {
  const ResourcePageOutcome(this.page);

  final Uri page;
}

/// What a resource's Download needs from the phone. Tests give their own.
abstract class ResourceDownloader {
  const ResourceDownloader();

  /// Reads the resource's address. Throws a [ResourceDownloadException] that says why it could not.
  Future<ResourceOutcome> fetch(ChapterResource resource);

  /// Saves [file] where the person chooses (the system "Save as" sheet); false when they cancel.
  Future<bool> save(DocumentBytes file);
}

class SystemResourceDownloader extends ResourceDownloader {
  const SystemResourceDownloader({this.dio});

  /// The client to read with; a plain one (no ICR session: the file's host is often someone else's) when null.
  final Dio? dio;

  /// The largest file read into memory to be saved; a bigger one is left to the browser.
  static const maxBytes = 150 * 1024 * 1024;

  @override
  Future<ResourceOutcome> fetch(ChapterResource resource) async {
    final uri = webLink(resource.url);
    if (uri == null) throw const ResourceDownloadException('This resource has no file attached yet.');
    if (isPlaceholderLink(uri)) {
      throw ResourceDownloadException('"${resource.title}" has no file yet. Its address is a placeholder.');
    }
    final client =
        dio ??
        Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30)));
    try {
      final res = await client.getUri<ResponseBody>(
        uri,
        options: Options(responseType: ResponseType.stream, headers: {'Accept': '*/*'}),
      );
      final body = res.data;
      if (body == null) throw const ResourceDownloadException('No response from that address.');
      final type = _typeOf(res.headers.value(Headers.contentTypeHeader));
      if (_isPage(type)) {
        await _discard(body);
        return ResourcePageOutcome(uri);
      }
      final length = int.tryParse(res.headers.value(Headers.contentLengthHeader) ?? '');
      if (length != null && length > maxBytes) {
        await _discard(body);
        throw _tooLarge(uri, length);
      }
      final bytes = BytesBuilder(copy: false);
      var first = true;
      await for (final chunk in body.stream) {
        // A page served without a type (or as a bare download) is told by its first bytes.
        if (first && (type == null || type == _binary) && _looksLikePage(chunk)) return ResourcePageOutcome(uri);
        first = false;
        bytes.add(chunk);
        if (bytes.length > maxBytes) throw _tooLarge(uri, null);
      }
      if (bytes.isEmpty) throw const ResourceDownloadException('The file is empty.');
      final name = resourceFileName(resource, uri, disposition: res.headers.value('content-disposition'), type: type);
      return ResourceFileOutcome(
        DocumentBytes(bytes: bytes.takeBytes(), fileName: name, mimeType: _mimeFor(name, type)),
      );
    } on DioException catch (e) {
      throw _failure(e, uri);
    } finally {
      if (dio == null) client.close(force: true);
    }
  }

  @override
  Future<bool> save(DocumentBytes file) => const SystemLibraryDevice().save(file);

  static ResourceDownloadException _tooLarge(Uri uri, int? length) => ResourceDownloadException(
    length == null
        ? 'The file is too large to save from the app.'
        : 'The file is ${(length / (1024 * 1024)).round()} MB, too large to save from the app.',
    openInstead: uri,
  );

  static ResourceDownloadException _failure(DioException e, Uri uri) {
    final host = uri.host;
    final status = e.response?.statusCode;
    switch (e.type) {
      case DioExceptionType.badResponse:
        if (status == 404 || status == 410) {
          return ResourceDownloadException('The file is no longer available ($host returned $status).');
        }
        if (status == 401 || status == 403) {
          return ResourceDownloadException('$host does not allow the app to download this file ($status).');
        }
        if (status != null && status >= 500) {
          return ResourceDownloadException('$host had a problem sending the file ($status). Try again later.');
        }
        return ResourceDownloadException('$host refused the download ($status).');
      case DioExceptionType.badCertificate:
        return ResourceDownloadException('Unable to make a secure connection to $host.');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ResourceDownloadException('Unable to reach $host. Check your connection and try again.');
      case DioExceptionType.cancel:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return const ResourceDownloadException('Unable to download the file. Try again.');
    }
  }
}

const _binary = 'application/octet-stream';

/// The media type of a `Content-Type` header, lower-cased and without its parameters; null when absent.
String? _typeOf(String? header) {
  final type = header?.split(';').first.trim().toLowerCase();
  return type == null || type.isEmpty ? null : type;
}

bool _isPage(String? type) => type == 'text/html' || type == 'application/xhtml+xml';

bool _looksLikePage(List<int> chunk) {
  final head = utf8.decode(chunk.take(512).toList(), allowMalformed: true).trimLeft().toLowerCase();
  return head.startsWith('<!doctype html') || head.startsWith('<html');
}

/// Stops reading a response the app has decided not to save, so the connection is let go.
Future<void> _discard(ResponseBody body) async {
  try {
    await body.stream.listen((_) {}, onError: (_) {}).cancel();
  } catch (_) {
    // Nothing more to do with a response already closed.
  }
}

const _typeByExtension = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'csv': 'text/csv',
  'txt': 'text/plain',
  'zip': 'application/zip',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'mp3': 'audio/mpeg',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
};

/// The extension a declared kind of resource usually has, for an address that names none.
const _extensionByKind = {'PRESENTATION': 'pptx', 'WHITEPAPER': 'pdf', 'TEMPLATE': 'xlsx', 'RECORDING': 'mp4'};

String? _extensionOfType(String? type) {
  if (type == null) return null;
  for (final e in _typeByExtension.entries) {
    if (e.value == type) return e.key;
  }
  return null;
}

String _mimeFor(String fileName, String? type) {
  if (type != null && type != _binary) return type;
  final dot = fileName.lastIndexOf('.');
  final byName = dot < 0 ? null : _typeByExtension[fileName.substring(dot + 1).toLowerCase()];
  return byName ?? _binary;
}

/// The name a resource is saved under: the host's own (`Content-Disposition`) when it sends one, else the
/// resource's title with the extension its address, its media type or its kind gives.
String resourceFileName(ChapterResource resource, Uri uri, {String? disposition, String? type}) {
  final given = _dispositionName(disposition);
  if (given != null) return _clean(given);
  final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final fromAddress = RegExp(r'\.([A-Za-z0-9]{1,5})$').firstMatch(last)?.group(1)?.toLowerCase();
  final ext = fromAddress ?? _extensionOfType(type) ?? _extensionByKind[resource.kind];
  final title = _clean(resource.title);
  if (title.isEmpty) return _clean(last.isEmpty ? 'resource${ext == null ? '' : '.$ext'}' : Uri.decodeComponent(last));
  return ext == null || title.toLowerCase().endsWith('.$ext') ? title : '$title.$ext';
}

String? _dispositionName(String? header) {
  if (header == null) return null;
  final star = RegExp(r"filename\*\s*=\s*[^']*'[^']*'([^;]+)", caseSensitive: false).firstMatch(header);
  if (star != null) {
    try {
      return Uri.decodeComponent(star.group(1)!.trim());
    } catch (_) {
      // Fall through to the plain filename.
    }
  }
  final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false).firstMatch(header);
  final name = plain?.group(1)?.trim();
  return name == null || name.isEmpty ? null : name;
}

/// A file name the phone accepts: no path separators or reserved characters, no runs of space, a sane length.
String _clean(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.length > 120 ? cleaned.substring(0, 120).trim() : cleaned;
}
