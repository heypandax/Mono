//
//  TrackListViewController.swift
//  Mono
//
//  书内章节页（Master 的 MChapterList）。当前章由文字 + 图标 + 短蓝竖线共同表达；
//  本版本不渲染「已完成章」，也不展示推断出的整本进度。
//

import UIKit

final class TrackListViewController: UIViewController {

    // MARK: - Data

    private let folder: AudioFolder
    private var tracks: [AudioTrack] = []
    /// nil 表示时长还没读完，UI 显示 “—”
    private var totalDuration: TimeInterval?
    private var hasPerformedInitialScroll = false

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(TrackChapterCell.self, forCellReuseIdentifier: TrackChapterCell.identifier)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 62
        table.separatorColor = DesignTokens.outlineVariant
        table.separatorInset = UIEdgeInsets(top: 0, left: TrackChapterCell.separatorLeftInset, bottom: 0, right: 0)
        table.backgroundColor = DesignTokens.background
        table.accessibilityIdentifier = "chapters.list"
        return table
    }()

    private lazy var headerView: TrackListHeaderView = {
        let header = TrackListHeaderView()
        header.onPrimaryAction = { [weak self] in self?.handlePrimaryAction() }
        return header
    }()

    /// 书籍信息区所在的固定单行 cell（只有一行，不参与复用）
    private lazy var headerCell = MonoHostCell(content: headerView)

    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.onTap = { [weak self] in self?.showPlayer() }
        return view
    }()

    // MARK: - Init

    init(folder: AudioFolder) {
        self.folder = folder
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        updateHeader()
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToCurrentChapterIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = miniPlayerView.contentOverlapHeight
        guard abs(tableView.contentInset.bottom - inset) > 0.5 else { return }
        tableView.contentInset.bottom = inset
        tableView.verticalScrollIndicatorInsets.bottom = inset
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = DesignTokens.background
        // 书名在正文头部完整展示，导航栏保持原生返回
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "文件夹设置",
            style: .plain,
            target: self,
            action: #selector(showFolderSettings)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "chapters.folderSettings"

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            tableView.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth)
        ])
        let fullWidth = tableView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fullWidth.priority = .defaultHigh
        fullWidth.isActive = true
    }

    private func setupMiniPlayer() {
        view.addSubview(miniPlayerView)
        NSLayoutConstraint.activate([
            miniPlayerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            miniPlayerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            miniPlayerView.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth),
            // 背景铺到屏幕底部，Home Indicator 区不会透出底层内容
            miniPlayerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let fullWidth = miniPlayerView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fullWidth.priority = .defaultHigh
        fullWidth.isActive = true
    }

    // MARK: - Data loading

    private func loadTracks() {
        // 快速出列表（不含时长）
        tracks = FileService.shared.getTracks(in: folder)
        updateHeader()
        tableView.reloadData()

        FileService.shared.loadDurations(for: tracks) { [weak self] updatedTracks in
            guard let self else { return }
            let durationByURL = Dictionary(uniqueKeysWithValues: updatedTracks.map {
                ($0.url.standardizedFileURL.path, $0.duration)
            })
            // 保留回调到达时的真实列表，避免异步读取把已删除章节重新插回。
            self.tracks = self.tracks.map { track in
                var updated = track
                if let duration = durationByURL[track.url.standardizedFileURL.path] {
                    updated.duration = duration
                }
                return updated
            }
            self.totalDuration = self.resolvedTotalDuration(for: self.tracks)
            self.updateHeader()
            self.tableView.reloadData()
        }
    }

    private func resolvedTotalDuration(for tracks: [AudioTrack]) -> TimeInterval? {
        guard !tracks.isEmpty,
              tracks.allSatisfy({ PlaybackPresenter.resolvedDuration($0.duration) != nil }) else { return nil }
        return tracks.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Presentation

    /// 当前正在播放/暂停的本书章节序号（0-based）
    private var currentChapterIndex: Int? {
        guard let currentTrack = AudioPlayerManager.shared.currentTrack,
              currentTrack.folderName == folder.name else { return nil }
        return tracks.firstIndex(of: currentTrack)
    }

    /// 上次收听章节序号（0-based）。位置为 0 也照常算，不推断成「听完了」
    private var lastPlayedChapterIndex: Int? {
        guard let url = PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name) else { return nil }
        return PlaybackPresenter.index(of: url, in: tracks)
    }

    /// 主动作的目标章节
    private var targetChapterIndex: Int {
        currentChapterIndex ?? lastPlayedChapterIndex ?? 0
    }

    private func updateHeader() {
        let known = currentChapterIndex ?? lastPlayedChapterIndex
        let currentText = known.map { "上次听到第 \($0 + 1) / \(tracks.count) 章" }
        let ctaTitle = known.map { "继续第 \($0 + 1) 章" } ?? "从第 1 章开始"

        headerView.configure(
            bookTitle: folder.name,
            meta: "\(MonoFormat.chapterCountText(tracks.count)) · \(MonoFormat.totalDurationText(totalDuration))",
            currentChapterText: currentText,
            ctaTitle: ctaTitle
        )
    }

    private func chapterState(at index: Int) -> TrackChapterCell.State {
        guard index == currentChapterIndex else { return .plain }
        let player = AudioPlayerManager.shared
        return .current(
            isPlaying: player.isPlaying,
            elapsed: PlaybackPresenter.sanitize(player.currentTime),
            duration: PlaybackPresenter.resolvedDuration(player.duration) ?? PlaybackPresenter.resolvedDuration(tracks[index].duration)
        )
    }

    private func configure(_ cell: TrackChapterCell, at index: Int) {
        let track = tracks[index]
        cell.configure(
            index: index + 1,
            title: track.displayName,
            duration: PlaybackPresenter.resolvedDuration(track.duration),
            state: chapterState(at: index)
        )
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        let player = AudioPlayerManager.shared
        if currentChapterIndex != nil {
            // 本书已经在播放器里：暂停时先继续，然后进入播放器
            if !player.isPlaying { player.play() }
            showPlayer()
            return
        }
        guard !tracks.isEmpty else { return }
        let index = min(targetChapterIndex, tracks.count - 1)
        player.play(track: tracks[index], in: tracks)
        showPlayer()
    }

    /// 自动定位到当前/上次章节；已经可见就不动，避免打断用户滚动
    private func scrollToCurrentChapterIfNeeded() {
        guard let index = currentChapterIndex ?? lastPlayedChapterIndex, index < tracks.count else { return }
        let indexPath = IndexPath(row: index, section: SectionIndex.chapters)
        if hasPerformedInitialScroll,
           tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
            return
        }
        hasPerformedInitialScroll = true
        tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
    }

    private func updateMiniPlayerVisibility() {
        let hasTrack = AudioPlayerManager.shared.currentTrack != nil
        miniPlayerView.isHidden = !hasTrack
        if hasTrack { miniPlayerView.refreshUI() }
        view.setNeedsLayout()
    }

    private func showPlayer() {
        PlayerViewController.present(from: self)
    }

    // MARK: - Folder settings

    @objc private func showFolderSettings() {
        let settings = PlaybackStateManager.shared
        let skipIntro = settings.getSkipIntroSeconds(forFolder: folder.name)
        let skipOutro = settings.getSkipOutroSeconds(forFolder: folder.name)

        let alert = UIAlertController(
            title: "文件夹设置",
            message: "「\(folder.name)」的播放设置",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "跳过片头：\(skipIntro.skipDurationText)", style: .default) { [weak self] _ in
            self?.showSkipPicker(isIntro: true)
        })
        alert.addAction(UIAlertAction(title: "跳过片尾：\(skipOutro.skipDurationText)", style: .default) { [weak self] _ in
            self?.showSkipPicker(isIntro: false)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    private func showSkipPicker(isIntro: Bool) {
        let settings = PlaybackStateManager.shared
        let options = isIntro ? [0, 5, 10, 15, 30, 60, 90, 120] : [0, 5, 10, 15, 30, 60]
        let currentValue = isIntro
            ? settings.getSkipIntroSeconds(forFolder: folder.name)
            : settings.getSkipOutroSeconds(forFolder: folder.name)
        let apply: (Int) -> Void = { [folderName = folder.name] seconds in
            if isIntro {
                settings.setSkipIntroSeconds(seconds, forFolder: folderName)
            } else {
                settings.setSkipOutroSeconds(seconds, forFolder: folderName)
            }
        }

        let alert = UIAlertController(
            title: isIntro ? "跳过片头" : "跳过片尾",
            message: isIntro ? "每次播放新章节时自动跳过开头" : "章节结束前自动跳到下一章",
            preferredStyle: .actionSheet
        )
        // 用标题前缀 ✓ 标记当前选中项（UIAlertAction 的 "checked" 是私有 KVC，有审核风险）
        for seconds in options {
            let isSelected = seconds == currentValue
            alert.addAction(UIAlertAction(title: (isSelected ? "✓ " : "") + seconds.skipDurationText, style: .default) { _ in
                apply(seconds)
            })
        }
        let isCustomSelected = !options.contains(currentValue) && currentValue > 0
        let customTitle = isCustomSelected ? "✓ 自定义（\(currentValue.skipDurationText)）" : "自定义…"
        alert.addAction(UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            self?.showCustomSkipInput(
                title: isIntro ? "自定义跳过片头" : "自定义跳过片尾",
                message: isIntro ? "请输入要跳过的秒数" : "请输入章节结束前要跳过的秒数",
                current: currentValue,
                setter: apply
            )
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    private func showCustomSkipInput(title: String, message: String, current: Int, setter: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "秒数"
            textField.keyboardType = .numberPad
            if current > 0 { textField.text = "\(current)" }
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            if let text = alert.textFields?.first?.text, let seconds = Int(text), seconds >= 0 {
                setter(seconds)
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension TrackListViewController {
    /// 第 0 节是书籍信息与主动作，第 1 节是章节
    fileprivate enum SectionIndex {
        static let header = 0
        static let chapters = 1
    }
}

extension TrackListViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == SectionIndex.header ? 1 : tracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section == SectionIndex.chapters else { return headerCell }
        let cell = tableView.dequeueReusableCell(withIdentifier: TrackChapterCell.identifier, for: indexPath)
        if let chapterCell = cell as? TrackChapterCell {
            configure(chapterCell, at: indexPath.row)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension TrackListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == SectionIndex.chapters else { return }
        AudioPlayerManager.shared.play(track: tracks[indexPath.row], in: tracks)
        updateMiniPlayerVisibility()
        updateHeader()
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == SectionIndex.chapters else { return nil }
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.confirmDeleteTrack(at: indexPath)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func confirmDeleteTrack(at indexPath: IndexPath) {
        guard indexPath.row < tracks.count else { return }
        let track = tracks[indexPath.row]

        let alert = UIAlertController(
            title: "删除这一章？",
            message: "音频文件「\(track.displayName)」和它的收听位置都会被删除。此操作无法撤销。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteTrack(at: indexPath)
        })
        present(alert, animated: true)
    }

    private func deleteTrack(at indexPath: IndexPath) {
        guard indexPath.row < tracks.count else { return }
        let track = tracks[indexPath.row]
        let isCurrentTrack = AudioPlayerManager.shared.currentTrack == track

        guard FileService.shared.deleteTrack(track) else { return }

        // 清理该曲目的进度记录，避免 UserDefaults 残留孤儿 key
        PlaybackStateManager.shared.clearTrackPosition(url: track.url)
        PlaybackStateManager.shared.clearLastPlayedTrack(
            ifMatching: track.url,
            forFolder: track.folderName
        )
        tracks.remove(at: indexPath.row)

        if isCurrentTrack {
            // 正在播放的章节被删除：完全停止并卸载，避免迷你播放器残留已删内容
            AudioPlayerManager.shared.stop()
        } else {
            // 同步播放列表并修正 currentIndex，防止上一/下一章错位
            AudioPlayerManager.shared.updatePlaylist(afterDeletion: tracks)
        }

        totalDuration = resolvedTotalDuration(for: tracks)
        updateHeader()
        tableView.reloadData()
        updateMiniPlayerVisibility()

        if tracks.isEmpty {
            navigationController?.popViewController(animated: true)
        }
    }
}

// MARK: - AudioPlayerDelegate

extension TrackListViewController: AudioPlayerDelegate {

    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        // 只就地更新当前章节行的时间，不整表刷新
        guard let index = currentChapterIndex else { return }
        let indexPath = IndexPath(row: index, section: SectionIndex.chapters)
        guard let cell = tableView.cellForRow(at: indexPath) as? TrackChapterCell else { return }
        configure(cell, at: index)
    }

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        tableView.reloadData()
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateMiniPlayerVisibility()
        updateHeader()
        tableView.reloadData()
        scrollToCurrentChapterIfNeeded()
    }

    func playerDidFinishTrack() {}

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
