import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({required this.hasQuery, super.key});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasQuery ? Icons.search_off : Icons.history,
                size: 48,
                color: MH.rule,
              ),
              const SizedBox(height: 16),
              Text(
                hasQuery ? 'Aucun résultat' : 'Aucun match archivé',
                style: MH.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: MH.inkSoft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasQuery
                    ? "Essayez un autre nom de joueur ou d'équipe"
                    : 'Les matchs terminés apparaîtront ici',
                textAlign: TextAlign.center,
                style: MH.sans(size: 13, color: MH.pencil),
              ),
            ],
          ),
        ),
      );
}
