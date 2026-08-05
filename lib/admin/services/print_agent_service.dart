// admin/services/print_agent_service.dart — ulangan print agentlar ro'yxati
// (GET /api/print-agents): agent nomi, online holati va real printer nomlari.
// Kategoriya dialogidagi printer dropdown shu ma'lumotdan quriladi.
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';

class PrintAgentInfo {
  final String name;
  final bool connected;
  final List<String> printers;

  PrintAgentInfo({
    required this.name,
    required this.connected,
    required this.printers,
  });

  static PrintAgentInfo fromJson(Map<String, dynamic> json) {
    return PrintAgentInfo(
      name: json['name'] ?? '',
      connected: json['connected'] ?? false,
      printers: List<String>.from(json['printers'] ?? const []),
    );
  }
}

class PrintAgentService {
  final Dio _dio = sl<Dio>();

  Future<List<PrintAgentInfo>> getPrintAgents() async {
    final response = await _dio.get(AppUrls.printAgents);
    if (response.statusCode == 200 && response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((e) => PrintAgentInfo.fromJson(e)).toList();
    }
    throw Exception(response.data['message'] ?? 'Agentlarni olishda xatolik');
  }
}
