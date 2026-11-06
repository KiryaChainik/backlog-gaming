//
//  SymbolColorPicker.swift
//  Backlog_Gaming
//

import SwiftUI

/// Выбор SF Symbol и цвета из палитры `GameTaskVisual` — для новой игры, экрана игры и редактора дела.
struct SymbolColorPicker: View {
    let symbols: [String]
    @Binding var symbol: String
    @Binding var accentIndex: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(symbols, id: \.self) { sym in
                let isSelected = sym == symbol
                Button {
                    symbol = sym
                } label: {
                    Image(systemName: sym)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: UITokens.cardCornerRadius, style: .continuous)
                                .fill(isSelected
                                    ? GameTaskVisual.accentColor(at: accentIndex)
                                    : Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0 ..< GameTaskVisual.accentCount, id: \.self) { i in
                    Button {
                        accentIndex = i
                    } label: {
                        Circle()
                            .fill(GameTaskVisual.accentColor(at: i))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if accentIndex == i {
                                    Circle().strokeBorder(Color.primary, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Цвет \(i + 1)")
                    .accessibilityAddTraits(accentIndex == i ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
}
