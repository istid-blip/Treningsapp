import SwiftUI

struct TreningsKort: View {
    var tittel: String
    var undertittel: String?
    var ikon: String?
    var bakgrunnsfarge: Color
    var tekstFarge: Color = .white
    
    var body: some View {
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
    }
}
