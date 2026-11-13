import SwiftUI

// MARK: - Save Group Modal
public struct SaveGroupModalView: View {
    @ObservedObject public var state: AppState
    @FocusState private var isFieldFocused: Bool
    
    public init(state: AppState) {
        self.state = state
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    state.showingSaveGroupModal = false
                }
            
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    GroupWindowIcon(size: 32, isHighlighted: true, paneCount: state.tiledAppIds.count)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save Group")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Save this \(state.tiledAppIds.count)-window layout to your Home dashboard for instant 1-click access.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Name Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("GROUP NAME")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    
                    TextField("e.g. Docs & Sheets Research", text: $state.groupModalInputName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(hex: "1A73E8").opacity(0.6), lineWidth: 1.5)
                        )
                        .focused($isFieldFocused)
                }
                
                // Included Apps Preview
                HStack(spacing: 8) {
                    Text("Included apps:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 6) {
                        ForEach(state.tiledApps) { app in
                            HStack(spacing: 4) {
                                GoogleAppIconView(appId: app.id, size: 14)
                                Text(app.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                        }
                    }
                    
                    Spacer()
                }
                
                // Actions
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button("Cancel") {
                        state.showingSaveGroupModal = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    
                    Button("Save Group") {
                        state.saveCurrentGroup(name: state.groupModalInputName)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(hex: "1A73E8")))
                    .shadow(color: Color(hex: "1A73E8").opacity(0.35), radius: 6, y: 2)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .liquidGlass(cornerRadius: 20, tintColor: Color(hex: "1A73E8"), isHighlighted: true)
            .frame(maxWidth: 460)
            .shadow(color: Color.black.opacity(0.4), radius: 24, y: 10)
        }
        .onAppear {
            isFieldFocused = true
        }
    }
}

// MARK: - Rename Group Modal
public struct RenameGroupModalView: View {
    @ObservedObject public var state: AppState
    @FocusState private var isFieldFocused: Bool
    
    public init(state: AppState) {
        self.state = state
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    state.showingRenameGroupModal = false
                }
            
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    GroupWindowIcon(size: 30, isHighlighted: true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rename Group")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Choose a new name for this workspace group.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Name Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEW GROUP NAME")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                    
                    TextField("Group Name", text: $state.groupModalInputName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(hex: "1A73E8").opacity(0.6), lineWidth: 1.5)
                        )
                        .focused($isFieldFocused)
                }
                
                // Actions
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button("Cancel") {
                        state.showingRenameGroupModal = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    
                    Button("Rename") {
                        if let targetId = state.groupModalTargetId ?? state.activeGroupId {
                            state.performRenameGroup(id: targetId, newName: state.groupModalInputName)
                        } else {
                            state.showingRenameGroupModal = false
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(hex: "1A73E8")))
                    .shadow(color: Color(hex: "1A73E8").opacity(0.35), radius: 6, y: 2)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .liquidGlass(cornerRadius: 20, tintColor: Color(hex: "1A73E8"), isHighlighted: true)
            .frame(maxWidth: 440)
            .shadow(color: Color.black.opacity(0.4), radius: 24, y: 10)
        }
        .onAppear {
            isFieldFocused = true
        }
    }
}
