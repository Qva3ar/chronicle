import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/homepage.dart';
import 'package:chrono/onboarding/onboarding_animations.dart';
import 'package:chrono/onboarding/onboarding_mockups.dart';
import 'package:chrono/services/subscription_service.dart';

// Required by App Store Review Guideline 3.1.2 — auto-renewable subscriptions
// must include functional links to Terms of Use (EULA) and Privacy Policy
// inside the purchase flow.
const String kTermsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const String kPrivacyPolicyUrl =
    'https://docs.google.com/document/d/16Yi3piQAQLk3SW5itI1iiIntvVG9amvWDSaZpIX43ts/edit?usp=sharing';

Future<void> _openLegalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _featurePages = [
    _PageData(
      title: 'Time is the only\nnon-renewable resource',
      subtitle: 'Stop spending it.\nStart investing it.',
      animationIndex: 0,
    ),
    _PageData(
      title: 'Your Data. Your Device.',
      titleFontSize: 22,
      subtitle:
          'Chrono works 100% offline.\nAll your data stays on your phone —\nprivate and always available.',
      footnote: 'AI features may send your data to third-party services.',
      animationIndex: 1,
    ),
    _PageData(
      title: 'Your External Brain',
      subtitle:
          'Writing isn\'t just recording — it\'s thinking.\nMaking notes has never been this easy.',
      animationIndex: 2,
    ),
    _PageData(
      title: 'Unbreakable Discipline',
      subtitle:
          'Routine is what makes us better every day.\nDaily reset. Persistent notifications.\nNo room for procrastination.',
      animationIndex: 3,
    ),
    _PageData(
      title: 'Invest Your Time',
      subtitle:
          'What gets measured, gets managed.\nDaily goals for deep work — see where your time goes\nand what still needs your attention.',
      animationIndex: 4,
    ),
    _PageData(
      title: 'Your Notes Are\na Knowledge Base',
      subtitle:
          'Chat with AI for free — bring your own API key.\nFeed your notes as context to get insights\nbuilt on your own data.',
      footnote: 'Requires your own API key.',
      animationIndex: 5,
    ),
    _PageData(
      title: 'Your Thinking Space',
      subtitle:
          'Great ideas need room to develop.\nCollect materials, shape thoughts, analyze —\neach workspace is a dedicated lab for your ideas.',
      animationIndex: 6,
    ),
    _PageData(
      title: 'Measure Your Growth',
      subtitle:
          'What you track, you improve.\nDaily score from your routines and goals.\nSpot trends, find patterns, keep rising.',
      animationIndex: 7,
    ),
  ];

  // Skip the paywall page entirely if the user already has a subscription.
  late final bool _showPaywall =
      !SubscriptionService.instance.hasSubscription.value;

  int get _totalPages => _featurePages.length + (_showPaywall ? 1 : 0);

  bool get _isLastFeaturePage => _currentPage == _featurePages.length - 1;
  bool get _isPaywallPage => _showPaywall && _currentPage == _totalPages - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomePage()),
      (_) => false,
    );
  }

  void _nextPage() {
    // On the last feature page with no paywall, finish onboarding directly.
    if (!_showPaywall && _isLastFeaturePage) {
      _finishOnboarding();
      return;
    }
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    // No paywall to jump to — finish onboarding right away.
    if (!_showPaywall) {
      _finishOnboarding();
      return;
    }
    // Jump to paywall
    _pageController.animateToPage(
      _totalPages - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isPaywallPage)
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  if (index < _featurePages.length) {
                    return _FeaturePage(
                      data: _featurePages[index],
                      isActive: _currentPage == index,
                    );
                  }
                  return PaywallContent(onFinish: _finishOnboarding);
                },
              ),
            ),

            // Bottom: dots + button
            if (!_isPaywallPage)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  children: [
                    // Dots indicator
                    Row(
                      children: List.generate(_totalPages, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? MyColors.orangeDivider
                                : textMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    // Next button
                    _NextButton(
                      onPressed: _nextPage,
                      label: _isLastFeaturePage
                          ? (_showPaywall ? 'Continue' : 'Get Started')
                          : 'Next',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Feature Page
// ═══════════════════════════════════════════════════════════════════════════

class _PageData {
  final String title;
  final String subtitle;
  final String? footnote;
  final int animationIndex;
  final double? titleFontSize;

  const _PageData({
    required this.title,
    required this.subtitle,
    this.footnote,
    required this.animationIndex,
    this.titleFontSize,
  });
}

class _FeaturePage extends StatelessWidget {
  final _PageData data;
  final bool isActive;

  const _FeaturePage({required this.data, required this.isActive});

  Widget? _buildMockup() {
    switch (data.animationIndex) {
      case 1:
        return const OfflineDataMockup();
      case 2:
        return const NotesFeedMockup();
      case 3:
        return const RoutinesMockup();
      case 4:
        return const GoalsTimerMockup();
      case 5:
        return const AIChatMockup();
      case 6:
        return const WorkspacesMockup();
      case 7:
        return const ProductivityIndexMockup();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mockup = _buildMockup();

    // Screen 0 keeps the original animation
    if (mockup == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 1),
            SizedBox(
              height: 300,
              child: Center(child: PulsingRingsAnimation(active: isActive)),
            ),
            const Spacer(flex: 1),
            _buildText(),
            const Spacer(flex: 2),
          ],
        ),
      );
    }

    // Screens 1–5: mockup on top, text on bottom
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Mockup area
          Expanded(
            flex: 5,
            child: ClipRect(child: mockup),
          ),
          const SizedBox(height: 12),
          // Text area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildText(),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildText() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.titleFontSize != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: textPrimary,
                fontSize: data.titleFontSize,
                fontWeight: FontWeight.w700,
                fontFamily: 'Montserrat',
                height: 1.2,
              ),
            ),
          )
        else
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFamily: 'Montserrat',
              height: 1.2,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          data.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textSecondary.withValues(alpha: 0.8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        if (data.footnote != null) ...[
          const SizedBox(height: 12),
          Text(
            data.footnote!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MyColors.remove.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Next Button
// ═══════════════════════════════════════════════════════════════════════════

class _NextButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _NextButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: MyColors.orangeDivider,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: MyColors.orangeDivider.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A1B1F),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Paywall Page
// ═══════════════════════════════════════════════════════════════════════════

class PaywallContent extends StatefulWidget {
  final VoidCallback onFinish;
  const PaywallContent({super.key, required this.onFinish});

  @override
  State<PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends State<PaywallContent> {
  bool _purchasing = false;
  List<dynamic>? _products;
  int _selectedIndex = 0;
  bool _plansVisible = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_plansVisible && _scrollController.offset > 80) {
      setState(() => _plansVisible = true);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await SubscriptionService.instance.loadProducts();
      if (mounted && products != null && products.isNotEmpty) {
        // Sort: monthly, 3-months, annual, lifetime
        products.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
        // Default select annual
        final annualIdx = products
            .indexWhere((p) => p.subscription?.period.unit.toString().contains('year') ?? false);
        setState(() {
          _products = products;
          _selectedIndex = annualIdx != -1 ? annualIdx : 0;
        });
      } else if (mounted) {
        setState(() => _products = []);
      }
    } catch (_) {
      if (mounted) setState(() => _products = []);
    }
  }

  int _sortKey(dynamic p) {
    final sub = p.subscription;
    if (sub == null) return 999; // lifetime last
    final units = sub.period.numberOfUnits as int;
    final unit = sub.period.unit.toString();
    if (unit.contains('week')) return units * 7;
    if (unit.contains('month')) return units * 30;
    if (unit.contains('year')) return units * 365;
    return 500;
  }

  double? _getMonthlyPrice() {
    if (_products == null) return null;
    try {
      final monthly = _products!.firstWhere((p) =>
          p.subscription?.period.unit.toString().contains('month') == true &&
          p.subscription?.period.numberOfUnits == 1);
      return monthly.price.amount;
    } catch (_) {
      return null;
    }
  }

  int? _calcSavings(dynamic product) {
    final monthlyPrice = _getMonthlyPrice();
    if (monthlyPrice == null) return null;
    final sub = product.subscription;
    if (sub == null) return null;
    final unit = sub.period.unit.toString();
    final units = sub.period.numberOfUnits as int;

    double monthlyEquiv;
    if (unit.contains('year')) {
      monthlyEquiv = product.price.amount / (12 * units);
    } else if (unit.contains('month') && units > 1) {
      monthlyEquiv = product.price.amount / units;
    } else {
      return null;
    }

    if (monthlyEquiv >= monthlyPrice) return null;
    return (((monthlyPrice - monthlyEquiv) / monthlyPrice) * 100).round();
  }

  String _planLabel(dynamic product) {
    final sub = product.subscription;
    if (sub == null) return 'Lifetime';
    final units = sub.period.numberOfUnits as int;
    final unit = sub.period.unit.toString();
    if (unit.contains('year')) return units == 1 ? '1 Year' : '$units Years';
    if (unit.contains('month')) return units == 1 ? '1 Month' : '$units Months';
    if (unit.contains('week')) return units == 1 ? '1 Week' : '$units Weeks';
    return 'Plan';
  }

  Future<void> _onButtonTap() async {
    if (!_plansVisible) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() => _plansVisible = true);
      return;
    }
    await _purchase();
  }

  Future<void> _purchase() async {
    if (_products == null || _products!.isEmpty) {
      widget.onFinish();
      return;
    }
    setState(() => _purchasing = true);
    try {
      final product = _products![_selectedIndex];
      final success = await SubscriptionService.instance.buyProduct(product);
      if (mounted) {
        setState(() => _purchasing = false);
        if (success) widget.onFinish();
      }
    } catch (_) {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    await SubscriptionService.instance.restorePurchases();
    if (mounted) {
      setState(() => _purchasing = false);
      if (SubscriptionService.instance.hasSubscription.value) {
        widget.onFinish();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 16),


                // Title
                const Text(
                  'Chrono Premium',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MyColors.orangeDivider,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unlock Your\nFull Potential',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Montserrat',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),

                // Features list
                ...paywallProFeatures.map((f) => PaywallFeatureRow(
                      icon: f.$1,
                      title: f.$2,
                      subtitle: f.$3,
                      note: f.$4,
                    )),

                const SizedBox(height: 8),

                // Subscription selector
                if (_products != null && _products!.isNotEmpty)
                  ...List.generate(_products!.length, (i) {
                    final product = _products![i];
                    final isSelected = _selectedIndex == i;
                    final savings = _calcSavings(product);
                    final isLifetime = product.subscription == null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = i),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? MyColors.orangeDivider.withValues(alpha: 0.08)
                                    : cardColor,
                                border: Border.all(
                                  color: isSelected ? MyColors.orangeDivider : cardColor3,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  // Radio circle
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? MyColors.orangeDivider : textMuted,
                                        width: 2,
                                      ),
                                      color:
                                          isSelected ? MyColors.orangeDivider : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 14, color: Colors.black)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _planLabel(product),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight:
                                                isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? textPrimary : textSecondary,
                                          ),
                                        ),
                                        if (isLifetime)
                                          Text(
                                            'One-time purchase',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    product.price.localizedString ??
                                        '${product.price.amount} ${product.price.currencyCode}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? MyColors.orangeDivider : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (savings != null && savings > 0)
                              Positioned(
                                top: -10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: MyColors.orangeDivider,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Save $savings%',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                if (_products == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(MyColors.orangeDivider),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Bottom bar
        Padding(
          padding: EdgeInsets.fromLTRB(28, 8, 28, MediaQuery.of(context).padding.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subscribe button
              GestureDetector(
                onTap: _purchasing ? null : _onButtonTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MyColors.orangeDivider, Color(0xFFFFAA4C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: MyColors.orangeDivider.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _purchasing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Color(0xFF1A1B1F),
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _plansVisible ? 'Start Growing' : 'See Plans',
                            style: const TextStyle(
                              color: Color(0xFF1A1B1F),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Secondary actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _purchasing ? null : _restore,
                    child: Text(
                      'Restore Purchases',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ),
                  Text('  |  ', style: TextStyle(color: textMuted.withValues(alpha: 0.3))),
                  TextButton(
                    onPressed: widget.onFinish,
                    child: Text(
                      'Continue Free',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _openLegalUrl(kTermsOfUseUrl),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Terms of Use (EULA)',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: textMuted,
                      ),
                    ),
                  ),
                  Text('·',
                      style: TextStyle(color: textMuted.withValues(alpha: 0.4))),
                  TextButton(
                    onPressed: () => _openLegalUrl(kPrivacyPolicyUrl),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: textMuted,
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. Manage or cancel subscriptions in your App Store account settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textMuted.withValues(alpha: 0.7),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const paywallProFeatures = [
  (
    Icons.schedule_rounded,
    'Routine Manager',
    'Build unbreakable daily habits',
    null,
  ),
  (
    Icons.track_changes_rounded,
    'Goal Manager',
    'Track deep work sessions with timers',
    null,
  ),
  (
    Icons.checklist_rounded,
    'Todo Manager',
    'Deadlines with daily reminders',
    null,
  ),
  (
    Icons.workspaces_rounded,
    'Workspaces',
    'Organize ideas into focused labs',
    null,
  ),
  (
    Icons.analytics_rounded,
    'Productivity Index',
    'Daily score from your progress',
    null,
  ),
  (
    Icons.psychology_rounded,
    'AI Context',
    'Feed your notes to AI for deeper insights',
    'Requires your own API key',
  ),
];

class PaywallFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? note;

  const PaywallFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MyColors.orangeDivider.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: MyColors.orangeDivider, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note!,
                    style: const TextStyle(
                      color: MyColors.remove,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: MyColors.orangeDivider.withValues(alpha: 0.6),
            size: 20,
          ),
        ],
      ),
    );
  }
}
