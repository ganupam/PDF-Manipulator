//
//  OpenedPDFSceneDelegate.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit
import PDFKit
import SwiftUI

final class OpenedPDFSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
          
        let window = UIWindow(windowScene: windowScene)

        let url = session.url
        if let url, let manager = PDFManager(url: url, scene: windowScene) {
            session.pdfManager = manager
            window.rootViewController = SplitViewController(scene: windowScene)
        } else {
            window.rootViewController = UIHostingController(rootView: ErrorOpeningPDFView())
        }
        windowScene.title = url?.lastPathComponent
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

extension OpenedPDFSceneDelegate {
    private struct ErrorOpeningPDFView: View {
        var body: some View {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Image(systemName: "info.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                
                Text("errorOpeningPDF")
                    .bold()
                    .padding(.bottom, 2)
                
                Spacer(minLength: 0)
            }
        }
    }
}
