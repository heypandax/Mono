//
//  SearchResultsViewController.swift
//  Mono
//

import UIKit

final class SearchResultsViewController: UIViewController {

    // MARK: - Callback

    /// 选中某本有声书时回调（由宿主负责收起搜索并跳转）
    var onSelectFolder: ((AudioFolder) -> Void)?

    // MARK: - UI

    private let resultCountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.labelMedium
        label.textColor = DesignTokens.secondary
        label.isHidden = true
        return label
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(AudiobookCardCell.self, forCellReuseIdentifier: AudiobookCardCell.identifier)
        table.delegate = self
        table.dataSource = self
        table.rowHeight = 110
        table.separatorStyle = .none
        table.backgroundColor = DesignTokens.background
        table.keyboardDismissMode = .onDrag
        return table
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "未找到相关有声书"
        label.font = DesignTokens.bodyMedium
        label.textColor = DesignTokens.secondary
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // MARK: - Data

    private var allFolders: [AudioFolder] = []
    private var filteredFolders: [AudioFolder] = []
    private var isSearching = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.background
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(resultCountLabel)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            resultCountLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.lg),
            resultCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            resultCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),

            tableView.topAnchor.constraint(equalTo: resultCountLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func updateUI() {
        let hasResults = !filteredFolders.isEmpty
        tableView.isHidden = !hasResults
        emptyLabel.isHidden = hasResults || !isSearching

        if isSearching {
            resultCountLabel.isHidden = false
            resultCountLabel.text = "找到 \(filteredFolders.count) 本有声书"
        } else {
            resultCountLabel.isHidden = true
        }

        tableView.reloadData()
    }

    private func statusForFolder(_ folder: AudioFolder) -> AudiobookStatus {
        if let currentTrack = AudioPlayerManager.shared.currentTrack,
           currentTrack.folderName == folder.name {
            return .listening
        }
        if PlaybackStateManager.shared.getLastPlayedTrack(forFolder: folder.name) != nil {
            return .listening
        }
        return .notStarted
    }
}

// MARK: - UISearchResultsUpdating
extension SearchResultsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if searchText.isEmpty {
            isSearching = false
            filteredFolders = []
        } else {
            isSearching = true
            allFolders = FileService.shared.getFolders()
            filteredFolders = allFolders.filter { folder in
                folder.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        updateUI()
    }
}

// MARK: - UITableViewDataSource
extension SearchResultsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredFolders.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AudiobookCardCell.identifier, for: indexPath) as! AudiobookCardCell
        let folder = filteredFolders[indexPath.row]
        let status = statusForFolder(folder)
        cell.configure(
            folder: folder,
            trackCount: folder.trackCount,
            totalDurationFormatted: "—",
            progress: 0,
            status: status,
            lastActivity: nil
        )
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SearchResultsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectFolder?(filteredFolders[indexPath.row])
    }
}
