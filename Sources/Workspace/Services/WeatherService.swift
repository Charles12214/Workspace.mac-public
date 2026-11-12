import Foundation
import SwiftUI
import CoreLocation
import Combine

// MARK: - Temperature Unit
public enum TemperatureUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"
    
    public var id: String { rawValue }
    
    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    public var displayName: String {
        switch self {
        case .celsius: return "Celsius (°C)"
        case .fahrenheit: return "Fahrenheit (°F)"
        }
    }
}

// MARK: - Hourly Forecast Item
public struct HourlyForecastItem: Identifiable, Sendable {
    public let id = UUID()
    public let timeString: String
    public let temperature: Int
    public let symbolName: String
    public let precipProbability: Int
    
    public init(timeString: String, temperature: Int, symbolName: String, precipProbability: Int) {
        self.timeString = timeString
        self.temperature = temperature
        self.symbolName = symbolName
        self.precipProbability = precipProbability
    }
}

// MARK: - Current Weather Info Model
public struct WeatherInfo: Sendable {
    public let temperature: Double
    public let apparentTemperature: Double
    public let weatherCode: Int
    public let isDay: Bool
    public let humidity: Int
    public let precipitation: Double
    public let conditionName: String
    public let symbolName: String
    public let cityName: String
    public let hourly: [HourlyForecastItem]
    
    public var formattedTemp: String {
        "\(Int(round(temperature)))"
    }
    
    public var formattedApparentTemp: String {
        "\(Int(round(apparentTemperature)))"
    }
}

// MARK: - Weather & Time Service
@MainActor
public final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherService()
    
    // MARK: - Dynamic Weather Symbol Colors
    public static func symbolColor(for name: String) -> Color {
        if name.contains("sun.max") {
            return Color(hex: "F4B400")
        } else if name.contains("sun") {
            return Color(hex: "FBBC04")
        } else if name.contains("rain") || name.contains("drizzle") {
            return Color(hex: "1A73E8")
        } else if name.contains("snow") || name.contains("snowflake") {
            return Color(hex: "00A4F9")
        } else if name.contains("bolt") {
            return Color(hex: "EA4335")
        } else if name.contains("moon") {
            return Color(hex: "9B51E0")
        } else {
            return Color.secondary
        }
    }
    
    // User preferences
    private let kShowWeatherKey = "Workspace_ShowWeather"
    private let kShowTimeKey = "Workspace_ShowTime"
    private let kIs24HourTimeKey = "Workspace_Is24HourTime"
    private let kTemperatureUnitKey = "Workspace_TemperatureUnit"
    
    @Published public var isWeatherEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isWeatherEnabled, forKey: kShowWeatherKey)
            if isWeatherEnabled && weatherInfo == nil {
                fetchWeather()
            }
        }
    }
    
    @Published public var isTimeEnabled: Bool {
        didSet { UserDefaults.standard.set(isTimeEnabled, forKey: kShowTimeKey) }
    }
    
    @Published public var is24HourTime: Bool {
        didSet {
            UserDefaults.standard.set(is24HourTime, forKey: kIs24HourTimeKey)
            updateClock()
        }
    }
    
    @Published public var temperatureUnit: TemperatureUnit {
        didSet {
            UserDefaults.standard.set(temperatureUnit.rawValue, forKey: kTemperatureUnitKey)
            fetchWeather()
        }
    }
    
    // Live State
    @Published public var currentTimeString: String = ""
    @Published public var currentDateString: String = ""
    @Published public var weatherInfo: WeatherInfo? = nil
    @Published public var isLoadingWeather: Bool = false
    @Published public var lastUpdated: Date? = nil
    @Published public var detectedCity: String = "Current Location"
    
    private var clockTimer: AnyCancellable?
    private var weatherTimer: AnyCancellable?
    private var locationManager: CLLocationManager?
    private var lastKnownLocation: CLLocation?
    
    public override init() {
        // Load preferences with sensible defaults
        if UserDefaults.standard.object(forKey: kShowWeatherKey) != nil {
            self.isWeatherEnabled = UserDefaults.standard.bool(forKey: kShowWeatherKey)
        } else {
            self.isWeatherEnabled = true
        }
        
        if UserDefaults.standard.object(forKey: kShowTimeKey) != nil {
            self.isTimeEnabled = UserDefaults.standard.bool(forKey: kShowTimeKey)
        } else {
            self.isTimeEnabled = true
        }
        
        if UserDefaults.standard.object(forKey: kIs24HourTimeKey) != nil {
            self.is24HourTime = UserDefaults.standard.bool(forKey: kIs24HourTimeKey)
        } else {
            // Default to system 24-hour preference if available
            let locale = Locale.current
            let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
            self.is24HourTime = !dateFormat.contains("a")
        }
        
        if let rawUnit = UserDefaults.standard.string(forKey: kTemperatureUnitKey),
           let unit = TemperatureUnit(rawValue: rawUnit) {
            self.temperatureUnit = unit
        } else {
            self.temperatureUnit = .celsius
        }
        
        super.init()
        
        setupClock()
        setupLocation()
        
        if isWeatherEnabled {
            fetchWeather()
        }
    }
    
    // MARK: - Clock Management
    private static let timeFormatter24: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "HH:mm"
        return f
    }()
    
    private static let timeFormatter12: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "h:mm a"
        return f
    }()
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEE, d MMM"
        return f
    }()
    
    private func setupClock() {
        updateClock()
        // Update clock every second, but ONLY publish changes when minute or date actually changes
        clockTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateClock()
            }
    }
    
    private func updateClock() {
        let now = Date()
        let timeFormatter = is24HourTime ? Self.timeFormatter24 : Self.timeFormatter12
        let newTime = timeFormatter.string(from: now)
        if self.currentTimeString != newTime {
            self.currentTimeString = newTime
        }
        
        let newDate = Self.dateFormatter.string(from: now)
        if self.currentDateString != newDate {
            self.currentDateString = newDate
        }
    }
    
    // MARK: - Location & Reverse Geocoding
    public var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager?.authorizationStatus ?? .notDetermined
    }
    
    public var isLocationAuthorized: Bool {
        locationAuthorizationStatus == .authorizedAlways
    }
    
    public func requestLocationAuthorization() {
        let status = locationManager?.authorizationStatus ?? .notDetermined
        if status == .notDetermined {
            locationManager?.requestAlwaysAuthorization()
        } else if status == .authorizedAlways {
            locationManager?.requestLocation()
        } else {
            fetchWeather()
        }
    }
    
    private func setupLocation() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer
        
        let status = locationManager?.authorizationStatus ?? .notDetermined
        if status == .notDetermined {
            locationManager?.requestAlwaysAuthorization()
        } else if status == .authorizedAlways {
            locationManager?.requestLocation()
        }
    }
    
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedAlways {
                self.locationManager?.requestLocation()
            } else {
                // Fallback coordinates if location denied
                self.fetchWeather()
            }
        }
    }
    
    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastKnownLocation = loc
            self.reverseGeocode(location: loc)
            self.fetchWeather()
        }
    }
    
    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // Location fetch failed or denied; proceed with fallback coordinates
            if self.lastKnownLocation == nil {
                self.fetchWeather()
            }
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self = self, let place = placemarks?.first else { return }
            let city = place.locality ?? place.subAdministrativeArea ?? place.name ?? "Current Location"
            Task { @MainActor in
                self.detectedCity = city
                if let cur = self.weatherInfo {
                    self.weatherInfo = WeatherInfo(
                        temperature: cur.temperature,
                        apparentTemperature: cur.apparentTemperature,
                        weatherCode: cur.weatherCode,
                        isDay: cur.isDay,
                        humidity: cur.humidity,
                        precipitation: cur.precipitation,
                        conditionName: cur.conditionName,
                        symbolName: cur.symbolName,
                        cityName: city,
                        hourly: cur.hourly
                    )
                }
            }
        }
    }
    
    // MARK: - Open-Meteo REST Weather Fetching
    public func fetchWeather() {
        guard isWeatherEnabled else { return }
        
        // 1. Determine coordinates (use location or timezone/London fallback)
        let lat: Double
        let lon: Double
        if let loc = lastKnownLocation {
            lat = loc.coordinate.latitude
            lon = loc.coordinate.longitude
        } else {
            // Default to London fallback coordinates
            lat = 51.5074
            lon = -0.1278
        }
        
        let unitParam = temperatureUnit == .fahrenheit ? "fahrenheit" : "celsius"
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code&hourly=temperature_2m,precipitation_probability,weather_code,is_day&temperature_unit=\(unitParam)&forecast_days=2"
        
        guard let url = URL(string: urlString) else { return }
        
        isLoadingWeather = true
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Workspace.mac Weather", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isLoadingWeather = false
                
                guard let data = data,
                      error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current"] as? [String: Any] else {
                    return
                }
                
                let temp = current["temperature_2m"] as? Double ?? 0.0
                let apparent = current["apparent_temperature"] as? Double ?? temp
                let code = current["weather_code"] as? Int ?? 0
                let isDay = (current["is_day"] as? Int ?? 1) == 1
                let humidity = current["relative_humidity_2m"] as? Int ?? 50
                let precip = current["precipitation"] as? Double ?? 0.0
                
                let (condition, symbol) = Self.mapWMOWeatherCode(code, isDay: isDay)
                
                // Parse hourly forecast (next 12 future hours across midnight)
                var hourlyItems: [HourlyForecastItem] = []
                if let hourly = json["hourly"] as? [String: Any],
                   let times = hourly["time"] as? [String],
                   let temps = hourly["temperature_2m"] as? [Double],
                   let codes = hourly["weather_code"] as? [Int],
                   let probs = hourly["precipitation_probability"] as? [Int] {
                    
                    let isDays = hourly["is_day"] as? [Int]
                    let nowIsoHour = ISO8601DateFormatter().string(from: Date()).prefix(13)
                    var startIndex = 0
                    for (idx, timeStr) in times.enumerated() {
                        if timeStr.hasPrefix(String(nowIsoHour)) {
                            startIndex = idx
                            break
                        }
                    }
                    
                    // Show next 12 hours
                    let count = min(times.count, startIndex + 12)
                    for i in startIndex..<count {
                        let tStr = times[i]
                        let tTemp = Int(round(temps[i]))
                        let tCode = codes[i]
                        let tProb = i < probs.count ? probs[i] : 0
                        let tIsDay = (isDays != nil && i < isDays!.count) ? (isDays![i] == 1) : (i % 24 >= 6 && i % 24 <= 20)
                        let (_, tSym) = Self.mapWMOWeatherCode(tCode, isDay: tIsDay)
                        
                        // Format hour string (e.g. "Now", "00:00", "01:00" or "11pm", "12am")
                        let hourDisplay: String
                        if i == startIndex {
                            hourDisplay = "Now"
                        } else if let date = Self.isoDate(from: tStr) {
                            let form = DateFormatter()
                            form.dateFormat = self.is24HourTime ? "HH:mm" : "ha"
                            hourDisplay = form.string(from: date).lowercased()
                        } else {
                            hourDisplay = String(tStr.suffix(5))
                        }
                        
                        hourlyItems.append(HourlyForecastItem(
                            timeString: hourDisplay,
                            temperature: tTemp,
                            symbolName: tSym,
                            precipProbability: tProb
                        ))
                    }
                }
                
                self.weatherInfo = WeatherInfo(
                    temperature: temp,
                    apparentTemperature: apparent,
                    weatherCode: code,
                    isDay: isDay,
                    humidity: humidity,
                    precipitation: precip,
                    conditionName: condition,
                    symbolName: symbol,
                    cityName: self.detectedCity,
                    hourly: hourlyItems
                )
                self.lastUpdated = Date()
                
                // Re-schedule automatic refresh every 20 minutes
                self.weatherTimer?.cancel()
                self.weatherTimer = Timer.publish(every: 1200, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.fetchWeather()
                    }
            }
        }.resume()
    }
    
    private static func isoDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: string)
    }
    
    // MARK: - WMO Weather Interpretation Code Mapping
    public static func mapWMOWeatherCode(_ code: Int, isDay: Bool) -> (condition: String, symbol: String) {
        switch code {
        case 0:
            return ("Clear Sky", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1:
            return ("Mainly Clear", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 2:
            return ("Partly Cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Fog", "cloud.fog.fill")
        case 51, 53, 55:
            return ("Drizzle", "cloud.drizzle.fill")
        case 56, 57:
            return ("Freezing Drizzle", "cloud.sleet.fill")
        case 61, 63:
            return ("Rain", "cloud.rain.fill")
        case 65:
            return ("Heavy Rain", "cloud.heavyrain.fill")
        case 66, 67:
            return ("Freezing Rain", "cloud.sleet.fill")
        case 71, 73:
            return ("Snow", "snowflake")
        case 75:
            return ("Heavy Snow", "snowflake")
        case 77:
            return ("Snow Grains", "snowflake")
        case 80, 81:
            return ("Rain Showers", "cloud.rain.fill")
        case 82:
            return ("Violent Rain", "cloud.heavyrain.fill")
        case 85, 86:
            return ("Snow Showers", "cloud.snow.fill")
        case 95:
            return ("Thunderstorm", "cloud.bolt.rain.fill")
        case 96, 99:
            return ("Thunderstorm & Hail", "cloud.bolt.rain.fill")
        default:
            return ("Fair", isDay ? "sun.max.fill" : "moon.stars.fill")
        }
    }
}
