import 'package:flutter/material.dart';
import 'package:inventory_sync_apps/core/styles/color_scheme.dart';
import 'package:inventory_sync_apps/core/utils/custom_back_button.dart';
import 'package:inventory_sync_apps/features/purchase_order/widget/purchase_item_card.dart';
import 'package:inventory_sync_apps/shared/presentation/widgets/primary_button.dart';

class PurchaseOrderDetailScreen extends StatelessWidget {
  const PurchaseOrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: CustomBackButton(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1),
        ),
        title: Text(
          'Detail Pembelian',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(width: 1.0, color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 2,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              margin: EdgeInsets.only(top: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                spacing: 2,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PO-2024-0089',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'PT MAJU JAYA',
                              style: TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '4/9',
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'ITEM',
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(10),
                    value: 4 / 9,
                    color: AppColors.success,
                    backgroundColor: Colors.grey[300],
                    minHeight: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Text(
                      'ITEM UNTUK DIPROSES',
                      style: TextStyle(
                        letterSpacing: 1.2,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      spacing: 10,
                      children: [
                        SizedBox(height: 2),
                        PurchaseItemCard(
                          itemCode: 'TEC-M-SP-0089',
                          itemName: 'Bearing',
                          total: 12,
                          current: 10,
                          uom: 'pcs',
                        ),
                        PurchaseItemCard(
                          itemCode: 'TEC-M-SP-0089',
                          itemName: 'Bearing',
                          total: 12,
                          current: 10,
                          uom: 'pcs',
                        ),
                        PurchaseItemCard(
                          itemCode: 'TEC-M-SP-0089',
                          itemName: 'Bearing',
                          total: 12,
                          current: 10,
                          uom: 'pcs',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
