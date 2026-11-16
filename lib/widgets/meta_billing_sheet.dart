import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MetaBillingRedirectHelper {
  // Default Meta Ad Account ID configured in backend
  static const String defaultAdAccountId = '1593227015623724';

  static String cleanAdAccountId(String? rawId) {
    if (rawId == null || rawId.trim().isEmpty) return defaultAdAccountId;
    final cleaned = rawId.trim().replaceAll('act_', '');
    return cleaned.isNotEmpty ? cleaned : defaultAdAccountId;
  }

  /// Direct URL to Add Funds into the specific Meta Ad Account
  static String getAddFundsUrl(String? adAccountId) {
    final cleaned = cleanAdAccountId(adAccountId);
    return 'https://adsmanager.facebook.com/adsmanager/manage/billing?act=$cleaned';
  }

  /// Direct URL to Meta Business Billing & Payment Methods (UPI, Cards, GST)
  static String getPaymentSettingsUrl(String? adAccountId) {
    final cleaned = cleanAdAccountId(adAccountId);
    return 'https://business.facebook.com/billing_hub/payment_settings?act=$cleaned';
  }

  /// Direct URL to Meta for Developers Portal
  static String getMetaDevelopersUrl() {
    return 'https://developers.facebook.com/apps/';
  }

  /// Direct URL to Meta Business Suite Ad Account Settings
  static String getBusinessSettingsUrl(String? adAccountId) {
    final cleaned = cleanAdAccountId(adAccountId);
    return 'https://business.facebook.com/settings/ad-accounts/$cleaned';
  }

  /// Bulletproof URL launcher with multi-tier fallback (external app -> platform default -> in-app browser)
  static Future<bool> openUrl(String urlString, {BuildContext? context, String? label}) async {
    final uri = Uri.parse(urlString);
    debugPrint('[MetaBilling] Launching URL ($label): $urlString');

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Opening ${label ?? "Meta Portal"} in browser...',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    bool launched = false;

    // 1. Primary Attempt: External browser application
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('[MetaBilling] externalApplication launch result: $launched');
    } catch (e) {
      debugPrint('[MetaBilling] externalApplication failed: $e');
    }

    // 2. Secondary Attempt: Platform default handler
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        debugPrint('[MetaBilling] platformDefault launch result: $launched');
      } catch (e) {
        debugPrint('[MetaBilling] platformDefault failed: $e');
      }
    }

    // 3. Tertiary Attempt: In-App Browser View
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        debugPrint('[MetaBilling] inAppBrowserView launch result: $launched');
      } catch (e) {
        debugPrint('[MetaBilling] inAppBrowserView failed: $e');
      }
    }

    // 4. Fallback if browser failed to open
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: urlString));
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not auto-open browser. Link copied to clipboard:\n$urlString',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }

    return launched;
  }

  /// Directly launch Add Funds for this ad account
  static Future<bool> openAddFunds({String? adAccountId, BuildContext? context}) async {
    final url = getAddFundsUrl(adAccountId);
    return await openUrl(url, context: context, label: 'Meta Add Funds');
  }

  /// Directly launch Meta for Developers Portal
  static Future<bool> openMetaDevelopers({BuildContext? context}) async {
    final url = getMetaDevelopersUrl();
    return await openUrl(url, context: context, label: 'Meta for Developers');
  }

  /// Directly launch Payment Settings
  static Future<bool> openPaymentSettings({String? adAccountId, BuildContext? context}) async {
    final url = getPaymentSettingsUrl(adAccountId);
    return await openUrl(url, context: context, label: 'Meta Payment Settings');
  }

  /// Directly launch Meta Business Settings
  static Future<bool> openBusinessSettings({String? adAccountId, BuildContext? context}) async {
    final url = getBusinessSettingsUrl(adAccountId);
    return await openUrl(url, context: context, label: 'Meta Business Settings');
  }

  /// Display comprehensive Meta Billing & Developer Redirection Modal Sheet
  static void showBillingOptions(
    BuildContext context, {
    String? adAccountId,
    String? accountName,
    double? currentBalance,
    String? currencySymbol = '₹',
  }) {
    HapticFeedback.mediumImpact();
    final cleanedId = cleanAdAccountId(adAccountId);
    final formattedAct = 'act_$cleanedId';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0668E1), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Meta Billing & Add Funds',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountName != null && accountName.isNotEmpty
                                ? '$accountName • $formattedAct'
                                : 'Account ID: $formattedAct',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                if (currentBalance != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Ad Balance:',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$currencySymbol${currentBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: currentBalance > 0
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                const Text(
                  'CHOOSE DESTINATION',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),

                // Option 1: Direct Add Funds (UPI, Cards, NetBanking)
                _buildActionTile(
                  icon: Icons.add_card_rounded,
                  iconBg: const Color(0xFF16A34A),
                  title: 'Add Funds (UPI / Cards / NetBanking)',
                  subtitle: 'Directly opens Meta Ads Manager to add prepaid balance to $formattedAct.',
                  badge: 'RECOMMENDED',
                  badgeColor: const Color(0xFF16A34A),
                  onTap: () {
                    Navigator.pop(ctx);
                    openAddFunds(adAccountId: cleanedId, context: context);
                  },
                ),

                const SizedBox(height: 10),

                // Option 2: Meta for Developers Portal
                _buildActionTile(
                  icon: Icons.code_rounded,
                  iconBg: const Color(0xFF7C3AED),
                  title: 'Meta for Developers Portal',
                  subtitle: 'Manage your Meta Developer App, tokens, Marketing API, and Webhooks.',
                  badge: 'DEVELOPER',
                  badgeColor: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.pop(ctx);
                    openMetaDevelopers(context: context);
                  },
                ),

                const SizedBox(height: 10),

                // Option 3: Meta Business Payment Settings & Invoices
                _buildActionTile(
                  icon: Icons.receipt_long_rounded,
                  iconBg: const Color(0xFF0284C7),
                  title: 'Payment Settings & Invoices',
                  subtitle: 'Manage payment methods, GST/Tax information, and official receipts.',
                  badge: null,
                  badgeColor: null,
                  onTap: () {
                    Navigator.pop(ctx);
                    openPaymentSettings(adAccountId: cleanedId, context: context);
                  },
                ),

                const SizedBox(height: 10),

                // Option 4: Meta Business Suite Ad Account Settings
                _buildActionTile(
                  icon: Icons.business_center_rounded,
                  iconBg: const Color(0xFFD97706),
                  title: 'Meta Business Ad Account Settings',
                  subtitle: 'Manage user access permissions, agency roles, and assets.',
                  badge: null,
                  badgeColor: null,
                  onTap: () {
                    Navigator.pop(ctx);
                    openBusinessSettings(adAccountId: cleanedId, context: context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String? badge,
    required Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconBg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null && badgeColor != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: badgeColor, width: 0.7),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF64748B),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
