//
//  SwiftUITooltipView.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 11/4/22.
//

import SwiftUI

private struct TutorialConfigurations: Hashable {
    let arrowPointingTo: CGPoint
    let configuration: SwiftUITooltipView.Configuration
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(arrowPointingTo.x)
        hasher.combine(arrowPointingTo.y)
    }
}

private struct TutorialConfigurationsPreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialConfigurations] = []
    
    static func reduce(value: inout [TutorialConfigurations], nextValue: () -> [TutorialConfigurations]) {
        value.append(contentsOf: nextValue())
    }
}

struct TutorialBackground<Content: View>: View {
    let tutorialShown: Binding<Bool>
    let content: () -> Content
    
    @State private var configs = [TutorialConfigurations]()
    
    var body: some View {
        if tutorialShown.wrappedValue {
            ZStack {
                content()
                    .coordinateSpace(name: "TutorialBackground")

                ForEach(configs, id: \.self) { config in
                    SwiftUITooltipView(configuration: config.configuration)
                        .position(config.arrowPointingTo)
                }
                
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            tutorialShown.wrappedValue = false
                        }
                    }
            }
            .onPreferenceChange(TutorialConfigurationsPreferenceKey.self) { configs in
                self.configs = configs
            }
        } else {
            content()
        }
    }
}

extension View {
    func tutorial(configuration: SwiftUITooltipView.Configuration) -> some View {
        self
            .overlay {
                GeometryReader { reader in
                    if configuration.arrowDirection == .up {
                        Color.clear
                            .preference(key: TutorialConfigurationsPreferenceKey.self, value: [TutorialConfigurations(arrowPointingTo: CGPoint(x: reader.frame(in: .named("TutorialBackground")).midX, y: reader.frame(in: .named("TutorialBackground")).maxY - 44), configuration: configuration)])
                    } else {
                        Color.clear
                            .preference(key: TutorialConfigurationsPreferenceKey.self, value: [TutorialConfigurations(arrowPointingTo: CGPoint(x: reader.frame(in: .named("TutorialBackground")).midX, y: reader.frame(in: .named("TutorialBackground")).minY), configuration: configuration)])
                    }
                }
            }
    }
}

struct SwiftUITooltipView: View {
    let configuration: Configuration
    
    enum ArrowDirection {
        case up
        case down
    }

    struct Configuration: Equatable {
        static let defaultPadding: CGFloat = 10
        
        private(set) var title, subtitle: NSAttributedString?
        private(set) var titleColor: UIColor = UIColor.white
        private(set) var subtitleColor: UIColor = UIColor.black
        private(set) var titleFont: UIFont = UIFont.systemFont(ofSize: 16)
        private(set) var subtitleFont: UIFont = UIFont.systemFont(ofSize: 14)
        private(set) var arrowDirection: ArrowDirection = .up
        private(set) var arrowHeight: CGFloat = 20.0
        private(set) var tooltipCenterOffsetXFromArrowCenterX: CGFloat = 0
        private(set) var backgroundColor: UIColor = .init(red: 7.0/255, green: 125.0/255, blue: 1, alpha: 1)
        private(set) var padding: CGFloat = Configuration.defaultPadding
    }
    
    @ViewBuilder
    private var text: some View {
        if let title = configuration.title {
            Text(AttributedString(title))
                .font(Font(configuration.titleFont))
                .foregroundColor(Color(uiColor: configuration.titleColor))
                .padding(configuration.padding)
                .background {
                    Color(uiColor: configuration.backgroundColor)
                }
                .cornerRadius(4)
                .offset(x: configuration.tooltipCenterOffsetXFromArrowCenterX, y: 0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch configuration.arrowDirection {
            case .up:
                Image("tooltipPointer")
                    .foregroundColor(Color(configuration.backgroundColor))
                
                if configuration.arrowHeight != 0 {
                    Color(configuration.backgroundColor)
                        .frame(width: 3, height: configuration.arrowHeight)
                }
                
                text
                
            case .down:
                text

                if configuration.arrowHeight != 0 {
                    Color(configuration.backgroundColor)
                        .frame(width: 3, height: configuration.arrowHeight)
                }

                Image("tooltipPointerDownArrow")
                    .foregroundColor(Color(configuration.backgroundColor))
            }
        }
        //.border(.green, width: 1)
    }
}

struct SwiftUITooltipView_Previews: PreviewProvider {
    @State private static var tutorialShown = true
    
    static var previews: some View {
        TutorialBackground(tutorialShown: $tutorialShown) {
            HStack {
                Text("Hello world")
                    .border(.red)
                    .tutorial(configuration: SwiftUITooltipView.Configuration(title: NSAttributedString(string: "Testing"), arrowDirection: .up, tooltipCenterOffsetXFromArrowCenterX: 0))

                Text("Hello world")
                    .border(.red)
                    .tutorial(configuration: SwiftUITooltipView.Configuration(title: NSAttributedString(string: "Testing"), arrowDirection: .up, tooltipCenterOffsetXFromArrowCenterX: 0))

//                Spacer()
            }
        }
    }
}
