import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  List<Map<String, String>> _faqs(AppLocalizations l10n) => [
        {'q': l10n.faq1Question, 'a': l10n.faq1Answer},
        {'q': l10n.faq2Question, 'a': l10n.faq2Answer},
        {'q': l10n.faq3Question, 'a': l10n.faq3Answer},
        {'q': l10n.faq4Question, 'a': l10n.faq4Answer},
        {'q': l10n.faq5Question, 'a': l10n.faq5Answer},
        {'q': l10n.faq6Question, 'a': l10n.faq6Answer},
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final faqs = _faqs(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return _FaqAccordionItem(question: faq['q']!, answer: faq['a']!);
        },
      ),
    );
  }
}

/// The design handoff's FAQ accordion card: +/- glyph instead of a chevron,
/// the open answer separated by a divider rather than just stacked below.
class _FaqAccordionItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqAccordionItem({required this.question, required this.answer});

  @override
  State<_FaqAccordionItem> createState() => _FaqAccordionItemState();
}

class _FaqAccordionItemState extends State<_FaqAccordionItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderAlt),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: AppTypography.body(size: 13.5).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(_open ? Icons.remove : Icons.add, size: 18, color: AppColors.mutedLight),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  Text(
                    widget.answer,
                    style: const TextStyle(fontSize: 12.5, height: 1.65, color: AppColors.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
