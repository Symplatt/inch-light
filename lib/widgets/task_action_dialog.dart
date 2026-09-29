import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TaskAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const TaskAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
}

Future<void> showTaskActionDialog(
  BuildContext context, {
  required String title,
  required List<TaskAction> actions,
  String caption = '事项操作',
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.22),
  builder: (dialogContext) => Dialog(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 4,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caption,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                color: AppColors.divider,
                indent: 12,
                endIndent: 12,
              ),
              const SizedBox(height: 8),
              for (final action in actions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    minLeadingWidth: 20,
                    leading: Icon(
                      action.icon,
                      size: 20,
                      color: action.destructive
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                    title: Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: action.destructive
                            ? AppColors.danger
                            : AppColors.textDark,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      action.onTap();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);
