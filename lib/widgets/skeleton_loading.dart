import 'package:flutter/material.dart';

class SkeletonLoading extends StatefulWidget {
  final Widget child;

  const SkeletonLoading({
    super.key,
    required this.child,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final progress = _animation.value;
            // Shimmer gradient sliding from left to right
            return LinearGradient(
              begin: Alignment(-1.5 + (progress * 3.0), -0.3),
              end: Alignment(-0.5 + (progress * 3.0), 0.3),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFFFFFFF),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E7EB),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton for StatCard
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 80, height: 14, borderRadius: 4),
              SkeletonBox(width: 28, height: 28, borderRadius: 8),
            ],
          ),
          SkeletonBox(width: 50, height: 26, borderRadius: 6),
          SkeletonBox(width: 90, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Skeleton for LeadCard
class SkeletonLeadCard extends StatelessWidget {
  const SkeletonLeadCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonCircle(size: 42),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 130, height: 16, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBox(width: 90, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              SkeletonBox(width: 65, height: 24, borderRadius: 12),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(width: 95, height: 22, borderRadius: 6),
              SizedBox(width: 8),
              SkeletonBox(width: 75, height: 22, borderRadius: 6),
              SizedBox(width: 8),
              SkeletonBox(width: 85, height: 22, borderRadius: 6),
            ],
          ),
          SizedBox(height: 14),
          Divider(height: 1, color: Color(0xFFF3F4F6)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 110, height: 14, borderRadius: 4),
              SkeletonBox(width: 70, height: 14, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for FollowupCard
class SkeletonFollowupCard extends StatelessWidget {
  const SkeletonFollowupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 45, height: 45, borderRadius: 13),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 15, borderRadius: 4),
                SizedBox(height: 6),
                SkeletonBox(width: 180, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 55, height: 14, borderRadius: 4),
              SizedBox(height: 6),
              SkeletonBox(width: 35, height: 10, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full Dashboard Skeleton view
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoading(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // Banner skeleton
          const SkeletonBox(height: 140, borderRadius: 20),
          const SizedBox(height: 18),

          // Stat cards 2x2 grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              SkeletonStatCard(),
              SkeletonStatCard(),
              SkeletonStatCard(),
              SkeletonStatCard(),
            ],
          ),
          const SizedBox(height: 22),

          // Recent leads header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 120, height: 20, borderRadius: 4),
              SkeletonBox(width: 60, height: 16, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 14),

          // Recent lead cards
          const SkeletonLeadCard(),
          const SkeletonLeadCard(),
          const SkeletonLeadCard(),
        ],
      ),
    );
  }
}

/// Full Leads Screen Skeleton view
class LeadsScreenSkeleton extends StatelessWidget {
  const LeadsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoading(
      child: Column(
        children: [
          // Filter pills skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                SkeletonBox(width: 60, height: 32, borderRadius: 16),
                SizedBox(width: 8),
                SkeletonBox(width: 65, height: 32, borderRadius: 16),
                SizedBox(width: 8),
                SkeletonBox(width: 80, height: 32, borderRadius: 16),
                SizedBox(width: 8),
                SkeletonBox(width: 75, height: 32, borderRadius: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Lead cards list skeleton
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: const [
                SkeletonLeadCard(),
                SkeletonLeadCard(),
                SkeletonLeadCard(),
                SkeletonLeadCard(),
                SkeletonLeadCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full Followups Screen Skeleton view
class FollowupsScreenSkeleton extends StatelessWidget {
  const FollowupsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoading(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // 3 summary boxes
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 70, borderRadius: 15)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 70, borderRadius: 15)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 70, borderRadius: 15)),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 90, height: 18, borderRadius: 4),
          const SizedBox(height: 14),
          const SkeletonFollowupCard(),
          const SkeletonFollowupCard(),
          const SizedBox(height: 20),
          const SkeletonBox(width: 110, height: 18, borderRadius: 4),
          const SizedBox(height: 14),
          const SkeletonFollowupCard(),
          const SkeletonFollowupCard(),
        ],
      ),
    );
  }
}

/// Full Analytics Screen Skeleton view
class AnalyticsScreenSkeleton extends StatelessWidget {
  const AnalyticsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoading(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // 3 top metric cards
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 85, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 85, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 85, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 130, height: 18, borderRadius: 4),
          const SizedBox(height: 12),
          // 5 pipeline bars
          const SkeletonBox(height: 58, borderRadius: 16),
          const SizedBox(height: 10),
          const SkeletonBox(height: 58, borderRadius: 16),
          const SizedBox(height: 10),
          const SkeletonBox(height: 58, borderRadius: 16),
          const SizedBox(height: 10),
          const SkeletonBox(height: 58, borderRadius: 16),
          const SizedBox(height: 10),
          const SkeletonBox(height: 58, borderRadius: 16),
          const SizedBox(height: 24),
          const SkeletonBox(width: 150, height: 18, borderRadius: 4),
          const SizedBox(height: 12),
          const SkeletonBox(height: 95, borderRadius: 16),
        ],
      ),
    );
  }
}
