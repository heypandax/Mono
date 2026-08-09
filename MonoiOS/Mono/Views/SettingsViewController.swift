//
//  SettingsViewController.swift
//  Mono
//
//  设置（Master 的 MSettings）。保留全部既有功能分组与取值，
//  只把外观换成语义色 + 真实深色模式。
//

import UIKit

final class SettingsViewController: UIViewController {

    // MARK: - Model

    fileprivate enum Row {
        case toggle(title: String, isOn: Bool, onChange: (Bool) -> Void)
        case value(title: String, value: String?, showsChevron: Bool)
        case destructive(title: String)
    }

    private struct Section {
        let header: String
        let footer: String?
        let rows: [Row]
    }

    private var sections: [Section] = []

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.register(SettingsCell.self, forCellReuseIdentifier: SettingsCell.identifier)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 46
        table.backgroundColor = DesignTokens.groupedBackground
        table.separatorColor = DesignTokens.outlineVariant
        table.accessibilityIdentifier = "settings.list"
        return table
    }()

    private let skipIntroOptions = [0, 5, 10, 15, 30, 60, 90, 120]
    private let skipOutroOptions = [0, 5, 10, 15, 30, 60]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadSections()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "设置"
        view.backgroundColor = DesignTokens.groupedBackground
        view.accessibilityIdentifier = "settings.root"

        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "settings.done"

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

    // MARK: - Data

    private func reloadSections() {
        let settings = PlaybackStateManager.shared
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        sections = [
            Section(header: "播放", footer: nil, rows: [
                .toggle(title: "启动时自动播放", isOn: settings.autoPlayOnLaunch) { settings.autoPlayOnLaunch = $0 },
                .toggle(title: "记住每章播放位置", isOn: settings.rememberPositionPerTrack) { settings.rememberPositionPerTrack = $0 }
            ]),
            Section(header: "跳过设置", footer: "这里是新书的默认值，可在每本书的「文件夹设置」中单独覆盖。", rows: [
                .value(title: "跳过片头", value: settings.defaultSkipIntroSeconds.skipDurationText, showsChevron: true),
                .value(title: "跳过片尾", value: settings.defaultSkipOutroSeconds.skipDurationText, showsChevron: true)
            ]),
            Section(header: "数据管理", footer: "音频文件不会被删除。", rows: [
                .destructive(title: "清除所有收听进度")
            ]),
            Section(header: "关于", footer: nil, rows: [
                .value(title: "版本", value: "\(version) (\(build))", showsChevron: false)
            ]),
            Section(header: "支持", footer: nil, rows: [
                .value(title: "发送反馈", value: nil, showsChevron: true)
            ])
        ]
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    private func showSkipPicker(isIntro: Bool, sourceIndexPath: IndexPath) {
        let settings = PlaybackStateManager.shared
        let options = isIntro ? skipIntroOptions : skipOutroOptions
        let currentValue = isIntro ? settings.defaultSkipIntroSeconds : settings.defaultSkipOutroSeconds
        let apply: (Int) -> Void = { [weak self] seconds in
            if isIntro {
                settings.defaultSkipIntroSeconds = seconds
            } else {
                settings.defaultSkipOutroSeconds = seconds
            }
            self?.reloadSections()
        }

        let alert = UIAlertController(
            title: isIntro ? "默认跳过片头" : "默认跳过片尾",
            message: isIntro ? "新书每章开头自动跳过的秒数" : "新书每章结束前自动跳到下一章的秒数",
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
            self?.showCustomInput(
                title: isIntro ? "自定义跳过片头" : "自定义跳过片尾",
                message: "请输入秒数",
                currentValue: currentValue,
                completion: apply
            )
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: sourceIndexPath)
        }
        present(alert, animated: true)
    }

    private func showCustomInput(title: String, message: String, currentValue: Int, completion: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "秒数"
            textField.keyboardType = .numberPad
            if currentValue > 0 { textField.text = "\(currentValue)" }
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            if let text = alert.textFields?.first?.text, let seconds = Int(text), seconds >= 0 {
                completion(seconds)
            }
        })
        present(alert, animated: true)
    }

    private func confirmClearProgress() {
        let bookCount = FileService.shared.getFolders().count
        let alert = UIAlertController(
            title: "清除所有收听进度？",
            message: "\(bookCount) 本书的收听位置都会被清除。音频文件会保留。此操作无法撤销。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in
            // Stop first so the active player cannot persist its old position again.
            AudioPlayerManager.shared.stop()
            PlaybackStateManager.shared.clearAllProgress()
            UIAccessibility.post(notification: .announcement, argument: "收听进度已清除")
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsCell.identifier, for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        (cell as? SettingsCell)?.configure(with: representation(for: row))
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch (indexPath.section, indexPath.row) {
        case (1, 0):
            showSkipPicker(isIntro: true, sourceIndexPath: indexPath)
        case (1, 1):
            showSkipPicker(isIntro: false, sourceIndexPath: indexPath)
        case (2, 0):
            confirmClearProgress()
        case (4, 0):
            if let url = URL(string: "mailto:feedback@mono.app") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = DesignTokens.onSurfaceVariant
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = DesignTokens.onSurfaceVariant
    }
}

// MARK: - Cell

final class SettingsCell: UITableViewCell {

    static let identifier = "SettingsCell"

    private var onToggle: ((Bool) -> Void)?

    private lazy var toggle: UISwitch = {
        let control = UISwitch()
        control.onTintColor = DesignTokens.primary
        control.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        return control
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        backgroundColor = DesignTokens.groupedCellBackground
        let selected = UIView()
        selected.backgroundColor = DesignTokens.surfaceContainerHigh
        selectedBackgroundView = selected
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    fileprivate func configure(with row: SettingsViewController.SettingsRowRepresentation) {
        var content = defaultContentConfiguration()
        content.text = row.title
        content.textProperties.color = row.isDestructive ? DesignTokens.error : DesignTokens.onSurface
        content.secondaryText = row.value
        content.prefersSideBySideTextAndSecondaryText = true
        content.secondaryTextProperties.color = DesignTokens.onSurfaceVariant
        contentConfiguration = content

        onToggle = row.onChange
        if let isOn = row.isOn {
            toggle.isOn = isOn
            accessoryView = toggle
            accessoryType = .none
            selectionStyle = .none
        } else {
            accessoryView = nil
            accessoryType = row.showsChevron ? .disclosureIndicator : .none
            selectionStyle = row.isSelectable ? .default : .none
        }
    }

    @objc private func toggleChanged() {
        onToggle?(toggle.isOn)
    }
}

// MARK: - Row bridging

extension SettingsViewController {

    /// 把私有 Row 枚举摊平成 cell 需要的字段，避免 cell 依赖 controller 的内部结构
    fileprivate struct SettingsRowRepresentation {
        let title: String
        let value: String?
        let isOn: Bool?
        let showsChevron: Bool
        let isDestructive: Bool
        let isSelectable: Bool
        let onChange: ((Bool) -> Void)?
    }

    fileprivate func representation(for row: Row) -> SettingsRowRepresentation {
        switch row {
        case let .toggle(title, isOn, onChange):
            return SettingsRowRepresentation(title: title, value: nil, isOn: isOn, showsChevron: false,
                                             isDestructive: false, isSelectable: false, onChange: onChange)
        case let .value(title, value, showsChevron):
            return SettingsRowRepresentation(title: title, value: value, isOn: nil, showsChevron: showsChevron,
                                             isDestructive: false, isSelectable: showsChevron, onChange: nil)
        case let .destructive(title):
            return SettingsRowRepresentation(title: title, value: nil, isOn: nil, showsChevron: false,
                                             isDestructive: true, isSelectable: true, onChange: nil)
        }
    }
}
