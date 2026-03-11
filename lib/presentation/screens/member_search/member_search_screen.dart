import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/checked_in_person.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/fitness_class.dart';
import '../../../presentation/providers/checkin_provider.dart';
import '../../../presentation/providers/class_provider.dart';
import '../../../presentation/widgets/kiosk_button.dart';
import '../../../presentation/widgets/member_list_tile.dart';

class MemberSearchScreen extends StatefulWidget {
  const MemberSearchScreen({super.key, required this.fitnessClass});

  final FitnessClass fitnessClass;

  @override
  State<MemberSearchScreen> createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final _controller = TextEditingController();

  // ── Multi-select state ─────────────────────────────────────────────────────
  bool _multiSelectMode = false;
  final Set<String> _selectedMemberIds = {};

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

  // ── Multi-select helpers ───────────────────────────────────────────────────

  void _enterMultiSelect(String memberId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _multiSelectMode = true;
      _selectedMemberIds.add(memberId);
    });
  }

  void _toggleMember(String memberId) {
    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
        if (_selectedMemberIds.isEmpty) _multiSelectMode = false;
      } else {
        _selectedMemberIds.add(memberId);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedMemberIds.clear();
    });
  }

  Future<bool> _confirmOverCapacity(int count, int maxCapacity) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Full class'),
        content: Text(
          'Are you sure you want to enroll $count student${count == 1 ? '' : 's'} in this class? '
          'It will exceed the limit of $maxCapacity students.',
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Yes, I have permission'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _checkInSelected() async {
    final provider = context.read<CheckInProvider>();
    final selected = provider.filteredMembers
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();
    if (selected.isEmpty) return;

    // Get live class data for an accurate capacity check.
    final allClasses = context.read<ClassProvider>().todaysClasses;
    final liveClass = allClasses.isEmpty
        ? widget.fitnessClass
        : allClasses.firstWhere(
            (c) => c.id == widget.fitnessClass.id,
            orElse: () => widget.fitnessClass,
          );

    // Count only members NOT already checked in to avoid false positives.
    final checkedInIds = context.read<ClassProvider>().checkedInMemberIds;
    final newCount =
        selected.where((m) => !checkedInIds.contains(m.id)).length;

    if (newCount > 0 &&
        liveClass.attendeeCount + newCount > liveClass.maxCapacity) {
      final ok = await _confirmOverCapacity(newCount, liveClass.maxCapacity);
      if (!ok || !mounted) return;
    }

    final result = await provider.bulkCheckIn(
      members: selected,
      fitnessClass: widget.fitnessClass,
    );

    _exitMultiSelect();
    if (!mounted) return;

    if (result.ok > 0) {
      // Navigate to the success screen showing all newly checked-in members.
      // We use pushNamedAndRemoveUntil so Back leads straight to Home.
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.success,
        (route) => route.settings.name == AppRouter.home,
        arguments: {
          'people': selected
              .map((m) => CheckedInPerson(
                    name: m.fullName,
                    photoUrl: m.profilePicture,
                  ))
              .toList(),
          'fitnessClass': widget.fitnessClass,
        },
      );
    } else {
      // All were already registered — just show a snack.
      final parts = [
        if (result.alreadyIn > 0) '${result.alreadyIn} already registered',
        if (result.failed > 0) '${result.failed} failed',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parts.join(' · ')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckInProvider>();
    final checkedInIds = context.watch<ClassProvider>().checkedInMemberIds;
    final isLoading = provider.state == CheckInState.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        leading: _multiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitMultiSelect,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: _multiSelectMode
            ? Text('${_selectedMemberIds.length} selected')
            : const Text('Select Member'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      bottomNavigationBar: _multiSelectMode && _selectedMemberIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: KioskButton(
                  label: 'Check In ${_selectedMemberIds.length} '
                      '${_selectedMemberIds.length == 1 ? 'Member' : 'Members'}',
                  icon: Icons.how_to_reg_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _checkInSelected,
                ),
              ),
            )
          : null,
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
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary),
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

          // ── Multi-select hint ──────────────────────────────────────────
          // Always rendered (never conditional) to prevent layout shifts.
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Hold a member to select multiple',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),

          // ── Member list / states ───────────────────────────────────────
          Expanded(
            child: !provider.membersLoaded
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () =>
                        context.read<CheckInProvider>().loadMembers(force: true),
                    child: Builder(
                      builder: (context) {
                        // Hide members already enrolled in this class so the
                        // instructor can't accidentally register them twice.
                        final visibleMembers = provider.filteredMembers
                            .where((m) => !checkedInIds.contains(m.id))
                            .toList();

                        if (visibleMembers.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [_NoResults(query: _controller.text)],
                          );
                        }

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: visibleMembers.length,
                          itemBuilder: (context, index) {
                            final member = visibleMembers[index];
                            final isSelected =
                                _selectedMemberIds.contains(member.id);
                            return MemberListTile(
                              member: member,
                              isSelected: isSelected,
                              inMultiSelectMode: _multiSelectMode,
                              onLongPress: _multiSelectMode
                                  ? null
                                  : () => _enterMultiSelect(member.id),
                              onTap: () {
                                if (_multiSelectMode) {
                                  _toggleMember(member.id);
                                  return;
                                }
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
                        );
                      },
                    ),
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
