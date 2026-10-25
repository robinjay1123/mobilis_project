part of '../admin_web_screen.dart';

extension AdminCustomerServiceTab on _AdminWebScreenState {
  Widget _buildCustomerServiceContent(bool isDark) {
    final selectedConversation = _supportConversations
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (conversation) =>
              conversation?['id']?.toString() == _selectedSupportConversationId,
          orElse: () => _supportConversations.isNotEmpty
              ? _supportConversations.first
              : null,
        );
    final selectedConversationId = selectedConversation?['id']?.toString();
    final messages = selectedConversationId == null
        ? const <Map<String, dynamic>>[]
        : (_supportMessages[selectedConversationId] ??
              const <Map<String, dynamic>>[]);

    if (_isLoadingSupportInbox && _supportConversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_supportConversations.isEmpty) {
      return Center(
        child: Text(
          'No customer service conversations yet.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            fontSize: 16,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSecondary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderColor : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Support Inbox',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadSupportInbox,
                        icon: const Icon(Icons.refresh),
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _supportConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _supportConversations[index];
                      final conversationId =
                          conversation['id']?.toString() ?? '';
                      final customer =
                          conversation['customer'] as Map<String, dynamic>? ??
                          {};
                      final latestMessage =
                          conversation['latest_message']
                              as Map<String, dynamic>? ??
                          {};
                      final isSelected =
                          conversationId == _selectedSupportConversationId;
                      final customerName =
                          customer['full_name']?.toString().trim().isNotEmpty ==
                              true
                          ? customer['full_name'].toString().trim()
                          : customer['email']?.toString().trim().isNotEmpty ==
                                true
                          ? customer['email'].toString().trim()
                          : 'Customer';

                      return InkWell(
                        onTap: () async {
                          setState(
                            () =>
                                _selectedSupportConversationId = conversationId,
                          );
                          _watchSupportTyping(conversationId);
                          await _loadSupportConversationMessages(
                            conversationId,
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customerName,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    (customer['role']?.toString().isNotEmpty ??
                                            false)
                                        ? customer['role']
                                              .toString()
                                              .toUpperCase()
                                        : 'USER',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (() {
                                  final c =
                                      latestMessage['content']?.toString() ??
                                      '';
                                  final url =
                                      (latestMessage['attachment_url'] ??
                                              latestMessage['image_url'] ??
                                              latestMessage['file_url'])
                                          ?.toString() ??
                                      '';
                                  if (url.isNotEmpty ||
                                      c.startsWith('Sent an attachment:')) {
                                    return '📷 Sent an attachment';
                                  }
                                  return c.isNotEmpty
                                      ? c
                                      : 'Open support thread';
                                })(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgSecondary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderColor : Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (() {
                              final customer =
                                  selectedConversation?['customer']
                                      as Map<String, dynamic>? ??
                                  {};
                              final fullName = customer['full_name']
                                  ?.toString()
                                  .trim();
                              if (fullName != null && fullName.isNotEmpty)
                                return fullName;
                              final email = customer['email']
                                  ?.toString()
                                  .trim();
                              if (email != null && email.isNotEmpty)
                                return email;
                              return 'Customer Service Chat';
                            })(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'Admin Support',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet in this support conversation.',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(18),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isAdminMessage =
                                  message['sender_id']?.toString() ==
                                  _supabase.auth.currentUser?.id;
                              final rawContent =
                                  (message['content'] ?? message['message'])
                                      ?.toString() ??
                                  '';
                              final isDeleted =
                                  message['is_deleted'] == true ||
                                  rawContent == 'Message deleted';
                              final isSending = message['_is_sending'] == true;
                              final sendFailed =
                                  message['_send_failed'] == true;

                              String attachmentUrl = '';
                              if (!isDeleted) {
                                attachmentUrl =
                                    (message['attachment_url'] ??
                                            message['image_url'] ??
                                            message['file_url'] ??
                                            message['media_url'] ??
                                            message['url'] ??
                                            message['attachment'])
                                        ?.toString()
                                        .trim() ??
                                    '';

                                if (attachmentUrl.isEmpty &&
                                    rawContent.trim().isNotEmpty) {
                                  final urlMatch = RegExp(
                                    r'https?://[^\s]+',
                                    caseSensitive: false,
                                  ).firstMatch(rawContent);
                                  if (urlMatch != null) {
                                    final matchedUrl = urlMatch.group(0) ?? '';
                                    final lower = matchedUrl.toLowerCase();
                                    if (RegExp(
                                          r'\.(png|jpe?g|webp|gif|heic|bmp|tiff)(\?|$)',
                                          caseSensitive: false,
                                        ).hasMatch(matchedUrl) ||
                                        lower.contains('/chat-attachments/') ||
                                        lower.contains('/chat/') ||
                                        lower.contains('/storage/v1/object/')) {
                                      attachmentUrl = matchedUrl;
                                    }
                                  }
                                }
                              }

                              final showContentText =
                                  isDeleted ||
                                  (rawContent.trim().isNotEmpty &&
                                      rawContent.trim() != attachmentUrl &&
                                      !rawContent.trim().startsWith(
                                        'Sent an attachment:',
                                      ));

                              return Align(
                                alignment: isAdminMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdminMessage
                                        ? AppColors.primary
                                        : (isDark
                                              ? Colors.black26
                                              : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (attachmentUrl.isNotEmpty) ...[
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () => _showFullImageDialog(
                                              attachmentUrl,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 340,
                                                      maxHeight: 280,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.black38
                                                      : Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    OptimizedNetworkImage(
                                                      imageUrl: attachmentUrl,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorWidget: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        color: Colors.black26,
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .broken_image_outlined,
                                                              color:
                                                                  Colors.amber,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                'Unable to load attachment image',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      isAdminMessage
                                                                      ? Colors
                                                                            .black87
                                                                      : Colors
                                                                            .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 8,
                                                      bottom: 8,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.65,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.zoom_in,
                                                              color:
                                                                  Colors.white,
                                                              size: 14,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Click to view',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (showContentText)
                                          const SizedBox(height: 8),
                                      ],
                                      if (showContentText ||
                                          attachmentUrl.isEmpty)
                                        Text(
                                          isDeleted
                                              ? 'Message deleted'
                                              : rawContent,
                                          style: TextStyle(
                                            fontStyle: isDeleted
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            color: isAdminMessage
                                                ? const Color(0xFF101820)
                                                : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                            fontWeight: isAdminMessage
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          RelativeTimeText(
                                            value: message['created_at'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isAdminMessage
                                                  ? const Color(0xA6101820)
                                                  : (isDark
                                                        ? Colors.white54
                                                        : Colors.black45),
                                            ),
                                          ),
                                          if (isSending || sendFailed) ...[
                                            const SizedBox(width: 7),
                                            Text(
                                              sendFailed
                                                  ? 'Failed'
                                                  : 'Sending...',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                                color: sendFailed
                                                    ? AppColors.error
                                                    : Colors.black45,
                                              ),
                                            ),
                                          ],
                                          if (isAdminMessage &&
                                              !isDeleted &&
                                              !isSending &&
                                              !sendFailed &&
                                              message['is_auto_generated'] !=
                                                  true) ...[
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Delete message',
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              constraints: const BoxConstraints(
                                                minWidth: 26,
                                                minHeight: 26,
                                              ),
                                              onPressed: () =>
                                                  _deleteSupportMessage(
                                                    message,
                                                  ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 15,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  if (_supportTypingUsers.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 9, 22, 0),
                        child: Text(
                          '${_supportTypingUsers.values.first} is typing...',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _supportReplyController,
                            onChanged: _handleSupportTyping,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            decoration: _settingsInputDecoration(
                              isDark,
                              label: 'Reply',
                              hint: 'Send a support response...',
                            ),
                            minLines: 1,
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSendingSupportReply
                              ? null
                              : _sendSupportReply,
                          icon: const Icon(Icons.send),
                          label: const Text('Reply'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
