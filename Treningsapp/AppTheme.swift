import SwiftUI

struct AppTheme {
    let name: String
    
    // Pil-innstillinger
    let arrowIcon: String
    let arrowColor: Color
    
    // Generelle farger
    let textColor: Color
    let backgroundColor: Color
    
    // ENDRET: Fra 'Color' til 'AnyShapeStyle' for å støtte både farger og glass-effekt
    let drawerBackground: AnyShapeStyle
    
    let drawerHeaderColor: Color
    let drawerCornerRadius: CGFloat
    let drawerShadowColor: Color
    
    
    // Funksjon for å hente farge basert på kategori
    func color(for category: ExerciseCategory) -> Color {
        switch name {
        case "Standard":
            switch category {
            case .strength: return .blue
            case .cardio: return .red
            case .combined: return .purple
            case .other: return .gray
            }
        case "Dark Mode":
            switch category {
            case .strength: return Color(.blue)
            case .cardio: return Color(.red)
            case .combined: return .indigo
            case .other: return .gray.opacity(0.5)
            }
        default:
            return .blue
        }
    }
}

extension AppTheme {
    static let standard = AppTheme(
        name: "Standard",
        arrowIcon: "arrow.right",
        arrowColor: .gray.opacity(0.6),
        textColor: .primary,
        backgroundColor: Color(.systemBackground),
        
        // HER: Vi bruker AnyShapeStyle(.regularMaterial) for glass-effekt
        drawerBackground: AnyShapeStyle(.regularMaterial),
        
        drawerHeaderColor: Color(.systemGray6),
        drawerCornerRadius: 24,
        drawerShadowColor: Color.primary.opacity(0.1)
    )
    
    static let minimal = AppTheme(
        name: "Minimal",
        arrowIcon: "chevron.right",
        arrowColor: .primary,
        textColor: .primary,
        backgroundColor: Color(.systemGray6),
        
        // Her bruker vi en vanlig farge, men pakket inn i AnyShapeStyle
        drawerBackground: AnyShapeStyle(Color(.systemGray6)),
        
        drawerHeaderColor: Color(.systemGray5),
        drawerCornerRadius: 16,
        drawerShadowColor: Color.primary.opacity(0.1)
    )
}
