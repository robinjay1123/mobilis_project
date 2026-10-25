part of '../partner_home_screen.dart';

extension _PartnerMessagesTab on _PartnerHomeScreenState {
  Widget _buildMessagesTab() {
    return Column(
      children: [
        _buildCenteredTabHeader('Messages'),
        Expanded(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: RoleTabHeader(
                  title: 'Messages',
                  subtitle: 'Renter conversations and customer service',
                  icon: Icons.chat_bubble_outline,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: conversations.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: const [
                          RoleEmptyStateCard(
                            icon: Icons.chat_bubble_outline,
                            title: 'No messages yet',
                            message:
                                'Renter booking chats and customer service conversations will appear here.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final conv = conversations[index];
                          final isCustomerService = conv['bookings'] is! Map;
                          final booking = conv['bookings'] as Map?;
                          final vehicle = (booking?['vehicles'] ??
                                  booking?['partner_vehicles'] ??
                                  booking?['partner_vehicle'] ??
                                  booking?['vehicle']) as Map?;
                          final vehicleName =
                              [vehicle?['brand'], vehicle?['model']]
                                  .where(
                                    (value) =>
                                        value?.toString().trim().isNotEmpty ==
                                        true,
                                  )
                                  .join(' ');
                          final carTitle = vehicleName.isNotEmpty
                              ? vehicleName
                              : (vehicle?['vehicle_name']?.toString().trim().isNotEmpty == true
                                  ? vehicle!['vehicle_name'].toString().trim()
                                  : '');
                          final topicTitle = isCustomerService
                              ? 'Customer Service'
                              : carTitle.isNotEmpty
                              ? '$carTitle Booking'
                              : 'Booking Conversation';
                          var imageUrl =
                              conv['vehicle_image_url']?.toString() ?? '';
                          if (imageUrl.isEmpty) {
                            imageUrl = (booking?['vehicle_image_url'] ??
                                    vehicle?['image_url'] ??
                                    vehicle?['imageUrl'] ??
                                    vehicle?['photo_url'] ??
                                    vehicle?['vehicle_image_url'])
                                ?.toString() ??
                                '';
                          }
                          final messages =
                              conv['messages'] as List<dynamic>? ?? [];
                          final lastMessage = messages.isNotEmpty
                              ? messages.last['content'] ?? ''
                              : 'No messages';

                          final statusRaw = (booking?['status'] ?? '').toString().toLowerCase().trim();
                          final statusGrp = bookingStatusGroup(statusRaw);
                          final String statusBadge = isCustomerService
                              ? 'Support'
                              : (statusGrp == BookingStatusGroup.ongoing
                                  ? 'Ongoing Trip'
                                  : (statusGrp == BookingStatusGroup.approved
                                      ? 'Approved Booking'
                                      : (statusGrp == BookingStatusGroup.completed
                                          ? 'Completed • Read-Only'
                                          : (statusGrp == BookingStatusGroup.cancelled
                                              ? 'Cancelled • Read-Only'
                                              : (statusGrp == BookingStatusGroup.frozen
                                                  ? 'Frozen'
                                                  : (statusRaw.isNotEmpty ? '${bookingStatusLabel(statusGrp)} Booking' : 'Active'))))));

                          return ConversationTile(
                            senderName: topicTitle,
                            lastMessage: lastMessage,
                            timestamp: _formatTime(conv['updated_at']),
                            unreadCount: 0,
                            imageUrl: imageUrl,
                            statusBadge: statusBadge,
                            fallbackIcon: isCustomerService
                                ? Icons.support_agent
                                : Icons.directions_car_outlined,
                            onTap: () {
                              final conversationId = conv['id'];
                              Navigator.of(context)
                                  .pushNamed(
                                    '/chat-detail',
                                    arguments: {
                                      'conversationId': conversationId,
                                      'recipientName': topicTitle,
                                      'recipientAvatar': imageUrl,
                                      'isDarkMode': true,
                                      'isCustomerService': isCustomerService,
                                      'userRole': 'partner',
                                    },
                                  )
                                  .then((_) => _loadPartnerData());
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

