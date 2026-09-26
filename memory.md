# LeadFlow CRM — Rapid Memory & Token-Saving Index

> **PURPOSE OF THIS FILE**: Read this file first to obtain complete context on data models, widget signatures, styling tokens, route maps, and active states across the entire repository without needing to read individual Dart files.

---

## 1. Quick File Map & Exports

| File | Status | Lines | Exports / Main Classes | Key Responsibilities |
|---|---|---|---|---|
| `lib/main.dart` | Complete | 24 | `LeadFlowCRM` | Entry point, sets `AppTheme.lightTheme`, sets `home: LoginScreen()`. |
| `lib/models/lead.dart` | Complete | 76 | `Lead`, `Activity`, `FollowUp`, `LeadStatus` | Pure Dart models with constructor parameters. |
| `lib/theme/app_theme.dart` | Complete | 82 | `AppTheme` | Static theme colors and `ThemeData lightTheme`. |
| `lib/data/mock_leads.dart` | Unused | 77 | `MockLeads` | Static list `MockLeads.all` (6 leads). Currently not referenced. |
| `lib/services/auth_service.dart` | Unused | 25 | `AuthService` | Async mock `login()` & `logout()`. Currently not called in `LoginScreen`. |
| `lib/widgets/app_bottom_navigation.dart` | Complete | 89 | `AppBottomNavigation` | 5-item Material 3 `NavigationBar`. Callback: `onChanged(int)`. |
| `lib/widgets/stat_card.dart` | Complete | 78 | `StatCard` | Metric tile: `title`, `value`, `change`, `icon`, optional compact sizes. |
| `lib/widgets/lead_card.dart` | Complete | 266 | `LeadCard` | Lead row with avatar, status badge, phone/email, taps to `LeadDetailsScreen`. |
| `lib/widgets/app_drawer.dart` | Legacy | 188 | `DashboardSidebar` | Unused pharmacy prototype sidebar. Safe to ignore or refactor. |
| `lib/screens/login_screen.dart` | Complete | 346 | `LoginScreen`, `_LoginScreenState` | Form with email & password validation, mock delay, routes to `DashboardScreen`. |
| `lib/screens/dashboard_screen.dart` | Complete | 963 | `DashboardScreen`, `_DashboardScreenState` | Root stateful shell (holds `currentIndex` 0-4 and internal `_demoLeads` array). |
| `lib/screens/lead_screen.dart` | Complete | 326 | `LeadsScreen`, `_LeadsScreenState` | Search bar, status chips filter, renders `LeadCard` list. |
| `lib/screens/lead_detail.dart` | Complete | 549 | `LeadDetailsScreen`, `_LeadDetailsScreenState` | Shows lead profile, contact buttons, status update picker, activity & notes. |
| `lib/screens/followups_screen.dart` | Complete | 439 | `FollowupsScreen`, `_FollowupsScreenState` | List of follow-ups partitioned into Today/Tomorrow, bottom sheet to add. |
| `lib/screens/analytics_screen.dart` | Complete | 275 | `AnalyticsScreen`, `_AnalyticsScreenState` | Summary cards, sales pipeline stage breakdown, conversion rates. |
| `lib/screens/campaigns_screen.dart` | Complete | 366 | `CampaignsScreen`, `_CampaignsScreenState` | Meta/IG ad campaigns with spend, budget, lead metrics. |
| `lib/screens/tasks_screen.dart` | Complete | 664 | `TasksScreen`, `_TasksScreenState` | CRM tasks filtered by All/Pending/Completed, FAB with Add Task modal. |
| `lib/screens/team_screen.dart` | Complete | 387 | `TeamScreen`, `_TeamScreenState` | Sales team listing with roles, delete item, FAB with Add Member modal. |
| `lib/screens/more_screen.dart` | Complete | 463 | `MoreScreen` | Menu for Workspace, Integrations, Account, Data, and Logout. |
| `lib/screens/add_lead_screen.dart` | Stub | 0 | None (Empty 0-byte file) | Placeholder for new lead creation form. |
| `lib/screens/notifications_screen.dart` | Stub | 0 | None (Empty 0-byte file) | Placeholder for notifications view. |
| `lib/screens/profile_screen.dart` | Stub | 0 | None (Empty 0-byte file) | Placeholder for user profile screen. |
| `lib/screens/integrations_screen.dart` | Stub | 0 | None (Empty 0-byte file) | Placeholder for integrations configuration. |

---

## 2. Core Data Models (`lib/models/lead.dart`)

```dart
enum LeadStatus {
  newLead,    // Color: 0xFF2563EB (Blue)
  contacted,  // Color: 0xFFEA580C (Orange)
  qualified,  // Color: 0xFF16A34A (Green)
  converted,  // Color: 0xFF0F766E (Teal)
  lost,       // Color: 0xFFDC2626 (Red)
}

class Lead {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String source;      // e.g., 'Facebook', 'Instagram', 'Website'
  final String campaign;    // e.g., 'Summer Campaign'
  final String? ad;
  final LeadStatus status;
  final String assignedTo;  // e.g., 'Shantanu', 'Amit'
  final DateTime createdAt;
  final String? avatarUrl;
  final String note;
  final List<Activity> activities;
  final List<FollowUp> followUps;
}

class Activity {
  final String id;
  final String type;
  final String description;
  final String user;
  final DateTime timestamp;
  final String? note;
}

class FollowUp {
  final String id;
  final String leadName;
  final String title;
  final DateTime dateTime;
  final bool isOverdue;
}
```

---

## 3. Design Tokens & Styling (`lib/theme/app_theme.dart`)

```dart
// Palette
AppTheme.primary       = Color(0xFF2563EB)  // Primary Blue
AppTheme.primaryDark   = Color(0xFF1D4ED8)  // Dark Blue
AppTheme.background    = Color(0xFFF8FAFC)  // Background Slate 50
AppTheme.surface       = Colors.white       // Surface Card White
AppTheme.textPrimary   = Color(0xFF0F172A)  // Slate 900
AppTheme.textSecondary = Color(0xFF64748B)  // Slate 500
AppTheme.border        = Color(0xFFE2E8F0)  // Slate 200

// Standard Card Decoration
BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppTheme.border),
)

// Standard Input Field Border
OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: BorderSide(color: AppTheme.border),
)
```

---

## 4. Key Component Signatures

| Widget | File | Constructor & Required Parameters |
|---|---|---|
| `AppBottomNavigation` | `widgets/app_bottom_navigation.dart` | `({required int currentIndex, required ValueChanged<int> onChanged})` |
| `StatCard` | `widgets/stat_card.dart` | `({required String title, required String value, required String change, required IconData icon, double? compactPadding, double? compactIconSize, double? compactValueSize})` |
| `LeadCard` | `widgets/lead_card.dart` | `({required Lead lead, bool compact = false})` |
| `LeadsScreen` | `screens/lead_screen.dart` | `({required List<Lead> leads, ValueChanged<int>? onNavigationChanged})` |
| `LeadDetailsScreen` | `screens/lead_detail.dart` | `({required Lead lead})` |

---

## 5. Active Mock Data State

1. **Active Leads List**: Located inside `lib/screens/dashboard_screen.dart` (`_demoLeads`, 5 items: `L001` Rahul Sharma, `L002` Priya Patil, `L003` Aditya Kulkarni, `L004` Sneha Joshi, `L005` Akash More).
2. **Follow-ups List**: Stored in `FollowupsScreenState.followups` (4 items: Call, Task, Meeting).
3. **Tasks List**: Stored in `TasksScreenState._tasks` (3 items with High/Medium/Low priority, Pending/Completed).
4. **Team Members**: Stored in `TeamScreenState._members` (3 members: Shantanu [Admin], Amit Patil [Sales], Priya Shah [Sales]).
5. **Campaigns**: Stored in `CampaignsScreenState._campaigns` (3 campaigns: Pune Property, Mumbai Property, Website Lead).

---

## 6. Critical Agent Rules & Gotchas

1. **Do not re-read all screen files**: Refer to the table in Section 1 or this summary when modifying navigation or widgets.
2. **Do not modify `app_drawer.dart` thinking it's the CRM drawer**: It contains legacy pharmacy demo code; the CRM uses `AppBottomNavigation`.
3. **Watch out for 0-byte stub files**: If wiring up navigation to Add Lead, Notifications, Profile, or Integrations, you must implement the screen widget first as the files are currently empty.
4. **Always preserve `AppTheme` colors**: Do not hardcode random hex colors; use `AppTheme.primary`, `AppTheme.border`, etc., or matching slate tones (`0xFFF8FAFC`, `0xFFE2E8F0`).
5. **Keep navigation consistent**:
   - Tab switching: Handled via `_handleNavigation(int index)` in `DashboardScreen`.
   - Stack pushes: `Navigator.push(context, MaterialPageRoute(builder: (_) => const TargetScreen()))`.
