// admin/model/print_device_model.dart — printer registri yozuvi (PrintDevice):
// print-server API manzili (apiUrl) + o'sha serverdagi printer raqami
// (printerNo). Kategoriya "printer" maydoni shu registrdagi id ga ishora
// qiladi. Backend: GET/POST/PUT/DELETE /api/printers.
class PrintDevice {
  final int id;
  final String name;
  final String apiUrl;
  final int printerNo;

  const PrintDevice({
    required this.id,
    required this.name,
    required this.apiUrl,
    required this.printerNo,
  });

  factory PrintDevice.fromJson(Map<String, dynamic> json) {
    return PrintDevice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      apiUrl: json['api_url'] as String? ?? '',
      printerNo: (json['printer_no'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'api_url': apiUrl, 'printer_no': printerNo};
  }
}
