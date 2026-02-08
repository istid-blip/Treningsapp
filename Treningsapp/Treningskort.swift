import SwiftUI

struct TreningsKort: View {
    // Interne variabler for visning
    private let tittel: String
    private let undertittel: String?
    private let ikon: String?
    private let bakgrunnsfarge: Color
    private let tekstFarge: Color
    
    // ------------------------------------------------------
    // INIT 1: For Hjem-skjermen (Tar imot en CircuitRoutine)
    // ------------------------------------------------------
    init(routine: CircuitRoutine, bakgrunnsfarge: Color = .blue) {
        self.tittel = routine.name
        self.undertittel = "\(routine.segments.count) øvelser"
        self.ikon = "figure.run.circle.fill"
        self.bakgrunnsfarge = bakgrunnsfarge
        self.tekstFarge = .white
    }
    
    // ------------------------------------------------------
    // INIT 2: For Detalj-skjermen (Manuelle verdier)
    // ------------------------------------------------------
    init(tittel: String, undertittel: String? = nil, ikon: String? = nil, bakgrunnsfarge: Color = .blue, tekstFarge: Color = .white) {
        self.tittel = tittel
        self.undertittel = undertittel
        self.ikon = ikon
        self.bakgrunnsfarge = bakgrunnsfarge
        self.tekstFarge = tekstFarge
    }
    
    var body: some View {
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
                .lineLimit(2)
            
            Spacer()
            
            if let under = undertittel {
                Text(under)
                    .font(.caption)
                    .foregroundStyle(tekstFarge.opacity(0.9))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bakgrunnsfarge)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}
