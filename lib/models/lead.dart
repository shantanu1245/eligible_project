enum LeadStatus {
  newLead,
  contacted,
  qualified,
  converted,
  lost,
}

class Lead {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String source;
  final String campaign;
  final String? ad;
  final LeadStatus status;
  final String assignedTo;
  final DateTime createdAt;
  final String? avatarUrl;
  final String note;
  final String? message;
  final List<Activity> activities;
  final List<FollowUp> followUps;

  // Loan Calculator Database Details
  final String? loanType;
  final double? requiredLoan;
  final double? estimatedLow;
  final double? estimatedHigh;
  final double? emi;
  final int? cibil;
  final String? city;
  final String? pincode;
  final double? salary;
  final double? monthlyIncome;
  final double? coApplicantIncome;
  final double? propertyCost;
  final String? propertyType;
  final String? propertyDocs;
  final String? applicantType;
  final double? annualTurnover;
  final double? monthlyProfit;
  final String? businessVintage;
  final String? businessType;
  final String? gstRegistered;
  final String? itrVintage;
  final String? premiseOwnership;
  final String? job;
  final double? experience;

  const Lead({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.source,
    required this.campaign,
    this.ad,
    required this.status,
    required this.assignedTo,
    required this.createdAt,
    this.avatarUrl,
    this.note = '',
    this.message,
    this.activities = const [],
    this.followUps = const [],
    this.loanType,
    this.requiredLoan,
    this.estimatedLow,
    this.estimatedHigh,
    this.emi,
    this.cibil,
    this.city,
    this.pincode,
    this.salary,
    this.monthlyIncome,
    this.coApplicantIncome,
    this.propertyCost,
    this.propertyType,
    this.propertyDocs,
    this.applicantType,
    this.annualTurnover,
    this.monthlyProfit,
    this.businessVintage,
    this.businessType,
    this.gstRegistered,
    this.itrVintage,
    this.premiseOwnership,
    this.job,
    this.experience,
  });

  /// Avatar initial; safe for empty names coming from the website/RTDB.
  String get initial {
    final n = name.trim();
    return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
  }

  /// Convenient helper to get WhatsApp / customer inquiry message or note
  String get displayMessage {
    if (message != null && message!.trim().isNotEmpty) return message!.trim();
    if (note.trim().isNotEmpty) return note.trim();
    return '';
  }

  /// Categorization based on loan type from website / Meta Ads
  String get categoryDisplay {
    final t = (loanType ?? '').toLowerCase().trim();
    if (t.contains('home')) return 'Home Loan';
    if (t.contains('business')) return 'Business Loan';
    if (t.contains('salary') || t.contains('personal')) return 'Personal / Salary Loan';
    if (t.contains('lap') || t.contains('mortgage') || t.contains('property')) return 'Loan Against Property';
    if (t.contains('education')) return 'Education Loan';
    if (t.contains('car') || t.contains('vehicle') || t.contains('auto')) return 'Vehicle Loan';

    final c = '$campaign $note'.toLowerCase();
    if (c.contains('home loan') || c.contains('home')) return 'Home Loan';
    if (c.contains('business loan') || c.contains('business')) return 'Business Loan';
    if (c.contains('personal loan') || c.contains('salary')) return 'Personal / Salary Loan';
    if (c.contains('doctor')) return 'Doctor Loan';

    return (loanType != null && loanType!.trim().isNotEmpty) ? loanType!.trim() : 'General Loan';
  }

  String get categoryKey {
    final c = categoryDisplay.toLowerCase();
    if (c.contains('home')) return 'home';
    if (c.contains('business')) return 'business';
    if (c.contains('salary') || c.contains('personal')) return 'salary';
    if (c.contains('property') || c.contains('lap')) return 'lap';
    return 'other';
  }

  Lead copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? source,
    String? campaign,
    String? ad,
    LeadStatus? status,
    String? assignedTo,
    DateTime? createdAt,
    String? avatarUrl,
    String? note,
    String? message,
    List<Activity>? activities,
    List<FollowUp>? followUps,
    String? loanType,
    double? requiredLoan,
    double? estimatedLow,
    double? estimatedHigh,
    double? emi,
    int? cibil,
    String? city,
    String? pincode,
    double? salary,
    double? monthlyIncome,
    double? coApplicantIncome,
    double? propertyCost,
    String? propertyType,
    String? propertyDocs,
    String? applicantType,
    double? annualTurnover,
    double? monthlyProfit,
    String? businessVintage,
    String? businessType,
    String? gstRegistered,
    String? itrVintage,
    String? premiseOwnership,
    String? job,
    double? experience,
  }) {
    return Lead(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      source: source ?? this.source,
      campaign: campaign ?? this.campaign,
      ad: ad ?? this.ad,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      note: note ?? this.note,
      message: message ?? this.message,
      activities: activities ?? this.activities,
      followUps: followUps ?? this.followUps,
      loanType: loanType ?? this.loanType,
      requiredLoan: requiredLoan ?? this.requiredLoan,
      estimatedLow: estimatedLow ?? this.estimatedLow,
      estimatedHigh: estimatedHigh ?? this.estimatedHigh,
      emi: emi ?? this.emi,
      cibil: cibil ?? this.cibil,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      salary: salary ?? this.salary,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      coApplicantIncome: coApplicantIncome ?? this.coApplicantIncome,
      propertyCost: propertyCost ?? this.propertyCost,
      propertyType: propertyType ?? this.propertyType,
      propertyDocs: propertyDocs ?? this.propertyDocs,
      applicantType: applicantType ?? this.applicantType,
      annualTurnover: annualTurnover ?? this.annualTurnover,
      monthlyProfit: monthlyProfit ?? this.monthlyProfit,
      businessVintage: businessVintage ?? this.businessVintage,
      businessType: businessType ?? this.businessType,
      gstRegistered: gstRegistered ?? this.gstRegistered,
      itrVintage: itrVintage ?? this.itrVintage,
      premiseOwnership: premiseOwnership ?? this.premiseOwnership,
      job: job ?? this.job,
      experience: experience ?? this.experience,
    );
  }

  factory Lead.fromJson(Map<String, dynamic> json) {
    LeadStatus parseStatus(dynamic val) {
      if (val == null) return LeadStatus.newLead;
      final str = val.toString().toLowerCase();
      if (str.contains('contacted')) return LeadStatus.contacted;
      if (str.contains('qualified')) return LeadStatus.qualified;
      if (str.contains('converted')) return LeadStatus.converted;
      if (str.contains('lost')) return LeadStatus.lost;
      return LeadStatus.newLead;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    // Determine clean loan type display string
    String? parsedLoanType = json['loanType']?.toString();
    if (parsedLoanType == null && json['requiredLoan'] != null) {
      parsedLoanType = 'salary';
    }
    final loanType = (parsedLoanType != null && parsedLoanType.trim().isNotEmpty)
        ? parsedLoanType.trim()
        : null;

    // Default source / campaign for Loan-Calculator leads
    final rawSource = json['source']?.toString();
    final defaultSource = loanType != null ? 'Loan Calculator' : 'Website';
    final source = (rawSource != null && rawSource.isNotEmpty) ? rawSource : defaultSource;

    final rawCampaign = json['campaign']?.toString();
    final defaultCampaign = loanType != null 
        ? '${loanType[0].toUpperCase()}${loanType.substring(1)} Loan Enquiry'
        : 'General Campaign';
    final campaign = (rawCampaign != null && rawCampaign.isNotEmpty) ? rawCampaign : defaultCampaign;

    final rawName = json['name']?.toString().trim() ?? '';

    return Lead(
      id: json['id']?.toString() ?? '',
      name: rawName.isNotEmpty ? rawName : 'Unnamed Lead',
      phone: json['mobile']?.toString() ?? json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      source: source,
      campaign: campaign,
      ad: json['ad']?.toString(),
      status: parseStatus(json['status']),
      assignedTo: json['assignedTo']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      avatarUrl: json['avatarUrl']?.toString(),
      note: json['note']?.toString() ?? json['message']?.toString() ?? '',
      message: json['message']?.toString() ?? json['whatsappMessage']?.toString() ?? json['note']?.toString(),
      activities: const [],
      followUps: const [],
      loanType: loanType,
      requiredLoan: parseDouble(json['requiredLoan']),
      estimatedLow: parseDouble(json['estimatedLow']),
      estimatedHigh: parseDouble(json['estimatedHigh']),
      emi: parseDouble(json['emi']),
      cibil: parseInt(json['cibil']),
      city: json['city']?.toString(),
      pincode: json['pincode']?.toString(),
      salary: parseDouble(json['salary']),
      monthlyIncome: parseDouble(json['monthlyIncome']),
      coApplicantIncome: parseDouble(json['coApplicantIncome']),
      propertyCost: parseDouble(json['propertyCost']),
      propertyType: json['propertyType']?.toString(),
      propertyDocs: json['propertyDocs']?.toString(),
      applicantType: json['applicantType']?.toString(),
      annualTurnover: parseDouble(json['annualTurnover']),
      monthlyProfit: parseDouble(json['monthlyProfit']),
      businessVintage: json['businessVintage']?.toString(),
      businessType: json['businessType']?.toString(),
      gstRegistered: json['gstRegistered']?.toString(),
      itrVintage: json['itrVintage']?.toString(),
      premiseOwnership: json['premiseOwnership']?.toString(),
      job: json['job']?.toString(),
      experience: parseDouble(json['experience']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'mobile': phone,
      'email': email,
      'source': source,
      'campaign': campaign,
      'ad': ad,
      'status': status.name,
      'assignedTo': assignedTo,
      'createdAt': createdAt.toIso8601String(),
      'avatarUrl': avatarUrl,
      'note': note,
      if (loanType != null) 'loanType': loanType,
      if (requiredLoan != null) 'requiredLoan': requiredLoan,
      if (estimatedLow != null) 'estimatedLow': estimatedLow,
      if (estimatedHigh != null) 'estimatedHigh': estimatedHigh,
      if (emi != null) 'emi': emi,
      if (cibil != null) 'cibil': cibil,
      if (city != null) 'city': city,
      if (pincode != null) 'pincode': pincode,
      if (salary != null) 'salary': salary,
      if (monthlyIncome != null) 'monthlyIncome': monthlyIncome,
      if (coApplicantIncome != null) 'coApplicantIncome': coApplicantIncome,
      if (propertyCost != null) 'propertyCost': propertyCost,
      if (propertyType != null) 'propertyType': propertyType,
      if (propertyDocs != null) 'propertyDocs': propertyDocs,
      if (applicantType != null) 'applicantType': applicantType,
      if (annualTurnover != null) 'annualTurnover': annualTurnover,
      if (monthlyProfit != null) 'monthlyProfit': monthlyProfit,
      if (businessVintage != null) 'businessVintage': businessVintage,
      if (businessType != null) 'businessType': businessType,
      if (gstRegistered != null) 'gstRegistered': gstRegistered,
      if (itrVintage != null) 'itrVintage': itrVintage,
      if (premiseOwnership != null) 'premiseOwnership': premiseOwnership,
      if (job != null) 'job': job,
      if (experience != null) 'experience': experience,
    };
  }
}

class Activity {
  final String id;
  final String type;
  final String description;
  final String user;
  final DateTime timestamp;
  final String? note;

  const Activity({
    required this.id,
    required this.type,
    required this.description,
    required this.user,
    required this.timestamp,
    this.note,
  });
}

class FollowUp {
  final String id;
  final String followupNumber;
  final String leadId;
  final String leadName;
  final String phone;
  final String category;
  final double? requiredAmount;
  final String remark;
  final DateTime dateTime;
  final List<String> pendingDocuments;
  final bool isOverdue;
  final bool isCompleted;

  const FollowUp({
    required this.id,
    String? followupNumber,
    this.leadId = '',
    required this.leadName,
    this.phone = '',
    this.category = 'General Loan',
    this.requiredAmount,
    String? remark,
    String? title,
    required this.dateTime,
    this.pendingDocuments = const [],
    this.isOverdue = false,
    this.isCompleted = false,
  })  : followupNumber = followupNumber ?? id,
        remark = remark ?? title ?? '';

  String get title => remark.isNotEmpty ? remark : 'Follow-up with $leadName';

  FollowUp copyWith({
    String? id,
    String? followupNumber,
    String? leadId,
    String? leadName,
    String? phone,
    String? category,
    double? requiredAmount,
    String? remark,
    DateTime? dateTime,
    List<String>? pendingDocuments,
    bool? isOverdue,
    bool? isCompleted,
  }) {
    return FollowUp(
      id: id ?? this.id,
      followupNumber: followupNumber ?? this.followupNumber,
      leadId: leadId ?? this.leadId,
      leadName: leadName ?? this.leadName,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      requiredAmount: requiredAmount ?? this.requiredAmount,
      remark: remark ?? this.remark,
      dateTime: dateTime ?? this.dateTime,
      pendingDocuments: pendingDocuments ?? this.pendingDocuments,
      isOverdue: isOverdue ?? this.isOverdue,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'followupNumber': followupNumber,
        'leadId': leadId,
        'leadName': leadName,
        'phone': phone,
        'category': category,
        'requiredAmount': requiredAmount,
        'remark': remark,
        'dateTime': dateTime.toIso8601String(),
        'pendingDocuments': pendingDocuments,
        'isOverdue': isOverdue,
        'isCompleted': isCompleted,
      };

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    return FollowUp(
      id: json['id']?.toString() ?? '',
      followupNumber: json['followupNumber']?.toString() ?? json['id']?.toString() ?? '',
      leadId: json['leadId']?.toString() ?? '',
      leadName: json['leadName']?.toString() ?? json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General Loan',
      requiredAmount: json['requiredAmount'] != null ? (json['requiredAmount'] as num).toDouble() : null,
      remark: json['remark']?.toString() ?? json['title']?.toString() ?? json['task']?.toString() ?? '',
      dateTime: json['dateTime'] != null ? DateTime.tryParse(json['dateTime'].toString()) ?? DateTime.now() : DateTime.now(),
      pendingDocuments: json['pendingDocuments'] is List ? List<String>.from(json['pendingDocuments']) : [],
      isOverdue: json['isOverdue'] == true,
      isCompleted: json['isCompleted'] == true,
    );
  }
}
