//
//  URL+Documents.swift
//  Mono
//

import Foundation

extension URL {
    /// 当前沙盒 Documents 目录
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 把 URL 转成相对 Documents 的路径，用作持久化 key。
    /// iOS 重装/更新 App 时沙盒容器 UUID 会变化，绝对路径会失效；相对路径不受影响。
    /// PlaybackStateManager（进度持久化）与 FileService（时长缓存）共用此一处实现，
    /// 避免两套规范化逻辑随时间漂移导致 key 对不上。
    var documentsRelativePath: String {
        let path = standardizedFileURL.path
        let docsPrefix = URL.documentsDirectory.standardizedFileURL.path + "/"
        if path.hasPrefix(docsPrefix) {
            return String(path.dropFirst(docsPrefix.count))
        }
        return path
    }
}
