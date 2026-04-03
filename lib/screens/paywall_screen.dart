import 'dart:developer';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:chrono/colors.dart';
import 'package:chrono/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<AdaptyPaywallProduct>? _products;
  int _selectedProductIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPaywall();
  }

  Future<void> _loadPaywall() async {
    setState(() => _errorMessage = null);
    try {
      final products = await SubscriptionService.instance.loadProducts();
      log('[PaywallScreen] Loaded ${products?.length} products');
      if (products != null && products.isNotEmpty) {
        if (mounted) {
          setState(() {
            _products = products;
            // По умолчанию выбираем годовой план если есть
            final annualIndex = products.indexWhere(
              (p) => p.subscription?.period.unit == AdaptyPeriodUnit.year,
            );
            _selectedProductIndex = annualIndex != -1 ? annualIndex : 0;
          });
        }
      } else {
        if (mounted) {
          setState(() => _errorMessage = 'Не удалось загрузить тарифы. Проверьте соединение.');
        }
      }
    } catch (e) {
      log('[PaywallScreen] Error loading paywall: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Ошибка при загрузке: $e');
      }
    }
  }

  Future<void> _handlePurchase() async {
    if (_products == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final product = _products![_selectedProductIndex];
      final success = await SubscriptionService.instance.buyProduct(product);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подписка успешно оформлена!'),
            backgroundColor: successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось оформить подписку'),
            backgroundColor: MyColors.remove,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: MyColors.remove),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    try {
      await SubscriptionService.instance.restorePurchases();
      if (!mounted) return;
      if (SubscriptionService.instance.hasSubscription.value) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Подписка успешно восстановлена!'),
            backgroundColor: successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Активные подписки не найдены'),
            backgroundColor: warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: MyColors.remove),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          leading: IconButton(
            icon: const Icon(Icons.close, color: textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: MyColors.remove, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPaywall,
                        style: ElevatedButton.styleFrom(backgroundColor: MyColors.orangeDivider),
                        child: const Text('Попробовать снова',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(MyColors.orangeDivider),
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildFeatures()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSubscriptionSelector(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 160)),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cardColor2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: textSecondary, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 48,
        left: 24,
        right: 24,
        bottom: 8,
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: MyColors.orangeDivider.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: MyColors.orangeDivider,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chrono Premium',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Раскройте полный потенциал вашей продуктивности',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildFeatureTile('🤖', 'AI-ассистент без ограничений',
              'GPT-анализ заметок, рабочие пространства с AI-поиском'),
          const SizedBox(height: 14),
          _buildFeatureTile('🗂️', 'Неограниченные рабочие пространства',
              'Организуйте проекты, идеи и цели в отдельных пространствах'),
          const SizedBox(height: 14),
          _buildFeatureTile('📊', 'Расширенная аналитика',
              'Подробные инсайты и статистика вашей продуктивности'),
          const SizedBox(height: 14),
          _buildFeatureTile('⏱️', 'Продвинутый трекер целей',
              'Сессии, история и детальная статистика по каждой цели'),
          const SizedBox(height: 14),
          _buildFeatureTile('🔔', 'Умные уведомления',
              'Персонализированные напоминания для рутин и целей'),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(String icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MyColors.orangeDivider.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionSelector() {
    return Column(
      children: List.generate(_products!.length, (index) {
        final product = _products![index];
        final isSelected = _selectedProductIndex == index;
        final savings = _calculateSavings(product);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedProductIndex = index),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
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
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? MyColors.orangeDivider : MyColors.trecondaryColor,
                            width: 2,
                          ),
                          color: isSelected ? MyColors.orangeDivider : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.black)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _getDurationText(product),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? textPrimary : textSecondary,
                          ),
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
                        'Выгода $savings%',
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
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        border: const Border(top: BorderSide(color: cardColor3, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '3 дня бесплатно, затем по выбранному тарифу',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MyColors.orangeDivider,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.orangeDivider,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.black),
                      ),
                    )
                  : const Text(
                      'Попробовать бесплатно',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _handleRestore,
            child: const Text(
              'Восстановить покупки',
              style: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              _buildLegalLink(
                'Условия использования',
                // TODO: добавить реальную ссылку
                'https://example.com/terms',
              ),
              _buildLegalLink(
                'Политика конфиденциальности',
                // TODO: добавить реальную ссылку
                'https://example.com/privacy',
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Нажимая кнопку, вы соглашаетесь с документами выше',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLink(String text, String urlString) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(urlString);
        if (!await launchUrl(url)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Не удалось открыть ссылку')),
            );
          }
        }
      },
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: textMuted,
          decoration: TextDecoration.underline,
          decorationColor: textMuted,
        ),
      ),
    );
  }

  double? _getMonthlyPrice() {
    if (_products == null) return null;
    try {
      final monthly = _products!.firstWhere(
        (p) =>
            p.subscription?.period.unit == AdaptyPeriodUnit.month &&
            p.subscription?.period.numberOfUnits == 1,
      );
      return monthly.price.amount;
    } catch (_) {
      return null;
    }
  }

  int? _calculateSavings(AdaptyPaywallProduct product) {
    final monthlyPrice = _getMonthlyPrice();
    if (monthlyPrice == null) return null;
    final subscription = product.subscription;
    if (subscription == null) return null;

    double monthlyEquivalent;
    if (subscription.period.unit == AdaptyPeriodUnit.year) {
      monthlyEquivalent = product.price.amount / (12 * subscription.period.numberOfUnits);
    } else if (subscription.period.unit == AdaptyPeriodUnit.month &&
        subscription.period.numberOfUnits > 1) {
      monthlyEquivalent = product.price.amount / subscription.period.numberOfUnits;
    } else {
      return null;
    }

    if (monthlyEquivalent >= monthlyPrice) return null;
    return (((monthlyPrice - monthlyEquivalent) / monthlyPrice) * 100).round();
  }

  String _getDurationText(AdaptyPaywallProduct product) {
    final subscription = product.subscription;
    if (subscription != null) {
      final period = subscription.period;
      switch (period.unit) {
        case AdaptyPeriodUnit.month:
          return period.numberOfUnits == 1 ? '1 Месяц' : '${period.numberOfUnits} месяца';
        case AdaptyPeriodUnit.year:
          return period.numberOfUnits == 1 ? '1 Год' : '${period.numberOfUnits} года';
        case AdaptyPeriodUnit.week:
          return period.numberOfUnits == 1 ? '1 Неделя' : '${period.numberOfUnits} недели';
        default:
          break;
      }
    }
    return 'Подписка';
  }
}
