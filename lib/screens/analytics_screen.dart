import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loading.dart';

class AnalyticsScreen extends StatefulWidget {
  final List<Lead> leads;
  final bool isLoading;

  const AnalyticsScreen({
    super.key,
    this.leads = const [],
    this.isLoading = false,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final leads = widget.leads;
    final totalCount = leads.length;

    final newCount = leads.where((l) => l.status == LeadStatus.newLead).length;
    final contactedCount = leads.where((l) => l.status == LeadStatus.contacted).length;
    final qualifiedCount = leads.where((l) => l.status == LeadStatus.qualified).length;
    final convertedCount = leads.where((l) => l.status == LeadStatus.converted).length;
    final lostCount = leads.where((l) => l.status == LeadStatus.lost).length;

    final now = DateTime.now();
    final thisMonthCount = leads.where((l) {
      return l.createdAt.year == now.year && l.createdAt.month == now.month;
    }).length;

    final conversionRate = totalCount > 0
        ? (convertedCount / totalCount * 100)
        : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            Text(
              'Realtime metrics from $totalCount database leads',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: widget.isLoading
          ? const AnalyticsScreenSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
          _buildSummaryCards(totalCount, thisMonthCount, conversionRate),

          const SizedBox(height: 24),

          const Text(
            'Lead Pipeline',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          _buildPipelineCard('New', '$newCount', Icons.people_alt_outlined, const Color(0xFF2563EB)),
          _buildPipelineCard('Contacted', '$contactedCount', Icons.phone_outlined, const Color(0xFFEA580C)),
          _buildPipelineCard('Qualified', '$qualifiedCount', Icons.verified_outlined, const Color(0xFF16A34A)),
          _buildPipelineCard('Converted', '$convertedCount', Icons.check_circle_outline, const Color(0xFF0F766E)),
          _buildPipelineCard('Lost', '$lostCount', Icons.close_outlined, const Color(0xFFDC2626)),

          const SizedBox(height: 24),

          const Text(
            'Conversion Rate',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Overall Conversion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${conversionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalCount > 0 ? (convertedCount / totalCount).clamp(0.0, 1.0) : 0.0,
                    minHeight: 10,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$convertedCount of $totalCount total applicants converted',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int total, int thisMonth, double convRate) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Total Leads',
            '$total',
            Icons.people_alt_outlined,
            const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'This Month',
            '$thisMonth',
            Icons.trending_up_rounded,
            const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            'Conversion',
            '${convRate.toStringAsFixed(1)}%',
            Icons.analytics_outlined,
            const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$count leads',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}