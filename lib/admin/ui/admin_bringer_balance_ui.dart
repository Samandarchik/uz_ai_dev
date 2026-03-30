import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/bringer/models/bringer_models.dart';
import 'package:uz_ai_dev/bringer/provider/bringer_provider.dart';
import 'package:uz_ai_dev/bringer/services/bringer_service.dart';
import 'package:intl/intl.dart';

class AdminBringerBalanceUi extends StatefulWidget {
  const AdminBringerBalanceUi({super.key});

  @override
  State<AdminBringerBalanceUi> createState() => _AdminBringerBalanceUiState();
}

class _AdminBringerBalanceUiState extends State<AdminBringerBalanceUi> {
  final BringerService _service = BringerService();
  int? _selectedBringerId;
  BringerBalance? _balance;
  List<BringerTransaction> _transactions = [];
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BringerProvider>().loadProfiles();
    });
  }

  Future<void> _loadBringerData(int bringerId) async {
    setState(() => _isLoadingData = true);

    try {
      final dio = _service.dio;

      // Balance olish (admin — bringer_profile_id query param bilan)
      final balanceResp = await dio.get(
        '/api/bringer/balance',
        queryParameters: {'bringer_profile_id': bringerId},
      );
      if (balanceResp.statusCode == 200 &&
          balanceResp.data['success'] == true) {
        _balance = BringerBalance.fromJson(balanceResp.data['data']);
      }

      // Tranzaksiyalar
      final txResp = await dio.get(
        '/api/bringer/balance/transactions',
        queryParameters: {'bringer_profile_id': bringerId},
      );
      if (txResp.statusCode == 200 && txResp.data['success'] == true) {
        final List<dynamic> data = txResp.data['data'] ?? [];
        _transactions =
            data.map((e) => BringerTransaction.fromJson(e)).toList();
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingData = false);
  }

  void _showAddBalanceDialog() {
    if (_selectedBringerId == null) return;

    final amountController = TextEditingController();
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Balans qo\'shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Summa (so\'m)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(labelText: 'Izoh'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;

                Navigator.pop(ctx);
                await context.read<BringerProvider>().addBalance(
                      bringerProfileId: _selectedBringerId!,
                      amount: amount,
                      comment: commentController.text.isEmpty
                          ? null
                          : commentController.text,
                    );
                await _loadBringerData(_selectedBringerId!);
              },
              child: const Text('Qo\'shish'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bringer balans'),
        actions: [
          if (_selectedBringerId != null)
            IconButton(
              onPressed: _showAddBalanceDialog,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Consumer<BringerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.profiles.isEmpty) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<int>(
                  value: _selectedBringerId,
                  decoration: InputDecoration(
                    labelText: 'Bringerni tanlang',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: provider.profiles.map((profile) {
                    return DropdownMenuItem<int>(
                      value: profile.id,
                      child: Text(profile.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBringerId = value;
                    });
                    if (value != null) {
                      _loadBringerData(value);
                    }
                  },
                ),
              ),

              if (_selectedBringerId != null) ...[
                if (_isLoadingData)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator.adaptive(),
                  )
                else ...[
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat('Umumiy',
                              _balance?.totalBalance ?? 0, Colors.blue),
                          _stat('Sarflangan',
                              _balance?.spentBalance ?? 0, Colors.red),
                          _stat('Mavjud',
                              _balance?.availableBalance ?? 0, Colors.green),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tranzaksiyalar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: _transactions.isEmpty
                        ? const Center(child: Text('Tranzaksiyalar yo\'q'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final isCredit = tx.type == 'credit';
                              return ListTile(
                                leading: Icon(
                                  isCredit
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isCredit ? Colors.green : Colors.red,
                                ),
                                title: Text(
                                  '${isCredit ? '+' : '-'}${_formatMoney(tx.amount)} so\'m',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCredit ? Colors.green : Colors.red,
                                  ),
                                ),
                                subtitle: Text(
                                  '${DateFormat('dd.MM.yyyy HH:mm').format(tx.created)}${tx.comment != null ? ' | ${tx.comment}' : ''}',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ] else
                const Expanded(
                  child: Center(child: Text('Bringerni tanlang')),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, int amount, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(
          _formatMoney(amount),
          style:
              TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
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
