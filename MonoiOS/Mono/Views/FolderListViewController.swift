//
//  FolderListViewController.swift
//  Mono
//
//  书库（Master 的 MLibrary / MEmpty）。首屏回答「上次听到哪」并给出唯一主动作。
//

import UIKit

final class FolderListViewController: UIViewController {

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(BookRowCell.self, forCellReuseIdentifier: BookRowCell.identifier)
        table.register(MonoSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: MonoSectionHeaderView.identifier)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 84
        table.sectionHeaderTopPadding = 0
        table.separatorColor = DesignTokens.outlineVariant
        table.separatorInset = UIEdgeInsets(top: 0, left: BookRowCell.separatorLeftInset, bottom: 0, right: 0)
        table.backgroundColor = DesignTokens.background
        table.accessibilityIdentifier = "library.list"
        return table
    }()

    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.onImportHelpTapped = { [weak self] in self?.showImportHelp() }
        return view
    }()

    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.onTap = { [weak self] in self?.showPlayer() }
        return view
    }()

    private lazy var resumeBlock: ResumeBlockView = {
        let view = ResumeBlockView()
        view.onPrimaryAction = { [weak self] in self?.handleResumeAction() }
        return view
    }()

    /// 续听区所在的固定单行 cell（只有一行，不参与复用）
    private lazy var resumeCell = MonoHostCell(content: resumeBlock)

    private lazy var searchResultsVC: SearchResultsViewController = {
        let vc = SearchResultsViewController()
        vc.onSelectFolder = { [weak self] folder in
            guard let self else { return }
            self.searchController.isActive = false
            self.navigationController?.pushViewController(TrackListViewController(folder: folder), animated: true)
        }
        vc.onClearSearch = { [weak self] in
            self?.searchController.searchBar.text = ""
            self?.searchController.searchBar.becomeFirstResponder()
        }
        return vc
    }()

    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: searchResultsVC)
        sc.searchResultsUpdater = searchResultsVC
        sc.searchBar.placeholder = "搜索书名"
        sc.searchBar.accessibilityIdentifier = "library.search"
        sc.searchBar.delegate = self
        sc.obscuresBackgroundDuringPresentation = false
        return sc
    }()

    // MARK: - Data

    private var folders: [AudioFolder] = []
    /// 书行表达的唯一来源（与搜索结果共用同一套状态口径）
    private let store = BookPresentationStore()
    /// 续听区当前表达，CTA 行为依赖它
    private var currentResume: NowPlayingPresentation?
    /// 待执行一次「把续听 CTA 让到迷你播放器上方」的对齐，见 alignResumeAboveMiniPlayerIfNeeded()
    private var needsResumeAlignment = true

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMiniPlayer()
        AudioPlayerManager.shared.addDelegate(self)

        // 字号切换会同时改变续听区高度和迷你播放器高度，需要重新对齐一次
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: FolderListViewController, _) in
            vc.needsResumeAlignment = true
            vc.view.setNeedsLayout()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFolders()
        refreshResumeArea()
        updateMiniPlayerVisibility()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBottomInsets()
        alignResumeAboveMiniPlayerIfNeeded()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "书库"
        view.backgroundColor = DesignTokens.background

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController = searchController
        navigationItem.preferredSearchBarPlacement = .stacked
        if #available(iOS 26.0, *) {
            navigationItem.searchBarPlacementAllowsToolbarIntegration = false
        }
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        let settingsItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        settingsItem.accessibilityLabel = "设置"
        settingsItem.accessibilityIdentifier = "library.settings"
        navigationItem.rightBarButtonItem = settingsItem

        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            tableView.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth),

            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            emptyStateView.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth)
        ])

        // iPad 上内容列不无限拉伸，但手机上必须铺满
        let fullWidth = tableView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fullWidth.priority = .defaultHigh
        fullWidth.isActive = true
        let emptyFullWidth = emptyStateView.widthAnchor.constraint(equalTo: view.widthAnchor)
        emptyFullWidth.priority = .defaultHigh
        emptyFullWidth.isActive = true

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshFolders), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    private func setupMiniPlayer() {
        view.addSubview(miniPlayerView)
        NSLayoutConstraint.activate([
            miniPlayerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            miniPlayerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            miniPlayerView.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth),
            // 背景铺到屏幕底部，Home Indicator 区不会透出底层的续听 CTA
            miniPlayerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let fullWidth = miniPlayerView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fullWidth.priority = .defaultHigh
        fullWidth.isActive = true
    }

    // MARK: - Data loading

    private func loadFolders() {
        folders = FileService.shared.getFolders()

        let isEmpty = folders.isEmpty
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
        miniPlayerView.isHidden = isEmpty ? true : miniPlayerView.isHidden
        // 空库时不把无效的搜索入口放在最强注意力位置；
        // 重复赋值会重置搜索栏状态，所以只在真的变化时改
        let desiredSearchController = isEmpty ? nil : searchController
        if navigationItem.searchController !== desiredSearchController {
            navigationItem.searchController = desiredSearchController
        }

        tableView.reloadData()

        for folder in folders {
            store.loadDurationIfNeeded(for: folder) { [weak self] name in
                guard let self, let index = self.folders.firstIndex(where: { $0.name == name }) else { return }
                self.tableView.reloadRows(at: [IndexPath(row: index, section: SectionIndex.books)], with: .none)
            }
        }
    }

    @objc private func refreshFolders() {
        store.invalidateAll()
        loadFolders()
        refreshResumeArea()
        tableView.refreshControl?.endRefreshing()
    }

    // MARK: - Resume area

    /// 有收听历史且书库非空时，第一节展示续听区
    private var showsResumeRow: Bool { currentResume != nil && !folders.isEmpty }

    private func refreshResumeArea() {
        let wasVisible = showsResumeRow
        currentResume = folders.isEmpty ? nil : PlaybackPresenter.nowPlaying()
        if let presentation = currentResume {
            resumeBlock.configure(with: presentation)
        }
        if wasVisible != showsResumeRow {
            needsResumeAlignment = showsResumeRow
            tableView.reloadData()
        } else if showsResumeRow {
            // 文案变化可能改变行高，重新测量但不重建内容
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }
        }
    }

    /// 播放中每 0.5 秒只刷新时间与进度，行高不会变，不重新测量
    private func tickResumeArea() {
        guard showsResumeRow,
              AudioPlayerManager.shared.currentTrack != nil,
              let presentation = PlaybackPresenter.nowPlaying() else { return }
        currentResume = presentation
        resumeBlock.configure(with: presentation)
    }

    private func handleResumeAction() {
        guard let resume = currentResume else { return }
        switch resume.mode {
        case .playing:
            showPlayer()
        case .paused:
            AudioPlayerManager.shared.play()
        case .history:
            startPlaybackFromHistory()
        }
    }

    /// 只有保存位置、播放器未加载时：把那本书装进播放器并从保存位置继续
    private func startPlaybackFromHistory() {
        guard let url = PlaybackStateManager.shared.currentTrackURL,
              let folder = FileService.shared.findFolder(for: url) else { return }
        let tracks = FileService.shared.getTracks(in: folder)
        guard let index = PlaybackPresenter.index(of: url, in: tracks) else { return }
        AudioPlayerManager.shared.play(track: tracks[index], in: tracks)
    }

    // MARK: - Mini player

    private func updateMiniPlayerVisibility() {
        let hasTrack = AudioPlayerManager.shared.currentTrack != nil && !folders.isEmpty
        let wasHidden = miniPlayerView.isHidden
        miniPlayerView.isHidden = !hasTrack
        if hasTrack { miniPlayerView.refreshUI() }
        // 迷你播放器刚出现时才有可能盖住续听 CTA，这时重新对齐一次
        if wasHidden, !miniPlayerView.isHidden { needsResumeAlignment = true }
        view.setNeedsLayout()
    }

    /// 迷你播放器高度随 Dynamic Type 变化，插入量必须按真实高度算，否则会压住最后一行
    private func updateBottomInsets() {
        let inset = miniPlayerView.contentOverlapHeight
        guard abs(tableView.contentInset.bottom - inset) > 0.5 else { return }
        tableView.contentInset.bottom = inset
        tableView.verticalScrollIndicatorInsets.bottom = inset
    }

    /// 辅助字号下续听区很高，首屏 CTA 会正好落在迷你播放器后面。
    /// contentInset 只保证「能滚到」，所以在布局条件变化后主动对齐一次；
    /// 只做一次，之后不再抢用户的滚动位置。
    private func alignResumeAboveMiniPlayerIfNeeded() {
        guard needsResumeAlignment else { return }
        guard showsResumeRow,
              !miniPlayerView.isHidden,
              traitCollection.preferredContentSizeCategory.isAccessibilityCategory else {
            needsResumeAlignment = false
            return
        }
        let indexPath = IndexPath(row: 0, section: SectionIndex.resume)
        let rowFrame = tableView.rectForRow(at: indexPath)
        guard rowFrame.height > 0 else { return }

        needsResumeAlignment = false
        // 可见区下沿已扣掉迷你播放器占用的插入量
        let visibleBottom = tableView.contentOffset.y + tableView.bounds.height - tableView.adjustedContentInset.bottom
        guard rowFrame.maxY > visibleBottom else { return }
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
    }

    // MARK: - Navigation

    private func showPlayer() {
        PlayerViewController.present(from: self)
    }

    @objc private func showSettings() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        MonoUI.configure(navigationBar: navController.navigationBar)
        present(navController, animated: true)
    }

    private func showImportHelp() {
        let alert = UIAlertController(
            title: "如何导入有声书",
            message: """

            1. 用数据线把 iPhone 连接到电脑
            2. Mac：打开「访达」，在侧栏选中 iPhone，切换到「文件」标签
               Windows：打开 iTunes，进入设备 →「文件共享」
            3. 找到 Mono，把整理好的有声书文件夹拖进去
            4. 回到书库下拉刷新即可看到
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension FolderListViewController: UISearchBarDelegate {

    /// 键盘上的「搜索」键只收起键盘：查询词、结果列表和搜索态都保留
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource

extension FolderListViewController {
    /// 第 0 节是续听区，第 1 节是全部书籍
    fileprivate enum SectionIndex {
        static let resume = 0
        static let books = 1
    }
}

extension FolderListViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == SectionIndex.resume ? (showsResumeRow ? 1 : 0) : folders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section == SectionIndex.books else { return resumeCell }
        let cell = tableView.dequeueReusableCell(withIdentifier: BookRowCell.identifier, for: indexPath)
        (cell as? BookRowCell)?.configure(with: store.presentation(for: folders[indexPath.row]))
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == SectionIndex.books, !folders.isEmpty else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: MonoSectionHeaderView.identifier)
        let chapters = folders.reduce(0) { $0 + $1.trackCount }
        (header as? MonoSectionHeaderView)?.configure(
            title: "全部书籍",
            detail: "\(folders.count) 本 · \(chapters) 章"
        )
        return header
    }
}

// MARK: - UITableViewDelegate

extension FolderListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == SectionIndex.books ? UITableView.automaticDimension : .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        section == SectionIndex.books ? 34 : .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == SectionIndex.books else { return }
        navigationController?.pushViewController(TrackListViewController(folder: folders[indexPath.row]), animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == SectionIndex.books else { return nil }
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            self?.confirmDeleteFolder(at: indexPath)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func confirmDeleteFolder(at indexPath: IndexPath) {
        guard indexPath.row < folders.count else { return }
        let folder = folders[indexPath.row]

        let alert = UIAlertController(
            title: "删除《\(folder.name)》？",
            message: "这本书的 \(folder.trackCount) 个音频文件和收听进度都会被删除。此操作无法撤销。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteFolder(at: indexPath)
        })
        present(alert, animated: true)
    }

    private func deleteFolder(at indexPath: IndexPath) {
        guard indexPath.row < folders.count else { return }
        let folder = folders[indexPath.row]
        let isCurrentFolder = AudioPlayerManager.shared.currentTrack?.folderName == folder.name

        guard FileService.shared.deleteFolder(folder) else { return }

        // 正在播放该文件夹时完全停止并卸载，避免迷你播放器残留已删内容
        if isCurrentFolder { AudioPlayerManager.shared.stop() }
        // 清理该文件夹的全部持久化数据（跳过设置、上次播放、各曲目进度）
        PlaybackStateManager.shared.clearFolderData(forFolder: folder.name)

        folders.remove(at: indexPath.row)
        store.invalidate(folderName: folder.name)

        if folders.isEmpty {
            loadFolders()
        } else {
            // 分组统计（N 本 · M 章）也要跟着变，整表刷新最省心
            tableView.reloadData()
        }
        refreshResumeArea()
        updateMiniPlayerVisibility()
    }
}

// MARK: - AudioPlayerDelegate

extension FolderListViewController: AudioPlayerDelegate {

    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        tickResumeArea()
    }

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        refreshResumeArea()
        updateMiniPlayerVisibility()
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        refreshResumeArea()
        updateMiniPlayerVisibility()
        tableView.reloadData()
    }

    func playerDidFinishTrack() {
        tableView.reloadData()
    }

    func playerDidFailToLoad(_ track: AudioTrack) {
        refreshResumeArea()
        updateMiniPlayerVisibility()
        guard navigationController?.topViewController === self,
              presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: "无法播放",
            message: "「\(track.displayName)」可能已损坏或格式不受支持。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}
