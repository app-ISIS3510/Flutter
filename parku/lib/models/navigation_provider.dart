enum NavigationProvider {
  googleMaps('Google Maps', 'google_maps'),
  waze('Waze', 'waze');

  final String label;
  final String analyticsValue;

  const NavigationProvider(this.label, this.analyticsValue);

  NavigationProvider get alternative => this == googleMaps ? waze : googleMaps;
}
