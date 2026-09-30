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

    return Lead(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Lead',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Meta Ads',
      campaign: json['campaign']?.toString() ?? 'General Campaign',
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'source': source,
      'campaign': campaign,
      'ad': ad,
      'status': status.name,
      'assignedTo': assignedTo,
      'createdAt': createdAt.toIso8601String(),
      'avatarUrl': avatarUrl,
      'note': note,
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
