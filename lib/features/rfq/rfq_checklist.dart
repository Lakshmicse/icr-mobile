/// What suppliers usually ask before they can price a facility service, and whether a description already answers
/// it: the website's `checklistRules.ts`, ported. Plain keyword matching on the buyer's own words, no guessing at
/// an answer. An item ticks only when the text mentions it, and the composer only ever adds a labelled prompt line
/// at the buyer's request.
library;

enum ChecklistItemId {
  scope('Scope of work', 'What the service includes'),
  size('Size or quantity', 'Area, headcount, units'),
  frequency('Frequency', 'Daily, weekly, one-off'),
  start('Start date', 'When the service should begin'),
  hours('Working hours', 'Shifts, days, timings'),
  sites('Number of sites', 'One site or several');

  const ChecklistItemId(this.label, this.hint);

  final String label;
  final String hint;
}

class ChecklistItem {
  const ChecklistItem(this.id, this.done);

  final ChecklistItemId id;

  /// Satisfied by the text as written.
  final bool done;
}

RegExp _re(String source) => RegExp(source, caseSensitive: false, unicode: true);

/// The order they are shown, and the pattern that satisfies each.
final _rules = <ChecklistItemId, RegExp>{
  ChecklistItemId.scope: _re(
    r'\b(scope|includ(e|es|ing)|cover(s|ing)?|tasks?|deliverables?|services? (required|needed)|areas?)\b',
  ),
  ChecklistItemId.size: _re(
    r'\b\d[\d,.]*\s*(sq\.?\s*(ft|m)|square|sqft|sqm|acres?|floors?|storeys?|rooms?|units?|staff|people|persons?|guards?|technicians?|cleaners?|seats?|desks?|beds?|kg|tonnes?|nos?|pcs|pieces)\b|\b(area|headcount|manpower|quantity|qty)\b',
  ),
  ChecklistItemId.frequency: _re(
    r'\b(daily|weekly|monthly|quarterly|annual(ly)?|yearly|fortnightly|every|per (day|week|month|year)|times a|shifts?|24\s*[x×*]\s*7|round[- ]the[- ]clock|one[- ]time|once)\b',
  ),
  ChecklistItemId.start: _re(
    r'\b(start(ing)?|from|begin(ning)?|commenc(e|ing|ement)|by|before|asap|immediately|urgent(ly)?|deadline|go[- ]live|jan(uary)?|feb(ruary)?|mar(ch)?|apr(il)?|may|june?|july?|aug(ust)?|sep(t|tember)?|oct(ober)?|nov(ember)?|dec(ember)?)\b|\b\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?\b',
  ),
  ChecklistItemId.hours: _re(
    r'\b(\d{1,2}\s*(am|pm)|\d{1,2}:\d{2}|hours?|hrs|shifts?|working days?|weekends?|night|morning|evening|24\s*[x×*]\s*7)\b',
  ),
  ChecklistItemId.sites: _re(
    r'\b(\d+\s*(sites?|locations?|branches|offices|buildings|campuses|stores|outlets|plants|facilities|towers|blocks)|single (site|location|building)|one (site|location|building)|multiple (sites|locations))\b',
  ),
};

/// A prompt line [withPromptLine] added and the buyer has not answered yet ("Start date: "). Its label would
/// otherwise tick its own item.
final _unansweredPrompt = RegExp(r'^[^\n:]{1,60}:[ \t]*$', multiLine: true);

/// Each item, ticked when the description already mentions it.
List<ChecklistItem> checklistFor(String text) {
  final said = text.replaceAll(_unansweredPrompt, '');
  return [for (final e in _rules.entries) ChecklistItem(e.key, e.value.hasMatch(said))];
}

/// The text with one labelled line added at its end, for the buyer to complete. Never rewrites what is there: it
/// only appends, on a new line when needed.
String withPromptLine(String text, String label) {
  final line = '$label: ';
  if (text.trim().isEmpty) return line;
  return text.endsWith('\n') ? '$text$line' : '$text\n$line';
}

final _labelOnly = RegExp(r'^[^\n:]{1,60}:[ \t]*$');
final _labelled = RegExp(r'^[^\n:]{1,60}:');

/// The text without the prompt lines nobody answered ("Frequency:" with nothing after it). A label-only line
/// still introduces content when the line below it is not another label ("Scope of work:" over a list), so only
/// one followed by nothing, a blank line or another label goes. Used before a requirement is sent.
String withoutEmptyPrompts(String text) {
  final lines = text.split('\n');
  final kept = <String>[];
  for (final (i, line) in lines.indexed) {
    if (!_labelOnly.hasMatch(line)) {
      kept.add(line);
      continue;
    }
    final next = lines.skip(i + 1).where((l) => l.trim().isNotEmpty).firstOrNull;
    final below = i + 1 < lines.length ? lines[i + 1] : null;
    if (next != null && below != null && below.trim().isNotEmpty && !_labelled.hasMatch(next)) kept.add(line);
  }
  return kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
