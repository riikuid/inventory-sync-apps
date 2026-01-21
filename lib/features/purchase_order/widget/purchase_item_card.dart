import 'package:flutter/material.dart';
import 'package:inventory_sync_apps/core/styles/color_scheme.dart';
import 'package:inventory_sync_apps/shared/presentation/widgets/primary_button.dart';

class PurchaseItemCard extends StatelessWidget {
  final String itemCode;
  final String itemName;
  final int total;
  final int current;
  final String uom;
  const PurchaseItemCard({
    super.key,
    required this.itemCode,
    required this.itemName,
    required this.total,
    required this.current,
    required this.uom,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      padding: EdgeInsets.all(16),
      elevation: 0,
      color: AppColors.surface,
      borderColor: AppColors.border,
      radius: 20,
      borderWidth: 1.2,
      onPressed: () {
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) =>
        //         PurchaseOrderDetailScreen(),
        //   ),
        // );
      },
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              // spacing: 2,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemCode,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),

                Text(
                  itemName,
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
            spacing: 1.2,
            children: [
              Text(
                '$current/$total',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                uom,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.onSurface),
        ],
      ),
    );
  }
}
