//
//  SettingsViewController.swift
//  Mono
//

import UIKit

final class SettingsViewController: UIViewController {

    // MARK: - UI
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.register(SettingSwitchCell.self, forCellReuseIdentifier: SettingSwitchCell.identifier)
        table.register(SettingValueCell.self, forCellReuseIdentifier: SettingValueCell.identifier)
        table.register(SettingActionCell.self, forCellReuseIdentifier: SettingActionCell.identifier)
        table.backgroundColor = DesignTokens.background
        table.separatorColor = DesignTokens.surfaceVariant
        return table
    }()

    // MARK: - Data
    private enum Section: Int, CaseIterable {
        case playback
        case skipSettings
        case dataManagement
        case about
        case support

        var title: String? {
            switch self {
            case .playback: return "播放设置"
            case .skipSettings: return "跳过设置"
            case .dataManagement: return "数据管理"
            case .about: return "关于"
            case .support: return "支持"
            }
        }
    }

    private let skipIntroOptions = [0, 5, 10, 15, 30, 60, 90, 120]
    private let skipOutroOptions = [0, 5, 10, 15, 30, 60]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup
    private func setupUI() {
        title = "设置"
        view.backgroundColor = DesignTokens.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = DesignTokens.primary

        // 导航栏样式
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = DesignTokens.background
        appearance.titleTextAttributes = [
            .foregroundColor: DesignTokens.onSurface,
            .font: DesignTokens.headlineSmall
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 底部 Logo
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 100))
        let logoLabel = UILabel()
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        logoLabel.text = "Mono"
        logoLabel.font = DesignTokens.serif(size: 20, weight: .semibold)
        logoLabel.textColor = DesignTokens.outlineVariant
        logoLabel.textAlignment = .center
        footerView.addSubview(logoLabel)
        NSLayoutConstraint.activate([
            logoLabel.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
        tableView.tableFooterView = footerView
    }

    // MARK: - Actions
    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    // MARK: - Skip Pickers

    private func showSkipIntroPicker() {
        let alert = UIAlertController(title: "默认跳过开头", message: "新文件夹的默认跳过开头秒数", preferredStyle: .actionSheet)
        let currentValue = PlaybackStateManager.shared.defaultSkipIntroSeconds

        // 用标题前缀 ✓ 标记当前选中项（UIAlertAction 的 "checked" 是私有 KVC，有审核风险）
        for seconds in skipIntroOptions {
            let isSelected = seconds == currentValue
            let action = UIAlertAction(title: (isSelected ? "✓ " : "") + seconds.skipDurationText, style: .default) { [weak self] _ in
                PlaybackStateManager.shared.defaultSkipIntroSeconds = seconds
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }

        let isCustomSelected = !skipIntroOptions.contains(currentValue) && currentValue > 0
        let customTitle = isCustomSelected ? "✓ 自定义 (\(currentValue.skipDurationText))" : "自定义..."
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            self?.showCustomInput(title: "自定义跳过开头", message: "请输入要跳过的秒数", currentValue: currentValue) { seconds in
                PlaybackStateManager.shared.defaultSkipIntroSeconds = seconds
                self?.tableView.reloadData()
            }
        }
        alert.addAction(customAction)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 0, section: Section.skipSettings.rawValue))
        }
        present(alert, animated: true)
    }

    private func showSkipOutroPicker() {
        let alert = UIAlertController(title: "默认跳过结尾", message: "新文件夹的默认跳过结尾秒数", preferredStyle: .actionSheet)
        let currentValue = PlaybackStateManager.shared.defaultSkipOutroSeconds

        for seconds in skipOutroOptions {
            let isSelected = seconds == currentValue
            let action = UIAlertAction(title: (isSelected ? "✓ " : "") + seconds.skipDurationText, style: .default) { [weak self] _ in
                PlaybackStateManager.shared.defaultSkipOutroSeconds = seconds
                self?.tableView.reloadData()
            }
            alert.addAction(action)
        }

        let isCustomSelected = !skipOutroOptions.contains(currentValue) && currentValue > 0
        let customTitle = isCustomSelected ? "✓ 自定义 (\(currentValue.skipDurationText))" : "自定义..."
        let customAction = UIAlertAction(title: customTitle, style: .default) { [weak self] _ in
            self?.showCustomInput(title: "自定义跳过结尾", message: "请输入曲目结束前要跳过的秒数", currentValue: currentValue) { seconds in
                PlaybackStateManager.shared.defaultSkipOutroSeconds = seconds
                self?.tableView.reloadData()
            }
        }
        alert.addAction(customAction)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: IndexPath(row: 1, section: Section.skipSettings.rawValue))
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
            if let text = alert.textFields?.first?.text,
               let seconds = Int(text), seconds >= 0 {
                completion(seconds)
            }
        })
        present(alert, animated: true)
    }

    private func confirmClearProgress() {
        let alert = UIAlertController(
            title: "清除播放进度",
            message: "将清除所有有声书的播放进度记录，包括每本书的上次播放位置。此操作不可恢复。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in
            PlaybackStateManager.shared.clearAllProgress()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .playback: return 2
        case .skipSettings: return 2
        case .dataManagement: return 1
        case .about: return 1
        case .support: return 1
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .skipSettings:
            return "这里设置的是新文件夹的默认值。每个文件夹可以在其曲目列表页面单独设置"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let settings = PlaybackStateManager.shared

        switch Section(rawValue: indexPath.section) {
        case .playback:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingSwitchCell.identifier, for: indexPath) as! SettingSwitchCell
            switch indexPath.row {
            case 0:
                cell.configure(title: "启动时自动播放", isOn: settings.autoPlayOnLaunch) { isOn in
                    settings.autoPlayOnLaunch = isOn
                }
            case 1:
                cell.configure(title: "记住每曲播放位置", isOn: settings.rememberPositionPerTrack) { isOn in
                    settings.rememberPositionPerTrack = isOn
                }
            default: break
            }
            return cell

        case .skipSettings:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingValueCell.identifier, for: indexPath) as! SettingValueCell
            switch indexPath.row {
            case 0:
                cell.configure(title: "默认跳过开头", value: settings.defaultSkipIntroSeconds.skipDurationText)
            case 1:
                cell.configure(title: "默认跳过结尾", value: settings.defaultSkipOutroSeconds.skipDurationText)
            default: break
            }
            return cell

        case .dataManagement:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingActionCell.identifier, for: indexPath) as! SettingActionCell
            cell.configure(title: "清除所有播放进度", isDestructive: true)
            return cell

        case .about:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingValueCell.identifier, for: indexPath) as! SettingValueCell
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            cell.configure(title: "版本", value: "\(version) (\(build))")
            cell.selectionStyle = .none
            cell.hideDisclosure()
            return cell

        case .support:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingValueCell.identifier, for: indexPath) as! SettingValueCell
            cell.configure(title: "发送反馈", value: "")
            return cell

        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section) {
        case .skipSettings:
            switch indexPath.row {
            case 0: showSkipIntroPicker()
            case 1: showSkipOutroPicker()
            default: break
            }
        case .dataManagement:
            confirmClearProgress()
        case .support:
            // 打开反馈邮件
            if let url = URL(string: "mailto:feedback@mono.app") {
                UIApplication.shared.open(url)
            }
        default: break
        }
    }
}

// MARK: - SettingSwitchCell
final class SettingSwitchCell: UITableViewCell {
    static let identifier = "SettingSwitchCell"

    private var onValueChanged: ((Bool) -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyLarge
        label.textColor = DesignTokens.onSurface
        return label
    }()

    private lazy var switchControl: UISwitch = {
        let s = UISwitch()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.onTintColor = DesignTokens.primaryContainer
        s.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        return s
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = DesignTokens.surfaceContainer
        contentView.addSubview(titleLabel)
        contentView.addSubview(switchControl)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: switchControl.leadingAnchor, constant: -12),
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isOn: Bool, onValueChanged: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        self.onValueChanged = onValueChanged
    }

    @objc private func switchValueChanged() {
        onValueChanged?(switchControl.isOn)
    }
}

// MARK: - SettingValueCell
final class SettingValueCell: UITableViewCell {
    static let identifier = "SettingValueCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyLarge
        label.textColor = DesignTokens.onSurface
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyMedium
        label.textColor = DesignTokens.secondary
        label.textAlignment = .right
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        backgroundColor = DesignTokens.surfaceContainer
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }

    func hideDisclosure() {
        accessoryType = .none
    }
}

// MARK: - SettingActionCell
final class SettingActionCell: UITableViewCell {
    static let identifier = "SettingActionCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyLarge
        label.textAlignment = .center
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = DesignTokens.surfaceContainer
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isDestructive: Bool = false) {
        titleLabel.text = title
        titleLabel.textColor = isDestructive ? DesignTokens.error : DesignTokens.primary
    }
}
