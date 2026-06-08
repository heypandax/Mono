//
//  FileService.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation
import AVFoundation

// @unchecked Sendable：唯一可变状态 durationCache 全部经由 cacheQueue 串行队列访问
final class FileService: @unchecked Sendable {
    static let shared = FileService()

    private let supportedExtensions = ["mp3", "m4a", "m4b", "wav", "aac", "flac", "caf"]

    // 时长缓存：key 为相对 Documents 的路径（跨重装稳定），持久化到 Caches 目录，
    // 避免每次冷启动都重新读取整个音频库的时长
    private var durationCache: [String: TimeInterval] = [:]
    private let cacheQueue = DispatchQueue(label: "com.mono.durationCache")
    private let cacheFileURL: URL

    private init() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheFileURL = cachesURL.appendingPathComponent("durationCache.json")
        loadDurationCache()
    }

    /// Documents 目录
    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - 时长缓存
    // 缓存 key 用 url.documentsRelativePath（与进度持久化共用同一规范化逻辑）

    private func loadDurationCache() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let cached = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return
        }
        durationCache = cached
    }

    /// 必须在 cacheQueue 上调用
    private func saveDurationCacheLocked() {
        guard let data = try? JSONEncoder().encode(durationCache) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)
    }

    private func cachedDuration(for url: URL) -> TimeInterval? {
        let key = url.documentsRelativePath
        return cacheQueue.sync { durationCache[key] }
    }

    // MARK: - 文件夹与曲目

    /// 获取所有文件夹（按名称排序）
    func getFolders() -> [AudioFolder] {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            var folders: [AudioFolder] = []

            for url in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    let trackCount = getTracksCount(in: url)
                    if trackCount > 0 {
                        folders.append(AudioFolder(
                            name: url.lastPathComponent,
                            url: url,
                            trackCount: trackCount
                        ))
                    }
                }
            }

            // 按文件夹名排序（数字感知排序）
            return folders.sorted {
                $0.name.compare($1.name, options: [.numeric, .caseInsensitive, .widthInsensitive]) == .orderedAscending
            }
        } catch {
            print("获取文件夹失败: \(error)")
            return []
        }
    }

    /// 获取文件夹内的音频文件数量
    private func getTracksCount(in folderURL: URL) -> Int {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            return contents.filter { url in
                supportedExtensions.contains(url.pathExtension.lowercased())
            }.count
        } catch {
            return 0
        }
    }

    /// 获取文件夹内的音频文件（按文件名排序）- 快速返回，不含时长
    func getTracks(in folder: AudioFolder) -> [AudioTrack] {
        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folder.url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            var tracks: [AudioTrack] = []

            for url in contents {
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    let track = AudioTrack(
                        fileName: url.lastPathComponent,
                        url: url,
                        folderName: folder.name,
                        duration: cachedDuration(for: url) ?? 0
                    )
                    tracks.append(track)
                }
            }

            // 按文件名排序（数字感知排序，确保 01 < 02 < 10）
            return tracks.sorted {
                $0.fileName.compare($1.fileName, options: [.numeric, .caseInsensitive, .widthInsensitive]) == .orderedAscending
            }
        } catch {
            print("获取音频文件失败: \(error)")
            return []
        }
    }

    /// 异步加载音频时长
    func loadDurations(for tracks: [AudioTrack], completion: @escaping ([AudioTrack]) -> Void) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            var updatedTracks: [AudioTrack] = []
            var didUpdateCache = false

            for track in tracks {
                var mutableTrack = track

                if let cached = self.cachedDuration(for: track.url) {
                    mutableTrack.duration = cached
                } else {
                    let duration = await self.loadAudioDuration(url: track.url)
                    mutableTrack.duration = duration
                    let key = track.url.documentsRelativePath
                    self.cacheQueue.sync { self.durationCache[key] = duration }
                    didUpdateCache = true
                }

                updatedTracks.append(mutableTrack)
            }

            if didUpdateCache {
                self.cacheQueue.async { self.saveDurationCacheLocked() }
            }

            let result = updatedTracks
            await MainActor.run {
                completion(result)
            }
        }
    }

    /// 获取音频时长。损坏文件返回 0，避免 NaN 污染上层求和计算
    private func loadAudioDuration(url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 0 }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }

    /// 根据URL查找对应的文件夹
    func findFolder(for trackURL: URL) -> AudioFolder? {
        let folderURL = trackURL.deletingLastPathComponent()
        let folderName = folderURL.lastPathComponent
        let trackCount = getTracksCount(in: folderURL)

        return AudioFolder(name: folderName, url: folderURL, trackCount: trackCount)
    }

    // MARK: - 删除操作

    /// 删除文件夹
    func deleteFolder(_ folder: AudioFolder) -> Bool {
        do {
            try FileManager.default.removeItem(at: folder.url)
            // 清除该文件夹下所有曲目的时长缓存
            let prefix = folder.name + "/"
            cacheQueue.async { [weak self] in
                guard let self = self else { return }
                self.durationCache = self.durationCache.filter { !$0.key.hasPrefix(prefix) }
                self.saveDurationCacheLocked()
            }
            return true
        } catch {
            print("删除文件夹失败: \(error)")
            return false
        }
    }

    /// 删除音频文件
    func deleteTrack(_ track: AudioTrack) -> Bool {
        do {
            try FileManager.default.removeItem(at: track.url)
            // 清除缓存
            let key = track.url.documentsRelativePath
            cacheQueue.async { [weak self] in
                guard let self = self else { return }
                self.durationCache.removeValue(forKey: key)
                self.saveDurationCacheLocked()
            }
            return true
        } catch {
            print("删除音频文件失败: \(error)")
            return false
        }
    }
}
