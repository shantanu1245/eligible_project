import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';

class CreateMetaCampaignScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onCampaignCreated;

  const CreateMetaCampaignScreen({super.key, this.onCampaignCreated});

  @override
  State<CreateMetaCampaignScreen> createState() => _CreateMetaCampaignScreenState();
}

class _CreateMetaCampaignScreenState extends State<CreateMetaCampaignScreen> {
  final BackendService _backend = BackendService();

  int _currentStep = 0; // 0: Campaign, 1: Ad Set & Targeting, 2: Ad Creative, 3: Review & Publish
  bool _isPublishing = false;

  // ---------------------------------------------------------------------------
  // STEP 1: CAMPAIGN LEVEL VARIABLES
  // ---------------------------------------------------------------------------
  final _campaignNameController = TextEditingController(text: 'Pune & PCMC High Intent Loan Campaign');
  String _selectedObjective = 'OUTCOME_LEADS'; // Leads, Engagement, Traffic, Awareness, Sales
  String _specialAdCategory = 'CREDIT'; // CREDIT, HOUSING, EMPLOYMENT, NONE
  String _budgetType = 'DAILY'; // DAILY, LIFETIME
  final _budgetController = TextEditingController(text: '1500');
  String _bidStrategy = 'LOWEST_COST_WITHOUT_CAP'; // Highest volume
  bool _isCboEnabled = true; // Advantage Campaign Budget

  // ---------------------------------------------------------------------------
  // STEP 2: AD SET LEVEL & TARGETING (PINCODE & AREA WISE)
  // ---------------------------------------------------------------------------
  final _adSetNameController = TextEditingController(text: 'Pune Prime Pincodes & IT Hubs - Age 24-55');
  String _conversionLocation = 'ON_AD'; // ON_AD (Instant Form), WHATSAPP, WEBSITE, CALLS
  String _locationStatus = 'HOME'; // 'HOME' (Living in this location), 'RECENT' (Living or recently in)

  // Pincode targeting
  final _pincodeInputController = TextEditingController();
  final List<String> _targetedPincodes = ['411038', '411057', '411045', '411014'];

  // Area & Locality targeting
  final _areaInputController = TextEditingController();
  final List<String> _targetedAreas = ['Hinjewadi', 'Kothrud', 'Baner', 'Viman Nagar', 'Wakad'];
  double _dropPinRadiusKm = 3.0; // 1 to 15 km

  // Excluded Locations
  final List<String> _excludedAreas = ['Industrial Outskirts'];

  // Demographics
  double _minAge = 24;
  double _maxAge = 55;
  String _selectedGender = 'ALL'; // ALL, MEN, WOMEN

  // Detailed loan interests & behaviors
  final List<String> _availableInterests = [
    'Personal Loans',
    'Home Loans & Mortgages',
    'Commercial Loans',
    'Small Business Owners',
    'Salaried Employees',
    'Credit Card Holders',
    'CIBIL & Credit Score Aware',
    'First-time Home Buyers',
    'Banking & Financial Services',
    'Chartered Accountants',
    'Doctors & Healthcare Pros',
  ];
  final Set<String> _selectedInterests = {
    'Personal Loans',
    'Home Loans & Mortgages',
    'Salaried Employees',
    'CIBIL & Credit Score Aware',
  };

  // ---------------------------------------------------------------------------
  // STEP 3: PLACEMENTS & CREATIVE LEVEL
  // ---------------------------------------------------------------------------
  bool _useAdvantagePlacements = true;
  bool _placementFacebook = true;
  bool _placementInstagram = true;
  bool _placementMessenger = true;
  bool _placementAudienceNetwork = false;

  final _adNameController = TextEditingController(text: 'Instant Approval Loan Ad - Creative 01');
  final String _selectedPage = 'Eligible Financial Services (Official)';
  final String _selectedInstagram = '@eligible.financial (Connected)';
  String _adFormat = 'SINGLE_IMAGE'; // SINGLE_IMAGE, CAROUSEL

  // Creative Presets
  int _selectedCreativePresetIndex = 0;
  final List<Map<String, dynamic>> _creativePresets = [
    {
      'title': 'Personal / Salary Loan',
      'banner': '💼 Instant Personal Loan up to ₹40L • Low EMI • Fast Disbursal',
      'gradient': [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      'badge': 'Lowest ROI 10.49%',
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'title': 'Home Loan & Balance Transfer',
      'banner': '🏠 Dream Home Loan @ 8.35% ROI • Zero Foreclosure Charges',
      'gradient': [Color(0xFF065F46), Color(0xFF10B981)],
      'badge': 'Subsidy Eligible',
      'icon': Icons.home_work_rounded,
    },
    {
      'title': 'Collateral Free Business Loan',
      'banner': '🏢 Working Capital & Business Expansion up to ₹75 Lakhs',
      'gradient': [Color(0xFF7C2D12), Color(0xFFF97316)],
      'badge': 'No Collateral',
      'icon': Icons.business_center_rounded,
    },
    {
      'title': 'Loan Against Property (LAP)',
      'banner': '📑 Unlock Your Property Value • Sanctions in 72 Hours',
      'gradient': [Color(0xFF4C1D95), Color(0xFF8B5CF6)],
      'badge': 'High Value Disbursals',
      'icon': Icons.domain_rounded,
    },
  ];

  final _primaryTextController = TextEditingController(
    text: 'Need immediate financial support for medical, marriage, or personal needs? Get instant paperless approval with low interest rates and flexible tenures. Check your eligibility in 2 minutes!',
  );
  final _headlineController = TextEditingController(text: 'Check Loan Eligibility in 2 Mins • Low EMI');
  final _descriptionController = TextEditingController(text: 'Zero Processing Fee • 100% Digital Process');
  String _selectedCta = 'APPLY_NOW'; // APPLY_NOW, GET_QUOTE, LEARN_MORE, WHATSAPP, CALL_NOW

  // Lead Form Questions
  final Set<String> _formQuestions = {
    'Full Name',
    'Phone Number',
    'Email Address',
    'City & Pincode',
    'Desired Loan Amount',
    'Monthly Income / Salary',
  };

  // Preview Mode
  String _previewPlatform = 'FACEBOOK_FEED'; // FACEBOOK_FEED, INSTAGRAM_FEED, INSTAGRAM_STORY

  @override
  void dispose() {
    _campaignNameController.dispose();
    _budgetController.dispose();
    _adSetNameController.dispose();
    _pincodeInputController.dispose();
    _areaInputController.dispose();
    _adNameController.dispose();
    _primaryTextController.dispose();
    _headlineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // AUDIENCE SIZE ESTIMATION CALCULATOR
  // ---------------------------------------------------------------------------
  int get _estimatedAudienceSize {
    int base = 250000;
    base += _targetedPincodes.length * 85000;
    base += _targetedAreas.length * 140000;
    if (_selectedGender != 'ALL') base = (base * 0.55).toInt();
    final ageSpan = (_maxAge - _minAge) / 47.0;
    base = (base * ageSpan).toInt();
    if (_selectedInterests.isNotEmpty) {
      base = (base * 0.72).toInt();
    }
    return base.clamp(50000, 4500000);
  }

  int get _estimatedDailyReach {
    final budget = double.tryParse(_budgetController.text) ?? 1000.0;
    return (budget * 22).toInt().clamp(2500, 120000);
  }

  int get _estimatedDailyLeads {
    final budget = double.tryParse(_budgetController.text) ?? 1000.0;
    return (budget / 65).toInt().clamp(5, 150);
  }

  // ---------------------------------------------------------------------------
  // PUBLISH ACTION
  // ---------------------------------------------------------------------------
  Future<void> _publishCampaign() async {
    setState(() => _isPublishing = true);

    try {
      final name = _campaignNameController.text.trim();
      final budget = double.tryParse(_budgetController.text.trim()) ?? 1500.0;

      // Compile target location tags (combining Pincodes & Areas)
      final allLocations = [
        ..._targetedPincodes.map((p) => 'PIN: $p'),
        ..._targetedAreas.map((a) => 'Area: $a (${_dropPinRadiusKm.toInt()}km)'),
      ];

      final res = await _backend.createCampaign(
        name: name,
        dailyBudget: budget,
        platform: _useAdvantagePlacements
            ? 'Facebook & Instagram (Advantage+)'
            : 'Manual (${_placementFacebook ? "FB " : ""}${_placementInstagram ? "IG" : ""})',
        targetLocations: allLocations.isNotEmpty ? allLocations : ['IN'],
        headline: _headlineController.text.trim(),
        bodyText: _primaryTextController.text.trim(),
      );

      if (mounted) {
        setState(() => _isPublishing = false);

        if (res['success'] == true) {
          final campaignData = Map<String, dynamic>.from(res['data'] ?? {});
          widget.onCampaignCreated?.call(campaignData);

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 70,
                    width: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF16A34A), size: 36),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Campaign Published to Meta!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your campaign "$name" with ${_targetedPincodes.length} Pincodes and ${_targetedAreas.length} Areas has been published to Meta Marketing API & synced to Firebase.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tag, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'ID: ${campaignData["meta_campaign_id"] ?? "act_meta_${DateTime.now().millisecondsSinceEpoch}"}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx); // Close dialog
                        Navigator.pop(context); // Back to campaigns screen
                      },
                      child: const Text('View in Meta Ads Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: ${res['message'] ?? 'Could not publish campaign'}'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0668E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'META',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Ads Manager • Create Ad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Text(
              'Official 3-Level Campaign Setup with Pincode & Area Targeting',
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 4),
                Text('Draft', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Step Progress Bar
          _buildStepBar(),

          // Main Step Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: _buildCurrentStepContent(),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomNavActions(),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP BAR WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildStepBar() {
    final steps = [
      {'num': '1', 'title': 'Campaign'},
      {'num': '2', 'title': 'Ad Set & Areas'},
      {'num': '3', 'title': 'Creative'},
      {'num': '4', 'title': 'Review'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCompleted = _currentStep > index;
          final isCurrent = _currentStep == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentStep = index);
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isCompleted
                        ? const Color(0xFF16A34A)
                        : isCurrent
                            ? const Color(0xFF0668E1)
                            : const Color(0xFFE2E8F0),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : Text(
                            steps[index]['num']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      steps[index]['title']!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent ? const Color(0xFF0668E1) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (index < steps.length - 1)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 1,
                      width: 12,
                      color: const Color(0xFFCBD5E1),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP ROUTER
  // ---------------------------------------------------------------------------
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Campaign();
      case 1:
        return _buildStep2AdSetAndTargeting();
      case 2:
        return _buildStep3AdCreative();
      case 3:
      default:
        return _buildStep4ReviewAndPublish();
    }
  }

  // ===========================================================================
  // STEP 1: CAMPAIGN LEVEL
  // ===========================================================================
  Widget _buildStep1Campaign() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Campaign Details',
          subtitle: 'Define overall objective, loan category compliance, and budget orchestration',
          icon: Icons.campaign_rounded,
          children: [
            const Text('CAMPAIGN NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: _campaignNameController,
              decoration: const InputDecoration(
                hintText: 'Enter campaign name...',
                prefixIcon: Icon(Icons.edit_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 16),

            // Special Ad Categories (Mandatory for financial/credit ads on Meta)
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF0668E1)),
                const SizedBox(width: 6),
                const Text('SPECIAL AD CATEGORY (MANDATORY FOR LOANS)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Meta requires financial, credit, and mortgage loan campaigns to declare a special ad category for non-discrimination compliance.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoicePill('💳 Credit & Loans', 'CREDIT', _specialAdCategory, (val) => setState(() => _specialAdCategory = val)),
                _buildChoicePill('🏠 Housing & Mortgages', 'HOUSING', _specialAdCategory, (val) => setState(() => _specialAdCategory = val)),
                _buildChoicePill('💼 Employment', 'EMPLOYMENT', _specialAdCategory, (val) => setState(() => _specialAdCategory = val)),
                _buildChoicePill('None', 'NONE', _specialAdCategory, (val) => setState(() => _specialAdCategory = val)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Campaign Objective (Meta ODAX)',
          subtitle: 'Choose the business outcome that matters most for this campaign',
          icon: Icons.track_changes_rounded,
          children: [
            _buildObjectiveTile(
              key: 'OUTCOME_LEADS',
              title: '🎯 Leads (Recommended for Eligible CRM)',
              description: 'Collect high-intent instant form submissions, WhatsApp loan chats, and verified customer phone numbers.',
              isRecommended: true,
            ),
            _buildObjectiveTile(
              key: 'OUTCOME_ENGAGEMENT',
              title: '💬 Engagement & WhatsApp Messages',
              description: 'Get direct WhatsApp and Instagram DM inquiries from prospective borrowers.',
            ),
            _buildObjectiveTile(
              key: 'OUTCOME_TRAFFIC',
              title: '🌐 Website / Loan Calculator Traffic',
              description: 'Send high volumes of clicks directly to your website or EMI eligibility calculator.',
            ),
            _buildObjectiveTile(
              key: 'OUTCOME_AWARENESS',
              title: '📢 Brand Awareness & Reach',
              description: 'Maximize recall across local area residents with high repetition and low CPM.',
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Advantage Campaign Budget (CBO)',
          subtitle: 'Automatically distribute budget across high-performing ad sets and audiences',
          icon: Icons.savings_outlined,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Advantage Campaign Budget', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('Meta AI allocates more budget to ad sets getting cheaper loan leads', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              value: _isCboEnabled,
              activeColor: const Color(0xFF0668E1),
              onChanged: (val) => setState(() => _isCboEnabled = val),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BUDGET TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _budgetType,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                        items: const [
                          DropdownMenuItem(value: 'DAILY', child: Text('Daily Budget', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'LIFETIME', child: Text('Lifetime Budget', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) => setState(() => _budgetType = val ?? 'DAILY'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AMOUNT (INR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: '₹ ',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [500, 1000, 1500, 2500, 5000].map((amt) {
                final isSelected = _budgetController.text == amt.toString();
                return ActionChip(
                  label: Text('₹$amt/day', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF334155))),
                  backgroundColor: isSelected ? const Color(0xFF0668E1) : const Color(0xFFF1F5F9),
                  onPressed: () => setState(() => _budgetController.text = amt.toString()),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text('BID STRATEGY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _bidStrategy,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
              items: const [
                DropdownMenuItem(value: 'LOWEST_COST_WITHOUT_CAP', child: Text('Highest Volume (Lowest Cost per Lead)', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'COST_CAP', child: Text('Cost Cap (Strict target cost per lead)', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (val) => setState(() => _bidStrategy = val ?? 'LOWEST_COST_WITHOUT_CAP'),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 2: AD SET & PINCODE / AREA TARGETING
  // ===========================================================================
  Widget _buildStep2AdSetAndTargeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Ad Set & Conversion Destination',
          subtitle: 'Set where you want to collect and convert loan applicants',
          icon: Icons.ads_click_rounded,
          children: [
            const Text('AD SET NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: _adSetNameController,
              decoration: const InputDecoration(
                hintText: 'Enter ad set name...',
                prefixIcon: Icon(Icons.layers_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            const Text('CONVERSION DESTINATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            _buildDestinationTile('ON_AD', '📋 Instant Forms', 'Built-in Meta lead form with auto-filled contact info (Highest Lead Conversion)'),
            _buildDestinationTile('WHATSAPP', '💬 WhatsApp Chat', 'Direct click-to-WhatsApp conversation to qualify borrower in real-time'),
            _buildDestinationTile('WEBSITE', '🌐 Website / EMI Calculator', 'Send traffic to eligible.co.in or dedicated loan landing pages'),
            _buildDestinationTile('CALLS', '📞 Direct Phone Calls', 'Show "Call Now" button for direct inbound phone inquiries'),
          ],
        ),

        const SizedBox(height: 16),

        // THE CORE FEATURE: PINCODE & AREA WISE TARGETING
        _buildSectionCard(
          title: '📍 Hyper-Local Pincode & Area Targeting',
          subtitle: 'Target specific Indian PIN codes, neighborhoods, and custom radius boundaries',
          icon: Icons.pin_drop_rounded,
          isHighlight: true,
          children: [
            // Location status selector (People living in this location)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city_rounded, color: Color(0xFF0668E1), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Targeting Rule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
                        DropdownButton<String>(
                          value: _locationStatus,
                          isDense: true,
                          underline: const SizedBox(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          items: const [
                            DropdownMenuItem(value: 'HOME', child: Text('People living in this location (Recommended)')),
                            DropdownMenuItem(value: 'RECENT', child: Text('People living in or recently in this location')),
                          ],
                          onChanged: (val) => setState(() => _locationStatus = val ?? 'HOME'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 1. PINCODE SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('1. TARGET BY PINCODE (POSTAL CODES)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text('${_targetedPincodes.length} Pincodes added', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0668E1))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pincodeInputController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter 6-digit PIN code (e.g. 411038)',
                      prefixIcon: Icon(Icons.markunread_mailbox_outlined, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onSubmitted: (val) => _addPincode(val),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0668E1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _addPincode(_pincodeInputController.text),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Add PIN', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Pincode Chips
            if (_targetedPincodes.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _targetedPincodes.map((pin) {
                  return Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Text('📮', style: TextStyle(fontSize: 10)),
                    ),
                    label: Text(pin, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E40AF))),
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF1E40AF)),
                    onDeleted: () {
                      setState(() => _targetedPincodes.remove(pin));
                    },
                  );
                }).toList(),
              ),

            // Quick Pincode Presets for Quick Demo
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickPresetPill('+ Pune West (411057, 411038, 411045)', ['411057', '411038', '411045']),
                  _buildQuickPresetPill('+ Pune East (411014, 411006, 411028)', ['411014', '411006', '411028']),
                  _buildQuickPresetPill('+ Mumbai West (400050, 400053, 400058)', ['400050', '400053', '400058']),
                ],
              ),
            ),

            const Divider(height: 28),

            // 2. AREA & LOCALITY SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('2. TARGET BY AREA / LOCALITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text('${_targetedAreas.length} Areas', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0668E1))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _areaInputController,
                    decoration: const InputDecoration(
                      hintText: 'Enter area / landmark (e.g. Hinjewadi)',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onSubmitted: (val) => _addArea(val),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _addArea(_areaInputController.text),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16, color: Colors.white),
                  label: const Text('Add Area', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Area Chips
            if (_targetedAreas.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _targetedAreas.map((area) {
                  return Chip(
                    avatar: const Icon(Icons.pin_drop, size: 14, color: Color(0xFF0F172A)),
                    label: Text('$area (+${_dropPinRadiusKm.toInt()}km)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() => _targetedAreas.remove(area));
                    },
                  );
                }).toList(),
              ),

            // Radius Slider
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Area Radius (Drop Pin reach):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF0668E1), borderRadius: BorderRadius.circular(6)),
                  child: Text('${_dropPinRadiusKm.toInt()} km', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Slider(
              value: _dropPinRadiusKm,
              min: 1.0,
              max: 15.0,
              divisions: 14,
              activeColor: const Color(0xFF0668E1),
              onChanged: (val) => setState(() => _dropPinRadiusKm = val),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('EXCLUDED LOCATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                Text('${_excludedAreas.length} Excluded', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _excludedAreas.map((ex) {
                return Chip(
                  avatar: const Icon(Icons.block, size: 14, color: Color(0xFFDC2626)),
                  label: Text(ex, style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                  backgroundColor: const Color(0xFFFEF2F2),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
                  onDeleted: () => setState(() => _excludedAreas.remove(ex)),
                );
              }).toList(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // DEMOGRAPHICS & DETAILED TARGETING
        _buildSectionCard(
          title: 'Demographics & Loan Interests',
          subtitle: 'Filter high-income professionals and borrowers needing personal or home financing',
          icon: Icons.person_search_rounded,
          children: [
            // Age Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Age Range:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('${_minAge.toInt()} - ${_maxAge.toInt()} years old', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0668E1))),
              ],
            ),
            RangeSlider(
              values: RangeValues(_minAge, _maxAge),
              min: 18.0,
              max: 65.0,
              divisions: 47,
              activeColor: const Color(0xFF0668E1),
              onChanged: (vals) {
                setState(() {
                  _minAge = vals.start;
                  _maxAge = vals.end;
                });
              },
            ),

            const SizedBox(height: 12),

            // Gender
            const Text('GENDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildGenderTile('ALL', 'All Genders'),
                const SizedBox(width: 8),
                _buildGenderTile('MEN', 'Men'),
                const SizedBox(width: 8),
                _buildGenderTile('WOMEN', 'Women'),
              ],
            ),

            const SizedBox(height: 16),

            // Detailed loan interests
            const Text('DETAILED TARGETING (FINANCE & LOAN PROFILES)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _availableInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  selectedColor: const Color(0xFFDBEAFE),
                  checkmarkColor: const Color(0xFF0668E1),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF334155),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? const Color(0xFF0668E1) : const Color(0xFFCBD5E1)),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 3: CREATIVE & PLACEMENTS
  // ===========================================================================
  Widget _buildStep3AdCreative() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Ad Placements',
          subtitle: 'Choose where your ads will appear across Meta family of apps',
          icon: Icons.devices_rounded,
          children: [
            RadioListTile<bool>(
              value: true,
              groupValue: _useAdvantagePlacements,
              title: const Text('Advantage+ Placements (Recommended)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('Maximize your budget by automatically showing ads to people most likely to apply for a loan across all FB & IG placements.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              activeColor: const Color(0xFF0668E1),
              onChanged: (val) => setState(() => _useAdvantagePlacements = true),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: _useAdvantagePlacements,
              title: const Text('Manual Placements', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('Manually select Facebook, Instagram, Feeds, or Reels', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              activeColor: const Color(0xFF0668E1),
              onChanged: (val) => setState(() => _useAdvantagePlacements = false),
            ),
            if (!_useAdvantagePlacements) ...[
              const Divider(),
              CheckboxListTile(
                title: const Text('Facebook Feeds & Stories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _placementFacebook,
                activeColor: const Color(0xFF0668E1),
                onChanged: (val) => setState(() => _placementFacebook = val ?? true),
              ),
              CheckboxListTile(
                title: const Text('Instagram Feeds, Stories & Reels', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _placementInstagram,
                activeColor: const Color(0xFF0668E1),
                onChanged: (val) => setState(() => _placementInstagram = val ?? true),
              ),
              CheckboxListTile(
                title: const Text('Messenger Inbox & Stories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _placementMessenger,
                activeColor: const Color(0xFF0668E1),
                onChanged: (val) => setState(() => _placementMessenger = val ?? true),
              ),
              CheckboxListTile(
                title: const Text('Audience Network (In-App Placements)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _placementAudienceNetwork,
                activeColor: const Color(0xFF0668E1),
                onChanged: (val) => setState(() => _placementAudienceNetwork = val ?? false),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Ad Identity & Loan Creative',
          subtitle: 'Craft the visual creative, primary copy, and call to action',
          icon: Icons.brush_rounded,
          children: [
            const Text('IDENTITY (FACEBOOK PAGE & INSTAGRAM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 14, backgroundColor: Color(0xFF0668E1), child: Icon(Icons.business, size: 14, color: Colors.white)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedPage, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(_selectedInstagram, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified, size: 16, color: Color(0xFF0668E1)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            const Text('AD FORMAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _adFormat = 'SINGLE_IMAGE'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _adFormat == 'SINGLE_IMAGE' ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _adFormat == 'SINGLE_IMAGE' ? const Color(0xFF0668E1) : const Color(0xFFE2E8F0),
                          width: _adFormat == 'SINGLE_IMAGE' ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Single Image / Video',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _adFormat == 'SINGLE_IMAGE' ? const Color(0xFF0668E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _adFormat = 'CAROUSEL'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _adFormat == 'CAROUSEL' ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _adFormat == 'CAROUSEL' ? const Color(0xFF0668E1) : const Color(0xFFE2E8F0),
                          width: _adFormat == 'CAROUSEL' ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Carousel Cards',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _adFormat == 'CAROUSEL' ? const Color(0xFF0668E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text('SELECT LOAN BANNER PRESET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_creativePresets.length, (idx) {
                  final preset = _creativePresets[idx];
                  final isSelected = _selectedCreativePresetIndex == idx;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCreativePresetIndex = idx;
                        _headlineController.text = '${preset["title"]} • Instant Sanction';
                      });
                    },
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: preset['gradient'] as List<Color>),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? Colors.amber : Colors.transparent, width: 2),
                        boxShadow: isSelected
                            ? [BoxShadow(color: (preset['gradient'][0] as Color).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(preset['icon'] as IconData, color: Colors.white, size: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
                                child: Text(preset['badge'] as String, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(preset['banner'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 16),

            const Text('PRIMARY TEXT (AD BODY)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: _primaryTextController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Describe the loan offer, interest rate, and requirements...'),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 14),

            const Text('HEADLINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: _headlineController,
              decoration: const InputDecoration(hintText: 'E.g. Check Loan Eligibility in 2 Mins'),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 14),

            const Text('CALL TO ACTION (CTA)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCta,
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
              items: const [
                DropdownMenuItem(value: 'APPLY_NOW', child: Text('Apply Now (Highest conversion for loans)')),
                DropdownMenuItem(value: 'GET_QUOTE', child: Text('Get Quote')),
                DropdownMenuItem(value: 'LEARN_MORE', child: Text('Learn More')),
                DropdownMenuItem(value: 'WHATSAPP', child: Text('Send WhatsApp Message')),
                DropdownMenuItem(value: 'CALL_NOW', child: Text('Call Now')),
              ],
              onChanged: (val) => setState(() => _selectedCta = val ?? 'APPLY_NOW'),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Instant Lead Form Builder',
          subtitle: 'The fields captured when a prospect taps your ad',
          icon: Icons.dynamic_form_rounded,
          children: [
            const Text('LEAD FORM QUESTIONS COLLECTED:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'Full Name',
                'Phone Number',
                'Email Address',
                'City & Pincode',
                'Desired Loan Amount',
                'Employment Type',
                'Monthly Salary / Turnover',
                'Existing EMIs',
              ].map((q) {
                final isSelected = _formQuestions.contains(q);
                return FilterChip(
                  label: Text(q),
                  selected: isSelected,
                  selectedColor: const Color(0xFFDCFCE7),
                  checkmarkColor: const Color(0xFF16A34A),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF15803D) : const Color(0xFF334155),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _formQuestions.add(q);
                      } else {
                        _formQuestions.remove(q);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 4: REVIEW & LIVE PREVIEW
  // ===========================================================================
  Widget _buildStep4ReviewAndPublish() {
    final activePreset = _creativePresets[_selectedCreativePresetIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Real-Time Estimated Daily Results Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Meta Estimated Daily Results', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(6)),
                    child: const Text('High Intent Pool', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCol('Estimated Reach', '$_estimatedDailyReach / day', Icons.people_outline),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _buildMetricCol('Estimated Leads', '$_estimatedDailyLeads leads / day', Icons.assignment_turned_in_outlined),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _buildMetricCol('Target Pool', '${(_estimatedAudienceSize / 100000).toStringAsFixed(1)}L People', Icons.gps_fixed),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Live Interactive Mockup Switcher
        _buildSectionCard(
          title: 'Live Ad Mockup Preview',
          subtitle: 'Interactive real-time preview of how your ad renders in Meta apps',
          icon: Icons.preview_rounded,
          children: [
            Row(
              children: [
                _buildPreviewTabPill('Facebook Feed', 'FACEBOOK_FEED'),
                const SizedBox(width: 6),
                _buildPreviewTabPill('Instagram Feed', 'INSTAGRAM_FEED'),
                const SizedBox(width: 6),
                _buildPreviewTabPill('Stories & Reels', 'INSTAGRAM_STORY'),
              ],
            ),
            const SizedBox(height: 14),

            // The Visual Feed Mockup
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mockup header
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFF0668E1),
                          child: Icon(Icons.account_balance, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPage,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              const Row(
                                children: [
                                  Text('Sponsored • ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  Icon(Icons.public, size: 11, color: AppTheme.textSecondary),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.more_horiz, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),

                  // Primary Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _primaryTextController.text,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Image / Banner Box
                  Container(
                    height: 180,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: activePreset['gradient'] as List<Color>),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
                          child: Text(activePreset['badge'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activePreset['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(activePreset['banner'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom CTA bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    color: const Color(0xFFF8FAFC),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ELIGIBLE.CO.IN', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.5)),
                              Text(
                                _headlineController.text,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0668E1),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(90, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {},
                          child: Text(_ctaLabel(_selectedCta), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Campaign Summary Review Card
        _buildSectionCard(
          title: 'Campaign Configuration Summary',
          subtitle: 'Verify your setup before launching on Meta Marketing API',
          icon: Icons.checklist_rounded,
          children: [
            _buildReviewRow('Campaign Name', _campaignNameController.text),
            _buildReviewRow('Special Category', _specialAdCategory == 'CREDIT' ? 'Credit / Loans (Declared)' : _specialAdCategory),
            _buildReviewRow('Objective', 'Leads (Meta Instant Forms & WhatsApp)'),
            _buildReviewRow('Daily Budget', '₹${_budgetController.text} / day ($_budgetType)'),
            _buildReviewRow('Bid Strategy', _bidStrategy == 'LOWEST_COST_WITHOUT_CAP' ? 'Highest Volume' : 'Cost Cap'),
            _buildReviewRow('Targeted Pincodes (${_targetedPincodes.length})', _targetedPincodes.join(', ')),
            _buildReviewRow('Targeted Areas (${_targetedAreas.length})', '${_targetedAreas.join(", ")} (${_dropPinRadiusKm.toInt()}km)'),
            _buildReviewRow('Excluded Locations (${_excludedAreas.length})', _excludedAreas.isEmpty ? 'None' : _excludedAreas.join(', ')),
            _buildReviewRow('Demographics', 'Age ${_minAge.toInt()}-${_maxAge.toInt()} • $_selectedGender'),
            _buildReviewRow('Placements', _useAdvantagePlacements ? 'Advantage+ (Automatic FB & IG)' : 'Manual Selection'),
            _buildReviewRow('Ad Format', _adFormat == 'SINGLE_IMAGE' ? 'Single Image / Video' : 'Carousel'),
            _buildReviewRow('Lead Questions (${_formQuestions.length})', _formQuestions.join(', ')),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM NAVIGATION BAR
  // ---------------------------------------------------------------------------
  Widget _buildBottomNavActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3))],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(90, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isPublishing ? null : () => setState(() => _currentStep--),
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentStep == 3 ? const Color(0xFF16A34A) : const Color(0xFF0668E1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isPublishing
                    ? null
                    : () {
                        if (_currentStep < 3) {
                          setState(() => _currentStep++);
                        } else {
                          _publishCampaign();
                        }
                      },
                icon: _isPublishing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_currentStep == 3 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  _isPublishing
                      ? 'Publishing to Meta Ads...'
                      : _currentStep == 3
                          ? 'Publish Campaign to Meta'
                          : 'Continue to Step ${_currentStep + 2}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isHighlight ? const Color(0xFF0668E1) : const Color(0xFFE2E8F0), width: isHighlight ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isHighlight ? const Color(0xFF0668E1) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: isHighlight ? Colors.white : const Color(0xFF0668E1), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildChoicePill(String label, String value, String current, Function(String) onSelect) {
    final isSelected = value == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0668E1),
      labelStyle: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF334155)),
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? const Color(0xFF0668E1) : const Color(0xFFCBD5E1)),
      onSelected: (_) => onSelect(value),
    );
  }

  Widget _buildObjectiveTile({
    required String key,
    required String title,
    required String description,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedObjective == key;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? const Color(0xFF0668E1) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
      ),
      child: RadioListTile<String>(
        value: key,
        groupValue: _selectedObjective,
        activeColor: const Color(0xFF0668E1),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            if (isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                child: const Text('RECOMMENDED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
              ),
          ],
        ),
        subtitle: Text(description, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        onChanged: (val) => setState(() => _selectedObjective = val ?? 'OUTCOME_LEADS'),
      ),
    );
  }

  Widget _buildDestinationTile(String key, String title, String subtitle) {
    final isSelected = _conversionLocation == key;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isSelected ? const Color(0xFF0668E1) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
      ),
      child: RadioListTile<String>(
        value: key,
        groupValue: _conversionLocation,
        activeColor: const Color(0xFF0668E1),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        onChanged: (val) => setState(() => _conversionLocation = val ?? 'ON_AD'),
      ),
    );
  }

  Widget _buildGenderTile(String key, String label) {
    final isSelected = _selectedGender == key;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF0668E1) : Colors.white,
          foregroundColor: isSelected ? Colors.white : const Color(0xFF334155),
          side: BorderSide(color: isSelected ? const Color(0xFF0668E1) : const Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => setState(() => _selectedGender = key),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildQuickPresetPill(String label, List<String> pincodes) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF0668E1), fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFEFF6FF),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
        onPressed: () {
          setState(() {
            for (final p in pincodes) {
              if (!_targetedPincodes.contains(p)) _targetedPincodes.add(p);
            }
          });
        },
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF60A5FA), size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildPreviewTabPill(String label, String key) {
    final isSelected = _previewPlatform == key;
    return Expanded(
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF0668E1),
        labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF334155)),
        backgroundColor: Colors.white,
        side: BorderSide(color: isSelected ? const Color(0xFF0668E1) : const Color(0xFFCBD5E1)),
        onSelected: (_) => setState(() => _previewPlatform = key),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  String _ctaLabel(String key) {
    switch (key) {
      case 'APPLY_NOW':
        return 'Apply Now';
      case 'GET_QUOTE':
        return 'Get Quote';
      case 'LEARN_MORE':
        return 'Learn More';
      case 'WHATSAPP':
        return 'WhatsApp';
      case 'CALL_NOW':
        return 'Call Now';
      default:
        return 'Apply Now';
    }
  }

  void _addPincode(String input) {
    final clean = input.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (clean.length == 6 && !_targetedPincodes.contains(clean)) {
      setState(() {
        _targetedPincodes.add(clean);
        _pincodeInputController.clear();
      });
    } else if (clean.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit Indian PIN code (e.g. 411038)'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _addArea(String input) {
    final clean = input.trim();
    if (clean.isNotEmpty && !_targetedAreas.contains(clean)) {
      setState(() {
        _targetedAreas.add(clean);
        _areaInputController.clear();
      });
    }
  }
}
