import SwiftUI
import AppKit

// MARK: - Larger Home Screen Weather & Clock Dashboard Card
public struct HomeWeatherClockWidgetView: View {
    @ObservedObject private var service = WeatherService.shared
    @State private var isHovered: Bool = false
    @State private var showingPopover: Bool = false
    
    public init() {}
    
    public var body: some View {
        if service.isWeatherEnabled {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 16) {
                    // Left Column: Large Weather Icon & Condition
                    if service.isWeatherEnabled, let weather = service.weatherInfo {
                        ZStack {
                            Circle()
                                .fill(WeatherService.symbolColor(for: weather.symbolName).opacity(0.16))
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(WeatherService.symbolColor(for: weather.symbolName))
                        }
                    } else if service.isLoadingWeather {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(width: 52, height: 52)
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    } else {
                        // Clock icon if weather is disabled
                        ZStack {
                            Circle()
                                .fill(Color(hex: "1A73E8").opacity(0.16))
                                .frame(width: 52, height: 52)
                            Image(systemName: "clock.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color(hex: "1A73E8"))
                        }
                    }
                    
                    // Middle Column: Temperatures, City, & Time
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if service.isWeatherEnabled, let weather = service.weatherInfo {
                                Text("\(weather.formattedTemp)\(service.temperatureUnit.symbol)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            
                            if service.isTimeEnabled {
                                Text(service.currentTimeString)
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(service.isWeatherEnabled ? .secondary : .primary)
                            }
                        }
                        
                        // Condition & City
                        if service.isWeatherEnabled, let weather = service.weatherInfo {
                            Text(weather.conditionName)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 8))
                                Text(weather.cityName)
                                    .font(.system(size: 10.5))
                                Text("• Feels \(weather.formattedApparentTemp)\(service.temperatureUnit.symbol)")
                                    .font(.system(size: 10.5))
                            }
                            .foregroundStyle(.secondary)
                        } else {
                            Text(service.currentDateString)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Right: Forecast Mini Strip or Expand Indicator
                    VStack(alignment: .trailing, spacing: 4) {
                        if service.isWeatherEnabled, let weather = service.weatherInfo {
                            HStack(spacing: 3) {
                                Image(systemName: "humidity")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(hex: "4285F4"))
                                Text("\(weather.humidity)%")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            
                            if weather.precipitation > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color(hex: "1A73E8"))
                                    Text("\(String(format: "%.1f", weather.precipitation))mm")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary.opacity(isHovered ? 0.9 : 0.4))
                            .offset(x: isHovered ? 2 : 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(isHovered ? 0.22 : 0.1),
                                    Color.primary.opacity(isHovered ? 0.08 : 0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.08), radius: isHovered ? 12 : 6, x: 0, y: 3)
                .scaleEffect(isHovered ? 1.015 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isHovered = hovering
                }
            }
            .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
                homeWeatherPopover
            }
            .help("Click to view full hourly forecast")
        }
    }
    
    // MARK: - Full Forecast Popover
    private var homeWeatherPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.weatherInfo?.cityName ?? "Local Forecast")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("\(service.currentDateString) • \(service.currentTimeString)")
                        .font(.system(size: 11))
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
            
            if let weather = service.weatherInfo {
                HStack(spacing: 14) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 28))
                        .foregroundStyle(WeatherService.symbolColor(for: weather.symbolName))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(weather.formattedTemp)\(service.temperatureUnit.symbol)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("\(weather.conditionName) • Feels like \(weather.formattedApparentTemp)\(service.temperatureUnit.symbol)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
                
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
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}
