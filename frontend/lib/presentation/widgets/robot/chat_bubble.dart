import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_manager/core/theme/app_theme.dart';
import 'package:expense_manager/presentation/widgets/robot/personality_robot_avatar.dart';

enum ChatBubbleType { user, bot, system }

class ChatBubble extends StatelessWidget {
  final String message;
  final ChatBubbleType type;
  final DateTime? timestamp;
  final String? subtext;
  final bool isTransaction;
  final PersonalityType? botPersonality;

  const ChatBubble({
    super.key,
    required this.message,
    this.type = ChatBubbleType.bot,
    this.timestamp,
    this.subtext,
    this.isTransaction = false,
    this.botPersonality,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case ChatBubbleType.user:
        return _UserBubble(
          message: message,
          timestamp: timestamp,
          isTransaction: isTransaction,
          subtext: subtext,
        );
      case ChatBubbleType.bot:
        return _BotBubble(
          message: message,
          timestamp: timestamp,
          subtext: subtext,
          botPersonality: botPersonality,
        );
      case ChatBubbleType.system:
        return _SystemBubble(message: message);
    }
  }
}

class _UserBubble extends StatelessWidget {
  final String message;
  final DateTime? timestamp;
  final bool isTransaction;
  final String? subtext;

  const _UserBubble({
    required this.message,
    this.timestamp,
    this.isTransaction = false,
    this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(48, 0, 10, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.35,
              ),
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext!,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(timestamp!),
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  final String message;
  final DateTime? timestamp;
  final String? subtext;
  final PersonalityType? botPersonality;

  const _BotBubble({
    required this.message,
    this.timestamp,
    this.subtext,
    this.botPersonality,
  });

  @override
  Widget build(BuildContext context) {
    final type = botPersonality ?? PersonalityType.happy;
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.82;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: PersonalityRobotAvatar(
              type: type,
              size: 32,
              isSelected: false,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    if (subtext != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtext!,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (timestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm').format(timestamp!),
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
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

class _SystemBubble extends StatelessWidget {
  final String message;

  const _SystemBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
