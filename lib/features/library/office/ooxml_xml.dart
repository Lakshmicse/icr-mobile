import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'office_models.dart';

/// Small helpers the Word, Excel and PowerPoint readers share for the XML parts inside an Office Open XML
/// package. Names are matched without their prefix, since a file may bind any prefix to a namespace.

/// The attribute of [e] whose local name is [local] (`val` for `w:val`, `id` for `r:id`), or null.
String? attr(XmlElement e, String local) {
  for (final a in e.attributes) {
    if (a.name.local == local) return a.value;
  }
  return null;
}

/// Child elements of [e] named [local].
Iterable<XmlElement> kids(XmlElement e, String local) => e.childElements.where((c) => c.name.local == local);

/// The first child element of [e] named [local], or null.
XmlElement? kid(XmlElement e, String local) {
  for (final c in e.childElements) {
    if (c.name.local == local) return c;
  }
  return null;
}

/// Every descendant element of [e] named [local], in document order.
Iterable<XmlElement> below(XmlElement e, String local) => e.descendantElements.where((c) => c.name.local == local);

/// The parsed XML part of the package at [path] (compared without regard to case), or null if absent.
XmlDocument? partXml(Archive zip, String path) {
  final text = partText(zip, path);
  if (text == null) return null;
  try {
    return XmlDocument.parse(text);
  } on XmlException {
    return null;
  }
}

/// The text of the package part at [path], or null if absent.
String? partText(Archive zip, String path) {
  final file = findPart(zip, path);
  if (file == null) return null;
  final bytes = file.readBytes();
  if (bytes == null) return null;
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  return text;
}

ArchiveFile? findPart(Archive zip, String path) {
  final want = path.toLowerCase();
  for (final f in zip.files) {
    if (f.isFile && f.name.replaceAll('\\', '/').toLowerCase() == want) return f;
  }
  return null;
}

/// Where a relationship [target] points, given the part [base] that holds the relationship.
String resolveTarget(String base, String target) {
  if (target.startsWith('/')) return target.substring(1);
  final dir = base.contains('/') ? base.substring(0, base.lastIndexOf('/')) : '';
  final parts = <String>[...dir.split('/').where((p) => p.isNotEmpty)];
  for (final p in target.split('/')) {
    if (p == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (p.isNotEmpty && p != '.') {
      parts.add(p);
    }
  }
  return parts.join('/');
}

/// The relationships of the part at [partPath], as relationship id to the part it points at.
Map<String, String> relationships(Archive zip, String partPath) {
  final slash = partPath.lastIndexOf('/');
  final dir = slash < 0 ? '' : partPath.substring(0, slash + 1);
  final name = slash < 0 ? partPath : partPath.substring(slash + 1);
  final rels = partXml(zip, '${dir}_rels/$name.rels');
  final out = <String, String>{};
  if (rels == null) return out;
  for (final r in below(rels.rootElement, 'Relationship')) {
    final id = attr(r, 'Id');
    final target = attr(r, 'Target');
    if (id == null || target == null) continue;
    if (attr(r, 'TargetMode') == 'External') continue;
    out[id] = resolveTarget(partPath, target);
  }
  return out;
}

/// Opens [bytes] as a ZIP package, or throws an [OfficeProblem] in the reader's words.
Archive openPackage(List<int> bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const OfficeProblem("This file can't be read. It may be damaged.");
  }
}

/// A flag element such as `<w:b/>` or `<w:b w:val="0"/>`: on unless its value says off.
bool flagOn(XmlElement? e) {
  if (e == null) return false;
  final v = attr(e, 'val')?.toLowerCase();
  return !(v == '0' || v == 'false' || v == 'off' || v == 'none');
}

/// The `val` attribute of [e] (`w:val`, `a:val`), or null when [e] or the attribute is absent.
String? valOf(XmlElement? e) => e == null ? null : attr(e, 'val');
