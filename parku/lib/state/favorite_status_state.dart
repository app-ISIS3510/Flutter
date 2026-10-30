class FavoriteStatusState {
  final bool? isFavorite;
  final bool isBusy;
  final String? errorMessage;
  const FavoriteStatusState({
    this.isFavorite,
    this.isBusy = false,
    this.errorMessage,
  });
}
