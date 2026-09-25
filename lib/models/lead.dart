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
