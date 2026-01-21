import 'package:flutter/material.dart';
import 'package:inventory_sync_apps/core/styles/color_scheme.dart';
import 'package:inventory_sync_apps/core/utils/custom_back_button.dart';
import 'package:inventory_sync_apps/features/purchase_order/screen/purchase_order_detail_screen.dart';
import 'package:inventory_sync_apps/features/purchase_order/widget/purchase_order_card.dart';
import 'package:inventory_sync_apps/shared/presentation/widgets/primary_button.dart';
import 'package:inventory_sync_apps/shared/presentation/widgets/search_field_widget.dart';

class PurchaseOrderListScreen extends StatelessWidget {
  const PurchaseOrderListScreen({super.key});

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
          'Penerimaan Barang',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            sliver: SliverToBoxAdapter(
              child: SearchFieldWidget(
                onChanged: (value) {},
                hintText: 'Cari nomor PO',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAFTAR PO',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // SizedBox(height: 10),
                  PurchaseOrderCard(
                    poNumber: 'PO-2024-0086',
                    supplier: 'PT Steel Indonesia',
                    poDate: DateTime.now(),
                    progressItem: 9,
                    totalItem: 9,
                  ),
                  PurchaseOrderCard(
                    poNumber: 'PO-2024-0089',
                    supplier: 'PT Maju Jaya',
                    poDate: DateTime.now(),
                    totalItem: 9,
                    progressItem: 0,
                  ),
                  PurchaseOrderCard(
                    poNumber: 'PO-2024-0088',
                    supplier: 'CV Teknik Indo',
                    poDate: DateTime.now(),
                    totalItem: 7,
                    progressItem: 5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
