//
//  AnimatedCheckmark.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/21/22.
//

import SwiftUI

struct AnimatedCheckmark: View {
    private(set) var completion: (() -> Void)? = nil
    @State private var innerTrimEnd: CGFloat = 0

    var body: some View {
        Checkmark()
            .trim(from: 0, to: innerTrimEnd)
            .stroke(.green, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            .onAppear() {
                withAnimation(.linear(duration: 0.3)) {
                    innerTrimEnd = 1
                }
                0.8.dispatchAsyncToMainQueueAfter {
                    completion?()
                }
            }
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
        AnimatedCheckmark()
            .frame(width: 50, height: 50)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
    }
}
