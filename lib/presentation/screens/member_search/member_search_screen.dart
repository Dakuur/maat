import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fitness_class.dart';
import '../../../presentation/providers/checkin_provider.dart';
import '../../../presentation/providers/class_provider.dart';
import '../../../presentation/widgets/member_list_tile.dart';

class MemberSearchScreen extends StatefulWidget {
  const MemberSearchScreen({super.key, required this.fitnessClass});

  final FitnessClass fitnessClass;

  @override
  State<MemberSearchScreen> createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checkin = context.read<CheckInProvider>();
      checkin.loadMembers();
      // Always reset search so stale queries don't persist across visits.
      checkin.filterMembers('');
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckInProvider>();
    final checkedInIds = context.watch<ClassProvider>().checkedInMemberIds;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Select Member'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name…',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          context.read<CheckInProvider>().filterMembers('');
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() {}); // refresh suffix icon
                context.read<CheckInProvider>().filterMembers(v);
              },
            ),
          ),

          // ── Member list / states ───────────────────────────────────────
          Expanded(
            child: !provider.membersLoaded
                ? const Center(child: CircularProgressIndicator())
                : provider.filteredMembers.isEmpty
                    ? _NoResults(query: _controller.text)
                    : ListView.builder(
                        itemCount: provider.filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = provider.filteredMembers[index];
                          return MemberListTile(
                            member: member,
                            isCheckedIn: checkedInIds.contains(member.id),
                            onTap: () {
                              provider.selectMember(member);
                              Navigator.of(context).pushNamed(
                                AppRouter.checkinConfirm,
                                arguments: {
                                  'member': member,
                                  'fitnessClass': widget.fitnessClass,
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No members found',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              query.isNotEmpty
                  ? 'No results for "$query".\nTry a different name.'
                  : 'No members registered yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
