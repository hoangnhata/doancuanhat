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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              color: AppColors.primary.withOpacity(0.25),
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
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext!,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(timestamp!),
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.7),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PersonalityRobotAvatar(
              type: type,
              size: 32,
              isSelected: false,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: AppColors.softShadow,
                border: Border.all(
                  color: AppColors.surface,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtext != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtext!,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(timestamp!),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
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
