//
//  TrackListViewController.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

final class TrackListViewController: UIViewController {

    // MARK: - Properties
    private let folder: AudioFolder
    private var tracks: [AudioTrack] = []
    private var totalDuration: TimeInterval = 0

    // MARK: - UI
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(TrackChapterCell.self, forCellReuseIdentifier: TrackChapterCell.identifier)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 56
        table.separatorStyle = .none
        table.backgroundColor = .clear
        return table
    }()

    private lazy var headerView: TrackListHeaderView = {
        let header = TrackListHeaderView()
        header.onResumePlay = { [weak self] in
            self?.resumePlayback()
        }
        return header
    }()

    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Init
    init(folder: AudioFolder) {
        self.folder = folder
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMiniPlayer()
        loadTracks()

        AudioPlayerManager.shared.addDelegate(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMiniPlayerVisibility()
        updateHeaderView()
        tableView.reloadData()
        scrollToLastPlayedTrack()
    }

    // MARK: - Scroll to Last Played

    /// 滚动到上次播放的曲目，使其显示在列表中间
    private func scrollToLastPlayedTrack() {
        // 优先滚动到当前正在播放的曲目
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name,
           let index = tracks.firstIndex(of: currentTrack) {
            scrollToIndex(index)
            return
        }

        // 否则滚动到该文件夹上次播放的曲目
        if let lastPlayedURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name),
           let index = tracks.firstIndex(where: { $0.url == lastPlayedURL }) {
            scrollToIndex(index)
        }
    }

    private func scrollToIndex(_ index: Int) {
        let indexPath = IndexPath(row: index, section: 0)

        // 延迟一点执行，确保 tableView 已经完成布局
        DispatchQueue.main.async {
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        }
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = DesignTokens.background

        // Navigation bar title with serif font
        let titleLabel = UILabel()
        titleLabel.text = folder.name
        titleLabel.font = DesignTokens.headlineSmall
        titleLabel.textColor = DesignTokens.onSurface
        navigationItem.titleView = titleLabel

        // Right bar button: settings
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showFolderSettings)
        )

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupMiniPlayer() {
        view.addSubview(miniPlayerView)

        NSLayoutConstraint.activate([
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 64),
        ])

        miniPlayerView.onTap = { [weak self] in
            self?.showPlayer()
        }
    }

    // MARK: - Header View

    private func configureTableHeaderView() {
        // Size the header to fit
        let targetWidth = tableView.bounds.width > 0 ? tableView.bounds.width : view.bounds.width
        let fittingSize = CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height)
        headerView.frame = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: 0))
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        let size = headerView.systemLayoutSizeFitting(
            fittingSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        headerView.frame = CGRect(origin: .zero, size: size)
        tableView.tableHeaderView = headerView
    }

    private func updateHeaderView() {
        let trackCount = tracks.count

        // Format total duration
        let totalDurationStr = formatTotalDuration(totalDuration)

        // Compute progress
        let progress = computeProgress()

        // Determine resume chapter name
        let resumeChapter = getResumeChapterName()

        headerView.configure(
            trackCount: trackCount,
            totalDuration: totalDurationStr,
            progress: progress,
            resumeChapter: resumeChapter
        )

        configureTableHeaderView()
    }

    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        // NaN/Inf 防御：Int(NaN) 会直接运行时崩溃
        guard duration.isFinite, duration > 0 else { return "0m" }
        return duration.hoursMinutesText
    }

    private func computeProgress() -> String {
        guard !tracks.isEmpty, totalDuration > 0 else { return "0%" }

        var listenedDuration: TimeInterval = 0
        let lastPlayedIndex = getLastPlayedTrackIndex()

        for (index, track) in tracks.enumerated() {
            if index < lastPlayedIndex {
                // Completed tracks: count full duration
                listenedDuration += track.duration
            } else if index == lastPlayedIndex {
                // Current / last played track: count saved position
                let savedPosition = PlaybackStateManager.shared.getTrackPosition(url: track.url)
                listenedDuration += savedPosition
            }
            // Tracks after last played: not listened
        }

        let percentage = Int((listenedDuration / totalDuration) * 100)
        return "\(min(percentage, 100))%"
    }

    private func getLastPlayedTrackIndex() -> Int {
        // Check currently playing track first
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name,
           let index = tracks.firstIndex(of: currentTrack) {
            return index
        }

        // Then check last played track
        if let lastPlayedURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name),
           let index = tracks.firstIndex(where: { $0.url == lastPlayedURL }) {
            return index
        }

        return -1
    }

    private func getResumeChapterName() -> String? {
        // Check currently playing track
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name,
           let index = tracks.firstIndex(of: currentTrack) {
            return "第\(index + 1)章"
        }

        // Check last played track
        if let lastPlayedURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name),
           let index = tracks.firstIndex(where: { $0.url == lastPlayedURL }) {
            return "第\(index + 1)章"
        }

        return nil
    }

    // MARK: - Resume Playback

    private func resumePlayback() {
        // Try to resume last played track
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name {
            // Already playing in this folder, just toggle or show player
            if !AudioPlayerManager.shared.isPlaying {
                AudioPlayerManager.shared.togglePlayPause()
            }
            showPlayer()
            return
        }

        if let lastPlayedURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name),
           let track = tracks.first(where: { $0.url == lastPlayedURL }) {
            AudioPlayerManager.shared.play(track: track, in: tracks)
        } else if let firstTrack = tracks.first {
            // No last played track, start from the beginning
            AudioPlayerManager.shared.play(track: firstTrack, in: tracks)
        }

        updateMiniPlayerVisibility()
        tableView.reloadData()
    }

    // MARK: - Data Loading
    private func loadTracks() {
        // 快速加载列表（不含时长）
        tracks = FileService.shared.getTracks(in: folder)
        updateHeaderView()
        tableView.reloadData()

        // 异步加载时长
        FileService.shared.loadDurations(for: tracks) { [weak self] updatedTracks in
            guard let self = self else { return }
            self.tracks = updatedTracks
            self.totalDuration = updatedTracks.reduce(0) { $0 + $1.duration }
            self.updateHeaderView()
            self.tableView.reloadData()
        }
    }

    // MARK: - Track Completed Heuristic

    private func isTrackCompleted(at index: Int) -> Bool {
        let lastPlayedIndex = getLastPlayedTrackIndex()
        guard lastPlayedIndex >= 0 else { return false }

        // Tracks before the current/last-played track are considered completed
        return index < lastPlayedIndex
    }

    // MARK: - Mini Player
    private func updateMiniPlayerVisibility() {
        let hasTrack = AudioPlayerManager.shared.currentTrack != nil
        miniPlayerView.isHidden = !hasTrack

        // 刷新 mini player 内容
        if hasTrack {
            miniPlayerView.refreshUI()
        }

        let bottomInset: CGFloat = hasTrack ? 64 : 0
        tableView.contentInset.bottom = bottomInset
        tableView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func showPlayer() {
        let playerVC = PlayerViewController()
        playerVC.modalPresentationStyle = .pageSheet
        if let sheet = playerVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(playerVC, animated: true)
    }

    // MARK: - Folder Settings
    @objc private func showFolderSettings() {
        let settings = PlaybackStateManager.shared
        let skipIntro = settings.getSkipIntroSeconds(forFolder: folder.name)
        let skipOutro = settings.getSkipOutroSeconds(forFolder: folder.name)

        let alert = UIAlertController(
            title: "文件夹设置",
            message: "「\(folder.name)」的播放设置",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(
            title: "跳过开头：\(skipIntro.skipDurationText)",
            style: .default
        ) { [weak self] _ in
            self?.showSkipIntroPicker()
        })

        alert.addAction(UIAlertAction(
            title: "跳过结尾：\(skipOutro.skipDurationText)",
            style: .default
        ) { [weak self] _ in
            self?.showSkipOutroPicker()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func showSkipIntroPicker() {
        let options = [0, 5, 10, 15, 30, 60, 90, 120]
        let currentValue = PlaybackStateManager.shared.getSkipIntroSeconds(forFolder: folder.name)

        let alert = UIAlertController(
            title: "跳过开头",
            message: "每次播放新曲目时自动跳过开头",
            preferredStyle: .actionSheet
        )

        // 用标题前缀 ✓ 标记当前选中项（UIAlertAction 的 "checked" 是私有 KVC，有审核风险）
        for seconds in options {
            let isSelected = seconds == currentValue
            let action = UIAlertAction(title: (isSelected ? "✓ " : "") + seconds.skipDurationText, style: .default) { [weak self] _ in
                guard let self = self else { return }
                PlaybackStateManager.shared.setSkipIntroSeconds(seconds, forFolder: self.folder.name)
            }
            alert.addAction(action)
        }

        // 自定义输入
        let isCustomSelected = !options.contains(currentValue) && currentValue > 0
        let customTitle = isCustomSelected ? "✓ 自定义 (\(currentValue.skipDurationText))" : "自定义..."
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.showCustomSkipInput(title: "自定义跳过开头", message: "请输入要跳过的秒数", current: currentValue) { seconds in
                PlaybackStateManager.shared.setSkipIntroSeconds(seconds, forFolder: self.folder.name)
            }
        }
        alert.addAction(customAction)

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    /// 通用「自定义秒数」输入弹窗，跳过开头/结尾共用
    private func showCustomSkipInput(title: String, message: String, current: Int, setter: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "秒数"
            textField.keyboardType = .numberPad
            if current > 0 {
                textField.text = "\(current)"
            }
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            if let text = alert.textFields?.first?.text,
               let seconds = Int(text), seconds >= 0 {
                setter(seconds)
            }
        })

        present(alert, animated: true)
    }

    private func showSkipOutroPicker() {
        let options = [0, 5, 10, 15, 30, 60]
        let currentValue = PlaybackStateManager.shared.getSkipOutroSeconds(forFolder: folder.name)

        let alert = UIAlertController(
            title: "跳过结尾",
            message: "曲目结尾前自动跳到下一曲",
            preferredStyle: .actionSheet
        )

        for seconds in options {
            let isSelected = seconds == currentValue
            let action = UIAlertAction(title: (isSelected ? "✓ " : "") + seconds.skipDurationText, style: .default) { [weak self] _ in
                guard let self = self else { return }
                PlaybackStateManager.shared.setSkipOutroSeconds(seconds, forFolder: self.folder.name)
            }
            alert.addAction(action)
        }

        // 自定义输入
        let isCustomSelected = !options.contains(currentValue) && currentValue > 0
        let customTitle = isCustomSelected ? "✓ 自定义 (\(currentValue.skipDurationText))" : "自定义..."
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.showCustomSkipInput(title: "自定义跳过结尾", message: "请输入曲目结束前要跳过的秒数", current: currentValue) { seconds in
                PlaybackStateManager.shared.setSkipOutroSeconds(seconds, forFolder: self.folder.name)
            }
        }
        alert.addAction(customAction)

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

}

// MARK: - UITableViewDataSource
extension TrackListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TrackChapterCell.identifier, for: indexPath) as! TrackChapterCell
        let track = tracks[indexPath.row]
        let isPlaying = AudioPlayerManager.shared.currentTrack == track
        let isCompleted = isTrackCompleted(at: indexPath.row)
        cell.configure(with: track, index: indexPath.row + 1, isPlaying: isPlaying, isCompleted: isCompleted)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension TrackListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let track = tracks[indexPath.row]
        AudioPlayerManager.shared.play(track: track, in: tracks)

        updateMiniPlayerVisibility()
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completionHandler in
            self?.confirmDeleteTrack(at: indexPath)
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func confirmDeleteTrack(at indexPath: IndexPath) {
        let track = tracks[indexPath.row]

        let alert = UIAlertController(
            title: "删除音频",
            message: "确定要删除「\(track.displayName)」吗？此操作不可恢复。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteTrack(at: indexPath)
        })

        present(alert, animated: true)
    }

    private func deleteTrack(at indexPath: IndexPath) {
        let track = tracks[indexPath.row]
        let isCurrentTrack = AudioPlayerManager.shared.currentTrack == track

        if FileService.shared.deleteTrack(track) {
            // 清理该曲目的进度记录，避免 UserDefaults 残留孤儿 key
            PlaybackStateManager.shared.clearTrackPosition(url: track.url)

            tracks.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)

            if isCurrentTrack {
                // 正在播放的曲目被删除：完全停止并卸载，避免迷你播放器残留已删内容
                AudioPlayerManager.shared.stop()
            } else {
                // 同步播放列表并修正 currentIndex，防止上一/下一曲错位
                AudioPlayerManager.shared.updatePlaylist(afterDeletion: tracks)
            }

            // Update total duration and header
            totalDuration = tracks.reduce(0) { $0 + $1.duration }
            updateHeaderView()

            // 如果删除后没有音频了，返回上一页
            if tracks.isEmpty {
                navigationController?.popViewController(animated: true)
            }
        }
    }
}

// MARK: - AudioPlayerDelegate
extension TrackListViewController: AudioPlayerDelegate {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        // MiniPlayerView 会自己处理
    }

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        tableView.reloadData()
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateMiniPlayerVisibility()
        updateHeaderView()
        tableView.reloadData()
    }

    func playerDidFinishTrack() {
        // 自动播放下一曲在 AudioPlayerManager 中处理
    }

    func playerDidFailToLoad(_ track: AudioTrack) {
        tableView.reloadData()
        // 仅当本页可见且没有其他弹窗时提示，避免多个页面同时弹
        guard view.window != nil, presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: "无法播放",
            message: "「\(track.displayName)」可能已损坏或格式不受支持。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}
