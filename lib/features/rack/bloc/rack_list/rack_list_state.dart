part of 'rack_list_cubit.dart';

enum RackListStatus { initial, loading, loaded, error }

enum PrinterConnectionStatus { disconnected, connecting, connected }

class RackListState extends Equatable {
  final RackListStatus status;
  final List<RackWithWarehouseAndSections> racks;
  final List<RackWithWarehouseAndSections> filteredRacks;
  final PrinterConnectionStatus printerStatus;
  final String? searchQuery;
  final String? errorMessage;

  const RackListState({
    required this.status,
    required this.racks,
    required this.filteredRacks,
    required this.printerStatus,
    this.searchQuery,
    this.errorMessage,
  });

  factory RackListState.initial() => const RackListState(
    status: RackListStatus.initial,
    racks: [],
    filteredRacks: [],
    printerStatus: PrinterConnectionStatus.disconnected,
    searchQuery: null,
    errorMessage: null,
  );

  RackListState copyWith({
    RackListStatus? status,
    List<RackWithWarehouseAndSections>? racks,
    List<RackWithWarehouseAndSections>? filteredRacks,
    PrinterConnectionStatus? printerStatus,
    String? searchQuery,
    String? errorMessage,
  }) {
    return RackListState(
      status: status ?? this.status,
      racks: racks ?? this.racks,
      filteredRacks: filteredRacks ?? this.filteredRacks,
      printerStatus: printerStatus ?? this.printerStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    racks,
    filteredRacks,
    printerStatus,
    searchQuery,
    errorMessage,
  ];
}
