import 'package:app/core/theme.dart';
import 'package:flutter/material.dart';

class HistorySearchBar extends StatelessWidget {
  const HistorySearchBar({
    required this.controller,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        color: MH.paper,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: MH.sans(),
          decoration: InputDecoration(
            hintText: 'Rechercher équipe ou joueur…',
            hintStyle: MH.sans(color: MH.pencil),
            prefixIcon: const Icon(Icons.search, size: 20, color: MH.pencil),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: MH.pencil),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: MH.sand,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}
