//
//  AnimatedCheckmark.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/21/22.
//

import SwiftUI

struct AnimatedCheckmarkWithText: View {
    private(set) var completion: (() -> Void)? = nil
    @State private var innerTrimEnd: CGFloat = 0

    var body: some View {
        VStack(spacing: 15) {
            Checkmark()
                .trim(from: 0, to: innerTrimEnd)
                .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(height: 50)
                .onAppear() {
                    withAnimation(.linear(duration: 0.3)) {
                        innerTrimEnd = 1
                    }
                    0.8.dispatchAsyncToMainQueueAfter {
                        completion?()
                    }
                }

            Text("pdfPagesAdded")
                .font(.title2)
        }
        .fixedSize()
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
    }
}

struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.size.width
        let height = rect.size.height
        
        var path = Path()
        path.move(to: .init(x: 0 * width, y: 0.5 * height))
        path.addLine(to: .init(x: 0.4 * width, y: 1.0 * height))
        path.addLine(to: .init(x: 1.0 * width, y: 0 * height))
        return path
    }
}

struct AnimatedCheckmark_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedCheckmarkWithText()
    }
}
