part of 'company_item_list_cubit.dart';

@immutable
sealed class CompanyItemListState {}

final class CompanyItemListLoading extends CompanyItemListState {}

final class CompanyItemListLoaded extends CompanyItemListState {
  final List<CategorySummary> categories;
  final List<CompanyItemListRow> companyItems;

  CompanyItemListLoaded({required this.categories, required this.companyItems});
}

final class CompanyItemListError extends CompanyItemListState {
  final String message;
  CompanyItemListError(this.message);
}
