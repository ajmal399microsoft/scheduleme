import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/task.dart';

const taskIconChoices = <String, IconData>{
  'task': Icons.task_alt_outlined,
  'home': Icons.home_outlined,
  'health': Icons.favorite_border,
  'shopping': Icons.shopping_bag_outlined,
  'work': Icons.work_outline,
  'cleaning': Icons.cleaning_services_outlined,
  'finance': Icons.payments_outlined,
  'food': Icons.restaurant_outlined,
};

class TaskArtwork extends StatelessWidget {
  const TaskArtwork({required this.task, this.size = 48, super.key});

  final Task task;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imagePath = task.attachmentPath;
    final icon = taskIconChoices[task.iconKey] ?? Icons.task_alt_outlined;
    final color = Theme.of(context).colorScheme.primaryContainer;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: imagePath != null && imagePath.isNotEmpty && !kIsWeb
            ? Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _iconTile(icon, color),
              )
            : _iconTile(icon, color),
      ),
    );
  }

  Widget _iconTile(IconData icon, Color color) => ColoredBox(
        color: color,
        child: Icon(icon, size: size * 0.54),
      );
}