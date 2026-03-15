import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';

class BringerTasksUi extends StatefulWidget {
  final int bringerProfileId;

  const BringerTasksUi({super.key, required this.bringerProfileId});

  @override
  State<BringerTasksUi> createState() => _BringerTasksUiState();
}

class _BringerTasksUiState extends State<BringerTasksUi> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BringerProvider>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Olish ro\'yxati')),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (provider.tasks.isEmpty) {
            return const Center(child: Text('Hozircha vazifa yo\'q'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadTasks(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.tasks.length,
              itemBuilder: (context, index) {
                final task = provider.tasks[index];
                final isComplete = task.remainingCount <= 0;

                return Card(
                  color: isComplete ? Colors.green.shade50 : null,
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: task.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: "${AppUrls.baseUrl}${task.imageUrl}",
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.image_not_supported),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.shopping_bag),
                            ),
                    ),
                    title: Text(
                      task.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration:
                            isComplete ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kerak: ${task.requiredCount.toStringAsFixed(1)} ${task.type}'),
                        if (task.purchasedCount > 0)
                          Text(
                            'Olingan: ${task.purchasedCount.toStringAsFixed(1)} ${task.type}',
                            style: const TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                    trailing: isComplete
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                task.remainingCount.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.red,
                                ),
                              ),
                              Text(task.type,
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
