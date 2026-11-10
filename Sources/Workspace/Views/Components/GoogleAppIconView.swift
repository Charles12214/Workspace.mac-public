import SwiftUI

// MARK: - Dedicated Google Workspace App Icon Renderer
public struct GoogleAppIconView: View {
    public let appId: String
    public let size: CGFloat
    
    public init(appId: String, size: CGFloat = 20) {
        self.appId = appId
        self.size = size
    }
    
    public var body: some View {
        Group {
            switch appId {
            case "gemini":
                geminiIcon
            case "docs":
                docsIcon
            case "sheets":
                sheetsIcon
            case "slides":
                slidesIcon
            case "drive":
                driveIcon
            case "gmail":
                gmailIcon
            case "calendar":
                calendarIcon
            case "meet":
                meetIcon
            case "chat":
                chatIcon
            case "keep":
                keepIcon
            case "notebooklm":
                notebooklmIcon
            case "forms":
                formsIcon
            case "sites":
                sitesIcon
            case "contacts":
                contactsIcon
            case "tasks":
                tasksIcon
            case "classroom":
                classroomIcon
            case "cloud":
                cloudIcon
            case "admin":
                adminIcon
            default:
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - 1. Gemini
    private var geminiIcon: some View {
        GeminiSparkleShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "1A73E8"),
                        Color(hex: "9B51E0"),
                        Color(hex: "EA4335")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color(hex: "9B51E0").opacity(0.35), radius: size * 0.1)
    }
    
    // MARK: - 2. Google Docs (Blue doc page with folded corner & white text lines)
    private var docsIcon: some View {
        ZStack {
            DocumentFoldBackground(color: Color(hex: "4285F4"), cornerFoldColor: Color(hex: "1A73E8"))
            
            VStack(alignment: .leading, spacing: size * 0.08) {
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.44, height: size * 0.08)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.44, height: size * 0.08)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.44, height: size * 0.08)
                RoundedRectangle(cornerRadius: size * 0.03)
                    .fill(Color.white)
                    .frame(width: size * 0.28, height: size * 0.08)
            }
            .offset(x: -size * 0.03, y: size * 0.04)
        }
    }
    
    // MARK: - 3. Google Sheets (Green spreadsheet with folded corner & grid)
    private var sheetsIcon: some View {
        ZStack {
            DocumentFoldBackground(color: Color(hex: "0F9D58"), cornerFoldColor: Color(hex: "0B8043"))
            
            // Spreadsheet 2x2 grid
            VStack(spacing: size * 0.05) {
                HStack(spacing: size * 0.05) {
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(Color.white)
                        .frame(width: size * 0.20, height: size * 0.16)
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(Color.white)
                        .frame(width: size * 0.20, height: size * 0.16)
                }
                HStack(spacing: size * 0.05) {
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(Color.white)
                        .frame(width: size * 0.20, height: size * 0.16)
                    RoundedRectangle(cornerRadius: size * 0.02)
                        .fill(Color.white)
                        .frame(width: size * 0.20, height: size * 0.16)
                }
            }
            .offset(x: -size * 0.03, y: size * 0.04)
        }
    }
    
    // MARK: - 4. Google Slides (Yellow presentation page with slide rectangle)
    private var slidesIcon: some View {
        ZStack {
            DocumentFoldBackground(color: Color(hex: "F4B400"), cornerFoldColor: Color(hex: "F29900"))
            
            // Presentation slide screen
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(Color.white)
                .frame(width: size * 0.46, height: size * 0.32)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(Color(hex: "F4B400").opacity(0.4))
                        .frame(width: size * 0.32, height: size * 0.18)
                )
                .offset(x: -size * 0.03, y: size * 0.04)
        }
    }
    
    // MARK: - 5. Google Drive (Triangular loop with Yellow, Green, Blue)
    private var driveIcon: some View {
        Canvas { context, sz in
            let w = sz.width
            let h = sz.height
            
            // Yellow top bar
            var yellowPath = Path()
            yellowPath.move(to: CGPoint(x: w * 0.34, y: h * 0.10))
            yellowPath.addLine(to: CGPoint(x: w * 0.66, y: h * 0.10))
            yellowPath.addLine(to: CGPoint(x: w * 0.88, y: h * 0.48))
            yellowPath.addLine(to: CGPoint(x: w * 0.56, y: h * 0.48))
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(hex: "FFBA00")))
            
            // Green right bar
            var greenPath = Path()
            greenPath.move(to: CGPoint(x: w * 0.66, y: h * 0.10))
            greenPath.addLine(to: CGPoint(x: w * 0.88, y: h * 0.48))
            greenPath.addLine(to: CGPoint(x: w * 0.68, y: h * 0.86))
            greenPath.addLine(to: CGPoint(x: w * 0.46, y: h * 0.48))
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(hex: "00AC47")))
            
            // Blue bottom-left bar
            var bluePath = Path()
            bluePath.move(to: CGPoint(x: w * 0.12, y: h * 0.86))
            bluePath.addLine(to: CGPoint(x: w * 0.68, y: h * 0.86))
            bluePath.addLine(to: CGPoint(x: w * 0.46, y: h * 0.48))
            bluePath.addLine(to: CGPoint(x: w * 0.22, y: h * 0.48))
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(hex: "0066DA")))
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - 6. Gmail (White card with iconic 4-color M logo)
    private var gmailIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: size * 0.05, x: 0, y: 1)
            
            Canvas { context, sz in
                let w = sz.width
                let h = sz.height
                let strokeW = w * 0.13
                
                // Left red leg
                var leftLeg = Path()
                leftLeg.move(to: CGPoint(x: w * 0.24, y: h * 0.78))
                leftLeg.addLine(to: CGPoint(x: w * 0.24, y: h * 0.32))
                context.stroke(leftLeg, with: .color(Color(hex: "EA4335")), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
                
                // Right green leg
                var rightLeg = Path()
                rightLeg.move(to: CGPoint(x: w * 0.76, y: h * 0.78))
                rightLeg.addLine(to: CGPoint(x: w * 0.76, y: h * 0.32))
                context.stroke(rightLeg, with: .color(Color(hex: "34A853")), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
                
                // Left diagonal (Red to Yellow)
                var leftDiag = Path()
                leftDiag.move(to: CGPoint(x: w * 0.24, y: h * 0.32))
                leftDiag.addLine(to: CGPoint(x: w * 0.50, y: h * 0.55))
                context.stroke(leftDiag, with: .color(Color(hex: "EA4335")), style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round))
                
                // Right diagonal (Blue)
                var rightDiag = Path()
                rightDiag.move(to: CGPoint(x: w * 0.76, y: h * 0.32))
                rightDiag.addLine(to: CGPoint(x: w * 0.50, y: h * 0.55))
                context.stroke(rightDiag, with: .color(Color(hex: "4285F4")), style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round))
                
                // Top yellow tip
                var yellowArc = Path()
                yellowArc.move(to: CGPoint(x: w * 0.24, y: h * 0.32))
                yellowArc.addLine(to: CGPoint(x: w * 0.33, y: h * 0.40))
                context.stroke(yellowArc, with: .color(Color(hex: "FBBC04")), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
            }
        }
    }
    
    // MARK: - 7. Google Calendar (Blue pad with white sheet & "31")
    private var calendarIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(hex: "4285F4"))
            
            VStack(spacing: 0) {
                // Top blue header bar
                Color(hex: "1A73E8")
                    .frame(height: size * 0.26)
                
                // White calendar page with number 31
                ZStack {
                    Color.white
                    
                    Text("31")
                        .font(.system(size: size * 0.44, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "1A73E8"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.20, style: .continuous))
            .padding(size * 0.05)
        }
    }
    
    // MARK: - 8. Google Meet (Green camera body with multi-color lens)
    private var meetIcon: some View {
        ZStack {
            HStack(spacing: size * 0.04) {
                // Green camera box
                RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                    .fill(Color(hex: "00AC47"))
                    .frame(width: size * 0.58, height: size * 0.58)
                
                // Camera cone/lens (Blue, Yellow, Red)
                Canvas { context, sz in
                    let w = sz.width
                    let h = sz.height
                    
                    var lensPath = Path()
                    lensPath.move(to: CGPoint(x: 0, y: h * 0.22))
                    lensPath.addLine(to: CGPoint(x: w, y: 0))
                    lensPath.addLine(to: CGPoint(x: w, y: h))
                    lensPath.addLine(to: CGPoint(x: 0, y: h * 0.78))
                    lensPath.closeSubpath()
                    
                    context.fill(lensPath, with: .linearGradient(
                        Gradient(colors: [Color(hex: "0066DA"), Color(hex: "EA4335")]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: w, y: h)
                    ))
                }
                .frame(width: size * 0.26, height: size * 0.46)
            }
        }
    }
    
    // MARK: - 9. Google Chat (Two overlapping green bubbles)
    private var chatIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color(hex: "00AC47"))
            
            // Speech bubble outline
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: size * 0.52))
                .foregroundStyle(Color.white)
        }
    }
    
    // MARK: - 10. Google Keep (Yellow sticky note with white lightbulb)
    private var keepIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(hex: "FBBC04"))
            
            Image(systemName: "lightbulb.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }
    
    // MARK: - 11. NotebookLM (Purple/Blue notebook with assist sparkle)
    private var notebooklmIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "7B1FA2"), Color(hex: "1A73E8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: "book.pages.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(Color.white)
            
            // Little sparkle
            GeminiSparkleShape()
                .fill(Color(hex: "FBBC04"))
                .frame(width: size * 0.26, height: size * 0.26)
                .offset(x: size * 0.22, y: -size * 0.22)
        }
    }
    
    // MARK: - 12. Google Forms (Purple document with checkmarks)
    private var formsIcon: some View {
        ZStack {
            DocumentFoldBackground(color: Color(hex: "7248B9"), cornerFoldColor: Color(hex: "56368C"))
            
            VStack(alignment: .leading, spacing: size * 0.07) {
                HStack(spacing: size * 0.05) {
                    Circle().fill(Color.white).frame(width: size * 0.08, height: size * 0.08)
                    RoundedRectangle(cornerRadius: size * 0.02).fill(Color.white).frame(width: size * 0.28, height: size * 0.07)
                }
                HStack(spacing: size * 0.05) {
                    Circle().fill(Color.white).frame(width: size * 0.08, height: size * 0.08)
                    RoundedRectangle(cornerRadius: size * 0.02).fill(Color.white).frame(width: size * 0.28, height: size * 0.07)
                }
                HStack(spacing: size * 0.05) {
                    Circle().fill(Color.white).frame(width: size * 0.08, height: size * 0.08)
                    RoundedRectangle(cornerRadius: size * 0.02).fill(Color.white).frame(width: size * 0.28, height: size * 0.07)
                }
            }
            .offset(x: -size * 0.02, y: size * 0.04)
        }
    }
    
    // MARK: - 13. Google Sites (Blue browser window layout)
    private var sitesIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(hex: "1A73E8"))
            
            VStack(spacing: size * 0.06) {
                // Top browser bar
                RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: size * 0.65, height: size * 0.16)
                
                // Split panels
                HStack(spacing: size * 0.06) {
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(Color.white.opacity(0.7))
                        .frame(width: size * 0.28, height: size * 0.32)
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(Color.white.opacity(0.7))
                        .frame(width: size * 0.31, height: size * 0.32)
                }
            }
        }
    }
    
    // MARK: - 14. Google Contacts (Blue badge with person silhouette)
    private var contactsIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "1A73E8"))
            
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.52))
                .foregroundStyle(Color.white)
        }
    }
    
    // MARK: - 15. Google Tasks (Blue circular badge with checkmark and yellow dot)
    private var tasksIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "1A73E8"))
            
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(Color.white)
                .offset(y: -size * 0.03)
            
            Circle()
                .fill(Color(hex: "FBBC04"))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: size * 0.24, y: size * 0.22)
        }
    }
    
    // MARK: - 16. Google Classroom (Green chalkboard with yellow frame)
    private var classroomIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(Color(hex: "F4B400"))
            
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(Color(hex: "0F9D58"))
                .padding(size * 0.10)
            
            Image(systemName: "person.2.fill")
                .font(.system(size: size * 0.44))
                .foregroundStyle(Color.white)
        }
    }
    
    // MARK: - 17. Google Cloud (4-color Cloud shape)
    private var cloudIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(hex: "F8F9FA"))
                .shadow(color: Color.black.opacity(0.12), radius: size * 0.06, x: 0, y: 1)
            
            Image(systemName: "cloud.fill")
                .font(.system(size: size * 0.62))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "4285F4"), Color(hex: "34A853")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - 18. Google Admin (Blue shield with gear)
    private var adminIcon: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .font(.system(size: size * 0.88))
                .foregroundStyle(Color(hex: "1A73E8"))
            
            Image(systemName: "gearshape.fill")
                .font(.system(size: size * 0.40, weight: .bold))
                .foregroundStyle(Color.white)
                .offset(y: -size * 0.04)
        }
    }
}

// MARK: - Folded Document Shape Helper for Docs, Sheets, Slides, Forms
private struct DocumentFoldBackground: View {
    let color: Color
    let cornerFoldColor: Color
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let corner = w * 0.28
            
            ZStack(alignment: .topTrailing) {
                // Main body with top-right corner cut
                Path { path in
                    path.move(to: CGPoint(x: w * 0.12, y: 0))
                    path.addLine(to: CGPoint(x: w - corner, y: 0))
                    path.addLine(to: CGPoint(x: w, y: corner))
                    path.addLine(to: CGPoint(x: w, y: h * 0.88))
                    path.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w * 0.88, y: h), radius: w * 0.12)
                    path.addLine(to: CGPoint(x: w * 0.12, y: h))
                    path.addArc(tangent1End: CGPoint(x: 0, y: h), tangent2End: CGPoint(x: 0, y: h * 0.88), radius: w * 0.12)
                    path.addLine(to: CGPoint(x: 0, y: w * 0.12))
                    path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: w * 0.12, y: 0), radius: w * 0.12)
                    path.closeSubpath()
                }
                .fill(color)
                
                // Corner fold triangle
                Path { path in
                    path.move(to: CGPoint(x: w - corner, y: 0))
                    path.addLine(to: CGPoint(x: w - corner, y: corner))
                    path.addLine(to: CGPoint(x: w, y: corner))
                    path.closeSubpath()
                }
                .fill(cornerFoldColor)
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
    }
}
