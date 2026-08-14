// admin/ui/rk7_sale_places_ui.dart — RK7 «Nuqtalar» tabi (Rk7SalePlacesTab):
// GET /api/rk7/sale-places ro'yxati, har qatorda filial (FilialProviderAdmin)
// va sklad (SkladRegistry) dropdownlari; saqlash → POST /api/rk7/sale-places.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/model/rk7_sale_place_model.dart';
import 'package:uz_ai_dev/admin/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin/services/rk7_service.dart';
import 'package:uz_ai_dev/admin/ui/widgets/rk7_common.dart';
import 'package:uz_ai_dev/core/data/sklad_registry.dart';

// Sotuv nuqtalari — RK7 dagi har bir nuqta (UOT) qaysi filial va qaysi
// skladdan yechilishini belgilaydi. Bog'lanmagan nuqta satrlari import
// paytida skladdan yechilmaydi.
//
// Sklad nomlari FAQAT SkladRegistry dan (CODEMAP: YAGONA manba, hardcode
// map yozilmaydi), filiallar — FilialProviderAdmin dan.
class Rk7SalePlacesTab extends StatefulWidget {
  const Rk7SalePlacesTab({super.key});

  @override
  State<Rk7SalePlacesTab> createState() => _Rk7SalePlacesTabState();
}

class _Rk7SalePlacesTabState extends State<Rk7SalePlacesTab>
    with AutomaticKeepAliveClientMixin {
  final Rk7Service _service = Rk7Service();

  List<Rk7SalePlace> _places = const [];
  // uot_guid → tahrirlanayotgan (hali saqlanmagan) tanlov.
  final Map<String, Rk7SalePlace> _draft = {};
  final Set<String> _saving = {};
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filialProvider = context.read<FilialProviderAdmin>();
      if (filialProvider.filials.isEmpty) filialProvider.getFilials();
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchSalePlaces();
      if (!mounted) return;
      setState(() {
        _places = list;
        _draft.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // Qatordagi joriy holat: tahrirlangan bo'lsa qoralama, aks holda server holati.
  Rk7SalePlace _current(Rk7SalePlace place) =>
      _draft[place.uotGuid] ?? place;

  bool _changed(Rk7SalePlace place) {
    final draft = _draft[place.uotGuid];
    if (draft == null) return false;
    return draft.filialId != place.filialId || draft.skladId != place.skladId;
  }

  void _setDraft(Rk7SalePlace place, {int? filialId, int? skladId}) {
    setState(() {
      _draft[place.uotGuid] = _current(place).copyWith(
        filialId: filialId,
        skladId: skladId,
      );
    });
  }

  Future<void> _save(Rk7SalePlace place) async {
    final draft = _current(place);
    if (draft.filialId <= 0 || draft.skladId <= 0) {
      rk7Snack(context, 'Filial va sklad tanlansin', error: true);
      return;
    }
    setState(() => _saving.add(place.uotGuid));
    try {
      final saved = await _service.saveSalePlace(
        uotGuid: place.uotGuid,
        filialId: draft.filialId,
        skladId: draft.skladId,
        active: draft.active,
      );
      if (!mounted) return;
      setState(() {
        // To'liq qayta so'rov YO'Q — qator joyida yangilanadi.
        _places = [
          for (final p in _places)
            p.uotGuid == place.uotGuid ? (saved ?? draft) : p,
        ];
        _draft.remove(place.uotGuid);
        _saving.remove(place.uotGuid);
      });
      rk7Snack(context, 'Nuqta saqlandi');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving.remove(place.uotGuid));
      rk7Snack(context, e.toString().replaceFirst('Exception: ', ''),
          error: true);
    }
  }

  // ─────────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _load,
      color: kRk7Accent,
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading && _places.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null && _places.isEmpty) {
      return rk7ErrorState(_error!, onRetry: _load);
    }
    if (_places.isEmpty) {
      return rk7EmptyState(
        Icons.store_mall_directory_outlined,
        'Sotuv nuqtalari yo\'q (adapter lug\'atni hali yubormagan)',
      );
    }
    final unmappedCount = _places.where((p) => !p.isMapped).length;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _places.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              unmappedCount == 0
                  ? 'Hamma nuqta bog\'langan (${_places.length} ta)'
                  : 'Bog\'lanmagan nuqta: $unmappedCount / ${_places.length}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: unmappedCount == 0
                    ? Colors.grey.shade700
                    : Colors.red.shade700,
              ),
            ),
          );
        }
        return _placeCard(_places[index - 1]);
      },
    );
  }

  Widget _placeCard(Rk7SalePlace place) {
    final draft = _current(place);
    final filials = context.watch<FilialProviderAdmin>().filials;
    final filialIds = filials.map((f) => f.id).toSet();
    final skladIds = SkladRegistry.ids;
    final saving = _saving.contains(place.uotGuid);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: draft.isMapped ? Colors.grey.shade300 : Colors.red.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name.isEmpty ? place.uotGuid : place.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _dropdown<int>(
                    label: 'Filial',
                    value: filialIds.contains(draft.filialId)
                        ? draft.filialId
                        : null,
                    items: [
                      for (final f in filials)
                        DropdownMenuItem(value: f.id, child: Text(f.name)),
                    ],
                    onChanged: (v) =>
                        v == null ? null : _setDraft(place, filialId: v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dropdown<int>(
                    label: 'Sklad',
                    value:
                        skladIds.contains(draft.skladId) ? draft.skladId : null,
                    items: [
                      for (final id in skladIds)
                        DropdownMenuItem(
                          value: id,
                          child: Text(SkladRegistry.nameOf(id)),
                        ),
                    ],
                    onChanged: (v) =>
                        v == null ? null : _setDraft(place, skladId: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!draft.isMapped)
                  Expanded(
                    child: Text(
                      'Bog\'lanmagan — bu nuqtadagi sotuv skladdan yechilmaydi',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed:
                      saving || !_changed(place) ? null : () => _save(place),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRk7Accent,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Saqlash'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kRk7Accent, width: 2),
        ),
      ),
      hint: Text(
        'tanlanmagan',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      ),
    );
  }
}
