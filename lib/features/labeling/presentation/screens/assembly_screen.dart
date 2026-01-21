import 'package:ellipsized_text/ellipsized_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_sync_apps/core/db/daos/variant_dao.dart';
import 'package:inventory_sync_apps/core/utils/custom_back_button.dart';
import 'package:inventory_sync_apps/features/labeling/data/labeling_repository.dart';
import 'package:inventory_sync_apps/features/printer/screen/printer_management_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../../core/db/model/variant_component_row.dart';
import '../../../../core/styles/app_style.dart';
import '../../../../core/styles/color_scheme.dart';
import '../../../../core/styles/text_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../printer/bloc/printer_cubit.dart';
import '../bloc/assembly/assembly_cubit.dart';
import '../bloc/create_labels/create_labels_cubit.dart';
import 'preview_print_screen.dart';

class AssemblyScreen extends StatefulWidget {
  final String variantId;
  final String variantName;
  final String companyCode;
  final int userId;
  final String variantManufCode;
  final String rackId;
  final String rackName;
  final List<VariantComponentRow> targetComponents;

  const AssemblyScreen({
    super.key,
    required this.variantId,
    required this.variantName,
    required this.companyCode,
    required this.userId,
    required this.targetComponents,
    required this.variantManufCode,
    required this.rackId,
    required this.rackName,
  });

  @override
  State<AssemblyScreen> createState() => _AssemblyScreenState();
}

class _AssemblyScreenState extends State<AssemblyScreen> {
  @override
  void initState() {
    super.initState();
    // Load & Auto Generate QR saat masuk
    context.read<AssemblyCubit>().loadRequirements(
      inBoxComponents: widget.targetComponents,
      variantRackId: widget.rackId,
      variantRackName: widget.rackName,
      userId: widget.userId,
      companyCode: widget.companyCode,
    );

    // Scan printer
    context.read<PrinterCubit>().scanPrinters();
  }

  // 👇 UPDATED: Print UNIT individual (bukan component)
  Future<void> _printUnit(int unitIndex) async {
    final printerCubit = context.read<PrinterCubit>();
    final assemblyCubit = context.read<AssemblyCubit>();
    final unit = assemblyCubit.state.units[unitIndex];

    final success = await printerCubit.printLabel(
      location: unit.rackName,
      name: unit.componentName,
      manufCode: unit.manufCode,
      qrValue: unit.qrValue,
      companyCode: widget.companyCode,
    );

    if (success) {
      assemblyCubit.markAsPrinted(unitIndex);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Label tercetak"),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 500),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal print. Cek koneksi."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // 👇 UPDATED: Print semua units
  Future<void> _printAllUnits({bool isReprint = false}) async {
    final printerCubit = context.read<PrinterCubit>();
    final assemblyCubit = context.read<AssemblyCubit>();
    final units = assemblyCubit.state.units;

    if (!printerCubit.state.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Printer belum terhubung!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isReprint ? "Mencetak ulang semua..." : "Mencetak semua label...",
        ),
        backgroundColor: Colors.blue,
      ),
    );

    for (int i = 0; i < units.length; i++) {
      bool shouldPrint = isReprint ? true : !units[i].isPrinted;

      if (shouldPrint) {
        await _printUnit(i);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  // Finalisasi Assembly
  void _onProceedToParent() async {
    final assemblyCubit = context.read<AssemblyCubit>();

    final parentUnit = await assemblyCubit.createDraftSet(
      userId: widget.userId,
      companyCode: widget.companyCode,
      rackId: widget.rackId,
      rackName: widget.rackName,
    );

    if (parentUnit != null && mounted) {
      final labelingRepo = RepositoryProvider.of<LabelingRepository>(context);

      bool? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (ctx) => CreateLabelsCubit(labelingRepo)
              ..loadExistingUnit(
                unit: parentUnit,
                itemName: widget.variantName,
                companyCode: widget.companyCode,
                rackName: widget.rackName,
              ),
            child: PreviewPrintScreen(
              userId: widget.userId,
              companyCode: widget.companyCode,
              manufcode: widget.variantManufCode,
              rackName: widget.rackName,
            ),
          ),
        ),
      );

      if (result == true) {
        await context.read<AssemblyCubit>().activateAllUnitComponents(
          userId: widget.userId,
        );
        if (mounted) Navigator.pop(context);
      } else if (result == false && mounted) {
        await context.read<AssemblyCubit>().cancelAssembly();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PrinterCubit, PrinterState>(
      listener: (context, printerState) {
        if (printerState.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(printerState.error!),
              backgroundColor: Colors.red,
            ),
          );
        }

        if (printerState.statusMessage.isNotEmpty &&
            printerState.statusMessage != "Siap Connect" &&
            printerState.statusMessage != "Disconnected") {
          Color color = Colors.blue;
          if (printerState.isConnected) color = Colors.green;
          if (printerState.statusMessage.contains("Gagal")) color = Colors.red;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(printerState.statusMessage),
              backgroundColor: color,
            ),
          );
        }
      },
      child: BlocBuilder<PrinterCubit, PrinterState>(
        builder: (context, printerState) {
          return BlocConsumer<AssemblyCubit, AssemblyState>(
            listener: (context, state) {
              if (state.lastScanMessage != null) {
                final isError = state.lastScanMessage!.contains('tidak');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.lastScanMessage!),
                    backgroundColor: isError ? Colors.red : Colors.green,
                  ),
                );
              }
            },
            builder: (context, assemblyState) {
              // 👇 UPDATED: Gunakan units, bukan components
              final isComplete = assemblyState.isAllUnitsScanned;
              final hasStartedPrinting = assemblyState.units.any(
                (u) => u.isPrinted || u.isScanned,
              );

              return WillPopScope(
                onWillPop: () async {
                  final leave = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        'Batalkan Proses Pelabelan?',
                        style: AppTextStyles.mono.copyWith(
                          color: AppColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: const Text(
                        'Unit QR sudah dibuat. Keluar sekarang akan menghapus data tersebut.',
                        style: TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text(
                            'Tetap Lanjut',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Hapus & Keluar',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (leave == true && mounted) {
                    await context.read<AssemblyCubit>().cancelAssembly();
                    return true;
                  }
                  return false;
                },
                child: Scaffold(
                  backgroundColor: AppColors.background,
                  appBar: AppBar(
                    iconTheme: IconThemeData(color: AppColors.onSurface),
                    leading: CustomBackButton(),
                    backgroundColor: AppColors.background,
                    elevation: 0.5,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Isi Box Komponen',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.variantName,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  body: Column(
                    children: [
                      _buildConnectionBar(context, printerState),

                      // 👇 UPDATED: Progress Info
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Status Box:",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.onBackground,
                              ),
                            ),
                            Text(
                              "${assemblyState.units.where((u) => u.isScanned).length} / ${assemblyState.units.length} Unit Tervalidasi",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isComplete
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 👇 UPDATED: Progress Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(
                          value: assemblyState.units.isEmpty
                              ? 0
                              : assemblyState.units
                                        .where((u) => u.isScanned)
                                        .length /
                                    assemblyState.units.length,
                          backgroundColor: Colors.grey.shade200,
                          color: isComplete ? Colors.green : AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),

                      // 👇 UPDATED: LIST UNITS (FLAT)
                      Expanded(
                        child: assemblyState.status == AssemblyStatus.loading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: assemblyState.units.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, index) {
                                  final unit = assemblyState.units[index];
                                  return _buildUnitCard(
                                    unit,
                                    unitIndex: index,
                                    isPrinterConnected:
                                        printerState.isConnected,
                                    hasStartedPrinting: hasStartedPrinting,
                                    onPrint: () => _printUnit(index),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // 👇 UPDATED: Bottom Bar
                  bottomNavigationBar: _buildBottomBar(
                    context,
                    assemblyState,
                    printerState.isConnected,
                    isComplete,
                    hasStartedPrinting,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 👇 UPDATED: Unit Card (bukan Component Card)
  Widget _buildUnitCard(
    AssemblyUnitItem unit, {
    required int unitIndex,
    required bool isPrinterConnected,
    required bool hasStartedPrinting,
    required VoidCallback onPrint,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (unit.isScanned) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = "Valid";
    } else if (unit.isPrinted) {
      statusColor = Colors.orange;
      statusIcon = Icons.print;
      statusText = "Tercetak";
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.hourglass_empty;
      statusText = "Pending";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [AppStyle.defaultBoxShadow],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20.0)),
                ),
                child: PrettyQrView.data(data: unit.qrValue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EllipsizedText(
                      unit.qrValue,
                      type: EllipsisType.middle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unit.componentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "LOK: ${unit.rackName}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // BADGE STATUS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // BUTTON: CETAK ULANG
              if (hasStartedPrinting && !unit.isScanned)
                CustomButton(
                  elevation: 0.2,
                  width: 30,
                  height: 30,
                  padding: EdgeInsets.symmetric(vertical: 5, horizontal: 15),
                  radius: 15,
                  color: isPrinterConnected
                      ? AppColors.surface
                      : Colors.grey.shade300,
                  borderColor: AppColors.border,
                  onPressed: isPrinterConnected ? onPrint : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.print_outlined,
                        size: 14,
                        color: isPrinterConnected
                            ? Colors.grey.shade500
                            : AppColors.onBackground,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Cetak Ulang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPrinterConnected
                              ? Colors.grey.shade500
                              : AppColors.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BOTTOM BAR ---
  Widget _buildBottomBar(
    BuildContext context,
    AssemblyState state,
    bool isPrinterConnected,
    bool isComplete,
    bool hasStartedPrinting,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: _buildBottomBarContent(
        context,
        state,
        isPrinterConnected,
        isComplete,
        hasStartedPrinting,
      ),
    );
  }

  Widget _buildBottomBarContent(
    BuildContext context,
    AssemblyState state,
    bool isPrinterConnected,
    bool isComplete,
    bool hasStartedPrinting,
  ) {
    // KONDISI 1: SUDAH SELESAI
    if (isComplete) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _onProceedToParent,
          child: const Text(
            "GENERATE LABEL BOX",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      );
    }

    // KONDISI 2: FASE VALIDASI
    if (hasStartedPrinting) {
      return Row(
        children: [
          Expanded(
            child: CustomButton(
              elevation: 0,
              radius: 40,
              height: 50,
              color: !isPrinterConnected ? Colors.grey : AppColors.secondary,
              onPressed: isPrinterConnected
                  ? () => _printAllUnits(isReprint: true)
                  : null,
              child: Row(
                spacing: 5,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_print_shop_outlined,
                    color: !isPrinterConnected
                        ? AppColors.onSurface.withAlpha(100)
                        : AppColors.onSurface,
                  ),
                  Text(
                    "Cetak Ulang",
                    style: TextStyle(
                      color: !isPrinterConnected
                          ? AppColors.onSurface.withAlpha(100)
                          : AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CustomButton(
              color: AppColors.surface,
              borderColor: AppColors.border,
              elevation: 0,
              radius: 40,
              height: 50,
              onPressed: () => _openScanner(context.read<AssemblyCubit>()),
              child: Row(
                spacing: 5,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  Text(
                    "Validasi",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // KONDISI 3: PRINT AWAL
    return CustomButton(
      elevation: 0,
      radius: 40,
      height: 50,
      width: double.infinity,
      color: isPrinterConnected ? AppColors.secondary : Colors.grey,
      onPressed: isPrinterConnected
          ? () => _printAllUnits(isReprint: false)
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: [
          Icon(
            Icons.print_outlined,
            size: 18,
            color: isPrinterConnected
                ? AppColors.onSurface
                : AppColors.onSurface.withAlpha(100),
          ),
          Text(
            'CETAK SEMUA',
            style: TextStyle(
              color: isPrinterConnected
                  ? AppColors.onSurface
                  : AppColors.onSurface.withAlpha(100),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // --- CONNECTION BAR ---
  Widget _buildConnectionBar(BuildContext context, PrinterState state) {
    final isConnected = state.isConnected;
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PrinterManagementScreen(),
          ),
        );
        if (context.mounted) {
          context.read<PrinterCubit>().checkConnection();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
          border: Border.symmetric(
            vertical: BorderSide(
              color: isConnected ? Colors.green : Colors.orange,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              size: 20,
              color: isConnected ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected
                        ? "Printer Terhubung"
                        : "Printer Belum Terhubung",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isConnected
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isConnected
                        ? state.selectedDevice?.name ?? 'Unknown'
                        : "Tap untuk menghubungkan",
                    style: TextStyle(
                      fontSize: 12,
                      color: isConnected
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.settings,
              size: 20,
              color: isConnected
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ],
        ),
      ),
    );
  }

  void _openScanner(AssemblyCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: AssemblyScannerModal(cubit: cubit),
      ),
    );
  }
}

// --- SCANNER MODAL ---
class AssemblyScannerModal extends StatefulWidget {
  final AssemblyCubit cubit;
  const AssemblyScannerModal({required this.cubit, super.key});

  @override
  State<AssemblyScannerModal> createState() => _AssemblyScannerModalState();
}

class _AssemblyScannerModalState extends State<AssemblyScannerModal> {
  late MobileScannerController controller;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text("Scan Komponen"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: controller,
                onDetect: (capture) async {
                  if (isProcessing) return;
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (raw == null) return;

                  setState(() => isProcessing = true);

                  await widget.cubit.onScanQr(raw);

                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isProcessing ? Colors.amber : Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
