//
//  AppDelegate.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 音频会话在 AudioPlayerManager 初始化时配置并激活（启动即激活是产品需求，
        // SceneDelegate 的 restorePlayback 会在启动时触发单例创建），此处不再重复
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // 释放与已丢弃场景相关的资源
    }
}
