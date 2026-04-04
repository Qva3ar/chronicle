import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/homepage.dart';
import 'package:chrono/onboarding/onboarding_animations.dart';
import 'package:chrono/services/subscription_service.dart';

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
      title: 'Your External Brain',
      subtitle:
          'Writing isn\'t just recording — it\'s thinking.\nCapture your evolution through the #Chrono stream.',
      animationIndex: 1,
    ),
    _PageData(
      title: 'Unbreakable Discipline',
      subtitle:
          'Daily reset. Persistent notifications.\nNo room for procrastination.',
      animationIndex: 2,
    ),
    _PageData(
      title: 'Invest Your Time',
      subtitle:
          'Deep work sessions where every minute\ncounts toward your progress.',
      animationIndex: 3,
    ),
    _PageData(
      title: 'Your Experience,\nAmplified',
      subtitle:
          'Turn your notes into knowledge.\nAI analyzes patterns and surfaces insights.',
      animationIndex: 4,
    ),
    _PageData(
      title: 'Your Command Center',
      subtitle:
          'Dedicated spaces for every domain of your life.\nWork, growth, side projects — organized, never scattered.',
      animationIndex: 5,
    ),
  ];

  static const _totalPages = 7; // 6 features + 1 paywall

  bool get _isLastFeaturePage => _currentPage == _featurePages.length - 1;
  bool get _isPaywallPage => _currentPage == _totalPages - 1;

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
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
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
                  return _PaywallPage(onFinish: _finishOnboarding);
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
                      label: _isLastFeaturePage ? 'Continue' : 'Next',
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
  final int animationIndex;

  const _PageData({
    required this.title,
    required this.subtitle,
    required this.animationIndex,
  });
}

class _FeaturePage extends StatelessWidget {
  final _PageData data;
  final bool isActive;

  const _FeaturePage({required this.data, required this.isActive});

  Widget _buildAnimation() {
    switch (data.animationIndex) {
      case 0:
        return PulsingRingsAnimation(active: isActive);
      case 1:
        return FlowingNotesAnimation(active: isActive);
      case 2:
        return StreakCheckAnimation(active: isActive);
      case 3:
        return ProgressRingAnimation(active: isActive);
      case 4:
        return NeuralNetworkAnimation(active: isActive);
      case 5:
        return WorkspaceGridAnimation(active: isActive);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Animation area
          SizedBox(
            height: 300,
            child: Center(child: _buildAnimation()),
          ),
          const Spacer(flex: 1),
          // Title
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
          // Subtitle
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
          const Spacer(flex: 2),
        ],
      ),
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

class _PaywallPage extends StatefulWidget {
  final VoidCallback onFinish;
  const _PaywallPage({required this.onFinish});

  @override
  State<_PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<_PaywallPage> {
  bool _purchasing = false;
  List<dynamic>? _products;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await SubscriptionService.instance.loadProducts();
      if (mounted) {
        setState(() => _products = products);
      }
    } catch (_) {}
  }

  Future<void> _purchase() async {
    if (_products == null || _products!.isEmpty) {
      widget.onFinish();
      return;
    }
    setState(() => _purchasing = true);
    try {
      final success =
          await SubscriptionService.instance.buyProduct(_products!.first);
      if (mounted) {
        setState(() => _purchasing = false);
        if (success) {
          widget.onFinish();
        }
      }
    } catch (e) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Premium badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: MyColors.orangeDivider.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MyColors.orangeDivider.withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'CHRONO PRO',
              style: TextStyle(
                color: MyColors.orangeDivider,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
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
          const SizedBox(height: 32),

          // Features list
          ..._proFeatures.map((f) => _FeatureRow(
                icon: f.$1,
                title: f.$2,
                subtitle: f.$3,
              )),

          const Spacer(flex: 3),

          // Subscribe button
          GestureDetector(
            onTap: _purchasing ? null : _purchase,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    MyColors.orangeDivider,
                    Color(0xFFFFAA4C),
                  ],
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
                    : const Text(
                        'Start Growing',
                        style: TextStyle(
                          color: Color(0xFF1A1B1F),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _restore,
                child: Text(
                  'Restore Purchases',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              Text('  |  ', style: TextStyle(color: textMuted.withValues(alpha: 0.3))),
              TextButton(
                onPressed: widget.onFinish,
                child: Text(
                  'Continue Free',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

const _proFeatures = [
  (
    Icons.auto_awesome_rounded,
    'Unlimited AI',
    'Insights, analysis, and chat — no limits',
  ),
  (
    Icons.analytics_rounded,
    'Advanced Analytics',
    'Deep productivity metrics and trends',
  ),
  (
    Icons.workspaces_rounded,
    'Workspaces',
    'Organize your life into focused domains',
  ),
  (
    Icons.sync_rounded,
    'Full Sync',
    'Seamless backup and cross-device access',
  ),
];

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
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
