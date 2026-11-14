import 'package:flutter/widgets.dart';

/// Above an Events screen for the staff who run events: an event's sheet opened under it shows a pencil that
/// hands the event's id to [onManage] (its manage page). Without one, or with a null [onManage], no pencil.
class EventManageScope extends InheritedWidget {
  const EventManageScope({super.key, required this.onManage, required super.child});

  final ValueChanged<String>? onManage;

  /// The door for the sheet opened from [context]; null for everyone who does not run events.
  static ValueChanged<String>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EventManageScope>()?.onManage;

  @override
  bool updateShouldNotify(EventManageScope old) => false;
}
