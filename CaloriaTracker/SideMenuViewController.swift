import UIKit

final class SideMenuViewController: UIViewController {
    var onSelectSection: ((AppSection) -> Void)?
    var onRequestBackup: (() -> Void)?

    private let headerView = UIView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupHeader()
        setupTable()
    }

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .secondarySystemBackground
        headerView.layer.cornerRadius = 20

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Caloria Tracker"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Controle diário de calorias e macros"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        let backupButton = UIButton(type: .system)
        backupButton.translatesAutoresizingMaskIntoConstraints = false
        backupButton.setTitle("Exportar backup", for: .normal)
        backupButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        backupButton.configuration = .tinted()
        backupButton.configuration?.title = "Exportar backup"
        backupButton.configuration?.image = UIImage(systemName: "square.and.arrow.up")
        backupButton.configuration?.imagePadding = 8
        backupButton.configuration?.cornerStyle = .large
        backupButton.addTarget(self, action: #selector(handleBackupTap), for: .touchUpInside)

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(backupButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),

            backupButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            backupButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backupButton.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor, constant: -16),
            backupButton.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
        ])
    }

    @objc private func handleBackupTap() {
        onRequestBackup?()
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 56

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension SideMenuViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AppSection.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "menu") ?? UITableViewCell(style: .default, reuseIdentifier: "menu")
        let item = AppSection.allCases[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.image = UIImage(systemName: item.icon)
        config.imageProperties.tintColor = .label
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectSection?(AppSection.allCases[indexPath.row])
    }
}
