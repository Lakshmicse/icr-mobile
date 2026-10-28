/// What a mentor profile may hold, and what it needs before it goes to ICR's
/// review team: a port of `packages/shared/src/mentor-rules.ts` (and the profile
/// rules for a role and the intro), so the form names the problem under the
/// field as it is typed, in the API's own words.
///
/// The mentor profile holds only what is about MENTORING. What is about the
/// person (photo, current role, years, languages, work history) lives on the
/// user and is checked by [mentorPersonProblems].
///
/// Saving a draft needs only the limits. Submitting for review needs the rest.
library;

import '../mentorship_my/mentoring_clock.dart';

/// `MENTOR_PROFILE_LIMITS`.
class MentorLimits {
  MentorLimits._();

  static const roleMin = 2;
  static const roleMax = 100;

  /// Plain-text characters "How you mentor" needs before submitting.
  static const bioMin = 100;

  /// The stored HTML, markup included.
  static const bioHtmlMax = 20000;
  static const yearsMin = 0;
  static const yearsMax = 60;
  static const competenciesMax = 12;
  static const topicsMax = 12;
  static const targetRolesMax = 8;
  static const languagesMax = 8;
  static const languageMax = 40;
  static const availabilityNoteMax = 280;

  /// `MAX_MENTOR_CAPACITY` and `DEFAULT_MENTOR_CAPACITY`.
  static const capacityMax = 10;
  static const capacityDefault = 2;

  /// `MAX_AVAILABILITY_BLOCKS`.
  static const availabilityBlocksMax = 21;

  /// `MAX_MENTOR_DOCUMENTS`.
  static const documentsMax = 12;
  static const meetingLinkMax = 500;
}

/// The facts the mentoring half's rules read: the form's draft or a stored row.
class MentorProfileFacts {
  const MentorProfileFacts({
    this.bioHtml,
    this.competencies,
    this.expertiseKeys,
    this.topics,
    this.targetRoles,
    this.targetAudiences,
    this.availabilityNote,
  });

  final String? bioHtml;
  final List<String>? competencies;

  /// Legacy expertise keys; either list satisfies "at least one area".
  final List<String>? expertiseKeys;
  final List<String>? topics;
  final List<String>? targetRoles;
  final List<String>? targetAudiences;
  final String? availabilityNote;
}

enum MentorProfileField { bioHtml, competencies, topics, targetRoles, targetAudiences, availabilityNote }

/// The person behind a mentor profile, as the form or the user row holds it.
class MentorPersonFacts {
  const MentorPersonFacts({
    this.avatarUrl,
    this.designation,
    this.yearsExperience,
    this.languages,
    this.experienceCount,
  });

  final String? avatarUrl;

  /// `User.designation`: the current role.
  final String? designation;
  final int? yearsExperience;
  final List<String>? languages;

  /// Rows of work history.
  final int? experienceCount;
}

enum MentorPersonField { avatarUrl, designation, yearsExperience, languages, experience }

/// One thing wrong, and the sentence that says it (shown as is, by the page and by the API).
class MentorProblem<F> {
  const MentorProblem(this.field, this.message);

  final F field;
  final String message;

  @override
  String toString() => '$field: $message';
}

/// The tags of an HTML string become spaces, entities are read back, runs of white space collapse
/// (`htmlToPlainText`).
String htmlToPlainText(String? html) => (html ?? '')
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The composer edits plain paragraphs; the API stores them as HTML. Blank lines start a paragraph.
String bioToHtml(String bio) {
  if (bio.trim().isEmpty) return '';
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return bio.split(RegExp(r'\n{2,}')).map((p) => '<p>${esc(p.trim())}</p>').join();
}

/// Back from the stored HTML to the paragraphs the sheet edits and the card shows.
String bioToText(String? html) => (html ?? '')
    .replaceAll(RegExp(r'</p>\s*<p>'), '\n\n')
    .replaceAll(RegExp(r'</?[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// Everything wrong with the mentoring half of a profile, in the order the form asks for it.
///
/// Limits always apply. [forSubmit] adds what the review team needs, so a draft can be saved
/// half-finished and still be refused at submit with a reason.
List<MentorProblem<MentorProfileField>> mentorProfileProblems(MentorProfileFacts p, {bool forSubmit = false}) {
  final out = <MentorProblem<MentorProfileField>>[];
  void add(MentorProfileField f, String message) => out.add(MentorProblem(f, message));
  int count(List<String>? l) => l?.length ?? 0;

  if ((p.bioHtml ?? '').length > MentorLimits.bioHtmlMax) {
    add(MentorProfileField.bioHtml, '“How you mentor” is too long — keep it under 20,000 characters.');
  } else if (forSubmit) {
    final chars = htmlToPlainText(p.bioHtml).length;
    if (chars < MentorLimits.bioMin) {
      add(
        MentorProfileField.bioHtml,
        chars > 0
            ? 'Say a little more about how you mentor — at least ${MentorLimits.bioMin} characters ($chars so far).'
            : 'Tell mentees how you mentor — at least ${MentorLimits.bioMin} characters.',
      );
    }
  }

  if (count(p.competencies) > MentorLimits.competenciesMax) {
    add(MentorProfileField.competencies, 'Choose at most ${MentorLimits.competenciesMax} areas of expertise.');
  } else if (forSubmit && count(p.competencies) == 0 && count(p.expertiseKeys) == 0) {
    add(MentorProfileField.competencies, 'Add at least one area of expertise — it is how mentees find you.');
  }

  if (count(p.topics) > MentorLimits.topicsMax) {
    add(MentorProfileField.topics, 'Keep “Happy to talk about” to ${MentorLimits.topicsMax} topics.');
  }

  if (forSubmit && count(p.targetAudiences) == 0) {
    add(MentorProfileField.targetAudiences, 'Choose who you want to mentor.');
  }

  if (count(p.targetRoles) > MentorLimits.targetRolesMax) {
    add(
      MentorProfileField.targetRoles,
      'Choose at most ${MentorLimits.targetRolesMax} roles you can help people reach.',
    );
  }

  if ((p.availabilityNote ?? '').length > MentorLimits.availabilityNoteMax) {
    add(
      MentorProfileField.availabilityNote,
      'Keep “When you\'re free” to ${MentorLimits.availabilityNoteMax} characters.',
    );
  }
  return out;
}

/// Everything wrong with the person behind a mentor profile, in the order the "Your profile" section
/// asks for it. Limits always apply (they are the person's own, so /profile refuses the same values);
/// [forSubmit] adds what a mentee needs to see before ICR lists someone: a face, a role, years, a
/// language and at least one job.
List<MentorProblem<MentorPersonField>> mentorPersonProblems(MentorPersonFacts p, {bool forSubmit = false}) {
  final out = <MentorProblem<MentorPersonField>>[];
  void add(MentorPersonField f, String message) => out.add(MentorProblem(f, message));
  int count(List<String>? l) => l?.length ?? 0;

  if (forSubmit && (p.avatarUrl == null || p.avatarUrl!.isEmpty)) {
    add(MentorPersonField.avatarUrl, 'Add a profile photo — it is the first thing a mentee sees.');
  }

  final role = (p.designation ?? '').trim();
  if (role.length > MentorLimits.roleMax) {
    add(
      MentorPersonField.designation,
      'Keep your current role to ${MentorLimits.roleMax} characters — just the job title.',
    );
  } else if (role.isNotEmpty && role.length < MentorLimits.roleMin) {
    add(MentorPersonField.designation, 'Your current role needs at least ${MentorLimits.roleMin} characters.');
  } else if (forSubmit && role.isEmpty) {
    add(MentorPersonField.designation, 'Add your current role.');
  }

  final years = p.yearsExperience;
  if (years != null && (years < MentorLimits.yearsMin || years > MentorLimits.yearsMax)) {
    add(
      MentorPersonField.yearsExperience,
      'Years in the profession must be a whole number from ${MentorLimits.yearsMin} to ${MentorLimits.yearsMax}.',
    );
  } else if (forSubmit && years == null) {
    add(MentorPersonField.yearsExperience, 'Add your years in the profession.');
  }

  if (count(p.languages) > MentorLimits.languagesMax) {
    add(MentorPersonField.languages, 'Choose at most ${MentorLimits.languagesMax} languages.');
  } else if (forSubmit && count(p.languages) == 0) {
    add(MentorPersonField.languages, 'Add at least one language you mentor in.');
  }

  if (forSubmit && (p.experienceCount ?? 0) == 0) {
    add(MentorPersonField.experience, 'Add at least one role to your career history.');
  }
  return out;
}

// ---------------------------------------------------------------------------
// The person's own rules that the composer's sheets share (`introProblems`,
// `experienceProblems`, the languages limit): the same sentences /profile shows.
// ---------------------------------------------------------------------------

/// "Whole years, 0–60." (`validation.profile.intro.yearsRange`), or null when [years] is fine or blank.
String? yearsProblem(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n == null || n < MentorLimits.yearsMin || n > MentorLimits.yearsMax) {
    return 'Whole years, ${MentorLimits.yearsMin}–${MentorLimits.yearsMax}.';
  }
  return null;
}

/// The current role, as the API's `PATCH /users/me` judges it (`headlineShort`, at most 100).
String? designationProblem(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (t.length < MentorLimits.roleMin) return 'A headline needs at least ${MentorLimits.roleMin} characters.';
  if (t.length > MentorLimits.roleMax) {
    return 'Keep your current role to ${MentorLimits.roleMax} characters — just the job title.';
  }
  return null;
}

/// The career-history limits (`PROFILE_LIMITS.experience`).
class ExperienceLimits {
  ExperienceLimits._();

  static const titleMin = 2;
  static const titleMax = 160;
  static const organisationMin = 2;
  static const organisationMax = 160;
  static const cityMax = 120;
  static const descriptionMax = 2000;
  static const minCareerYear = 1950;
  static const rowsMax = 20;
}

/// One role as the experience sheet holds it.
class ExperienceFacts {
  const ExperienceFacts({
    this.title = '',
    this.organisation = '',
    this.city = '',
    this.startYear,
    this.startMonth,
    this.endYear,
    this.endMonth,
    this.isCurrent = false,
    this.description = '',
  });

  final String title;
  final String organisation;
  final String city;
  final int? startYear;
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool isCurrent;
  final String description;
}

enum ExperienceField { title, organisation, city, start, end, description }

/// Everything wrong with one role, in field order (`experienceProblems`, strict: dates are judged on the
/// Indian clock, as the API does; [now] is the module's clock).
List<MentorProblem<ExperienceField>> experienceProblems(ExperienceFacts row, {DateTime? now}) {
  final out = <MentorProblem<ExperienceField>>[];
  void add(ExperienceField f, String m) => out.add(MentorProblem(f, m));
  final india = (now ?? mentoringNow()).toUtc().add(const Duration(hours: 5, minutes: 30));
  final thisYear = india.year;
  final thisMonth = india.month;

  final title = row.title.trim();
  if (title.isEmpty) {
    add(ExperienceField.title, 'Add your role.');
  } else if (title.length < ExperienceLimits.titleMin) {
    add(ExperienceField.title, 'A role needs at least ${ExperienceLimits.titleMin} characters.');
  } else if (title.length > ExperienceLimits.titleMax) {
    add(ExperienceField.title, 'Keep the role under ${ExperienceLimits.titleMax} characters.');
  }

  final org = row.organisation.trim();
  if (org.isEmpty) {
    add(ExperienceField.organisation, 'Add the organisation.');
  } else if (org.length < ExperienceLimits.organisationMin) {
    add(ExperienceField.organisation, 'An organisation needs at least ${ExperienceLimits.organisationMin} characters.');
  } else if (org.length > ExperienceLimits.organisationMax) {
    add(ExperienceField.organisation, 'Keep the organisation under ${ExperienceLimits.organisationMax} characters.');
  }

  if (row.city.trim().length > ExperienceLimits.cityMax) {
    add(ExperienceField.city, 'Keep the city under ${ExperienceLimits.cityMax} characters.');
  }

  final sy = row.startYear;
  final sm = row.startMonth;
  if (sy == null) {
    add(ExperienceField.start, 'Add the year you started.');
  } else if (sy < ExperienceLimits.minCareerYear) {
    add(ExperienceField.start, 'Choose a year from ${ExperienceLimits.minCareerYear} on.');
  } else if (sy > thisYear || (sy == thisYear && sm != null && sm > thisMonth)) {
    add(ExperienceField.start, 'The start date can’t be in the future.');
  }

  if (!row.isCurrent) {
    final ey = row.endYear;
    final em = row.endMonth;
    if (ey == null) {
      add(
        ExperienceField.end,
        em != null ? 'Add the end year too.' : 'Add when this role ended, or tick “I work here now”.',
      );
    } else if (ey > thisYear || (ey == thisYear && em != null && em > thisMonth)) {
      add(ExperienceField.end, 'The end date can’t be in the future. If you still work here, tick “I work here now”.');
    } else if (sy != null && (ey < sy || (ey == sy && sm != null && em != null && em < sm))) {
      add(ExperienceField.end, 'The end date is before the start date.');
    }
  }

  if (row.description.trim().length > ExperienceLimits.descriptionMax) {
    add(ExperienceField.description, 'Keep the description under 2,000 characters.');
  }
  return out;
}
