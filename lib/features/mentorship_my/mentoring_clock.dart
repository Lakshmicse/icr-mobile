/// The mentoring screens' clock. Everything that says "tomorrow", "in 3 days",
/// "Awaiting" or decides whether a session is still ahead reads it, so a golden
/// or a test can pin the day (`mentoringNow = () => DateTime(2026, 10, 26, 10)`).
DateTime Function() mentoringNow = DateTime.now;
