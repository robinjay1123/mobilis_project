part of '../admin_web_screen.dart';

extension AdminAnnouncementsTab on _AdminWebScreenState {
  Widget _buildAnnouncementsContent(bool isDark) {
    if (_isAnnouncementEditorOpen) {
      return _buildAnnouncementEditor(isDark);
    }
    return _buildAnnouncementsOverview(isDark);
  }

  Widget _buildAnnouncementsOverview(bool isDark) {
    final selectedAnnouncements =
        _announcements
            .where(
              (announcement) => isSameDay(
                _announcementDate(announcement),
                _announcementSelectedDay,
              ),
            )
            .toList()
          ..sort(
            (a, b) => _announcementDate(a).compareTo(_announcementDate(b)),
          );
    final statusCounts = <String, int>{
      'scheduled': 0,
      'active': 0,
      'completed': 0,
      'cancelled': 0,
    };
    for (final announcement in _announcements) {
      final status = _announcementStatus(announcement);
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF021F35) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: AppColors.primary,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Announcement Management',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Plan maintenance notices, system updates, and important announcements from one calendar.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openAnnouncementEditor,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add Announcement'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _buildAnnouncementSummaryBadge(
                      'Scheduled',
                      statusCounts['scheduled'] ?? 0,
                      const Color(0xFFF59E0B),
                      Icons.schedule_rounded,
                      isDark,
                    ),
                    _buildAnnouncementSummaryBadge(
                      'Active',
                      statusCounts['active'] ?? 0,
                      AppColors.success,
                      Icons.campaign_rounded,
                      isDark,
                    ),
                    _buildAnnouncementSummaryBadge(
                      'Completed',
                      statusCounts['completed'] ?? 0,
                      const Color(0xFF4EA5FF),
                      Icons.task_alt_rounded,
                      isDark,
                    ),
                    _buildAnnouncementSummaryBadge(
                      'Cancelled',
                      statusCounts['cancelled'] ?? 0,
                      AppColors.error,
                      Icons.cancel_outlined,
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final calendar = _buildAnnouncementCalendar(isDark);
              final dayList = _buildSelectedDayAnnouncements(
                selectedAnnouncements,
                isDark,
              );
              if (constraints.maxWidth < 1050) {
                return Column(
                  children: [calendar, const SizedBox(height: 20), dayList],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: calendar),
                    const SizedBox(width: 20),
                    Expanded(flex: 7, child: dayList),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementEditor(bool isDark) {
    const roles = ['all', 'renter', 'driver', 'partner', 'operator'];
    const types = ['maintenance', 'general', 'system_update', 'emergency'];
    final isEditing = _editingAnnouncement != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _isSendingAnnouncement
                    ? null
                    : _closeAnnouncementEditor,
                tooltip: 'Back to announcements',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? 'Edit Scheduled Announcement'
                          : 'Add Announcement',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      isEditing
                          ? 'Update the content or reschedule its publication time.'
                          : 'Create an announcement without cluttering the calendar view.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildCard(
            'Announcement Details',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _announcementTitleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: _announcementInputDecoration(
                    isDark,
                    label: 'Announcement Title',
                    hint: 'e.g. Scheduled Maintenance Notice',
                    icon: Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _announcementMessageController,
                  minLines: 4,
                  maxLines: 6,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: _announcementInputDecoration(
                    isDark,
                    label: 'Announcement Description / Message',
                    hint: 'Explain what users need to know...',
                    icon: Icons.notes_rounded,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _announcementType,
                        dropdownColor: isDark
                            ? AppColors.darkCard
                            : Colors.white,
                        decoration: _announcementInputDecoration(
                          isDark,
                          label: 'Announcement Type',
                          icon: Icons.category_rounded,
                        ),
                        items: types
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(_announcementTypeLabel(type)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _announcementType = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _announcementTargetRole,
                        dropdownColor: isDark
                            ? AppColors.darkCard
                            : Colors.white,
                        decoration: _announcementInputDecoration(
                          isDark,
                          label: 'Audience',
                          icon: Icons.groups_rounded,
                        ),
                        items: roles
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role == 'all'
                                      ? 'All users'
                                      : '${role[0].toUpperCase()}${role.substring(1)}s',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _announcementTargetRole = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Publication Schedule',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The announcement becomes active automatically at this exact date and time.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnnouncementSchedulePicker(
                        label: 'Scheduled Announcement Date',
                        value: DateFormat(
                          'MMMM d, yyyy',
                        ).format(_announcementScheduledAt),
                        icon: Icons.calendar_month_rounded,
                        onTap: _pickAnnouncementDate,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnnouncementSchedulePicker(
                        label: 'Scheduled Announcement Time',
                        value: DateFormat(
                          'h:mm a',
                        ).format(_announcementScheduledAt),
                        icon: Icons.schedule_rounded,
                        onTap: _pickAnnouncementTime,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Automatic publication: ${_formatAnnouncementDateTime(_announcementScheduledAt)}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _isSendingAnnouncement
                    ? null
                    : _closeAnnouncementEditor,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isSendingAnnouncement ? null : _saveAnnouncement,
                icon: _isSendingAnnouncement
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isEditing ? Icons.save_rounded : Icons.schedule_send,
                      ),
                label: Text(
                  _isSendingAnnouncement
                      ? 'Saving...'
                      : (isEditing
                            ? 'Save & Reschedule'
                            : 'Schedule Announcement'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCalendar(bool isDark) {
    return _buildCard(
      'Announcement Calendar',
      TableCalendar<Map<String, dynamic>>(
        firstDay: DateTime.now().subtract(const Duration(days: 365 * 3)),
        lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
        focusedDay: _announcementFocusedDay,
        selectedDayPredicate: (day) => isSameDay(day, _announcementSelectedDay),
        eventLoader: (day) => _announcements
            .where(
              (announcement) => isSameDay(_announcementDate(announcement), day),
            )
            .toList(),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _announcementSelectedDay = selectedDay;
            _announcementFocusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _announcementFocusedDay = focusedDay;
        },
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        rowHeight: 38,
        daysOfWeekHeight: 22,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          titleTextStyle: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade600,
            fontSize: 11,
          ),
          weekendStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade500,
            fontSize: 11,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          weekendTextStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey.shade700,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          markersMaxCount: 3,
          markerDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      isDark,
    );
  }

  Widget _buildSelectedDayAnnouncements(
    List<Map<String, dynamic>> announcements,
    bool isDark,
  ) {
    final dateLabel = DateFormat(
      'EEEE, MMMM d, yyyy',
    ).format(_announcementSelectedDay);
    return _buildCard(
      dateLabel,
      announcements.isEmpty
          ? SizedBox(
              height: 260,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      size: 46,
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No announcements on this date',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _openAnnouncementEditor,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Schedule one'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: announcements
                  .map(
                    (announcement) =>
                        _buildAnnouncementListCard(announcement, isDark),
                  )
                  .toList(),
            ),
      isDark,
    );
  }

  Widget _buildAnnouncementListCard(
    Map<String, dynamic> announcement,
    bool isDark,
  ) {
    final status = _announcementStatus(announcement);
    final type = announcement['announcement_type']?.toString() ?? 'general';
    final statusColor = _announcementStatusColor(status);
    final typeColor = _announcementTypeColor(type);
    final canEdit = status == 'scheduled';
    final canComplete = status == 'active';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _announcementTypeIcon(type),
                  color: typeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement['title']?.toString() ?? 'Announcement',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_announcementTypeLabel(type)} • ${_formatAnnouncementDateTime(_announcementDate(announcement))}',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _buildAnnouncementStatusBadge(status, statusColor),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Announcement actions',
                onSelected: (action) {
                  switch (action) {
                    case 'view':
                      _showAnnouncementDetails(announcement, isDark);
                      break;
                    case 'edit':
                      _openAnnouncementEditor(announcement);
                      break;
                    case 'cancel':
                      _cancelAnnouncement(announcement);
                      break;
                    case 'complete':
                      _completeAnnouncement(announcement);
                      break;
                    case 'delete':
                      _deleteAnnouncement(announcement);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View details'),
                  ),
                  if (canEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit / Reschedule'),
                    ),
                  if (canEdit)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel schedule'),
                    ),
                  if (canComplete)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark completed'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            announcement['message']?.toString() ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade800,
              height: 1.4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.groups_2_outlined,
                size: 15,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                _announcementAudienceLabel(
                  announcement['target_role']?.toString() ?? 'all',
                ),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementSummaryBadge(
    String label,
    int count,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Text(
            '$label  $count',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _announcementStatusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildAnnouncementSchedulePicker({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  InputDecoration _announcementInputDecoration(
    bool isDark, {
    required String label,
    String? hint,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(icon, size: 19),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey.shade700,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderColor : Colors.grey.shade300,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  DateTime _announcementDate(Map<String, dynamic> announcement) {
    for (final key in ['scheduled_at', 'published_at', 'created_at']) {
      final parsed = DateTime.tryParse(announcement[key]?.toString() ?? '');
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.now();
  }

  String _announcementStatus(Map<String, dynamic> announcement) {
    final status = announcement['status']?.toString().toLowerCase() ?? 'active';
    if (status == 'scheduled' &&
        !_announcementDate(announcement).isAfter(DateTime.now())) {
      return 'active';
    }
    return {'scheduled', 'active', 'completed', 'cancelled'}.contains(status)
        ? status
        : 'active';
  }

  String _announcementStatusLabel(String status) => switch (status) {
    'scheduled' => 'Scheduled',
    'active' => 'Active',
    'completed' => 'Completed / Expired',
    'cancelled' => 'Cancelled',
    _ => 'Active',
  };

  Color _announcementStatusColor(String status) => switch (status) {
    'scheduled' => const Color(0xFFF59E0B),
    'active' => AppColors.success,
    'completed' => const Color(0xFF4EA5FF),
    'cancelled' => AppColors.error,
    _ => AppColors.success,
  };

  String _announcementTypeLabel(String type) => switch (type) {
    'maintenance' => 'Maintenance',
    'system_update' => 'System Update',
    'emergency' => 'Emergency / Important Notice',
    _ => 'General Announcement',
  };

  Color _announcementTypeColor(String type) => switch (type) {
    'maintenance' => const Color(0xFFF59E0B),
    'system_update' => const Color(0xFF4EA5FF),
    'emergency' => AppColors.error,
    _ => AppColors.primary,
  };

  IconData _announcementTypeIcon(String type) => switch (type) {
    'maintenance' => Icons.build_circle_outlined,
    'system_update' => Icons.system_update_alt_rounded,
    'emergency' => Icons.warning_amber_rounded,
    _ => Icons.campaign_outlined,
  };

  String _announcementAudienceLabel(String role) {
    if (role == 'all') return 'All users';
    return '${role[0].toUpperCase()}${role.substring(1)}s';
  }

  String _formatAnnouncementDateTime(DateTime date) {
    return DateFormat('MMMM d, yyyy • h:mm a').format(date.toLocal());
  }

  void _showAnnouncementDetails(
    Map<String, dynamic> announcement,
    bool isDark,
  ) {
    final status = _announcementStatus(announcement);
    final type = announcement['announcement_type']?.toString() ?? 'general';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Row(
          children: [
            Icon(
              _announcementTypeIcon(type),
              color: _announcementTypeColor(type),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(announcement['title']?.toString() ?? 'Announcement'),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAnnouncementStatusBadge(
                    status,
                    _announcementStatusColor(status),
                  ),
                  Chip(label: Text(_announcementTypeLabel(type))),
                  Chip(
                    label: Text(
                      _announcementAudienceLabel(
                        announcement['target_role']?.toString() ?? 'all',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                announcement['message']?.toString() ?? '',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                '${status == 'scheduled' ? 'Scheduled' : 'Announcement date'}: ${_formatAnnouncementDateTime(_announcementDate(announcement))}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildOldSettingsContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          // 1. Appearance & Theme (Original Setting)
          _buildCard(
            'Appearance & Theme',
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toggle dark or light color palette for the admin portal',
                      style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Switch(
                  value: isDark,
                  onChanged: widget.onThemeToggle,
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 2. Rental Terms & Agreement (Original Setting)
          _buildCard(
            'Rental Terms & Agreement',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This text is shown to renters before they finalize a booking. Renters must check the agreement box before continuing.',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rentalTermsController,
                  minLines: 8,
                  maxLines: 14,
                  enabled: !_isLoadingTerms && !_isSavingTerms,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter rental terms and policies...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isLoadingTerms)
                      Text(
                        'Loading current terms...',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _isLoadingTerms || _isSavingTerms
                          ? null
                          : _loadRentalTerms,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoadingTerms || _isSavingTerms
                          ? null
                          : _saveRentalTerms,
                      icon: _isSavingTerms
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSavingTerms ? 'Saving...' : 'Save Terms'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 3. Privacy Policy
          _buildCard(
            'Privacy Policy',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This text is displayed in the Privacy Policy section for users and renters detailing data usage, identity verification policies, location tracking, and security.',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _privacyPolicyController,
                  minLines: 8,
                  maxLines: 14,
                  enabled: !_isLoadingPrivacy && !_isSavingPrivacy,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter privacy policy content...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isLoadingPrivacy)
                      Text(
                        'Loading privacy policy...',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _isLoadingPrivacy || _isSavingPrivacy
                          ? null
                          : _loadPrivacyPolicy,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoadingPrivacy || _isSavingPrivacy
                          ? null
                          : _savePrivacyPolicy,
                      icon: _isSavingPrivacy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSavingPrivacy ? 'Saving...' : 'Save Privacy Policy',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 3. Reservation Payment (Original Setting)
          _buildCard(
            'Reservation Payment',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure the refundable reservation payment shown to renters before booking requests are created.',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reservationAmountController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Reservation Amount (₱)',
                          hint: '1000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _reservationAccountNameController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Account Name',
                          hint: 'PSDC',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Security Deposit by Seater Capacity',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Automatically applied based on vehicle seat count (4–5 seaters vs 6+ seaters).',
                  style: TextStyle(
                    color: isDark ? Colors.grey : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _securityDeposit4to5Controller,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: '4–5 Seater Deposit (₱)',
                          hint: '2000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _securityDeposit6PlusController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: '6+ Seater Deposit (₱)',
                          hint: '3000',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Late Return Fee Settings
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lateFee4to5Controller,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Late Fee 4–5 Seaters (₱/hr)',
                          hint: '200',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _lateFee6PlusController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Late Fee 6+ Seaters (₱/hr)',
                          hint: '350',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _lateFeeDayCapHoursController,
                        enabled:
                            !_isLoadingReservationPayment &&
                            !_isSavingReservationPayment,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: _settingsInputDecoration(
                          isDark,
                          label: 'Late Daily Cap (Hours)',
                          hint: '6',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBg
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child:
                            _reservationQrUrlController.text.trim().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: OptimizedNetworkImage(
                                  imageUrl: _reservationQrUrlController.text
                                      .trim(),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                  errorWidget: const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.error,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.qr_code_2,
                                color: AppColors.textTertiary,
                                size: 42,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment QR Code',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reservationQrUrlController.text.trim().isEmpty
                                  ? 'No QR uploaded yet.'
                                  : 'QR uploaded. Renters will see this after settings are saved.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      _isLoadingReservationPayment ||
                                          _isSavingReservationPayment ||
                                          _isUploadingReservationQr ||
                                          _isDeletingReservationQr
                                      ? null
                                      : _uploadReservationPaymentQr,
                                  icon: _isUploadingReservationQr
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file),
                                  label: Text(
                                    _isUploadingReservationQr
                                        ? 'Uploading...'
                                        : _reservationQrUrlController.text
                                              .trim()
                                              .isEmpty
                                        ? 'Upload QR Image'
                                        : 'Replace QR Image',
                                  ),
                                ),
                                if (_reservationQrUrlController.text
                                    .trim()
                                    .isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isLoadingReservationPayment ||
                                            _isSavingReservationPayment ||
                                            _isUploadingReservationQr ||
                                            _isDeletingReservationQr
                                        ? null
                                        : _deleteReservationPaymentQr,
                                    icon: _isDeletingReservationQr
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.delete_outline),
                                    label: Text(
                                      _isDeletingReservationQr
                                          ? 'Deleting...'
                                          : 'Delete QR',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _reservationInstructionsController,
                  minLines: 3,
                  maxLines: 5,
                  enabled:
                      !_isLoadingReservationPayment &&
                      !_isSavingReservationPayment,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                  decoration: _settingsInputDecoration(
                    isDark,
                    label: 'Payment Instructions',
                    hint: 'Tell renters how to pay and upload proof...',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isLoadingReservationPayment)
                      Text(
                        'Loading payment settings...',
                        style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed:
                          _isLoadingReservationPayment ||
                              _isSavingReservationPayment ||
                              _isUploadingReservationQr ||
                              _isDeletingReservationQr
                          ? null
                          : _loadReservationPaymentSettings,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed:
                          _isLoadingReservationPayment ||
                              _isSavingReservationPayment ||
                              _isUploadingReservationQr ||
                              _isDeletingReservationQr
                          ? null
                          : _saveReservationPaymentSettings,
                      icon: _isSavingReservationPayment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSavingReservationPayment
                            ? 'Saving...'
                            : 'Save Payment Settings',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 4. Customer Support FAQ Auto-Replies (Original Setting)
          _buildCard(
            'Customer Support FAQ Auto-Replies',
            _buildSupportFaqEditor(isDark),
            isDark,
          ),
          const SizedBox(height: 20),

          // 5. Admin Profile & Identity (Essential Setting)
          _buildCard(
            'Admin Profile & Identity',
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _supabase.auth.currentUser?.email ??
                            'Super Administrator',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Super Admin',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Full System Access',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 6. Workflow & Operating Rules (Essential Setting)
          _buildCard(
            'Workflow & Operating Rules',
            Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'System Online / Active',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'When active, new booking requests and registrations can be processed normally.',
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'Auto-Accept Partner Verification Requests',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Requires manual review if turned off.',
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  value: false,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 7. Operational Alerts & Notifications (Essential Setting)
          _buildCard(
            'Operational Alerts & Notifications',
            Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'New Verification Requests Alert',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
                SwitchListTile(
                  title: Text(
                    'Booking Cancellation & Refund Alerts',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: true,
                  onChanged: (val) {},
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 8. Account & Security (Essential Setting)
          _buildCard(
            'Account & Security',
            ListTile(
              leading: const Icon(Icons.lock_reset, color: AppColors.primary),
              title: Text(
                'Change Password',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Update your administrator portal password',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password change email link sent to your administrator address.',
                    ),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 9. Ratings, Reviews & System Legal (Essential Setting)
          _buildCard(
            'Ratings, Reviews & System Legal',
            ListTile(
              leading: const Icon(
                Icons.star_rate_rounded,
                color: AppColors.warning,
              ),
              title: Text(
                'View All Ratings & Renter Reviews',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Inspect trip reviews, ratings, and customer feedback across all bookings.',
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RatingsReviewsScreen(
                      userId: _supabase.auth.currentUser?.id ?? '',
                      title: 'Ratings & Reviews',
                    ),
                  ),
                );
              },
            ),
            isDark,
          ),
          const SizedBox(height: 20),

          // 10. Account Sign Out (Original Setting)
          _buildCard(
            'Account',
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out Admin',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _handleLogout,
            ),
            isDark,
          ),
        ],
      ),
    );
  }
}
