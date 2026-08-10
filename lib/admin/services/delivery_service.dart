// admin/services/delivery_service.dart — Яндекс/Узум yetkazib berish daftari
// servisi (DeliveryService) va modellari: GET /api/delivery (oy kunlari+qarz),
// POST /api/delivery/day (kun upsert), GET /api/delivery/summary (yillik),
// PUT /api/delivery/settings (komissiya %/boshlang'ich qoldiq — admin).
import 'package:dio/dio.dart';
import 'package:uz_ai_dev/core/constants/urls.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/core/network/error_handler.dart';

class DeliveryDay {
  final String date; // YYYY-MM-DD
  final int orders;
  final int checkSum;
  final int orderSum;
  final int commissionSum;
  final int ostatok;
  final int payment;

  DeliveryDay({
    required this.date,
    required this.orders,
    required this.checkSum,
    required this.orderSum,
    required this.commissionSum,
    required this.ostatok,
    required this.payment,
  });

  factory DeliveryDay.fromJson(Map<String, dynamic> j) => DeliveryDay(
        date: j['date']?.toString() ?? '',
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        checkSum: (j['check_sum'] as num?)?.toInt() ?? 0,
        orderSum: (j['order_sum'] as num?)?.toInt() ?? 0,
        commissionSum: (j['commission_sum'] as num?)?.toInt() ?? 0,
        ostatok: (j['ostatok'] as num?)?.toInt() ?? 0,
        payment: (j['payment'] as num?)?.toInt() ?? 0,
      );
}

class DeliveryMonth {
  final String platform;
  final String month; // YYYY-MM
  final double commissionPercent;
  final List<DeliveryDay> days;
  final Map<String, int> totals;
  final int debt;

  DeliveryMonth({
    required this.platform,
    required this.month,
    required this.commissionPercent,
    required this.days,
    required this.totals,
    required this.debt,
  });

  factory DeliveryMonth.fromJson(Map<String, dynamic> j) => DeliveryMonth(
        platform: j['platform']?.toString() ?? '',
        month: j['month']?.toString() ?? '',
        commissionPercent:
            (j['commission_percent'] as num?)?.toDouble() ?? 26,
        days: ((j['days'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => DeliveryDay.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        totals: ((j['totals'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        debt: (j['debt'] as num?)?.toInt() ?? 0,
      );
}

class DeliveryMonthAgg {
  final String month; // YYYY-MM
  final Map<String, int> orders; // platform -> zakazlar
  final Map<String, int> sums; // platform -> summa
  final int total;

  DeliveryMonthAgg({
    required this.month,
    required this.orders,
    required this.sums,
    required this.total,
  });

  factory DeliveryMonthAgg.fromJson(Map<String, dynamic> j) => DeliveryMonthAgg(
        month: j['month']?.toString() ?? '',
        orders: ((j['orders'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        sums: ((j['sums'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class DeliveryService {
  final Dio dio = sl<Dio>();

  Future<DeliveryMonth> fetchMonth(String platform, String month) async {
    try {
      final response = await dio.get(AppUrls.delivery,
          queryParameters: {'platform': platform, 'month': month});
      return DeliveryMonth.fromJson(
          Map<String, dynamic>.from(response.data['data']));
    } on DioException catch (e) {
      throw Exception(parseDioError(e, fallback: 'Yuklab bo\'lmadi'));
    }
  }

  Future<int> saveDay({
    required String platform,
    required String date,
    required int orders,
    required int checkSum,
    required int orderSum,
    required int payment,
  }) async {
    try {
      final response = await dio.post(AppUrls.deliveryDay, data: {
        'platform': platform,
        'date': date,
        'orders': orders,
        'check_sum': checkSum,
        'order_sum': orderSum,
        'payment': payment,
      });
      return ((response.data['data'] as Map?)?['debt'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw Exception(parseDioError(e, fallback: 'Saqlanmadi'));
    }
  }

  Future<(List<DeliveryMonthAgg>, Map<String, int>)> fetchSummary() async {
    try {
      final response = await dio.get(AppUrls.deliverySummary);
      final data = Map<String, dynamic>.from(response.data['data']);
      final months = ((data['months'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => DeliveryMonthAgg.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final debts = ((data['debts'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      return (months, debts);
    } on DioException catch (e) {
      throw Exception(parseDioError(e, fallback: 'Hisobot yuklanmadi'));
    }
  }

  Future<void> saveSettings({
    required String platform,
    double? commissionPercent,
    int? openingBalance,
  }) async {
    try {
      await dio.put(AppUrls.deliverySettings, data: {
        'platform': platform,
        if (commissionPercent != null) 'commission_percent': commissionPercent,
        if (openingBalance != null) 'opening_balance': openingBalance,
      });
    } on DioException catch (e) {
      throw Exception(parseDioError(e, fallback: 'Sozlama saqlanmadi'));
    }
  }
}
