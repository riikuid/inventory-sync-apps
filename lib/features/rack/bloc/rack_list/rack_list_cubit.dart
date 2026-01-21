import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:inventory_sync_apps/features/labeling/data/labeling_repository.dart';
import '../../../../core/db/model/rack_with_warehouse_sections.dart';
import '../../../printer/bloc/printer_cubit.dart';

part 'rack_list_state.dart';

class RackListCubit extends Cubit<RackListState> {
  final LabelingRepository rackRepository;
  final PrinterCubit printerCubit;

  StreamSubscription? _racksSubscription;
  StreamSubscription? _printerSubscription;

  RackListCubit({required this.rackRepository, required this.printerCubit})
    : super(RackListState.initial());

  // Watch racks dan printer status
  void watchRacks() {
    emit(state.copyWith(status: RackListStatus.loading));

    // Subscribe to racks stream
    _racksSubscription = rackRepository.watchRacks().listen(
      (racks) {
        emit(
          state.copyWith(
            status: RackListStatus.loaded,
            racks: racks,
            filteredRacks: _applyFilter(racks, state.searchQuery),
          ),
        );
      },
      onError: (error) {
        emit(
          state.copyWith(
            status: RackListStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );

    // Subscribe to printer status via stream
    _printerSubscription = printerCubit.stream.listen((printerState) {
      emit(
        state.copyWith(
          printerStatus: printerState.isConnected
              ? PrinterConnectionStatus.connected
              : PrinterConnectionStatus.disconnected,
        ),
      );
    });

    emit(
      state.copyWith(
        printerStatus: printerCubit.state.isConnected
            ? PrinterConnectionStatus.connected
            : PrinterConnectionStatus.disconnected,
      ),
    );
  }

  // Search/filter racks
  void searchRacks(String query) {
    final filtered = _applyFilter(state.racks, query);
    emit(state.copyWith(searchQuery: query, filteredRacks: filtered));
  }

  // Helper untuk filter
  List<RackWithWarehouseAndSections> _applyFilter(
    List<RackWithWarehouseAndSections> racks,
    String? query,
  ) {
    if (query == null || query.trim().isEmpty) {
      return racks;
    }

    final lowerQuery = query.toLowerCase();
    return racks.where((rack) {
      // Search by rack name, warehouse name, or section codes
      final matchRackName = rack.rackName.toLowerCase().contains(lowerQuery);
      final matchWarehouse = rack.warehouseName.toLowerCase().contains(
        lowerQuery,
      );
      final matchSectionCode = rack.sectionCodes.any(
        (code) => code.toLowerCase().contains(lowerQuery),
      );

      return matchRackName || matchWarehouse || matchSectionCode;
    }).toList();
  }

  // Check printer connection
  void checkPrinterConnection() {
    printerCubit.checkConnection();
  }

  // Navigate to printer management (dari screen, bukan cubit)
  // Atau bisa trigger reconnect
  void reconnectPrinter() {
    if (printerCubit.state.selectedDevice != null) {
      printerCubit.reconnect();
    }
  }

  @override
  Future<void> close() {
    _racksSubscription?.cancel();
    _printerSubscription?.cancel();
    return super.close();
  }
}
