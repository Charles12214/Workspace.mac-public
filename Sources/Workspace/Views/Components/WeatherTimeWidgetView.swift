import SwiftUI
import AppKit

// MARK: - Top Bar Weather & Time Widget Pill
public struct WeatherTimeWidgetView: View {
    @ObservedObject private var service = WeatherService.shared
    @State private var showingPopover: Bool = false
    @State private var isHovered: Bool = false
    
    public init() {}
    
    public var body: some View {
        if service.isTimeEnabled || service.isWeatherEnabled {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 6) {
                    // Local Time
                    if service.isTimeEnabled {
                        Text(service.currentTimeString)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    
                    // Separator dot if both visible
                    if service.isTimeEnabled && service.isWeatherEnabled && service.weatherInfo != nil {
                        Circle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 3, height: 3)
                    }
                    
                    // Weather Symbol & Temperature
                    if service.isWeatherEnabled {
                        if let weather = service.weatherInfo {
                            HStack(spacing: 4) {
                                Image(systemName: weather.symbolName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(WeatherService.symbolColor(for: weather.symbolName))
                                
                                Text("\(weather.formattedTemp)\(service.temperatureUnit.symbol)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        } else if service.isLoadingWeather {
                            ProgressView()
                                .scaleEffect(0.55)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(isHovered ? 0.15 : 0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
                weatherDetailPopover
            }
            .help("Local Time & Weather")
        }
    }
    
    // MARK: - Weather Detail Popover
    private var weatherDetailPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: City & Date
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.weatherInfo?.cityName ?? "Local Weather")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("\(service.currentDateString) • \(service.currentTimeString)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    service.fetchWeather()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Refresh Weather")
            }
            
            // Quick Location Switcher (when 2+ locations saved)
            WeatherLocationSwitcherStrip()
            
            // Primary Condition Card
            if let weather = service.weatherInfo {
                HStack(spacing: 16) {
                    // Condition Icon
                    ZStack {
                        Circle()
                            .fill(WeatherService.symbolColor(for: weather.symbolName).opacity(0.14))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(WeatherService.symbolColor(for: weather.symbolName))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(weather.formattedTemp)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text(service.temperatureUnit.symbol)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(weather.conditionName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Text("Feels like \(weather.formattedApparentTemp)\(service.temperatureUnit.symbol)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Quick Stats
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "humidity")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "4285F4"))
                            Text("\(weather.humidity)%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        
                        if weather.precipitation > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "1A73E8"))
                                Text("\(String(format: "%.1f", weather.precipitation)) mm")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                
                // Hourly Forecast Strip (Upcoming Future Hours)
                if !weather.hourly.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UPCOMING HOURS")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(weather.hourly) { hour in
                                    VStack(spacing: 5) {
                                        Text(hour.timeString)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        
                                        Image(systemName: hour.symbolName)
                                            .font(.system(size: 14))
                                            .foregroundStyle(WeatherService.symbolColor(for: hour.symbolName))
                                            .frame(height: 16)
                                        
                                        Text("\(hour.temperature)°")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                        
                                        if hour.precipProbability > 10 {
                                            Text("\(hour.precipProbability)%")
                                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                                .foregroundStyle(Color(hex: "1A73E8"))
                                        } else {
                                            Text(" ")
                                                .font(.system(size: 8.5))
                                        }
                                    }
                                    .frame(width: 48)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.primary.opacity(0.04))
                                    )
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Fetching local weather...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}

// MARK: - Shared Popover Location Switcher Strip
public struct WeatherLocationSwitcherStrip: View {
    @ObservedObject private var service = WeatherService.shared
    
    public init() {}
    
    public var body: some View {
        if service.savedLocations.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(service.savedLocations) { loc in
                        let isActive = service.activeLocation?.id == loc.id
                        Button(action: {
                            service.selectLocation(id: loc.id)
                        }) {
                            HStack(spacing: 4) {
                                if loc.isCurrentGPS {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 8.5))
                                }
                                Text(loc.name)
                                    .font(.system(size: 10.5, weight: isActive ? .bold : .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(isActive ? Color(hex: "1A73E8").opacity(0.16) : Color.primary.opacity(0.05))
                            )
                            .overlay(
                                Capsule().stroke(isActive ? Color(hex: "1A73E8").opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(isActive ? Color(hex: "1A73E8") : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}
