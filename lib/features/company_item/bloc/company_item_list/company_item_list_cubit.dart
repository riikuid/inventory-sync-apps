// lib/features/inventory/presentation/bloc/home/home_cubit.dart

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart' show immutable;
import 'package:inventory_sync_apps/core/user_storage.dart';

import 'package:inventory_sync_apps/core/db/daos/category_dao.dart';
import 'package:inventory_sync_apps/core/db/daos/company_item_dao.dart';
import 'package:inventory_sync_apps/features/inventory/data/inventory_repository.dart';

import '../../../auth/models/user.dart';

part 'company_item_list_state.dart';

class CompanyItemListCubit extends Cubit<CompanyItemListState> {
  final InventoryRepository _repository;

  StreamSubscription<List<CategorySummary>>? _categorySub;
  StreamSubscription<List<CompanyItemListRow>>? _companyItemSub;

  List<CategorySummary> _categories = const [];
  List<CompanyItemListRow> _companyItems = const [];

  CompanyItemListCubit(this._repository) : super(CompanyItemListLoading()) {
    _subscribeStreams();
  }

  void _subscribeStreams() async {
    User user = (await UserStorage.getUser())!;
    emit(CompanyItemListLoading());

    _categorySub = _repository.watchRootCategories().listen(
      (cats) {
        _categories = cats;
        _emitCombined();
      },
      onError: (error, _) {
        emit(CompanyItemListError(error.toString()));
      },
    );

    _companyItemSub = _repository
        .watchCompanyItems(sectionId: user.sectionId!)
        .listen(
          (items) {
            _companyItems = items;
            _emitCombined();
          },
          onError: (error, _) {
            emit(CompanyItemListError(error.toString()));
          },
        );
  }

  void _emitCombined() {
    // Jangan override state error
    if (state is CompanyItemListError) return;

    emit(
      CompanyItemListLoaded(
        categories: _categories,
        companyItems: _companyItems,
      ),
    );
  }

  Future<void> refreshFromLocal() async {
    // Karena kita pakai stream dari Drift, data akan auto-refresh ketika sync.
    // Di sini kita cukup emit ulang state Loaded supaya RefreshIndicator selesai.
    _emitCombined();
  }

  @override
  Future<void> close() {
    _categorySub?.cancel();
    _companyItemSub?.cancel();
    return super.close();
  }
}
