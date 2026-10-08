import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/home_widgets.dart';
import '../widgets/settings_widgets.dart';

/// TODO: replace with your real support address.
const String kSupportEmail = 'support@reveduc.app';

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}

const List<_Faq> _faqs = [
  _Faq(
    'How do I mark a lesson as complete?',
    'Open the lesson and take its Competency Quiz. Scoring 70% or higher '
        'marks it complete automatically. Lessons without a PDF also have a '
        '"Mark as Complete" button.',
  ),
  _Faq(
    'How do the quizzes work?',
    'Each question has a 60-second timer. When it runs out, the quiz moves '
        'to the next question (or submits on the last one). Questions and '
        'answer choices are shuffled every attempt, so Retake gives you a '
        'fresh set.',
  ),
  _Faq(
    'What are the different assessments?',
    'A Competency Quiz has 5 questions, a Topic Quiz has 15 across a '
        "subject's competencies, a Subject Exam has 150 questions for one "
        'category, and the Mock Exam covers all three categories.',
  ),
  _Faq(
    'How do I earn a Topic Mastery badge?',
    'Complete every competency under a subject, then score at least 75% on '
        "that subject's Topic Quiz. Badges appear in your User Ledger on the "
        'Profile screen.',
  ),
  _Faq(
    'How is my day streak counted?',
    'Opening the app counts as a day of use. Your streak is the number of '
        'consecutive days, ending today or yesterday, that you opened it.',
  ),
  _Faq(
    'Why is a lesson empty or missing its quiz?',
    'Content is published by your administrators. If a lesson has no PDF '
        'or quiz yet, it has not been uploaded. Pull down to refresh on the '
        'Subjects screen to check for new content.',
  ),
  _Faq(
    'Can I use RevEduc offline?',
    'Yes. Lessons and quizzes you have already opened are cached on your '
        'device, and your progress syncs automatically once you are back '
        'online. You can also tap Sync Now in Settings.',
  ),
  _Faq(
    'How do I change my username or password?',
    'Go to Profile → Settings → Account Settings. If you signed in with '
        'Google, your password is managed by your Google account.',
  ),
  _Faq(
    'I forgot my password.',
    'On the log-in screen, tap "Forgot Password?" and enter your email '
        'address to get a reset link.',
  ),
  _Faq(
    'How do I turn off reminders?',
    'Open Settings and switch off Study Reminders. You can turn them back '
        'on at any time.',
  ),
  _Faq(
    'Where are my notes?',
    'Notes for a subject are under that subject\'s "My Notes" button. All '
        'of your notes are under Profile → My Notes, where you can search '
        'and filter them.',
  ),
];

/// FAQ list with search, plus a contact card.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Faq> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _faqs;
    return _faqs
        .where((f) =>
            f.question.toLowerCase().contains(q) ||
            f.answer.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(const ClipboardData(text: kSupportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support email copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: kMaroon,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Container(
              color: kMaroon,
              height: MediaQuery.of(context).padding.top,
            ),
            const SubScreenHeader(
              title: 'Help Center',
              icon: Icons.help_outline_rounded,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final faqs = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search help topics',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: primaryTextColor(context),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 12),
          if (faqs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No results. Try different keywords, or contact support below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryTextColor(context)),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < faqs.length; i++) ...[
                    FaqTile(
                        question: faqs[i].question, answer: faqs[i].answer),
                    if (i != faqs.length - 1)
                      Divider(
                          height: 1, color: Theme.of(context).dividerColor),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 28),
          _buildContactCard(),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Still need help?',
            style: TextStyle(
              color: kGold,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Send us an email and include a short description of the '
            'problem. A screenshot helps.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  kSupportEmail,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _copyEmail,
                icon: const Icon(Icons.copy_rounded, color: kGold, size: 16),
                label: const Text(
                  'Copy',
                  style: TextStyle(
                      color: kGold, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
