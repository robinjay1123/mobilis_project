/// Philippine locations data for cascading dropdowns
/// This provides provinces, cities, and barangays for pick-up/drop-off selection

class PhilippineLocations {
  // Main Philippines provinces and their cities
  static final provinces = {
    'Metro Manila': [
      'Makati',
      'Quezon City',
      'Manila',
      'Pasig',
      'Taguig',
      'Valenzuela',
      'Parañaque',
      'Las Piñas',
      'Muntinlupa',
      'Malabon',
      'Navotas',
      'Caloocan',
    ],
    'Cavite': [
      'Dasmariñas',
      'Tagaytay',
      'Bacoor',
      'Kawit',
      'Rosario',
      'Silang',
      'Tanza',
      'Imus',
      'Magallanes',
      'Trece Martires',
    ],
    'Laguna': [
      'Biñan',
      'Cabuyao',
      'Calamba',
      'Sta. Rosa',
      'Laguna',
      'Pagsanjan',
      'Pakilan',
      'Pangil',
      'Pila',
      'Siniloan',
    ],
    'Rizal': [
      'Antipolo',
      'Cainta',
      'Taytay',
      'Morong',
      'Angono',
      'Baras',
      'Bosoboso',
      'Jala-jala',
      'Montalban',
      'Tanay',
    ],
    'Bulacan': [
      'Malolos',
      'Meycauayan',
      'Marilao',
      'Obando',
      'Pandi',
      'Polo',
      'San Ildefonso',
      'Norzagaray',
      'Bustos',
      'Baliuag',
    ],
  };

  // Sample barangays (expanded per city would be ideal)
  static final barangays = {
    'Makati': [
      'Ayala',
      'Bangkal',
      'Barrio Marave',
      'Bel-Air',
      'Cembo',
      'Dasmariñas',
      'East Rembo',
      'Forbes Park',
      'Fort Bonifacio',
      'Magallanes',
    ],
    'Quezon City': [
      'Bagbag',
      'Balangiga',
      'Balingasa',
      'Balintawak',
      'Banavar',
      'Batasan',
      'Batino',
      'Binabanang',
      'Bungad',
      'Caniogan',
    ],
    'Manila': [
      'Binondo',
      'Intramuros',
      'Ermita',
      'Malate',
      'Paco',
      'Pandacan',
      'Port Area',
      'Quiapo',
      'Recto',
      'Sampaloc',
    ],
    'Pasig': [
      'Bagong Ilog',
      'Buting',
      'Caltabellotta',
      'Caruncho',
      'Cintamani',
      'Dela Paz',
      'Doña Imelda',
      'Greyfriar',
      'Kalumputan',
      'Kingina',
    ],
    'Taguig': [
      'Bagumbayan',
      'Bambang',
      'Barrio Mayroon',
      'Binay-Bayanan',
      'Biyaya',
      'Bolbok',
      'Bonifacio',
      'Central Bicutan',
      'Comembo',
      'Cupang',
    ],
    'Default': ['Downtown', 'North', 'South', 'East', 'West'],
  };

  // Default location for PSDC Garage
  static const String psdc_garage = 'PSDC Garage, Manila';

  // Get cities for a province
  static List<String> getCitiesForProvince(String province) {
    return provinces[province] ?? [];
  }

  // Get barangays for a city
  static List<String> getBarangaysForCity(String city) {
    return barangays[city] ?? barangays['Default']!;
  }

  // All provinces available
  static List<String> getAllProvinces() => provinces.keys.toList();

  // Format location as "Barangay, City, Province"
  static String formatLocation(String barangay, String city, String province) {
    return '$barangay, $city, $province';
  }
}
