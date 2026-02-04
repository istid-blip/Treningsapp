import SwiftUI

struct TreningsKort: View {
    var tittel: String
    var undertittel: String?
    var ikon: String?
    var bakgrunnsfarge: Color
    var tekstFarge: Color = .white
    
    // Forenklet: Skal vi vise pil til neste?
    var visPil: Bool = false
    
    var body: some View {
        ZStack(alignment: .center) {
            // Selve boksen
            VStack(spacing: 10) {
                if let ikon = ikon {
                    Image(systemName: ikon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundStyle(tekstFarge)
                }
                
                Text(tittel)
                    .font(.headline)
                    .foregroundStyle(tekstFarge)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                
                if let under = undertittel {
                    Spacer()
                    Text(under)
                        .font(.caption)
                        .foregroundStyle(tekstFarge.opacity(0.8))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
            .background(bakgrunnsfarge)
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // --- PILEN ---
            // Vi legger en pil som peker mot høyre på kanten av kortet
            if visPil {
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .bold()
                    .foregroundStyle(.gray)
                    // Flytter den ut til høyre kant, slik at den ligger mellom kortene
                    .offset(x: 55)
                    .zIndex(1)
            }
        }
        // Sørger for at pilen synes selv om den stikker utenfor
        .zIndex(visPil ? 1 : 0)
    }
}
