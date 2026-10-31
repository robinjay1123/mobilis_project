import 'package:flutter/material.dart';
import '../../../../mobile_ui/theme/app_colors.dart';

class FaqSection extends StatefulWidget {
  final Key? sectionKey;
  final bool isDesktop;
  final double width;

  const FaqSection({
    super.key,
    this.sectionKey,
    required this.isDesktop,
    required this.width,
  });

  @override
  State<FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<FaqSection> {
  int? _expandedFaqIndex = 0;

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'Where is Mobilis exclusively available?',
      'a': 'Mobilis is exclusively available throughout the province of Pangasinan (including Urdaneta City, Dagupan City, San Carlos, Lingayen, Manaoag, Alaminos, Rosales, etc.) and neighboring transit corridors. Our central headquarters is in Urdaneta City.',
    },
    {
      'q': 'What are the requirements to rent a vehicle?',
      'a': 'Renters need 1 valid Government-issued ID, a valid Driver’s License (for self-drive), emergency contact details, and a digital signature (saved once in your profile). If you have an adult co-maker/guarantor, their details can also be attached (passengers like children do not require registration). All verification is handled conveniently inside the Mobilis app.',
    },
    {
      'q': 'Can I hire a professional driver?',
      'a': 'Yes! You can hire an accredited professional driver for PHP 1,500.00 / day. When hiring a driver, doorstep pick-up is already included in your booking.',
    },
    {
      'q': 'What is the minimum hourly rental duration?',
      'a': 'Hourly rentals have a minimum duration of 12 hours (Half-day) to guarantee vehicle reservation and turnaround readiness.',
    },
    {
      'q': 'How does vehicle doorstep delivery work?',
      'a': 'For self-drive bookings, you can request doorstep delivery anywhere in Pangasinan at PHP 75.00 per kilometer from the PSDC garage.',
    },
    {
      'q': 'How can vehicle owners join as Partners?',
      'a': 'Vehicle owners can register as Partners in the app, upload vehicle OR/CR documentation, connect their GPS tracker, and start earning passive rental income.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.width < 768;

    return Container(
      key: widget.sectionKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: widget.isDesktop ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF061229),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              const Text(
                'FREQUENTLY ASKED QUESTIONS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Got Questions? We Have Answers',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isDesktop ? 36 : (isMobile ? 24 : 28),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 32),

              Column(
                children: List.generate(_faqs.length, (index) {
                  final faq = _faqs[index];
                  final isExpanded = _expandedFaqIndex == index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1838),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isExpanded
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : const Color(0x1AFFFFFF),
                      ),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _expandedFaqIndex = isExpanded ? null : index;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 16 : 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    faq['q']!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 13.5 : 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded
                                      ? Icons.remove_circle_outline_rounded
                                      : Icons.add_circle_outline_rounded,
                                  color: isExpanded ? AppColors.primary : const Color(0xFF64748B),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              isMobile ? 16 : 20,
                              0,
                              isMobile ? 16 : 20,
                              isMobile ? 16 : 20,
                            ),
                            child: Text(
                              faq['a']!,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
