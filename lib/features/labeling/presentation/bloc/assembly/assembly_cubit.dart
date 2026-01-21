// lib/features/labeling/presentation/bloc/assembly/assembly_cubit.dart

import 'dart:developer' as dev;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:inventory_sync_apps/core/db/app_database.dart';
import 'package:inventory_sync_apps/features/labeling/data/labeling_repository.dart';
import '../../../../../core/db/model/variant_component_row.dart';

part 'assembly_state.dart';

class AssemblyCubit extends Cubit<AssemblyState> {
  final LabelingRepository repo;

  AssemblyCubit(this.repo, String variantId, String variantName)
    : super(AssemblyState(variantId: variantId, variantName: variantName));

  /// 1. Load requirements dan AUTO-GENERATE semua units
  Future<void> loadRequirements({
    required List<VariantComponentRow> inBoxComponents,
    required String variantRackId,
    required String variantRackName,
    required int userId,
    required String companyCode,
  }) async {
    emit(state.copyWith(status: AssemblyStatus.loading));

    try {
      // 👇 FLAT LIST: Expand komponen jadi units individual
      List<AssemblyUnitItem> allUnits = [];

      for (var component in inBoxComponents) {
        // Generate units sesuai quantity
        final generatedUnits = await repo.generateBatchLabels(
          variantId: state.variantId,
          companyCode: companyCode,
          rackId: variantRackId,
          qty: component.quantity, // 🔥 Gunakan quantity dari DB!
          userId: userId,
          componentId: component.componentId,
          manufCode: component.manufCode ?? '-',
        );

        // Convert ke AssemblyUnitItem (flat)
        for (var unit in generatedUnits) {
          allUnits.add(
            AssemblyUnitItem(
              componentId: component.componentId,
              componentName: component.name,
              manufCode: component.manufCode ?? '-',
              rackName: variantRackName,
              rackId: variantRackId,
              unitId: unit.id,
              qrValue: unit.qrValue,
              isPrinted: false,
              isScanned: false,
            ),
          );
        }
      }

      emit(
        state.copyWith(
          status: AssemblyStatus.loaded,
          units: allUnits, // 👈 Flat list!
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: AssemblyStatus.failure, error: e.toString()));
    }
  }

  /// 2. Mark unit sebagai printed
  void markAsPrinted(int index) {
    if (index < 0 || index >= state.units.length) return;

    final updatedUnits = List<AssemblyUnitItem>.from(state.units);
    updatedUnits[index] = updatedUnits[index].copyWith(isPrinted: true);

    emit(state.copyWith(units: updatedUnits));
  }

  /// 3. Validasi Scan QR
  Future<void> onScanQr(String rawQr) async {
    // Cari unit yang punya QR ini
    final index = state.units.indexWhere(
      (u) => u.qrValue == rawQr && !u.isScanned,
    );

    if (index == -1) {
      emit(
        state.copyWith(
          lastScanMessage: 'QR tidak dikenali atau sudah di-scan.',
        ),
      );
      return;
    }

    final unit = state.units[index];

    // Tandai sebagai scanned
    final updatedUnits = List<AssemblyUnitItem>.from(state.units);
    updatedUnits[index] = unit.copyWith(isScanned: true);

    emit(
      state.copyWith(
        units: updatedUnits,
        lastScanMessage: '${unit.componentName} ✓',
      ),
    );
  }

  /// 4. Create Draft Set (Status PENDING)
  Future<Unit?> createDraftSet({
    required int userId,
    required String companyCode,
    required String rackId,
    required String rackName,
  }) async {
    if (!state.isAllUnitsScanned) return null;

    emit(state.copyWith(status: AssemblyStatus.assembling));

    try {
      // Kumpulkan semua unit IDs
      final componentUnitIds = state.units.map((u) => u.unitId).toList();

      final result = await repo.generateParentUnit(
        variantId: state.variantId,
        componentUnitIds: componentUnitIds,
        userId: userId,
        rackName: rackName,
        rackId: rackId,
      );

      final parentUnitWithRel = await repo.findUnitByQr(result.parentQrValue);

      emit(state.copyWith(status: AssemblyStatus.success));

      return parentUnitWithRel?.unit;
    } catch (e) {
      emit(state.copyWith(status: AssemblyStatus.failure, error: e.toString()));
      return null;
    }
  }

  /// 5. Finalisasi Set (Status ACTIVE)
  Future<Unit?> createFinalSet({
    required int userId,
    required String companyCode,
    required String rackId,
    required String rackName,
  }) async {
    if (!state.isAllUnitsScanned) return null;

    emit(state.copyWith(status: AssemblyStatus.assembling));

    try {
      // Kumpulkan semua unit IDs
      final componentUnitIds = state.units.map((u) => u.unitId).toList();

      final result = await repo.generateParentUnit(
        variantId: state.variantId,
        componentUnitIds: componentUnitIds,
        userId: userId,
        rackId: rackId,
        rackName: rackName,
      );

      final parentUnit = await repo.findUnitByQr(result.parentQrValue);

      emit(
        state.copyWith(
          status: AssemblyStatus.success,
          parentSetQr: result.parentQrValue,
          parentSetUnitId: result.parentUnitId,
        ),
      );

      return parentUnit?.unit;
    } catch (e) {
      emit(state.copyWith(status: AssemblyStatus.failure, error: e.toString()));
      return null;
    }
  }

  Future<void> activateAllUnitComponents({required int userId}) async {
    try {
      final componentUnitIds = state.units.map((u) => u.unitId).toList();
      dev.log(componentUnitIds.toString());
      await repo.activateAllUnitComponents(
        componentUnitIds: componentUnitIds,
        userId: userId,
      );
    } catch (e) {
      dev.log('ERROR ACTIVATE UNIT $e');
    }
  }

  /// 6. Cancel Assembly (Hapus sampah units)
  Future<void> cancelAssembly() async {
    final generatedIds = state.units.map((u) => u.unitId).toList();

    if (generatedIds.isEmpty) return;

    try {
      await repo.cancelGeneratedUnits(unitIds: generatedIds);
    } catch (e) {
      // Silent fail
    }
  }
}
