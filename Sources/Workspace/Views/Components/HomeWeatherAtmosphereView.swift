import SwiftUI
import AppKit

/// Animated dynamic background layer for the Home screen that adapts to live weather
/// (or a user-selected WeatherAtmosphereMode preview) with low-overhead procedural Canvas rendering.
/// Horizontal coordinates anchor to the right window edge using a fixed virtual width so toggling
/// the left sidebar never shifts, stretches, or flickers active sky particles or glows.
public struct HomeWeatherAtmosphereView: View {
    public let mode: WeatherAtmosphereMode
    @ObservedObject private var weatherService = WeatherService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAppActive: Bool = NSApplication.shared.isActive
    
    private static let virtualWidth: Double = 1800.0
    
    public init(mode: WeatherAtmosphereMode) {
        self.mode = mode
    }
    
    private enum ResolvedAtmosphere: Equatable, Sendable {
        case clear
        case foggy
        case rain
        case thunderstorm
        case snow
        case frosty
    }
    
    private var resolvedAtmosphere: ResolvedAtmosphere {
        switch mode {
        case .clear: return .clear
        case .foggy: return .foggy
        case .rain: return .rain
        case .thunderstorm: return .thunderstorm
        case .snow: return .snow
        case .frosty: return .frosty
        case .auto:
            guard weatherService.isWeatherEnabled, let info = weatherService.weatherInfo else {
                return .clear
            }
            let tempCelsius: Double = weatherService.temperatureUnit == .fahrenheit
                ? (info.temperature - 32.0) * 5.0 / 9.0
                : info.temperature
            
            switch info.weatherCode {
            case 95, 96, 99:
                return .thunderstorm
            case 71, 73, 75, 77, 85, 86:
                return .snow
            case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
                return .rain
            case 45, 48:
                return .foggy
            case 2, 3:
                return tempCelsius <= 1.0 ? .frosty : .foggy
            case 0, 1:
                return tempCelsius <= 2.0 ? .frosty : .clear
            default:
                return tempCelsius <= 2.0 ? .frosty : .clear
            }
        }
    }
    
    public var body: some View {
        let activeMode = resolvedAtmosphere
        let isDark = colorScheme == .dark
        let frameInterval: TimeInterval = (activeMode == .clear || activeMode == .frosty) ? (1.0 / 15.0) : (1.0 / 30.0)
        
        TimelineView(.animation(minimumInterval: frameInterval, paused: !isAppActive)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                switch activeMode {
                case .clear:
                    drawClearGlow(context: &context, size: size, time: t, isDark: isDark)
                case .foggy:
                    drawFoggyClouds(context: &context, size: size, time: t, isDark: isDark)
                case .rain:
                    drawRain(context: &context, size: size, time: t, isDark: isDark, withLightning: false)
                case .thunderstorm:
                    drawRain(context: &context, size: size, time: t, isDark: isDark, withLightning: true)
                case .snow:
                    drawSnow(context: &context, size: size, time: t, isDark: isDark)
                case .frosty:
                    drawFrostCrystals(context: &context, size: size, time: t, isDark: isDark)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAppActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isAppActive = false
        }
        .transaction { $0.animation = nil }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
    
    // MARK: - Clear: Subtle Warm Yellow Glow Emitting from Top-Right Corner
    private func drawClearGlow(context: inout GraphicsContext, size: CGSize, time: Double, isDark: Bool) {
        let breathe = 0.5 + 0.5 * sin(time * 0.65)
        let secondaryPulse = 0.5 + 0.5 * cos(time * 0.42 + 0.7)
        let origin = CGPoint(x: size.width - 64.0, y: 28.0)
        let maxDim = max(size.height * 1.45, 1100.0)
        
        // Primary warm golden glow
        let primaryRadius = maxDim * (0.48 + 0.04 * breathe)
        let coreOpacity = isDark ? (0.20 + 0.04 * breathe) : (0.24 + 0.05 * breathe)
        let midOpacity = isDark ? (0.09 + 0.02 * breathe) : (0.11 + 0.02 * breathe)
        
        let primaryGradient = Gradient(stops: [
            .init(color: Color(hex: "F4B400").opacity(coreOpacity), location: 0.0),
            .init(color: Color(hex: "FBBC04").opacity(midOpacity), location: 0.35),
            .init(color: Color(hex: "FF8F00").opacity(midOpacity * 0.35), location: 0.68),
            .init(color: .clear, location: 1.0)
        ])
        context.fill(
            Path(ellipseIn: CGRect(
                x: origin.x - primaryRadius,
                y: origin.y - primaryRadius,
                width: primaryRadius * 2.0,
                height: primaryRadius * 2.0
            )),
            with: .radialGradient(primaryGradient, center: origin, startRadius: 0, endRadius: primaryRadius)
        )
        
        // Soft breathing inner sun core
        let coreRadius = maxDim * (0.20 + 0.03 * secondaryPulse)
        let coreGradient = Gradient(stops: [
            .init(color: Color(hex: "FFE082").opacity(isDark ? 0.14 : 0.22), location: 0.0),
            .init(color: Color(hex: "FBBC04").opacity(isDark ? 0.04 : 0.07), location: 0.5),
            .init(color: .clear, location: 1.0)
        ])
        context.fill(
            Path(ellipseIn: CGRect(
                x: origin.x - coreRadius,
                y: origin.y - coreRadius,
                width: coreRadius * 2.0,
                height: coreRadius * 2.0
            )),
            with: .radialGradient(coreGradient, center: origin, startRadius: 0, endRadius: coreRadius)
        )
        
        // Gentle drifting diagonal sunbeams from top-right corner
        for i in 0..<3 {
            let sway = sin(time * 0.32 + Double(i) * 1.9) * 0.04
            let baseAngle = Double.pi * (0.64 + Double(i) * 0.11) + sway
            let spread = 0.095
            let rayLength = maxDim * 0.62
            
            let p1 = CGPoint(
                x: origin.x + cos(baseAngle - spread) * rayLength,
                y: origin.y + sin(baseAngle - spread) * rayLength
            )
            let p2 = CGPoint(
                x: origin.x + cos(baseAngle + spread) * rayLength,
                y: origin.y + sin(baseAngle + spread) * rayLength
            )
            
            var path = Path()
            path.move(to: origin)
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.closeSubpath()
            
            let rayAlpha = (isDark ? 0.032 : 0.05) * (0.7 + 0.3 * sin(time * 0.5 + Double(i) * 2.1))
            let midEnd = CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5)
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: "FBBC04").opacity(rayAlpha), .clear]),
                    startPoint: origin,
                    endPoint: midEnd
                )
            )
        }
    }
    
    // MARK: - Foggy: Animated Multi-Layer Drifting Mist & Clouds
    private func drawFoggyClouds(context: inout GraphicsContext, size: CGSize, time: Double, isDark: Bool) {
        let hazeColor = isDark ? Color(hex: "94A3B8") : Color(hex: "64748B")
        let highlightColor = isDark ? Color(hex: "CBD5E1") : Color(hex: "94A3B8")
        let vWidth = Self.virtualWidth
        
        // Soft ambient top mist veil
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: hazeColor.opacity(isDark ? 0.13 : 0.16), location: 0.0),
                    .init(color: hazeColor.opacity(isDark ? 0.05 : 0.06), location: 0.45),
                    .init(color: .clear, location: 0.85)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        
        // Softly fading drifting fog banks anchored to the stationary right edge
        for i in 0..<10 {
            let layer = Double(i)
            let speed = 8.0 + hash01(i, 1) * 14.0
            let rx = max(vWidth * (0.17 + hash01(i, 2) * 0.13), 220.0)
            let ry = max(size.height * (0.14 + hash01(i, 3) * 0.14), 100.0)
            let spanW = vWidth + rx * 2.6
            
            let offsetFromVirtualLeft = (time * speed + hash01(i, 4) * spanW).truncatingRemainder(dividingBy: spanW) - rx * 1.3
            let centerX = size.width - vWidth + offsetFromVirtualLeft
            let baseY = size.height * (0.08 + 0.72 * hash01(i, 5))
            let bobY = sin(time * (0.22 + layer * 0.03) + layer) * 16.0
            let center = CGPoint(x: centerX, y: baseY + bobY)
            
            guard center.x + rx >= -40 && center.x - rx <= size.width + 40 else { continue }
            
            let pulse = 0.78 + 0.22 * sin(time * 0.35 + layer * 1.4)
            let alpha = (isDark ? 0.10 : 0.14) * pulse
            let cloudColor = i % 2 == 0 ? highlightColor : hazeColor
            
            var layerCtx = context
            layerCtx.scaleBy(x: 1.0, y: ry / rx)
            let scaledCenter = CGPoint(x: center.x, y: center.y * (rx / ry))
            let scaledRect = CGRect(
                x: scaledCenter.x - rx,
                y: scaledCenter.y - rx,
                width: rx * 2,
                height: rx * 2
            )
            layerCtx.fill(
                Path(ellipseIn: scaledRect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: cloudColor.opacity(alpha), location: 0.0),
                        .init(color: cloudColor.opacity(alpha * 0.45), location: 0.48),
                        .init(color: .clear, location: 1.0)
                    ]),
                    center: scaledCenter,
                    startRadius: 0,
                    endRadius: rx
                )
            )
        }
    }
    
    // MARK: - Rain & Thunderstorm: Falling Rain Droplets + Optional Lightning
    private func drawRain(context: inout GraphicsContext, size: CGSize, time: Double, isDark: Bool, withLightning: Bool) {
        let vWidth = Self.virtualWidth
        let skyTint = withLightning
            ? Color(hex: isDark ? "3B5BDB" : "475569")
            : Color(hex: isDark ? "1A73E8" : "3B82F6")
        
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: skyTint.opacity(isDark ? (withLightning ? 0.14 : 0.11) : 0.12), location: 0.0),
                    .init(color: skyTint.opacity(isDark ? 0.04 : 0.05), location: 0.45),
                    .init(color: .clear, location: 0.9)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        
        // Periodic double-pulse sheet lightning for Thunderstorm mode
        var lightningIntensity = 0.0
        var lightningSeed = 0
        if withLightning {
            let cycle = 8.5
            let phase = time.truncatingRemainder(dividingBy: cycle)
            lightningSeed = Int(floor(time / cycle))
            if phase < 0.22 {
                lightningIntensity = max(0, sin((phase / 0.22) * .pi)) * 0.85
            } else if phase >= 0.28 && phase < 0.62 {
                let p = (phase - 0.28) / 0.34
                lightningIntensity = max(0, sin(p * .pi)) * (1.0 - p * 0.45)
            }
            
            if lightningIntensity > 0.01 {
                let flashCenter = CGPoint(
                    x: size.width - (120.0 + 620.0 * hash01(lightningSeed, 11)),
                    y: size.height * 0.08
                )
                let flashRadius = max(size.height * 1.15, 760.0)
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: flashCenter.x - flashRadius,
                        y: flashCenter.y - flashRadius,
                        width: flashRadius * 2,
                        height: flashRadius * 2
                    )),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Color(hex: "DBEAFE").opacity((isDark ? 0.22 : 0.28) * lightningIntensity), location: 0.0),
                            .init(color: Color(hex: "60A5FA").opacity((isDark ? 0.10 : 0.12) * lightningIntensity), location: 0.45),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: flashCenter,
                        startRadius: 0,
                        endRadius: flashRadius
                    )
                )
                
                // Subtle distant sky bolt silhouette during peak flash
                if lightningIntensity > 0.35 {
                    drawDistantBolt(
                        context: &context,
                        startX: flashCenter.x,
                        height: size.height * 0.42,
                        seed: lightningSeed,
                        opacity: (isDark ? 0.28 : 0.22) * lightningIntensity
                    )
                }
            }
        }
        
        // Raindrop streaks across fixed virtual width anchored to right edge
        let dropCount = withLightning ? 130 : 96
        let dropColor = isDark ? Color(hex: "93C5FD") : Color(hex: "2563EB")
        let windAngle = withLightning ? -0.17 : -0.10
        let spanH = size.height + 90.0
        let spanW = vWidth + 120.0
        
        for i in 0..<dropCount {
            let depth = 0.45 + 0.55 * hash01(i, 21)
            let speed = (withLightning ? 560.0 : 440.0) * (0.75 + 0.55 * depth)
            let length = (12.0 + 18.0 * depth)
            let xRatio = hash01(i, 22)
            let startPhase = hash01(i, 23) * spanH
            
            let y = (time * speed + startPhase).truncatingRemainder(dividingBy: spanH) - 45.0
            let driftX = y * windAngle
            let rawX = xRatio * spanW + driftX
            let wrappedX = (rawX.truncatingRemainder(dividingBy: spanW) + spanW).truncatingRemainder(dividingBy: spanW) - 30.0
            let x = size.width - vWidth + wrappedX
            
            guard x >= -24 && x <= size.width + 24 else { continue }
            
            let dx = length * windAngle
            let dy = length
            
            // Fade near the bottom and intensify slightly on lightning flash
            let verticalFade = y > size.height * 0.85 ? max(0, 1.0 - (y - size.height * 0.85) / (size.height * 0.15)) : 1.0
            let alpha = ((isDark ? 0.18 : 0.20) * depth + lightningIntensity * 0.12) * verticalFade
            
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx, y: y + dy))
            
            context.stroke(
                path,
                with: .color(dropColor.opacity(alpha)),
                style: StrokeStyle(lineWidth: 0.9 + depth * 0.7, lineCap: .round)
            )
            
            // Subtle splash ripple on subset of foreground drops near lower edges
            if i % 6 == 0 && y > size.height * 0.78 && y < size.height * 0.96 {
                let progress = (y - size.height * 0.78) / (size.height * 0.18)
                let ringRadius = 3.0 + progress * 9.0
                let ringRect = CGRect(x: x - ringRadius, y: y - ringRadius * 0.35, width: ringRadius * 2, height: ringRadius * 0.7)
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(dropColor.opacity(alpha * (1.0 - progress) * 0.8)),
                    lineWidth: 0.8
                )
            }
        }
    }
    
    private func drawDistantBolt(context: inout GraphicsContext, startX: Double, height: Double, seed: Int, opacity: Double) {
        var bolt = Path()
        var current = CGPoint(x: startX, y: 0)
        bolt.move(to: current)
        
        let segments = 7
        for s in 1...segments {
            let jitter = (hash01(seed * 31 + s, 7) - 0.5) * 44.0
            current = CGPoint(x: current.x + jitter, y: (Double(s) / Double(segments)) * height)
            bolt.addLine(to: current)
        }
        
        context.stroke(
            bolt,
            with: .color(Color(hex: "E0F2FE").opacity(opacity)),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
        )
    }
    
    // MARK: - Snow: Soft Falling Snowflakes with Sinusoidal Drift
    private func drawSnow(context: inout GraphicsContext, size: CGSize, time: Double, isDark: Bool) {
        let vWidth = Self.virtualWidth
        let skyColor = Color(hex: isDark ? "38BDF8" : "0284C7")
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: skyColor.opacity(isDark ? 0.09 : 0.08), location: 0.0),
                    .init(color: .clear, location: 0.55)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
        
        let flakeCount = 96
        let flakeColor = isDark ? Color.white : Color(hex: "0284C7")
        let spanH = size.height + 60.0
        
        for i in 0..<flakeCount {
            let depth = 0.3 + 0.7 * hash01(i, 31)
            let speed = 28.0 + 52.0 * depth
            let baseX = size.width - hash01(i, 32) * vWidth
            let startY = hash01(i, 33) * spanH
            let swayAmp = 10.0 + 18.0 * hash01(i, 34)
            let swayFreq = 0.6 + 0.7 * hash01(i, 35)
            let phase = hash01(i, 36) * .pi * 2.0
            
            let y = (time * speed + startY).truncatingRemainder(dividingBy: spanH) - 30.0
            let x = baseX + sin(time * swayFreq + phase) * swayAmp
            
            guard x >= -16 && x <= size.width + 16 else { continue }
            
            let radius = 1.4 + 2.8 * depth
            let alpha = (isDark ? 0.34 : 0.24) * (0.4 + 0.6 * depth)
            
            // Larger foreground flakes get soft radial glow + crisp crystal; smaller ones get soft circles
            if i % 4 == 0 && depth > 0.7 {
                drawDendriticSnowflake(
                    context: &context,
                    center: CGPoint(x: x, y: y),
                    radius: radius * 1.8,
                    rotation: time * 0.35 + phase,
                    color: flakeColor.opacity(alpha * 0.9),
                    lineWidth: 0.85
                )
            } else {
                let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [flakeColor.opacity(alpha), flakeColor.opacity(alpha * 0.25), .clear]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
    }
    
    // MARK: - Frosty: Stationary Snowflakes & Frost Crystals Fading In and Out
    private func drawFrostCrystals(context: inout GraphicsContext, size: CGSize, time: Double, isDark: Bool) {
        let vWidth = Self.virtualWidth
        let frostColor = isDark ? Color(hex: "BAE6FD") : Color(hex: "0284C7")
        let icyWash = isDark ? Color(hex: "38BDF8") : Color(hex: "0EA5E9")
        
        // Crisp icy perimeter glow around top-right corner
        let cornerCenter = CGPoint(x: size.width - 90.0, y: 36.0)
        let cornerRadius = max(size.height * 0.65, 520.0)
        context.fill(
            Path(ellipseIn: CGRect(
                x: cornerCenter.x - cornerRadius,
                y: cornerCenter.y - cornerRadius,
                width: cornerRadius * 2,
                height: cornerRadius * 2
            )),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: icyWash.opacity(isDark ? 0.11 : 0.10), location: 0.0),
                    .init(color: .clear, location: 1.0)
                ]),
                center: cornerCenter,
                startRadius: 0,
                endRadius: cornerRadius
            )
        )
        
        // Stationary snowflakes anchored relative to the right edge fading in and out
        for i in 0..<42 {
            let x = size.width - (0.03 + 0.94 * hash01(i, 41)) * vWidth
            let crystalRadius = 8.0 + 18.0 * hash01(i, 43)
            guard x >= -crystalRadius * 2 && x <= size.width + crystalRadius * 2 else { continue }
            
            let y = (0.05 + 0.90 * hash01(i, 42)) * size.height
            let rotation = hash01(i, 44) * .pi
            let cycle = 6.5 + 5.5 * hash01(i, 45)
            let phase = hash01(i, 46) * cycle
            
            // Smooth fade-in and fade-out wave (clamped so each crystal rests cleanly at 0 between blooms)
            let localT = (time + phase).truncatingRemainder(dividingBy: cycle) / cycle
            let wave = sin(localT * .pi * 2.0 - .pi * 0.5) * 0.5 + 0.5
            let smoothFade = pow(wave, 2.2)
            guard smoothFade > 0.02 else { continue }
            
            let peakOpacity = isDark ? 0.26 : 0.22
            let alpha = peakOpacity * smoothFade * (0.65 + 0.35 * hash01(i, 47))
            
            // Subtle halo under each crystal
            let haloRadius = crystalRadius * 1.45
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x - haloRadius,
                    y: y - haloRadius,
                    width: haloRadius * 2,
                    height: haloRadius * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [frostColor.opacity(alpha * 0.45), .clear]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: haloRadius
                )
            )
            
            drawDendriticSnowflake(
                context: &context,
                center: CGPoint(x: x, y: y),
                radius: crystalRadius,
                rotation: rotation,
                color: frostColor.opacity(alpha),
                lineWidth: 1.0 + (crystalRadius / 26.0) * 0.4
            )
        }
    }
    
    // MARK: - Geometric 6-Point Dendritic Crystal Helper
    private func drawDendriticSnowflake(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        rotation: Double,
        color: Color,
        lineWidth: Double
    ) {
        var path = Path()
        for arm in 0..<6 {
            let angle = rotation + Double(arm) * (.pi / 3.0)
            let tip = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            path.move(to: center)
            path.addLine(to: tip)
            
            // Add delicate chevron branches along each arm when large enough
            if radius >= 7.0 {
                for branchFactor in [0.48, 0.74] {
                    let branchOrigin = CGPoint(
                        x: center.x + cos(angle) * (radius * branchFactor),
                        y: center.y + sin(angle) * (radius * branchFactor)
                    )
                    let branchLen = radius * (branchFactor < 0.6 ? 0.30 : 0.20)
                    for side in [-1.0, 1.0] {
                        let bAngle = angle + side * (.pi / 3.2)
                        path.move(to: branchOrigin)
                        path.addLine(to: CGPoint(
                            x: branchOrigin.x + cos(bAngle) * branchLen,
                            y: branchOrigin.y + sin(bAngle) * branchLen
                        ))
                    }
                }
            }
        }
        
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    // MARK: - Deterministic Pseudo-Random Hash in [0, 1)
    private func hash01(_ index: Int, _ salt: Int) -> Double {
        let raw = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453123
        return raw - floor(raw)
    }
}
