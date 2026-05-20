import 'package:app/core/theme.dart';
import 'package:app/features/match/providers/match_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MatchNotes extends ConsumerStatefulWidget {
  const MatchNotes({super.key});

  @override
  ConsumerState<MatchNotes> createState() => _MatchNotesState();
}

class _MatchNotesState extends ConsumerState<MatchNotes> {
  late final TextEditingController _ctrl = TextEditingController(
    text: ref.read(matchProvider).notes,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            color: MH.paper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: MH.rule, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit, size: 11, color: MH.pencil),
                  const SizedBox(width: 6),
                  Text('NOTES',
                      style: MH.sans(
                        size: 9,
                        weight: FontWeight.w600,
                        color: MH.pencil,
                        letterSpacing: 0.5,
                      )),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _ctrl,
                onChanged: (v) =>
                    ref.read(matchProvider.notifier).setNotes(v),
                maxLines: 2,
                minLines: 2,
                style: MH.sans(
                    size: 13, color: MH.inkSoft, height: 1.4),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Observations, conditions, tactique…',
                  hintStyle:
                      MH.sans(size: 13, color: MH.pencil, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
}
