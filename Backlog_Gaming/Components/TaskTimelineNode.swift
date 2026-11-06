//
//  TaskTimelineNode.swift
//  Backlog_Gaming
//

import SwiftUI

/// Узел таймлайна дел: кружок с иконкой и «стебель» к соседним строкам.
/// Общий для карточки игры в канбане и для «Потока», чтобы они выглядели одинаково.
struct TaskTimelineNode: View {
    let symbolName: String
    let color: Color
    let isDone: Bool
    let isLast: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if !isLast {
                VStack(spacing: 0) {
                    Color.clear.frame(height: UITokens.nodeSize * 0.5 + 6)
                    Rectangle()
                        .fill(color.opacity(0.35))
                        .frame(width: UITokens.stemWidth)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            // Верхний стебель: между строками или «хвост» от верха секции у первой строки.
            VStack { Spacer() }
                .frame(width: UITokens.stemWidth)
                .background(color.opacity(0.35))
                .frame(height: 14)
                .offset(y: -12)
            Circle()
                .fill(color.opacity(isDone ? 0.45 : 0.92))
                .frame(width: UITokens.nodeSize, height: UITokens.nodeSize)
                .overlay {
                    Image(systemName: symbolName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
        .frame(width: UITokens.timelineLaneWidth)
        .accessibilityHidden(true)
    }
}
