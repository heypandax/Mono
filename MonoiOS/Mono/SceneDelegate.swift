//
//  SceneDelegate.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 创建窗口
        window = UIWindow(windowScene: windowScene)
        window?.backgroundColor = DesignTokens.background

        // 设置根视图控制器
        let folderListVC = FolderListViewController()
        let navigationController = UINavigationController(rootViewController: folderListVC)

        // 配置导航栏外观
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = DesignTokens.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: DesignTokens.onSurface,
            .font: DesignTokens.headlineSmall
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: DesignTokens.onSurface,
            .font: DesignTokens.headlineLarge
        ]

        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.tintColor = DesignTokens.primary

        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        // 恢复上次播放状态
        AudioPlayerManager.shared.restorePlayback()

        // 如果设置了启动时自动播放，则开始播放
        if PlaybackStateManager.shared.autoPlayOnLaunch,
           AudioPlayerManager.shared.currentTrack != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AudioPlayerManager.shared.play()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        savePlaybackState()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {
        savePlaybackState()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {
        savePlaybackState()
    }

    private func savePlaybackState() {
        if let track = AudioPlayerManager.shared.currentTrack {
            let time = AudioPlayerManager.shared.currentTime
            PlaybackStateManager.shared.saveState(trackURL: track.url, time: time)
            // 同时保存每曲位置：定时保存间隔 30 秒，退后台时不补存会丢最多 30 秒进度
            PlaybackStateManager.shared.saveTrackPosition(url: track.url, time: time)
        }
    }
}
