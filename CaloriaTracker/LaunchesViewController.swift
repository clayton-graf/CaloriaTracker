import UIKit

final class LaunchesViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let selectedDate = Calendar.current.startOfDay(for: Date())
    private var observer: NSObjectProtocol?

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addLaunch))
        setupTable()
        bindStore()
        updateTitle()
    }

    private func bindStore() {
        observer = NotificationCenter.default.addObserver(forName: .appStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    private func updateTitle() {
        title = "Lançamentos de hoje"
    }

    private var dayLaunches: [LaunchEntry] {
        AppStore.shared.launches(for: selectedDate)
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 88
        tableView.tableFooterView = UIView()

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func addLaunch() {
        guard !AppStore.shared.foods.isEmpty else {
            let alert = UIAlertController(
                title: "Cadastre um alimento primeiro",
                message: "Você precisa ter ao menos um alimento cadastrado para lançar consumo.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let picker = FoodPickerViewController()
        picker.onSelectFood = { [weak self] food in
            self?.showQuantityEditor(food: food, existing: nil)
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    private func showQuantityEditor(food: FoodItem, existing: LaunchEntry?) {
        let alert = UIAlertController(
            title: food.name,
            message: food.measure == .weight100g ? "Quantidade em gramas" : "Quantidade em unidades",
            preferredStyle: .alert
        )

        alert.addTextField { tf in
            tf.placeholder = food.measure == .weight100g ? "gramas" : "unidades"
            tf.keyboardType = .numberPad
            if let existing {
                tf.text = "\(existing.quantity)"
            }
        }

        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Salvar", style: .default) { [weak self] _ in
            guard let self else { return }

            let raw = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty, raw.allSatisfy({ $0.isNumber }), let quantity = Int(raw), quantity > 0 else {
                self.showMessage(title: "Quantidade inválida", message: "Informe um número inteiro maior que zero.")
                return
            }

            if let existing {
                AppStore.shared.updateLaunch(existing, food: food, quantity: quantity, date: self.selectedDate)
                self.showToast(message: "Lançamento atualizado")
            } else {
                AppStore.shared.addLaunch(food: food, quantity: quantity, date: self.selectedDate)
                self.showToast(message: "Lançamento salvo")
            }
        })

        present(alert, animated: true)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func confirmDelete(_ entry: LaunchEntry) {
        let alert = UIAlertController(
            title: "Excluir lançamento",
            message: "Deseja remover esse lançamento de hoje?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Excluir", style: .destructive) { [weak self] _ in
            AppStore.shared.deleteLaunch(entry)
            self?.showToast(message: "Lançamento excluído")
        })
        present(alert, animated: true)
    }
}

extension LaunchesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = dayLaunches.count
        tableView.backgroundView = count == 0 ? emptyView() : nil
        return count
    }

    private func emptyView() -> UIView {
        let label = UILabel()
        label.text = "Sem lançamentos hoje."
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "launch") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "launch")
        let item = dayLaunches[indexPath.row]
        let factor = item.food.measure == .weight100g ? Double(item.quantity) / 100.0 : Double(item.quantity)
        let kcal = item.food.calories * factor
        let quantityText = "\(item.quantity)"

        cell.textLabel?.text = item.food.name
        cell.detailTextLabel?.text = "\(quantityText) \(item.food.measure == .weight100g ? "g" : "un") • \(kcal.formattedOneDecimalPTBR) kcal"
        cell.accessoryType = .none
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let entry = dayLaunches[indexPath.row]

        let edit = UIContextualAction(style: .normal, title: "Editar") { [weak self] _, _, completion in
            self?.showQuantityEditor(food: entry.food, existing: entry)
            completion(true)
        }
        edit.backgroundColor = .systemBlue

        let delete = UIContextualAction(style: .destructive, title: "Excluir") { [weak self] _, _, completion in
            self?.confirmDelete(entry)
            completion(true)
        }

        let config = UISwipeActionsConfiguration(actions: [delete, edit])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}

