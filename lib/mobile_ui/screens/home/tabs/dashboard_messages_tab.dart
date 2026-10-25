part of '../dashboard_screen.dart';

extension _DashboardMessagesTab on _DashboardScreenState {
  Widget _buildMessagesTab() {
    final conversations = _uiConversations();
    final unreadCount = conversations.fold<int>(
      0,
      (sum, conversation) => sum + (conversation['unreadCount'] as int? ?? 0),
    );

    return Column(
      children: [
        _buildCenteredTabHeader(
          'Messages',
          trailing: unreadCount > 0
              ? TextButton(
                  onPressed: _markAllMessagesRead,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoleTabHeader(
                  title: 'Messages',
                  subtitle: 'Booking conversations and customer service',
                  icon: Icons.chat_bubble_outline,
                  badge: unreadCount > 0 ? '$unreadCount unread' : null,
                ),
                const SizedBox(height: 18),
                // Empty State
                if (conversations.isEmpty)
                  const RoleEmptyStateCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message:
                        'Booking group chats and customer service conversations will appear here.',
                  )
                else
                  // Conversations List
                  Column(
                    children: List.generate(
                      conversations.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _openConversation(conversations[index]),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3548),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      conversations[index]['imageUrl']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ==
                                          true
                                      ? OptimizedNetworkImage(
                                          imageUrl:
                                              conversations[index]['imageUrl']
                                                  .toString(),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          errorWidget: const Icon(
                                            Icons.directions_car_outlined,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Icon(
                                          conversations[index]['isCustomerService'] ==
                                                  true
                                              ? Icons.support_agent
                                              : Icons.directions_car_outlined,
                                          color: AppColors.primary,
                                          size: 24,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                            conversations[index]['recipientName'],
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            conversations[index]['timestamp'],
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (conversations[index]['statusBadge'] !=
                                              null &&
                                          conversations[index]['statusBadge']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _buildConversationStatusChip(
                                          conversations[index]['statusBadge']
                                              .toString(),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              conversations[index]['lastMessage'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if ((conversations[index]['unreadCount']
                                                      as int? ??
                                                  0) >
                                              0)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  (conversations[index]['unreadCount']
                                                              as int?)
                                                          ?.toString() ??
                                                      '0',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppColors.textTertiary,
                                  size: 14,
                                ),
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
      ],
    );
  }
}

