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

    // Default source / campaign for Loan-Calculator leads
    final rawSource = json['source']?.toString();
    final defaultSource = parsedLoanType != null ? 'Loan Calculator' : 'Website';
    final source = (rawSource != null && rawSource.isNotEmpty) ? rawSource : defaultSource;

    final rawCampaign = json['campaign']?.toString();
    final defaultCampaign = parsedLoanType != null 
        ? '${parsedLoanType[0].toUpperCase()}${parsedLoanType.substring(1)} Loan Enquiry'
        : 'General Campaign';
    final campaign = (rawCampaign != null && rawCampaign.isNotEmpty) ? rawCampaign : defaultCampaign;

    return Lead(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Lead',
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
      note: json['note']?.toString() ?? '',
      activities: const [],
      followUps: const [],
      loanType: parsedLoanType,
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
  final String leadName;
  final String title;
  final DateTime dateTime;
  final bool isOverdue;

  const FollowUp({
    required this.id,
    required this.leadName,
    required this.title,
    required this.dateTime,
    this.isOverdue = false,
  });
}
