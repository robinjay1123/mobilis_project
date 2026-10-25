part of '../dashboard_screen.dart';

extension _DashboardNotificationsTab on _DashboardScreenState {
  Widget _buildNotificationsTab() {
    final notificationItems = _uiNotifications();

    return Column(
      children: [
        _buildCenteredTabHeader('Notifications'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadNotifications,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoleTabHeader(
                    title: 'Notifications',
                    subtitle: 'Booking updates, approvals, and trip reminders',
                    icon: Icons.notifications_outlined,
                    badge: '$_unreadNotificationCount unread',
                    action: _unreadNotificationCount > 0
                        ? TextButton.icon(
                            onPressed: _markAllNotificationsRead,
                            icon: const Icon(
                              Icons.done_all,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Mark all read',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 18),
                  // Empty State
                  if (notificationItems.isEmpty)
                    const RoleEmptyStateCard(
                      icon: Icons.notifications_none,
                      title: 'No notifications yet',
                      message:
                          'Booking updates, approvals, and trip reminders will appear here.',
                    )
                  else
                    Column(
                      children: List.generate(
                        notificationItems.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _handleNotificationTap(
                              notificationItems[index],
                            ),
                            onLongPress: () => _showNotificationDetails(
                              notificationItems[index],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color:
                                    notificationItems[index]['isRead'] == true
                                    ? const Color(0xFF2A3548)
                                    : const Color(0xFF354156),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      notificationItems[index]['isRead'] == true
                                      ? AppColors.borderColor
                                      : Colors.white70,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color:
                                          notificationItems[index]['iconColor']
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child:
                                        notificationItems[index]['imageUrl']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ==
                                            true
                                        ? OptimizedNetworkImage(
                                            imageUrl:
                                                notificationItems[index]['imageUrl']
                                                    .toString(),
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            errorWidget: Icon(
                                              notificationItems[index]['icon'],
                                              color:
                                                  notificationItems[index]['iconColor'],
                                              size: 24,
                                            ),
                                          )
                                        : Icon(
                                            notificationItems[index]['icon'],
                                            color:
                                                notificationItems[index]['iconColor'],
                                            size: 24,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notificationItems[index]['title'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notificationItems[index]['message'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notificationItems[index]['timestamp'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (notificationItems[index]['isRead'] !=
                                      true) ...[
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

