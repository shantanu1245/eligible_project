import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final List<Map<String, dynamic>> _campaigns = [
    {
      'name': 'Pune Property Campaign',
      'platform': 'Facebook & Instagram',
      'leads': 87,
      'budget': '₹1,000/day',
      'status': 'Active',
    },
    {
      'name': 'Mumbai Property Campaign',
      'platform': 'Facebook',
      'leads': 42,
      'budget': '₹800/day',
      'status': 'Active',
    },
    {
      'name': 'Website Lead Campaign',
      'platform': 'Instagram',
      'leads': 31,
      'budget': '₹500/day',
      'status': 'Paused',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Campaigns',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          30,
        ),
        children: [
          _buildSummary(),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Campaigns',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${_campaigns.length} campaigns',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ..._campaigns.map(
            (campaign) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CampaignCard(
                campaign: campaign,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final totalLeads = _campaigns.fold<int>(
      0,
      (sum, campaign) => sum + campaign['leads'] as int,
    );

    final activeCampaigns = _campaigns.where(
      (campaign) => campaign['status'] == 'Active',
    ).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Campaigns',
            value: '${_campaigns.length}',
            icon: Icons.campaign_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'Active',
            value: '$activeCampaigns',
            icon: Icons.play_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'Leads',
            value: '$totalLeads',
            icon: Icons.people_outline,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
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
}

class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> campaign;

  const _CampaignCard({
    required this.campaign,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = campaign['status'] == 'Active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign['platform'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                text: campaign['status'],
                active: active,
              ),
            ],
          ),

          const SizedBox(height: 15),
          const Divider(
            color: AppTheme.border,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _CampaignInfo(
                  label: 'Leads',
                  value: '${campaign['leads']}',
                  icon: Icons.people_outline,
                ),
              ),
              Expanded(
                child: _CampaignInfo(
                  label: 'Budget',
                  value: campaign['budget'],
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampaignInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CampaignInfo({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final bool active;

  const _StatusBadge({
    required this.text,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: active
              ? const Color(0xFF16A34A)
              : const Color(0xFFEA580C),
        ),
      ),
    );
  }
}