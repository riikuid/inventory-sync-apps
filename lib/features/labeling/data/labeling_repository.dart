import 'dart:developer' as dev;

import 'package:drift/drift.dart';
import 'package:inventory_sync_apps/core/constant.dart';
import 'package:inventory_sync_apps/core/db/app_database.dart';
import 'package:inventory_sync_apps/core/db/daos/brand_dao.dart';
import 'package:inventory_sync_apps/core/db/daos/rack_dao.dart';
import 'package:inventory_sync_apps/core/generate_custom_id.dart';

import '../../../core/db/daos/company_item_dao.dart';
import '../../../core/db/daos/unit_dao.dart';
import '../../../core/db/daos/variant_dao.dart';
import '../../../core/db/daos/variant_photo_dao.dart';
import '../../../core/db/model/rack_with_warehouse_sections.dart';
import '../../../core/db/model/variant_component_row.dart';
import 'models/assembly_result.dart';
import 'models/scan_unit_result.dart';

class LabelingRepository {
  final AppDatabase db;

  LabelingRepository(this.db);

  CompanyItemDao get _companyItemDao => db.companyItemDao;
  VariantDao get _variantDao => db.variantDao;
  BrandDao get _brandDao => db.brandDao;
  RackDao get _rackDao => db.rackDao;
  VariantPhotoDao get _variantPhotoDao => db.variantPhotoDao;
  UnitDao get _unitDao => db.unitDao;

  /// CORE FUNCTION: Generate Batch Labels
  /// Menangani generate label untuk Variant (Set) maupun Component (Separate).
  /// [parentUnitId] Opsional: Jika diisi, unit ini akan langsung ter-link ke parent tersebut.
  Future<List<Unit>> generateBatchLabels({
    required String variantId,
    required String companyCode,
    String? rackId,
    required int qty,
    required int userId,
    // Parameter Opsional untuk Component Mode
    String? componentId,
    String? manufCode,
    String? parentUnitId, // 👈 NEW: Untuk pre-link ke parent
  }) async {
    return db.transaction(() async {
      final List<Unit> generatedUnits = [];
      final now = DateTime.now();

      for (int i = 0; i < qty; i++) {
        String unitId = generateCustomId(unitsPrefix);

        // Logic QR Generation
        String qrResult;

        if (componentId != null) {
          // Jika ada parentUnitId, masukkan ke dalam QR string?
          // Format lama: U$userId|$companyCode|$componentId|$unitId
          // User request: QR Komponen memiliki parent unit id = parent qr id
          // IMPLIKASI: QR string harus berubah jika kita ingin parent info ada di QR.
          // TAPI: Request user bilang "merubah parent_unit_id unit dari komponen ... dengan id dari qr unit yg baru dicetak"
          // Jadi yang penting di DB relasinya sudah terbentuk.
          // QR Content tetap standard unique ID component unit, TAPI relasi di DB sudah ada.
          // Kalo user mau di QR String ada parent ID, format QR harus ganti.
          // Asumsi: "QR ... memiliki ... parent unit id" maksudnya STRUCTURE DATA-nya, bukan literally string QR-nya.
          // KARENA di prompt dibilang: "QR 1 ... (memiliki variantid, komponenid, parent unit id = qr3.id)" -> ini deskripsi object/recordnya.

          qrResult = 'U$userId|$companyCode|$componentId|$unitId';
        } else {
          qrResult = 'U$userId|$companyCode|$variantId|$unitId';
        }

        dev.log(qrResult, name: 'QR RESULT');
        final companion = UnitsCompanion.insert(
          id: unitId,
          variantId: Value(variantId),
          componentId: Value(componentId),
          parentUnitId: Value(parentUnitId), // 👈 Insert Parent Link here!
          rackId: Value(rackId),
          qrValue: qrResult,
          status: const Value(pendingStatus),

          // Audit Trails
          createdBy: Value(userId.toString()),
          createdAt: now,
          updatedAt: now,

          // Sync Flags
          needSync: const Value(true),
          lastModifiedAt: Value(now),
        );

        final row = await db.into(db.units).insertReturning(companion);
        generatedUnits.add(row);
      }

      return generatedUnits;
    });
  }

  /// Create Parent Unit Entry (Pending) without components initially
  Future<Unit> createParentUnitEntry({
    required String variantId,
    required String rackId,
    required String companyCode,
    required int userId,
  }) async {
    final now = DateTime.now();
    final parentId = generateCustomId(unitsPrefix);
    final parentQr = 'U$userId|$companyCode|$variantId|$parentId';

    final parentEntry = UnitsCompanion.insert(
      id: parentId,
      variantId: Value(variantId),
      componentId: const Value(null),
      qrValue: parentQr,
      status: const Value(pendingStatus),
      rackId: Value(rackId),
      createdBy: Value(userId.toString()),
      updatedBy: Value(userId.toString()),
      lastModifiedAt: Value(now),
      needSync: const Value(true),
      createdAt: now,
      updatedAt: now,
    );

    return await db.into(db.units).insertReturning(parentEntry);
  }

  Future<void> recordPrintedUnits({
    required List<String> unitIds,
    required int userId,
  }) async {
    return db.unitDao.markUnitsPrinted(unitIds, userId);
  }

  Future<void> finalizeValidatedUnits({
    required List<String> unitIds,
    required int userId,
  }) async {
    // Gunakan transaction untuk menjamin data konsisten
    await db.transaction(() async {
      // 1. Aktifkan Unit yang dipilih (Parent atau Single Unit)
      await db.unitDao.markUnitsActive(unitIds, userId);

      // 2. CASCADING UPDATE (THE FIX)
      // Cari semua unit 'anak' yang parent_unit_id-nya adalah salah satu dari unitIds yang sedang divalidasi.
      // Update status mereka menjadi activeStatus juga.

      await (db.update(
        db.units,
      )..where((tbl) => tbl.parentUnitId.isIn(unitIds))).write(
        const UnitsCompanion(
          status: Value(activeStatus),
          // Opsional: update lastModifiedAt agar ter-sync ke server
          // lastModifiedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> cancelGeneratedUnits({required List<String> unitIds}) async {
    return db.unitDao.deletePendingUnits(unitIds);
  }

  Future<UnitWithRelations?> findUnitByQr(String qr) async {
    return db.unitDao.findByQrWithJoins(qr);
  }

  Future<List<VariantComponentRow>> getVariantComponentsByType({
    required String variantId,
    required int type,
  }) {
    return _variantDao.getVariantComponentsByType(
      variantId: variantId,
      type: type,
    );
  }

  /// Get variant by ID untuk keperluan edit
  Future<Variant?> getVariantById(String variantId) async {
    return await _variantDao.getVariantById(variantId);
  }

  /// Get brand by ID
  Future<Brand?> getBrandById(String brandId) async {
    return await _brandDao.getById(brandId);
  }

  /// Get rack by ID
  Future<Rack?> getRackById(String rackId) async {
    return await _rackDao.getById(rackId);
  }

  /// Get variant photos by variant ID
  Future<List<VariantPhoto>> getVariantPhotos(String variantId) async {
    return await _variantPhotoDao.getPhotosByVariantId(variantId);
  }

  /// Update existing variant
  Future<void> updateVariant({
    required String variantId,
    required String? brandId,
    required String variantName,
    required String uom,
    String? rackId,
    String? specification,
    String? manufCode,
    required int userId,
  }) async {
    final now = DateTime.now();

    await db.transaction(() async {
      // Update variant
      final variantCompanion = VariantsCompanion(
        id: Value(variantId),
        brandId: Value(brandId),
        name: Value(variantName),
        uom: Value(uom),
        rackId: Value(rackId),
        specification: Value(specification),
        manufCode: Value(manufCode),
        updatedAt: Value(now),
        lastModifiedAt: Value(now),
        needSync: const Value(true),
      );

      await _variantDao.updateVariant(variantCompanion);

      dev.log(variantCompanion.toString(), name: 'UPDATE VARIANT');
    });
  }

  /// Setup company_item (is_set, has_components) + create/update 1 variant + photos.
  Future<void> createVariant({
    required bool isSetUp,
    required String companyItemId,
    required String? brandId,
    required String variantName,
    required String uom,
    String? rackId,
    String? specification,
    String? manufCode,
    required List<String> photoLocalPaths,
    required int userId,
  }) async {
    final now = DateTime.now();
    if (photoLocalPaths.isEmpty) {
      throw Exception('Foto produk tidak boleh kosong');
    }
    await db.transaction(() async {
      final companyItem = await _companyItemDao.getById(companyItemId);
      if (companyItem == null) throw Exception('Company item not found');

      if (isSetUp && companyItem.defaultRackId == null && rackId != null) {
        await _companyItemDao.updateDefaultRackCompanyItem(
          id: companyItemId,
          rackId: rackId,
        );
      }

      final variantId = generateCustomId(variantsPrefix);
      final variantCompanion = VariantsCompanion(
        id: Value(variantId),
        companyItemId: Value(companyItemId),
        brandId: Value(brandId),
        name: Value(variantName),
        uom: Value(uom),
        rackId: Value(rackId),
        specification: Value(specification),
        manufCode: Value(manufCode),
        createdAt: Value(now),
        updatedAt: Value(now),
        lastModifiedAt: Value(now),
        needSync: const Value(true),
      );

      await _variantDao.upsertVariants([variantCompanion]);

      dev.log(variantCompanion.toString(), name: 'CREATE VARIANT');

      final photoCompanions = <VariantPhotosCompanion>[];
      for (var i = 0; i < photoLocalPaths.length; i++) {
        final photoId = generateCustomId(variantPhotosPrefix);
        photoCompanions.add(
          VariantPhotosCompanion(
            id: Value(photoId),
            variantId: Value(variantId),
            localPath: Value(photoLocalPaths[i]),
            remoteUrl: const Value(null),
            sortOrder: Value(i),
            createdAt: Value(now),
            updatedAt: Value(now),
            lastModifiedAt: Value(now),
            needSync: const Value(true),
          ),
        );
      }
      await _variantPhotoDao.upsertPhotos(photoCompanions);
    });
  }

  /// Membuat 1 unit SET untuk variant (label as set) - Single.
  Future<String> createSetUnit({
    required String variantId,
    String? rackId,
    required String qrValue,
    required String userId,
  }) async {
    final now = DateTime.now();
    final unitId = generateCustomId(unitsPrefix);

    final companion = UnitsCompanion(
      id: Value(unitId),
      variantId: Value(variantId),
      componentId: const Value(null),
      qrValue: Value(qrValue),
      status: const Value(activeStatus),
      rackId: Value(rackId),
      printCount: const Value(1),
      lastPrintedAt: Value(now),
      createdBy: Value(userId),
      updatedBy: Value(userId),
      lastPrintedBy: Value(userId),
      lastModifiedAt: Value(now),
      needSync: const Value(true),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _unitDao.insertUnit(companion);

    return unitId;
  }

  @override
  Future<ScanUnitResult?> scanUnitByQr(String qrValue) async {
    final joined = await _unitDao.findByQrWithJoins(qrValue);
    if (joined == null) return null;

    final u = joined.unit;
    final c = joined.component;
    final v = joined.variant;

    return ScanUnitResult(
      unitId: u.id,
      qrValue: u.qrValue,
      status: u.status,
      componentId: c?.id,
      componentName: c?.name,
      variantId: v?.id,
      variantName: v?.name,
    );
  }

  Future<void> activateAllUnitComponents({
    required List<String> componentUnitIds,
    required int userId,
  }) async {
    final now = DateTime.now();
    await _unitDao.activateAllUnitComponents(
      componentUnitIds: componentUnitIds,
      userId: userId,
      now: now,
    );
  }

  Future<UnitWithRelations?> scanQrUnit(String qrValue) async {
    try {
      // Trim whitespace untuk menghindari false negative
      final cleanQr = qrValue.trim();

      if (cleanQr.isEmpty) {
        return null;
      }

      // Query database dengan joins
      final result = await _unitDao.findByQrWithJoins(cleanQr);

      return result;
    } catch (e) {
      print('Error scanning QR: $e');
      rethrow;
    }
  }

  /// Watch all racks with warehouse and sections info
  Stream<List<RackWithWarehouseAndSections>> watchRacks() {
    return _rackDao.watchRacksWithWarehouseAndSections();
  }

  /// Get all warehouses for dropdown
  Future<List<Warehouse>> getWarehouses() async {
    return await _rackDao.getAllWarehouses();
  }

  /// Create new rack
  Future<String> createRack({
    required String name,
    required String warehouseId,
  }) async {
    final now = DateTime.now();
    final rackId = generateCustomId(racksPrefix);

    final companion = RacksCompanion.insert(
      id: rackId,
      name: name,
      warehouseId: warehouseId,
      createdAt: now,
      updatedAt: now,
      lastModifiedAt: Value(now),
      needSync: const Value(true),
    );

    await _rackDao.upsertRacks([companion]);
    return rackId;
  }

  /// Update existing rack
  Future<void> updateRack({
    required String rackId,
    required String name,
    required String warehouseId,
  }) async {
    final now = DateTime.now();

    final companion = RacksCompanion(
      id: Value(rackId),
      name: Value(name),
      warehouseId: Value(warehouseId),
      updatedAt: Value(now),
      lastModifiedAt: Value(now),
      needSync: const Value(true),
    );

    await _rackDao.updateRack(companion);
  }

  /// Delete rack (soft delete)
  Future<void> deleteRack(String rackId) async {
    await _rackDao.softDeleteRack(rackId);
  }
}
