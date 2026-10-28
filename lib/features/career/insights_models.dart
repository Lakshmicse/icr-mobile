/// What a company's insights screen draws and sends beyond the reviews
/// themselves: its people, a page of anything, and the three forms (a review,
/// a salary, an interview experience) with the API's own limits
/// (`employer-insights.dto.ts`), so a form refuses locally what the API would.
library;

import '../feed/feed_models.dart' show FeedPicture;

/// A person who works at a company, from its People tab (`GET /companies/:id/people`).
class CompanyPerson {
  const CompanyPerson({required this.id, required this.name, this.headline, this.photo});

  final String id;
  final String name;
  final String? headline;
  final FeedPicture? photo;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'.toUpperCase();
  }
}

/// One page of a company's reviews, interview experiences or people.
class InsightPage<T> {
  const InsightPage({required this.items, required this.hasMore, this.total, this.averages = const {}});

  final List<T> items;
  final bool hasMore;
  final int? total;

  /// Interview experiences: `difficulty` and `experience`, each 1-5 (the API averages them).
  final Map<String, double> averages;
}

/// The five sub-ratings of a review, in the order the website lists them.
const reviewSubRatings = <String, String>{
  'workLife': 'Work-life balance',
  'compensation': 'Pay and benefits',
  'culture': 'Culture',
  'management': 'Management',
  'growth': 'Growth',
};

/// What the "Write a review" form sends (`POST /companies/:id/reviews`, `SubmitReviewDto`).
class ReviewDraft {
  const ReviewDraft({
    required this.overall,
    required this.title,
    required this.pros,
    required this.cons,
    this.subRatings = const {},
    this.advice,
    this.jobTitle,
    this.employmentStatus,
  });

  final int overall;
  final String title;
  final String pros;
  final String cons;

  /// Keys of [reviewSubRatings], each 1-5.
  final Map<String, int> subRatings;
  final String? advice;
  final String? jobTitle;

  /// CURRENT or FORMER.
  final String? employmentStatus;

  static const titleMax = 140;
  static const textMax = 4000;
  static const jobTitleMax = 120;

  /// Why the form cannot be sent, in the website's words.
  String? get problem {
    if (overall < 1 || title.trim().isEmpty || pros.trim().isEmpty || cons.trim().isEmpty) {
      return 'Overall rating, a headline, pros and cons are required.';
    }
    if (title.trim().length > titleMax) return 'Keep the headline under $titleMax characters.';
    if (pros.trim().length > textMax || cons.trim().length > textMax || (advice?.trim().length ?? 0) > textMax) {
      return 'Keep each answer under $textMax characters.';
    }
    if ((jobTitle?.trim().length ?? 0) > jobTitleMax) return 'Keep the job title under $jobTitleMax characters.';
    return null;
  }

  static const _subKeys = {
    'workLife': 'ratingWorkLife',
    'compensation': 'ratingCompensation',
    'culture': 'ratingCulture',
    'management': 'ratingManagement',
    'growth': 'ratingGrowth',
  };

  Map<String, dynamic> toJson() => {
    'overallRating': overall,
    for (final e in subRatings.entries)
      if (_subKeys.containsKey(e.key)) _subKeys[e.key]!: e.value,
    'title': title.trim(),
    'pros': pros.trim(),
    'cons': cons.trim(),
    if (advice != null && advice!.trim().isNotEmpty) 'advice': advice!.trim(),
    if (jobTitle != null && jobTitle!.trim().isNotEmpty) 'jobTitle': jobTitle!.trim(),
    if (employmentStatus != null && employmentStatus!.isNotEmpty) 'employmentStatus': employmentStatus,
  };
}

/// What "Share a salary" sends (`POST /companies/:id/salaries`, `SubmitSalaryDto`).
class SalaryDraft {
  const SalaryDraft({
    required this.jobTitle,
    required this.amount,
    this.period = 'YEARLY',
    this.city,
    this.years,
    this.employmentStatus,
  });

  final String jobTitle;
  final num? amount;

  /// YEARLY, MONTHLY or HOURLY.
  final String period;
  final String? city;
  final num? years;
  final String? employmentStatus;

  static const jobTitleMax = 120;
  static const cityMax = 80;

  String? get problem {
    if (jobTitle.trim().isEmpty || amount == null) return 'A job title and an amount are required.';
    if (amount! < 0) return 'Enter an amount of 0 or more.';
    if (jobTitle.trim().length > jobTitleMax) return 'Keep the job title under $jobTitleMax characters.';
    if ((city?.trim().length ?? 0) > cityMax) return 'Keep the city under $cityMax characters.';
    if (years != null && years! < 0) return 'Years of experience cannot be negative.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'jobTitle': jobTitle.trim(),
    if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
    'salaryAmount': amount,
    'salaryPeriod': period,
    'yearsExperience': ?years,
    if (employmentStatus != null && employmentStatus!.isNotEmpty) 'employmentStatus': employmentStatus,
  };
}

/// What "Share an interview" sends (`POST /companies/:id/interview-reviews`, `SubmitInterviewReviewDto`).
class InterviewReviewDraft {
  const InterviewReviewDraft({
    required this.difficulty,
    required this.experience,
    required this.process,
    this.jobTitle,
    this.outcome,
    this.questions,
    this.durationDays,
  });

  final int difficulty;
  final int experience;
  final String process;
  final String? jobTitle;

  /// OFFER_ACCEPTED, OFFER_DECLINED, NO_OFFER or IN_PROGRESS.
  final String? outcome;
  final String? questions;
  final int? durationDays;

  static const textMax = 4000;

  String? get problem {
    if (difficulty < 1 || experience < 1 || process.trim().isEmpty) {
      return 'Difficulty, overall experience and how the process went are required.';
    }
    if (process.trim().length > textMax || (questions?.trim().length ?? 0) > textMax) {
      return 'Keep each answer under $textMax characters.';
    }
    if ((jobTitle?.trim().length ?? 0) > SalaryDraft.jobTitleMax) {
      return 'Keep the job title under ${SalaryDraft.jobTitleMax} characters.';
    }
    if (durationDays != null && durationDays! < 0) return 'The process length cannot be negative.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    if (jobTitle != null && jobTitle!.trim().isNotEmpty) 'jobTitle': jobTitle!.trim(),
    'difficulty': difficulty,
    'experienceRating': experience,
    if (outcome != null && outcome!.isNotEmpty) 'outcome': outcome,
    'processDescription': process.trim(),
    if (questions != null && questions!.trim().isNotEmpty) 'questionsAsked': questions!.trim(),
    'durationDays': ?durationDays,
  };
}
