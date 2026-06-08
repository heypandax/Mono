//
//  FolderListViewController.swift
//  Mono
//
//  Created by Phase 3 UI Overhaul
//

import UIKit

final class FolderListViewController: UIViewController {

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(AudiobookCardCell.self, forCellReuseIdentifier: AudiobookCardCell.identifier)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 110
        table.separatorStyle = .none
        table.backgroundColor = DesignTokens.background
        table.contentInset = UIEdgeInsets(top: DesignTokens.Spacing.sm, left: 0, bottom: DesignTokens.Spacing.sm, right: 0)
        return table
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private var miniPlayerBottomConstraint: NSLayoutConstraint!

    private lazy var searchResultsVC: SearchResultsViewController = {
        let vc = SearchResultsViewController()
        vc.onSelectFolder = { [weak self] folder in
            guard let self = self else { return }
            self.searchController.isActive = false
            let trackListVC = TrackListViewController(folder: folder)
            self.navigationController?.pushViewController(trackListVC, animated: true)
        }
        return vc
    }()

    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: searchResultsVC)
        sc.searchResultsUpdater = searchResultsVC
        sc.searchBar.placeholder = "搜索有声书"
        sc.obscuresBackgroundDuringPresentation = false
        return sc
    }()

    // MARK: - Data

    private var folders: [AudioFolder] = []
    /// Cached total duration strings per folder name
    private var folderDurations: [String: String] = [:]
    /// Cached track lists per folder name —— 进度/状态计算每 0.5s 触发一次，
    /// 不缓存的话会在主线程反复做磁盘目录枚举
    private var folderTracks: [String: [AudioTrack]] = [:]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMiniPlayer()
        AudioPlayerManager.shared.addDelegate(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFolders()
        updateMiniPlayerVisibility()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "听书"
        view.backgroundColor = DesignTokens.background

        // Large title with serif font
        navigationController?.navigationBar.prefersLargeTitles = true
        let largeTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.serif(size: 34, weight: .bold),
            .foregroundColor: DesignTokens.onSurface
        ]
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: DesignTokens.headlineSmall,
            .foregroundColor: DesignTokens.onSurface
        ]
        navigationController?.navigationBar.largeTitleTextAttributes = largeTitleAttributes
        navigationController?.navigationBar.titleTextAttributes = titleAttributes
        navigationController?.navigationBar.tintColor = DesignTokens.primary
        navigationController?.navigationBar.barTintColor = DesignTokens.background
        navigationController?.navigationBar.backgroundColor = DesignTokens.background

        // Search controller
        navigationItem.searchController = searchController
        definesPresentationContext = true

        // Settings button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )

        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Pull-to-refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshFolders), for: .valueChanged)
        tableView.refreshControl = refreshControl

        // 空状态的「了解如何导入」入口
        emptyStateView.onImportHelpTapped = { [weak self] in
            self?.showImportHelp()
        }
    }

    private func showImportHelp() {
        let alert = UIAlertController(
            title: "如何导入有声书",
            message: """

            1. 用数据线把 iPhone 连接到电脑
            2. Mac：打开「访达」，在侧栏选中你的 iPhone，切换到「文件」标签
               Windows：打开 iTunes，进入设备 →「文件共享」
            3. 找到 Mono，把整理好的有声书文件夹拖进去
            4. 回到本页下拉刷新即可看到
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }

    private func setupMiniPlayer() {
        view.addSubview(miniPlayerView)

        miniPlayerBottomConstraint = miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerBottomConstraint,
            miniPlayerView.heightAnchor.constraint(equalToConstant: 64)
        ])

        miniPlayerView.onTap = { [weak self] in
            self?.showPlayer()
        }
    }

    // MARK: - Data Loading

    private func loadFolders() {
        folders = FileService.shared.getFolders()
        tableView.reloadData()
        emptyStateView.isHidden = !folders.isEmpty
        tableView.isHidden = folders.isEmpty

        // Load durations asynchronously for each folder
        for folder in folders {
            // 曲目数变化（外部增删了文件）时使缓存失效
            if let cached = folderTracks[folder.name], cached.count != folder.trackCount {
                folderTracks.removeValue(forKey: folder.name)
                folderDurations.removeValue(forKey: folder.name)
            }
            if folderDurations[folder.name] == nil {
                loadDuration(for: folder)
            }
        }
    }

    /// 取文件夹的曲目列表（带缓存，避免在主线程高频做磁盘 I/O）
    private func tracksForFolder(_ folder: AudioFolder) -> [AudioTrack] {
        if let cached = folderTracks[folder.name] { return cached }
        let tracks = FileService.shared.getTracks(in: folder)
        folderTracks[folder.name] = tracks
        return tracks
    }

    private func loadDuration(for folder: AudioFolder) {
        let tracks = FileService.shared.getTracks(in: folder)
        folderTracks[folder.name] = tracks
        FileService.shared.loadDurations(for: tracks) { [weak self] loadedTracks in
            guard let self = self else { return }
            let totalSeconds = loadedTracks.reduce(0.0) { $0 + $1.duration }
            let formatted = self.formatDuration(totalSeconds)
            DispatchQueue.main.async {
                self.folderDurations[folder.name] = formatted
                // Reload only the affected row if the folder is still present
                if let index = self.folders.firstIndex(where: { $0.name == folder.name }) {
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds > 0, seconds.isFinite else { return "\u{2014}" }
        return seconds.hoursMinutesText
    }

    @objc private func refreshFolders() {
        folderDurations.removeAll()
        folderTracks.removeAll()
        loadFolders()
        tableView.refreshControl?.endRefreshing()
    }

    // MARK: - Status & Progress

    private func statusForFolder(_ folder: AudioFolder) -> AudiobookStatus {
        // Currently playing this folder
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name {
            return .listening
        }
        guard let lastPlayedURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name) else {
            return .notStarted
        }
        // 上次播放的是最后一曲且其进度已被清除（曲目播完会清进度）→ 视为已完成
        let tracks = tracksForFolder(folder)
        if let lastTrack = tracks.last, lastTrack.url == lastPlayedURL,
           PlaybackStateManager.shared.getTrackPosition(url: lastPlayedURL) <= 0 {
            return .completed
        }
        return .listening
    }

    private func progressForFolder(_ folder: AudioFolder) -> CGFloat {
        guard folder.trackCount > 0 else { return 0 }

        // If currently playing this folder, use live data
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name {
            let player = AudioPlayerManager.shared
            let duration = player.duration
            if duration > 0, duration.isFinite {
                // Simplified: progress within current track / trackCount as a rough indicator
                let trackProgress = player.currentTime / duration
                // Find the index of the current track
                let tracks = tracksForFolder(folder)
                if let trackIndex = tracks.firstIndex(where: { $0.url == currentTrack.url }) {
                    let completedFraction = CGFloat(trackIndex) / CGFloat(folder.trackCount)
                    let currentFraction = CGFloat(trackProgress) / CGFloat(folder.trackCount)
                    return min(completedFraction + currentFraction, 1.0)
                }
                return CGFloat(trackProgress) / CGFloat(folder.trackCount)
            }
        }

        // Has a last-played track
        if let lastURL = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name) {
            let tracks = tracksForFolder(folder)
            if let trackIndex = tracks.firstIndex(where: { $0.url == lastURL }) {
                let position = PlaybackStateManager.shared.getTrackPosition(url: lastURL)
                let completedFraction = CGFloat(trackIndex) / CGFloat(folder.trackCount)
                // If we have position info, add partial progress for the last track
                if position > 0 {
                    let partialFraction = CGFloat(0.5) / CGFloat(folder.trackCount) // rough estimate
                    return min(completedFraction + partialFraction, 1.0)
                }
                return completedFraction
            }
        }

        return 0
    }

    // MARK: - Mini Player

    private func updateMiniPlayerVisibility() {
        let hasTrack = AudioPlayerManager.shared.currentTrack != nil
        miniPlayerView.isHidden = !hasTrack

        if hasTrack {
            miniPlayerView.refreshUI()
        }

        let bottomInset: CGFloat = hasTrack ? 64 : 0
        tableView.contentInset.bottom = bottomInset + DesignTokens.Spacing.sm
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

    @objc private func showSettings() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension FolderListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AudiobookCardCell.identifier, for: indexPath) as! AudiobookCardCell
        let folder = folders[indexPath.row]

        let durationText = folderDurations[folder.name] ?? "\u{2014}"
        let status = statusForFolder(folder)
        let progress = progressForFolder(folder)

        cell.configure(
            folder: folder,
            trackCount: folder.trackCount,
            totalDurationFormatted: durationText,
            progress: progress,
            status: status,
            lastActivity: nil
        )
        return cell
    }
}

// MARK: - UITableViewDelegate
extension FolderListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let folder = folders[indexPath.row]
        let trackListVC = TrackListViewController(folder: folder)
        navigationController?.pushViewController(trackListVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completionHandler in
            self?.confirmDeleteFolder(at: indexPath)
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func confirmDeleteFolder(at indexPath: IndexPath) {
        let folder = folders[indexPath.row]

        let alert = UIAlertController(
            title: "删除文件夹",
            message: "确定要删除「\(folder.name)」及其中的 \(folder.trackCount) 个音频文件吗？此操作不可恢复。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteFolder(at: indexPath)
        })

        present(alert, animated: true)
    }

    private func deleteFolder(at indexPath: IndexPath) {
        let folder = folders[indexPath.row]
        let isCurrentFolder = AudioPlayerManager.shared.currentTrack?.folderName == folder.name

        if FileService.shared.deleteFolder(folder) {
            // 正在播放该文件夹时完全停止并卸载，避免迷你播放器残留已删内容
            if isCurrentFolder {
                AudioPlayerManager.shared.stop()
            }
            // 清理该文件夹的全部持久化数据（跳过设置、上次播放、各曲目进度）
            PlaybackStateManager.shared.clearFolderData(forFolder: folder.name)

            folders.remove(at: indexPath.row)
            folderDurations.removeValue(forKey: folder.name)
            folderTracks.removeValue(forKey: folder.name)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            emptyStateView.isHidden = !folders.isEmpty
            tableView.isHidden = folders.isEmpty
            updateMiniPlayerVisibility()
        }
    }
}

// MARK: - AudioPlayerDelegate
extension FolderListViewController: AudioPlayerDelegate {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        // Refresh currently playing folder's cell to update progress
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           let index = folders.firstIndex(where: { $0.name == currentTrack.folderName }) {
            let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? AudiobookCardCell
            let progress = progressForFolder(folders[index])
            cell?.configure(
                folder: folders[index],
                trackCount: folders[index].trackCount,
                totalDurationFormatted: folderDurations[folders[index].name] ?? "\u{2014}",
                progress: progress,
                status: .listening,
                lastActivity: nil
            )
        }
    }

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        updateMiniPlayerVisibility()
        tableView.reloadData()
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateMiniPlayerVisibility()
        tableView.reloadData()
    }

    func playerDidFinishTrack() {
        tableView.reloadData()
    }
}
