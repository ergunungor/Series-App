import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../models/program.dart';

Future<ActiveProgram?> showSelectActiveProgramSheet({
  required BuildContext context,
  required List<ActiveProgram> programs,
  required String? currentActiveId,
}) {
  return showModalBottomSheet<ActiveProgram>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.brandSecondary,
                borderRadius: BorderRadius.circular(45),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aktif Program Seç',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: programs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final program = programs[index];
                  final isActive = program.id == currentActiveId;
                  return Material(
                    color: isActive ? AppColors.background : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(program),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isActive
                                    ? AppColors.brandPrimary
                                    : AppColors.brandSecondary,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                program.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body16Medium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isActive)
                              Icon(
                                Icons.check_circle,
                                color: AppColors.brandPrimary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
