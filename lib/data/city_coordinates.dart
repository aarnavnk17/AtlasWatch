import 'package:latlong2/latlong.dart';

class CityCoordinates {
  static final Map<String, LatLng> _coordinates = {
    // Andhra Pradesh
    'Visakhapatnam': const LatLng(17.6868, 83.2185),
    'Vijayawada': const LatLng(16.5062, 80.6480),
    'Guntur': const LatLng(16.3067, 80.4365),
    'Nellore': const LatLng(14.4426, 79.9865),
    'Kurnool': const LatLng(15.8281, 78.0373),
    
    // Arunachal Pradesh
    'Itanagar': const LatLng(27.0844, 93.6053),
    'Tawang': const LatLng(27.5861, 91.8594),
    'Pasighat': const LatLng(28.0665, 95.3275),
    'Ziro': const LatLng(27.5946, 93.8443),
    'Bomdila': const LatLng(27.2645, 92.4159),

    // Assam
    'Guwahati': const LatLng(26.1158, 91.7086),
    'Silchar': const LatLng(24.8170, 92.8023),
    'Dibrugarh': const LatLng(27.4728, 94.9120),
    'Jorhat': const LatLng(26.7509, 94.2037),
    'Tezpur': const LatLng(26.6528, 92.7926),

    // Bihar
    'Patna': const LatLng(25.5941, 85.1376),
    'Gaya': const LatLng(24.7914, 85.0002),
    'Muzaffarpur': const LatLng(26.1197, 85.3910),
    'Bhagalpur': const LatLng(25.2425, 87.0118),
    'Darbhanga': const LatLng(26.1118, 85.8960),

    // Chhattisgarh
    'Raipur': const LatLng(21.2514, 81.6296),
    'Bhilai': const LatLng(21.1938, 81.3509),
    'Bilaspur': const LatLng(22.0797, 82.1409),
    'Korba': const LatLng(22.3569, 82.6807),
    'Durg': const LatLng(21.1904, 81.2849),

    // Goa
    'Panaji': const LatLng(15.4909, 73.8278),
    'Margao': const LatLng(15.2832, 73.9862),
    'Vasco da Gama': const LatLng(15.3991, 73.8125),
    'Mapusa': const LatLng(15.5945, 73.8166),
    'Ponda': const LatLng(15.4026, 74.0182),

    // Gujarat
    'Ahmedabad': const LatLng(23.0225, 72.5714),
    'Surat': const LatLng(21.1702, 72.8311),
    'Vadodara': const LatLng(22.3072, 73.1812),
    'Rajkot': const LatLng(22.3039, 70.8022),
    'Bhavnagar': const LatLng(21.7645, 72.1519),

    // Haryana
    'Gurugram': const LatLng(28.4595, 77.0266),
    'Faridabad': const LatLng(28.4089, 77.3178),
    'Panipat': const LatLng(29.3909, 76.9635),
    'Ambala': const LatLng(30.3782, 76.7767),
    'Rohtak': const LatLng(28.8955, 76.6066),

    // Himachal Pradesh
    'Shimla': const LatLng(31.1048, 77.1734),
    'Manali': const LatLng(32.2396, 77.1887),
    'Dharamshala': const LatLng(32.2190, 76.3239),
    'Solan': const LatLng(30.9084, 77.0999),
    'Mandi': const LatLng(31.5892, 76.9182),

    // Jharkhand
    'Ranchi': const LatLng(23.3441, 85.3096),
    'Jamshedpur': const LatLng(22.8046, 86.2029),
    'Dhanbad': const LatLng(23.7957, 86.4304),
    'Bokaro': const LatLng(23.6693, 86.1511),
    'Hazaribagh': const LatLng(23.9962, 85.3629),

    // Karnataka
    'Bengaluru': const LatLng(12.9716, 77.5946),
    'Mysuru': const LatLng(12.2958, 76.6394),
    'Hubballi': const LatLng(15.3647, 75.1240),
    'Mangaluru': const LatLng(12.9141, 74.8560),
    'Belagavi': const LatLng(15.8497, 74.4977),

    // Kerala
    'Kochi': const LatLng(9.9312, 76.2673),
    'Thiruvananthapuram': const LatLng(8.5241, 76.9366),
    'Kozhikode': const LatLng(11.2588, 75.7804),
    'Thrissur': const LatLng(10.5276, 76.2144),
    'Kollam': const LatLng(8.8932, 76.6141),

    // Madhya Pradesh
    'Indore': const LatLng(22.7196, 75.8577),
    'Bhopal': const LatLng(23.2599, 77.4126),
    'Gwalior': const LatLng(26.2183, 78.1828),
    'Jabalpur': const LatLng(23.1815, 79.9864),
    'Ujjain': const LatLng(23.1765, 75.7885),

    // Maharashtra
    'Mumbai': const LatLng(19.0760, 72.8777),
    'Pune': const LatLng(18.5204, 73.8567),
    'Nagpur': const LatLng(21.1458, 79.0882),
    'Thane': const LatLng(19.2183, 72.9781),
    'Nashik': const LatLng(19.9975, 73.7898),

    // Manipur
    'Imphal': const LatLng(24.8170, 93.9368),
    'Churachandpur': const LatLng(24.3364, 93.6707),
    'Thoubal': const LatLng(24.6401, 93.9933),
    'Kakching': const LatLng(24.4984, 93.9678),
    'Ukhrul': const LatLng(25.1111, 94.3582),

    // Meghalaya
    'Shillong': const LatLng(25.5788, 91.8933),
    'Tura': const LatLng(25.5141, 90.2030),
    'Jowai': const LatLng(25.4526, 92.2030),
    'Nongpoh': const LatLng(25.9080, 91.8688),
    'Williamnagar': const LatLng(25.4983, 90.6276),

    // Mizoram
    'Aizawl': const LatLng(23.7271, 92.7176),
    'Lunglei': const LatLng(22.8844, 92.7302),
    'Champhai': const LatLng(23.4759, 93.3293),
    'Kolasib': const LatLng(24.2186, 92.6841),
    'Serchhip': const LatLng(23.2872, 92.8390),

    // Nagaland
    'Kohima': const LatLng(25.6751, 94.1086),
    'Dimapur': const LatLng(25.8629, 93.7538),
    'Mokokchung': const LatLng(26.3236, 94.5126),
    'Tuensang': const LatLng(26.2796, 94.8214),
    'Wokha': const LatLng(26.1030, 94.2690),

    // Odisha
    'Bhubaneswar': const LatLng(20.2961, 85.8245),
    'Cuttack': const LatLng(20.4625, 85.8828),
    'Rourkela': const LatLng(22.2604, 84.8536),
    'Berhampur': const LatLng(19.3149, 84.7941),
    'Sambalpur': const LatLng(21.4669, 83.9812),

    // Punjab
    'Ludhiana': const LatLng(30.9010, 75.8573),
    'Amritsar': const LatLng(31.6340, 74.8723),
    'Jalandhar': const LatLng(31.3260, 75.5762),
    'Patiala': const LatLng(30.3398, 76.3869),
    'Bathinda': const LatLng(30.2110, 74.9455),

    // Rajasthan
    'Jaipur': const LatLng(26.9124, 75.7873),
    'Jodhpur': const LatLng(26.2389, 73.0243),
    'Kota': const LatLng(25.2138, 75.8648),
    'Udaipur': const LatLng(24.5854, 73.7125),
    'Ajmer': const LatLng(26.4499, 74.6399),

    // Sikkim
    'Gangtok': const LatLng(27.3389, 88.6065),
    'Namchi': const LatLng(27.1668, 88.3610),
    'Geyzing': const LatLng(27.3005, 88.2435),
    'Mangan': const LatLng(27.5029, 88.5309),
    'Rangpo': const LatLng(27.1751, 88.5298),

    // Tamil Nadu
    'Chennai': const LatLng(13.0827, 80.2707),
    'Coimbatore': const LatLng(11.0168, 76.9558),
    'Madurai': const LatLng(9.9252, 78.1198),
    'Tiruchirappalli': const LatLng(10.7905, 78.7047),
    'Salem': const LatLng(11.6643, 78.1460),

    // Telangana
    'Hyderabad': const LatLng(17.3850, 78.4867),
    'Warangal': const LatLng(17.9689, 79.5941),
    'Nizamabad': const LatLng(18.6725, 78.0941),
    'Karimnagar': const LatLng(18.4386, 79.1288),
    'Khammam': const LatLng(17.2473, 80.1514),

    // Tripura
    'Agartala': const LatLng(23.8315, 91.2868),
    'Dharmanagar': const LatLng(24.3794, 92.1691),
    'Udaipur': const LatLng(23.5350, 91.4883),
    'Kailashahar': const LatLng(24.3263, 92.0164),
    'Belonia': const LatLng(23.2505, 91.4552),

    // Uttar Pradesh
    'Lucknow': const LatLng(26.8467, 80.9462),
    'Kanpur': const LatLng(26.4499, 80.3319),
    'Ghaziabad': const LatLng(28.6692, 77.4538),
    'Agra': const LatLng(27.1767, 78.0081),
    'Varanasi': const LatLng(25.3176, 82.9739),

    // Uttarakhand
    'Dehradun': const LatLng(30.3165, 78.0322),
    'Haridwar': const LatLng(29.9457, 78.1642),
    'Rishikesh': const LatLng(30.0869, 78.2676),
    'Haldwani': const LatLng(29.2190, 79.5126),
    'Roorkee': const LatLng(29.8543, 77.8880),

    // West Bengal
    'Kolkata': const LatLng(22.5726, 88.3639),
    'Howrah': const LatLng(22.5958, 88.2636),
    'Durgapur': const LatLng(23.5204, 87.3119),
    'Asansol': const LatLng(23.6739, 86.9524),
    'Siliguri': const LatLng(26.7271, 88.3953),

    // Delhi
    'New Delhi': const LatLng(28.6139, 77.2090),
    'Delhi': const LatLng(28.7041, 77.1025),
  };

  /// Fetch LatLng for a city name (case-insensitive)
  static LatLng? get(String city) {
    for (var key in _coordinates.keys) {
      if (key.toLowerCase() == city.toLowerCase().trim()) {
        return _coordinates[key];
      }
    }
    return null;
  }
}
