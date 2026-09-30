# Eligible CRM — Rapid Memory & Token-Saving Index

> **PURPOSE OF THIS FILE**: Read this file first to obtain complete context on data models, widget signatures, styling tokens, route maps, and active states across the entire repository without needing to read individual Dart files.

---

## 1. Quick File Map & Exports

| File | Status | Exports / Main Classes | Key Responsibilities |
|---|---|---|---|
| `lib/main.dart` | Complete | `EligibleCRMApp` | Entry point, sets `AppTheme.lightTheme`, sets `home: LoginScreen()`. |
| `lib/models/user.dart` | Complete | `UserModel`, `UserRole` | Role definitions (`administrator`, `salesExecutive`), demo accounts. |
| `lib/models/lead.dart` | Complete | `Lead`, `Activity`, `FollowUp`, `LeadStatus` | Pure Dart models with constructor parameters and `copyWith()`. |
| `lib/theme/app_theme.dart` | Complete | `AppTheme` | Static theme colors and `ThemeData lightTheme`. |
| `lib/services/auth_service.dart` | Complete | `AuthService` | Singleton: `login()`, `loginAs()`, `logout()`, `currentUser`. |
| `lib/widgets/app_bottom_navigation.dart` | Complete | `AppBottomNavigation` | 5-item Material 3 `NavigationBar`. Callback: `onChanged(int)`. |
| `lib/widgets/app_drawer.dart` | Complete | `AppDrawer` | Eligible CRM Navigation Drawer with role filtering & allotment link. |
| `lib/widgets/stat_card.dart` | Complete | `StatCard` | Metric tile: `title`, `value`, `change`, `icon`, optional compact sizes. |
| `lib/widgets/lead_card.dart` | Complete | `LeadCard` | Lead row with status/allotment badge, taps to `LeadDetailsScreen`. |
| `lib/screens/login_screen.dart` | Complete | `LoginScreen`, `_LoginScreenState` | Form auth + 3 quick 1-tap demo logins (Admin, Amit, Priya). |
| `lib/screens/dashboard_screen.dart` | Complete | `DashboardScreen`, `_DashboardScreenState` | Root stateful shell (holds `currentIndex` 0-4, `leads`, `visibleLeads` filter). |
| `lib/screens/lead_allotment_screen.dart` | Complete | `LeadAllotmentScreen` | Admin screen to distribute & allot leads to Sales Executives (individual & bulk). |
| `lib/screens/lead_screen.dart` | Complete | `LeadsScreen`, `_LeadsScreenState` | Leads list, search bar, role status banner, allotment shortcut. |
| `lib/screens/lead_detail.dart` | Complete | `LeadDetailsScreen`, `_LeadDetailsScreenState` | Profile, contact actions, status picker, Admin allotment dropdown. |
| `lib/screens/followups_screen.dart` | Complete | `FollowupsScreen`, `_FollowupsScreenState` | List of follow-ups partitioned into Today/Tomorrow, bottom sheet to add. |
| `lib/screens/analytics_screen.dart` | Complete | `AnalyticsScreen`, `_AnalyticsScreenState` | Summary cards, sales pipeline stage breakdown, conversion rates. |
| `lib/services/backend_service.dart` | Complete | `BackendService` | Singleton client for backend endpoints: Meta Ads creation, lead sync, Firestore data. |
| `lib/screens/campaigns_screen.dart` | Complete | `CampaignsScreen`, `_CampaignsScreenState` | Meta/IG ad campaigns with live sync & **"Create Meta Campaign"** launch modal. |
| `lib/screens/tasks_screen.dart` | Complete | `TasksScreen`, `_TasksScreenState` | CRM tasks filtered by All/Pending/Completed, FAB with Add Task modal. |
| `lib/screens/team_screen.dart` | Complete | `TeamScreen`, `_TeamScreenState` | Sales team listing with roles, delete item, FAB with Add Member modal. |
| `lib/screens/more_screen.dart` | Complete | `MoreScreen` | User profile card, Workspace (role-gated), Integrations Hub link, and Logout. |
| `lib/screens/add_lead_screen.dart` | Stub (0 B) | None | Placeholder for new lead creation form. |
| `lib/screens/notifications_screen.dart` | Stub (0 B) | None | Placeholder for notifications view. |
| `lib/screens/profile_screen.dart` | Stub (0 B) | None | Placeholder for user profile screen. |
| `lib/screens/integrations_screen.dart` | Complete | `IntegrationsScreen` | Meta Marketing API & Firebase Firestore connection monitor, webhook setup, and sync. |
| `backend/` | Complete | Node.js Express Backend | Meta Marketing API (Campaign/AdSet/Ad pipeline), Lead Webhooks & Firebase Admin SDK. |

---

## 2. Core Data Models

### User & Roles (`lib/models/user.dart`)
```dart
enum UserRole { administrator, salesExecutive }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String initial;

  bool get isAdmin => role == UserRole.administrator;
  bool get isSalesExecutive => role == UserRole.salesExecutive;
  String get roleDisplayName; // 'Administrator' or 'Sales Executive'

  // Pre-configured Accounts:
  static const UserModel admin = UserModel(id: 'U-001', name: 'Shantanu', email: 'admin@eligiblecrm.com', role: UserRole.administrator, initial: 'S');
  static const UserModel executiveAmit = UserModel(id: 'U-002', name: 'Amit Patil', email: 'amit@eligiblecrm.com', role: UserRole.salesExecutive, initial: 'A');
  static const UserModel executivePriya = UserModel(id: 'U-003', name: 'Priya Shah', email: 'priya@eligiblecrm.com', role: UserRole.salesExecutive, initial: 'P');
}
```

### Lead & Allotment (`lib/models/lead.dart`)
```dart
enum LeadStatus { newLead, contacted, qualified, converted, lost }

class Lead {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String source;      // 'Facebook', 'Instagram', 'Google Ads', 'Website'
  final String campaign;
  final String? ad;
  final LeadStatus status;
  final String assignedTo;  // Empty string '' = UNASSIGNED; or executive name e.g. 'Amit Patil'
  final DateTime createdAt;
  final String? avatarUrl;
  final String note;
  final List<Activity> activities;
  final List<FollowUp> followUps;

  Lead copyWith({...});     // Essential for lead allotment updates
}
```

---

## 3. Role-Based Access Control (RBAC) & Visibility Matrix

| Feature / Screen | Administrator (`Shantanu`) | Sales Executive (`Amit Patil` / `Priya Shah`) |
|---|---|---|
| **Leads Visibility** | Views ALL leads (Assigned + Unassigned) | Views ONLY leads allotted to their name (`lead.assignedTo == user.name`) |
| **Lead Allotment** | Full access to `LeadAllotmentScreen` (single & bulk allot) | Hidden & Restricted |
| **Allotment from Detail** | Can allot or reassign leads via dropdown | View-only assignee indicator |
| **Navigation Drawer** | Shows Lead Allotment, Team, Campaigns | Hides Admin tools; shows My Leads, Follow-ups, Tasks |
| **Dashboard Stats** | Reflects whole company + Unassigned count alert | Reflects personal allotted leads only |
| **More Screen Menu** | Shows Team, Campaigns, Lead Allotment | Hides Team, Campaigns, and Lead Allotment |

---

## 4. Key Component Signatures

| Widget | File | Constructor Parameters |
|---|---|---|
| `DashboardScreen` | `screens/dashboard_screen.dart` | `({Key? key, UserModel user = UserModel.admin})` |
| `LeadAllotmentScreen` | `screens/lead_allotment_screen.dart` | `({required List<Lead> leads, required Function(List<Lead>) onLeadsUpdated})` |
| `AppDrawer` | `widgets/app_drawer.dart` | `({required UserModel user, required int currentTabIndex, required Function(int) onTabSelected, required List<Lead> leads, required Function(List<Lead>) onLeadsUpdated})` |
| `LeadsScreen` | `screens/lead_screen.dart` | `({required List<Lead> leads, ValueChanged<int>? onNavigationChanged, UserModel? currentUser, Function(Lead)? onLeadUpdated, VoidCallback? onOpenAllotment})` |
| `LeadDetailsScreen` | `screens/lead_detail.dart` | `({required Lead lead, UserModel? currentUser, Function(Lead)? onLeadUpdated})` |
| `MoreScreen` | `screens/more_screen.dart` | `({UserModel user, List<Lead> leads, required Function(List<Lead>) onLeadsUpdated})` |
| `LeadCard` | `widgets/lead_card.dart` | `({required Lead lead, bool compact = false, UserModel? currentUser, Function(Lead)? onLeadUpdated})` |

---

## 5. Active Demo Datasets

1. **Users**:
   - `admin@eligiblecrm.com` (Administrator: Shantanu)
   - `amit@eligiblecrm.com` (Sales Executive: Amit Patil)
   - `priya@eligiblecrm.com` (Sales Executive: Priya Shah)
2. **Leads (`_demoLeads` in `dashboard_screen.dart`)**:
   - `L001` Rahul Sharma (Unassigned)
   - `L002` Priya Patil (Assigned to `Amit Patil`)
   - `L003` Aditya Kulkarni (Assigned to `Priya Shah`)
   - `L004` Sneha Joshi (Assigned to `Amit Patil`)
   - `L005` Akash More (Unassigned)
   - `L006` Vikram Deshmukh (Assigned to `Priya Shah`)
   - `L007` Ananya Verma (Unassigned)

---

## 6. Critical Agent Rules

1. **Never bypass `visibleLeads`**: In `DashboardScreen`, `visibleLeads` guarantees Sales Executives never see unassigned or other executives' leads.
2. **Preserve `onLeadUpdated` / `onLeadsUpdated` callbacks**: Propagate updates up to `DashboardScreen` state so all tabs and the drawer reflect new allotments immediately.
3. **Use `AppDrawer` for overflow navigation**: Do not add extra tabs to `AppBottomNavigation` (keep standard 5 tabs: Home, Leads, Follow-ups, Analytics, More).
