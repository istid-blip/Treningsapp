//
//  CircuitUIComponents.swift
//  Treningsapp
//
//  Created by Frode Halrynjo on 15/02/2026.
//
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Draggable Segment View
/// Visningen av hver enkelt øvelse i rutenettet (grid).
/// Håndterer drag-and-drop logikk og visning av info.
struct DraggableSegmentView: View {
    var segment: CircuitExercise
    var isLast: Bool
    var theme: AppTheme
    @Binding var draggingSegment: CircuitExercise?
    var onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TreningsKort(
                tittel: segment.name,
                undertittel: segmentDescription(for: segment), // Funksjon fra Helpers
                ikon: iconForSegment(segment),                 // Funksjon fra Helpers
                bakgrunnsfarge: theme.color(for: segment.category),
                tekstFarge: segment.category == .other ? Color.primary : theme.textColor
            )
            .onTapGesture { onEdit() }
            .aspectRatio(1.0, contentMode: .fit)
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
            .onDrag {
                self.draggingSegment = segment
                return NSItemProvider(object: String(describing: segment.persistentModelID) as NSString)
            }
            
            // Pil som viser flyt mellom øvelser
            Image(systemName: theme.arrowIcon)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(theme.arrowColor)
                .frame(width: 20)
                .opacity(isLast ? 0 : 1)
        }
    }
}

// MARK: - Drawer View
/// En gjenbrukbar "skuff" som glir opp fra bunnen eller ned fra toppen.
struct DrawerView<Content: View>: View {
    let theme: AppTheme
    let edge: VerticalEdge
    let maxHeight: CGFloat
    let content: Content
    
    init(theme: AppTheme, edge: VerticalEdge = .top, maxHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.edge = edge
        if let max = maxHeight {
            self.maxHeight = max
        } else {
            self.maxHeight = (edge == .bottom ? 320 : 550)
        }
        self.content = content()
    }
    
    var body: some View {
        VStack {
            if edge == .bottom { Spacer() }
            content
                .background(theme.drawerBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.drawerCornerRadius))
                .shadow(color: theme.drawerShadowColor, radius: 20, x: 0, y: edge == .top ? 10 : -10)
                .padding(.horizontal, 16)
                .padding(.top, edge == .top ? 100 : 0)
                .padding(.bottom, edge == .bottom ? 40 : 0)
                .frame(maxHeight: maxHeight)
                .animation(.snappy, value: maxHeight)
            if edge == .top { Spacer() }
        }
        .transition(.move(edge: edge == .top ? .top : .bottom))
    }
}

// MARK: - Vertical Ruler
/// En rullbar linjal for å velge verdier (reps, vekt, etc.)
struct VerticalRuler: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    
    private let itemHeight: CGFloat = 40
    private let rulerHeight: CGFloat = 200
    
    @State private var dragOffset: CGFloat = 0
    @State private var initialDragValue: Int? = nil
    let feedbackGenerator = UISelectionFeedbackGenerator()
    
    var body: some View {
        GeometryReader { geometry in
            let midY = geometry.size.height / 2
            let centerX = geometry.size.width / 2
            
            ZStack {
                Color.black.opacity(0.001).contentShape(Rectangle())
                let numLinesHalf = Int(ceil(rulerHeight / itemHeight / 2)) + 1
                
                ForEach(-numLinesHalf...numLinesHalf, id: \.self) { i in
                    let num = value + (i * step)
                    if range.contains(num) {
                        let lineY = midY + CGFloat(i) * itemHeight + dragOffset
                        let isMajor = num % (step * 5) == 0
                        let dist = abs(lineY - midY)
                        let opacity = max(0, 1 - (dist / (rulerHeight / 2)))
                        
                        if opacity > 0 {
                            Rectangle()
                                .fill(Color.gray.opacity(isMajor ? 0.5 : 0.3))
                                .frame(width: isMajor ? 80 : 40, height: 2)
                                .position(x: centerX, y: lineY)
                                .opacity(opacity)
                        }
                    }
                }
                
                // Indikator-strek
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 110, height: 4)
                    .cornerRadius(2)
                    .position(x: centerX, y: midY)
                    .allowsHitTesting(false)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        handleDragChange(gesture)
                    }
                    .onEnded { _ in
                        initialDragValue = nil
                        withAnimation(.snappy(duration: 0.15)) { dragOffset = 0 }
                    }
            )
        }
        .frame(height: rulerHeight)
        .clipped()
    }
    
    private func handleDragChange(_ gesture: DragGesture.Value) {
        if initialDragValue == nil {
            initialDragValue = value
            feedbackGenerator.prepare()
        }
        let rawTranslation = gesture.translation.height
        let magnitude = abs(rawTranslation)
        // Akselerasjonseffekt: Raskere scrolling ved lange drag
        let boostFactor = 1.0 + (magnitude / 200.0)
        let effectiveTranslation = rawTranslation * boostFactor
        let steps = -Int(effectiveTranslation / itemHeight)
        let remainder = effectiveTranslation.truncatingRemainder(dividingBy: itemHeight)
        
        if let startVal = initialDragValue {
            let calculatedValue = startVal + (steps * step)
            var newValue = value
            
            if calculatedValue < range.lowerBound {
                newValue = range.lowerBound
                dragOffset = remainder / 3
            } else if calculatedValue > range.upperBound {
                newValue = range.upperBound
                dragOffset = remainder / 3
            } else {
                newValue = calculatedValue
                dragOffset = remainder
            }
            
            if newValue != value {
                feedbackGenerator.selectionChanged()
                value = newValue
            }
        }
    }
}
