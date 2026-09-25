import '../models/lead.dart';

class MockLeads {
  static final List<Lead> all = [
    Lead(
      id: 'L-1001',
      name: 'Rahul Sharma',
      phone: '+91 98765 43210',
      email: 'rahul@example.com',
      source: 'Facebook',
      campaign: 'Summer Campaign',
      status: LeadStatus.newLead,
      createdAt: DateTime(2026, 9, 22, 10, 30),
      note: 'Interested in premium package.', assignedTo: '',
    ),

    Lead(
      id: 'L-1002',
      name: 'Priya Patil',
      phone: '+91 98220 12345',
      email: 'priya@example.com',
      source: 'Instagram',
      campaign: 'Instagram Leads',
      status: LeadStatus.contacted,
      createdAt: DateTime(2026, 9, 22, 9, 15),
      note: 'Requested pricing details.', assignedTo: '',
    ),

    Lead(
      id: 'L-1003',
      name: 'Amit Joshi',
      phone: '+91 97654 76543',
      email: 'amit@example.com',
      source: 'Facebook',
      campaign: 'Product Campaign',
      status: LeadStatus.qualified,
      createdAt: DateTime(2026, 9, 21, 17, 40),
      note: 'Demo scheduled.', assignedTo: '',
    ),

    Lead(
      id: 'L-1004',
      name: 'Sneha Kulkarni',
      phone: '+91 98901 34567',
      email: 'sneha@example.com',
      source: 'Instagram',
      campaign: 'Brand Awareness',
      status: LeadStatus.converted,
      createdAt: DateTime(2026, 9, 21, 15, 20),
      note: 'Converted successfully.', assignedTo: '',
    ),

    Lead(
      id: 'L-1005',
      name: 'Vikas More',
      phone: '+91 98123 56789',
      email: 'vikas@example.com',
      source: 'Facebook',
      campaign: 'Lead Generation',
      status: LeadStatus.newLead,
      createdAt: DateTime(2026, 9, 21, 12, 10),
      note: 'Needs follow-up.', assignedTo: '',
    ),

    Lead(
      id: 'L-1006',
      name: 'Neha Deshmukh',
      phone: '+91 99345 67890',
      email: 'neha@example.com',
      source: 'Instagram',
      campaign: 'September Campaign',
      status: LeadStatus.lost,
      createdAt: DateTime(2026, 9, 20, 11, 30),
      note: 'Not interested currently.', assignedTo: '',
    ),
  ];
}