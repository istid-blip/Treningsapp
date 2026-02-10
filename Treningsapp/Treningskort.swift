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
            VStack(spacing: 8) { // Endret spacing litt
                if let ikon = ikon {
                    Image(systemName: ikon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24) // Litt mindre ikon for å gi plass til tekst
                        .foregroundStyle(tekstFarge)
                }
                
                Text(tittel)
                    .font(.headline)
                    .foregroundStyle(tekstFarge)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1) // Tittelen får én linje
                
                Spacer()
                
                if let under = undertittel {
                    Text(under)
                        .font(.caption)
                        .fontWeight(.medium) // Litt tydeligere tekst
                        .foregroundStyle(tekstFarge.opacity(0.95))
                        .multilineTextAlignment(.center) // Sentrerer teksten hvis det er flere linjer
                        .fixedSize(horizontal: false, vertical: true) // Lar teksten bruke plassen den trenger i høyden
                }
                
                Spacer() // Ekstra spacer for å balansere innholdet vertikalt
            }
            .padding(8) // Litt mindre padding for å utnytte plassen på små kort
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(bakgrunnsfarge)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        }
}
