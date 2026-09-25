import 'package:flutter/material.dart';
import '../screens/login_screen.dart';

class DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      const _SidebarItem(
        icon: Icons.dashboard_outlined,
        title: 'Dashboard',
      ),
      const _SidebarItem(
        icon: Icons.medication_outlined,
        title: 'Medicines',
      ),
      const _SidebarItem(
        icon: Icons.inventory_2_outlined,
        title: 'Inventory',
      ),
      const _SidebarItem(
        icon: Icons.point_of_sale_outlined,
        title: 'Sales',
      ),
      const _SidebarItem(
        icon: Icons.receipt_long_outlined,
        title: 'Invoices',
      ),
      const _SidebarItem(
        icon: Icons.analytics_outlined,
        title: 'Reports',
      ),
    ];

    return Container(
      width: 245,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 26),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_outlined,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 11),

                const Text(
                  'New Medico',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                final selected = selectedIndex == index;

                return GestureDetector(
                  onTap: () => onItemSelected(index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: selected
                              ? Colors.white
                              : Colors.white60,
                          size: 21,
                        ),
                        const SizedBox(width: 13),
                        Text(
                          item.title,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.logout_outlined,
                      color: Colors.white70,
                      size: 21,
                    ),
                    SizedBox(width: 13),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String title;

  const _SidebarItem({
    required this.icon,
    required this.title,
  });
}