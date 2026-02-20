class KenyaLocations {
  // Accurate Data for your Demo
  static const Map<String, List<String>> _data = {
    "Makueni": [
      "Mbooni", "Kilome", "Kaiti", "Kibwezi West", "Kibwezi East", "Makueni"
    ],
    "Nairobi": [
      "Westlands", "Dagoretti North", "Dagoretti South", "Langata", "Kibra",
      "Roysambu", "Kasarani", "Ruaraka", "Embakasi South", "Embakasi North",
      "Embakasi Central", "Embakasi East", "Embakasi West", "Makadara",
      "Kamukunji", "Starehe", "Mathare"
    ],
    "Mombasa": [
      "Changamwe", "Jomvu", "Kisauni", "Nyali", "Likoni", "Mvita"
    ],
    "Kiambu": [
      "Gatundu South", "Gatundu North", "Juja", "Thika Town", "Ruiru",
      "Githunguri", "Kiambu", "Kiambaa", "Kabete", "Kikuyu", "Limuru", "Lari"
    ],
    "Machakos": [
      "Masinga", "Yatta", "Kangundo", "Matungulu", "Kathiani", "Mavoko",
      "Machakos Town", "Mwala"
    ],
    "Nakuru": [
      "Molo", "Njoro", "Naivasha", "Gilgil", "Kuresoi South", "Kuresoi North",
      "Subukia", "Rongai", "Bahati", "Nakuru Town West", "Nakuru Town East"
    ],
    "Uasin Gishu": [
      "Soy", "Turbo", "Moiben", "Ainabkoi", "Kapseret", "Kesses"
    ],
    "Kisumu": [
      "Kisumu East", "Kisumu West", "Kisumu Central", "Seme", "Nyando", "Muhoroni", "Nyakach"
    ]
  };

  /// Returns sorted list of Counties
  static List<String> getCounties() {
    // .toList() creates a new modifiable copy of the keys
    final list = _data.keys.toList();
    list.sort();
    return list;
  }

  /// Returns sorted list of Sub-Counties for the selected County
  static List<String> getSubCounties(String county) {
    // FIX: We must use .toList() to create a COPY of the const list
    // If we try to sort _data[county] directly, it crashes.
    final list = _data[county]?.toList() ?? [];
    list.sort(); 
    return list;
  }
  
  /// Returns Wards (Generic for now)
  static List<String> getWards(String subCounty) {
    return ["Township", "Central Ward", "East Ward", "West Ward", "Market Ward"];
  }
}