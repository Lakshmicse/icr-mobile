import 'package:flutter/material.dart';

import 'title_bar.dart';

/// A record page's way to its manage page, for the staff who may manage it (a chapter, a council, an event).
///
/// On the website these are the people holding `chapters:manage`, `councils:manage` or `events:manage`: a Super
/// Admin, or anyone a Super Admin gave the Chapters Admin, Councils Admin, Events Admin or Community Manager role.
/// A role can be given over some records only, so whether THIS record is theirs is asked per record ([may]).
class RecordManage {
  const RecordManage({required this.may, required this.open});

  /// Whether the reader may manage the record with this id.
  final Future<bool> Function(String id) may;

  /// Opens the record's manage page.
  final void Function(BuildContext context, String id) open;
}

/// Puts a screen pushed by a feature into the app's frame (the bottom bar under it). The shell gives the real
/// one; a feature on its own (a test) keeps the page as it is.
typedef PageWrap = Widget Function(Widget page);

Widget plainPage(Widget page) => page;

/// The pencil left of the bell on a record's page, drawn only once [RecordManage.may] has said yes for [id].
class ManagePencil extends StatefulWidget {
  const ManagePencil({super.key, required this.manage, required this.id, this.label = 'Manage'});

  final RecordManage manage;
  final String id;
  final String label;

  @override
  State<ManagePencil> createState() => _ManagePencilState();
}

class _ManagePencilState extends State<ManagePencil> {
  bool _may = false;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(ManagePencil old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _may = false;
      _ask();
    }
  }

  Future<void> _ask() async {
    final id = widget.id;
    bool may;
    try {
      may = await widget.manage.may(id);
    } catch (_) {
      may = false;
    }
    if (mounted && id == widget.id && may != _may) setState(() => _may = may);
  }

  @override
  Widget build(BuildContext context) {
    if (!_may) return const SizedBox.shrink();
    return BarEditButton(label: widget.label, onTap: () => widget.manage.open(context, widget.id));
  }
}
