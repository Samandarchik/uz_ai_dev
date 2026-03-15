import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:intl/intl.dart';

class BringerBalanceUi extends StatefulWidget {
  final int bringerProfileId;

  const BringerBalanceUi({super.key, required this.bringerProfileId});

  @override
  State<BringerBalanceUi> createState() => _BringerBalanceUiState();
}

class _BringerBalanceUiState extends State<BringerBalanceUi> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BringerProvider>();
      provider.loadBalance();
      provider.loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balans')),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadBalance();
              await provider.loadTransactions();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance card
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Mavjud balans',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatMoney(provider.balance?.availableBalance ?? 0)} so\'m',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _balanceStat(
                              'Umumiy kirim',
                              provider.balance?.totalBalance ?? 0,
                              Colors.blue,
                            ),
                            _balanceStat(
                              'Sarflangan',
                              provider.balance?.spentBalance ?? 0,
                              Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Transactions
                const Text(
                  'Tranzaksiyalar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (provider.isLoading && provider.transactions.isEmpty)
                  const Center(child: CircularProgressIndicator.adaptive()),

                if (provider.transactions.isEmpty && !provider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Tranzaksiyalar yo\'q'),
                    ),
                  ),

                ...provider.transactions.map((tx) {
                  final isCredit = tx.type == 'credit';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCredit
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        child: Icon(
                          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isCredit ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(
                        '${isCredit ? '+' : '-'}${_formatMoney(tx.amount)} so\'m',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCredit ? Colors.green : Colors.red,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd.MM.yyyy HH:mm')
                              .format(tx.created)),
                          if (tx.comment != null)
                            Text(tx.comment!,
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _balanceStat(String label, int amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '${_formatMoney(amount)} so\'m',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 14),
        ),
      ],
    );
  }

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ');
  }
}
