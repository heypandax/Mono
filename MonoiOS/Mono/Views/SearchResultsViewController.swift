//
//  SearchResultsViewController.swift
//  Mono
//
//  搜索结果（Master 的 MSearchScreen）。搜索只匹配书名；
//  「没有结果」与「书库为空」是两种状态，恢复动作不同。
//

import UIKit

final class SearchResultsViewController: UIViewController {

    // MARK: - Callbacks

    /// 选中某本书（由宿主负责收起搜索并跳转）
    var onSelectFolder: ((AudioFolder) -> Void)?
    /// 无结果时的恢复动作：清空搜索词
    var onClearSearch: (() -> Void)?

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
        table.keyboardDismissMode = .interactive
        table.accessibilityIdentifier = "search.results"
        return table
    }()

    private let noResultContainer: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        scroll.keyboardDismissMode = .interactive
        scroll.isHidden = true
        scroll.accessibilityIdentifier = "search.noResult"
        return scroll
    }()

    private let noResultTitle = MonoUI.label(.headline, color: DesignTokens.onSurface)
    private let noResultBody = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant)
    private let clearSearchButton = MonoPrimaryButton(kind: .outline)

    private lazy var miniPlayerView: MiniPlayerView = {
        let view = MiniPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.onTap = { [weak self] in
            guard let self else { return }
            PlayerViewController.present(from: self)
        }
        return view
    }()

    // MARK: - Data

    private let store = BookPresentationStore()
    private var allFolders: [AudioFolder] = []
    private var filteredFolders: [AudioFolder] = []
    private var query: String = ""
    /// 键盘遮住本页底部的高度（含底部安全区）
    private var keyboardOverlap: CGFloat = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.background
        setupUI()
        allFolders = FileService.shared.getFolders()
        AudioPlayerManager.shared.addDelegate(self)
        observeKeyboard()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        allFolders = FileService.shared.getFolders()
        applyFilter()
        updateMiniPlayerVisibility()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = bottomObstructionHeight
        if abs(tableView.contentInset.bottom - inset) > 0.5 {
            tableView.contentInset.bottom = inset
            tableView.verticalScrollIndicatorInsets.bottom = inset
        }
        if abs(noResultContainer.contentInset.bottom - inset) > 0.5 {
            noResultContainer.contentInset.bottom = inset
            noResultContainer.verticalScrollIndicatorInsets.bottom = inset
        }
    }

    /// 底部被遮挡的高度。迷你播放器与键盘不会同时出现，取较大者即可。
    /// 两者都包含底部安全区，而 scroll view 的 adjustedContentInset 已经计入过一次，要先扣掉。
    private var bottomObstructionHeight: CGFloat {
        max(miniPlayerView.contentOverlapHeight, max(0, keyboardOverlap - view.safeAreaInsets.bottom))
    }

    // MARK: - Setup

    private func setupUI() {
        noResultBody.text = "搜索只匹配书名。确认这本书的文件夹已经导入书库。"
        clearSearchButton.apply(title: "清除搜索", symbol: nil)
        clearSearchButton.accessibilityIdentifier = "search.clear"
        clearSearchButton.addTarget(self, action: #selector(clearSearchTapped), for: .touchUpInside)

        view.addSubview(tableView)
        view.addSubview(noResultContainer)
        view.addSubview(miniPlayerView)
        [noResultTitle, noResultBody, clearSearchButton].forEach(noResultContainer.addSubview)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            tableView.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth),

            // 搜索激活后导航栏会扩展；空态必须从安全区下方开始，不能藏到搜索栏背后。
            noResultContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            noResultContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            noResultContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noResultContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            noResultContainer.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth),

            noResultTitle.topAnchor.constraint(equalTo: noResultContainer.contentLayoutGuide.topAnchor,
                                               constant: DesignTokens.Spacing.xxl),
            noResultTitle.leadingAnchor.constraint(equalTo: noResultContainer.frameLayoutGuide.leadingAnchor,
                                                   constant: DesignTokens.contentInset),
            noResultTitle.trailingAnchor.constraint(equalTo: noResultContainer.frameLayoutGuide.trailingAnchor,
                                                    constant: -DesignTokens.contentInset),

            noResultBody.topAnchor.constraint(equalTo: noResultTitle.bottomAnchor, constant: DesignTokens.Spacing.sm),
            noResultBody.leadingAnchor.constraint(equalTo: noResultContainer.frameLayoutGuide.leadingAnchor,
                                                  constant: DesignTokens.contentInset),
            noResultBody.trailingAnchor.constraint(equalTo: noResultContainer.frameLayoutGuide.trailingAnchor,
                                                   constant: -DesignTokens.contentInset),

            clearSearchButton.topAnchor.constraint(equalTo: noResultBody.bottomAnchor, constant: DesignTokens.Spacing.lg),
            clearSearchButton.leadingAnchor.constraint(equalTo: noResultContainer.frameLayoutGuide.leadingAnchor,
                                                       constant: DesignTokens.contentInset),
            clearSearchButton.trailingAnchor.constraint(equalTo: noResultContainer.frameLayoutGuide.trailingAnchor,
                                                        constant: -DesignTokens.contentInset),
            clearSearchButton.bottomAnchor.constraint(equalTo: noResultContainer.contentLayoutGuide.bottomAnchor,
                                                      constant: -DesignTokens.Spacing.xxl),

            noResultContainer.contentLayoutGuide.widthAnchor.constraint(
                equalTo: noResultContainer.frameLayoutGuide.widthAnchor
            ),

            miniPlayerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            miniPlayerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            miniPlayerView.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.listMaxWidth),
            // 背景铺到屏幕底部，Home Indicator 区不会透出底层结果行
            miniPlayerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let fullWidth = tableView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fullWidth.priority = .defaultHigh
        fullWidth.isActive = true
        let noResultWidth = noResultContainer.widthAnchor.constraint(equalTo: view.widthAnchor)
        noResultWidth.priority = .defaultHigh
        noResultWidth.isActive = true
        let miniPlayerFullWidth = miniPlayerView.widthAnchor.constraint(equalTo: view.widthAnchor)
        miniPlayerFullWidth.priority = .defaultHigh
        miniPlayerFullWidth.isActive = true
    }

    // MARK: - Update

    private func updateUI() {
        let hasResults = !filteredFolders.isEmpty
        let isSearching = !query.isEmpty

        tableView.isHidden = !hasResults
        noResultContainer.isHidden = hasResults || !isSearching
        noResultTitle.text = "没有找到「\(query)」"

        tableView.reloadData()

        for folder in filteredFolders {
            store.loadDurationIfNeeded(for: folder) { [weak self] name in
                guard let self, let index = self.filteredFolders.firstIndex(where: { $0.name == name }) else { return }
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            }
        }
    }

    private func applyFilter() {
        if query.isEmpty {
            filteredFolders = []
        } else {
            filteredFolders = allFolders.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
        }
        updateUI()
    }

    private func updateMiniPlayerVisibility() {
        let hasTrack = AudioPlayerManager.shared.currentTrack != nil
        // 本页的 safe area 不跟随键盘：输入期间让出底部，键盘收起后按真实播放状态恢复
        let isVisible = hasTrack && keyboardOverlap <= 0
        miniPlayerView.isHidden = !isVisible
        if isVisible { miniPlayerView.refreshUI() }
        view.setNeedsLayout()
    }

    // MARK: - 键盘

    private func observeKeyboard() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(keyboardFrameWillChange),
                           name: UIResponder.keyboardWillChangeFrameNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(keyboardWillHide),
                           name: UIResponder.keyboardWillHideNotification,
                           object: nil)
    }

    @objc private func keyboardFrameWillChange(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = view.convert(frame.cgRectValue, from: nil)
        applyKeyboardOverlap(max(0, view.bounds.maxY - keyboardFrame.minY))
    }

    @objc private func keyboardWillHide() {
        applyKeyboardOverlap(0)
    }

    private func applyKeyboardOverlap(_ overlap: CGFloat) {
        guard abs(keyboardOverlap - overlap) > 0.5 else { return }
        keyboardOverlap = overlap
        updateMiniPlayerVisibility()
    }

    // MARK: - Actions

    @objc private func clearSearchTapped() {
        onClearSearch?()
    }
}

// MARK: - UISearchResultsUpdating

extension SearchResultsViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        query = text

        // 只匹配书名，不匹配章节名；输入过程只做内存过滤。
        applyFilter()
    }
}

// MARK: - UITableViewDataSource

extension SearchResultsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredFolders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BookRowCell.identifier, for: indexPath)
        (cell as? BookRowCell)?.configure(with: store.presentation(for: filteredFolders[indexPath.row]))
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !filteredFolders.isEmpty else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: MonoSectionHeaderView.identifier)
        (header as? MonoSectionHeaderView)?.configure(title: "找到 \(filteredFolders.count) 本", detail: nil)
        return header
    }
}

// MARK: - UITableViewDelegate

extension SearchResultsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectFolder?(filteredFolders[indexPath.row])
    }
}

// MARK: - AudioPlayerDelegate

extension SearchResultsViewController: AudioPlayerDelegate {

    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {}

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        updateMiniPlayerVisibility()
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateMiniPlayerVisibility()
        tableView.reloadData()
    }

    func playerDidFinishTrack() {}
}
