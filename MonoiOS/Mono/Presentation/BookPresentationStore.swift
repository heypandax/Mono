//
//  BookPresentationStore.swift
//  Mono
//
//  书库与搜索结果共用的书行数据源：缓存曲目列表与总时长，并统一产出 BookPresentation，
//  确保两个入口不会各自推断出互相矛盾的书级状态。必须在主线程使用。
//

import Foundation

final class BookPresentationStore {

    private let files: FileService
    private let player: AudioPlayerManager
    private let state: PlaybackStateManager

    private var tracksCache: [String: [AudioTrack]] = [:]
    private var durationCache: [String: TimeInterval] = [:]
    private var durationLoadTokens: [String: UUID] = [:]
    private var completedDurationLoads: Set<String> = []

    init(files: FileService = .shared,
         player: AudioPlayerManager = .shared,
         state: PlaybackStateManager = .shared) {
        self.files = files
        self.player = player
        self.state = state
    }

    // MARK: - 读取

    /// 曲目数与文件夹记录不一致（外部增删了文件）时自动重新枚举
    func tracks(for folder: AudioFolder) -> [AudioTrack] {
        if let cached = tracksCache[folder.name], cached.count == folder.trackCount {
            return cached
        }
        // 曲目集合已变化：让尚未返回的旧时长任务失效。
        durationLoadTokens.removeValue(forKey: folder.name)
        let tracks = files.getTracks(in: folder)
        tracksCache[folder.name] = tracks
        durationCache.removeValue(forKey: folder.name)
        completedDurationLoads.remove(folder.name)
        return tracks
    }

    func presentation(for folder: AudioFolder) -> BookPresentation {
        let status = PlaybackPresenter.status(
            folderName: folder.name,
            chapterCount: folder.trackCount,
            tracks: tracks(for: folder),
            currentTrack: player.currentTrack,
            lastPlayedURL: state.getLastPlayedTrack(forFolder: folder.name)
        )
        return BookPresentation(
            title: folder.name,
            chapterCount: folder.trackCount,
            totalDuration: durationCache[folder.name],
            status: status
        )
    }

    // MARK: - 异步时长

    /// 时长尚未读取时异步补齐；完成后回调，调用方只需刷新对应行
    func loadDurationIfNeeded(for folder: AudioFolder, completion: @escaping (String) -> Void) {
        guard !completedDurationLoads.contains(folder.name),
              durationLoadTokens[folder.name] == nil else { return }
        let name = folder.name
        let tracksToLoad = tracks(for: folder)
        let token = UUID()
        durationLoadTokens[name] = token
        files.loadDurations(for: tracksToLoad) { [weak self] loadedTracks in
            guard let self, self.durationLoadTokens[name] == token else { return }
            self.durationLoadTokens.removeValue(forKey: name)
            self.completedDurationLoads.insert(name)
            self.tracksCache[name] = loadedTracks
            if !loadedTracks.isEmpty,
               loadedTracks.allSatisfy({ PlaybackPresenter.resolvedDuration($0.duration) != nil }) {
                self.durationCache[name] = loadedTracks.reduce(0) { $0 + $1.duration }
            } else {
                self.durationCache.removeValue(forKey: name)
            }
            completion(name)
        }
    }

    // MARK: - 失效

    func invalidate(folderName: String) {
        tracksCache.removeValue(forKey: folderName)
        durationCache.removeValue(forKey: folderName)
        durationLoadTokens.removeValue(forKey: folderName)
        completedDurationLoads.remove(folderName)
    }

    func invalidateAll() {
        tracksCache.removeAll()
        durationCache.removeAll()
        durationLoadTokens.removeAll()
        completedDurationLoads.removeAll()
    }
}
