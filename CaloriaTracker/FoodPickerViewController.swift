import UIKit

final class FoodPickerViewController: UIViewController {
    var onSelectFood: ((FoodItem) -> Void)?

    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var filteredFoods: [FoodItem] = []
    private var observer: NSObjectProtocol?

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Escolher alimento"
        navigationItem.largeTitleDisplayMode = .never
        setupViews()
        bindStore()
        applyFilter()
    }

    private func bindStore() {
        observer = NotificationCenter.default.addObserver(forName: .appStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyFilter()
        }
    }

    private func setupViews() {
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Pesquise um alimento"
        searchBar.delegate = self

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()

        view.addSubview(searchBar)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyFilter() {
        filteredFoods = AppStore.shared.sortedFoods(matching: searchBar.text)
        tableView.backgroundView = filteredFoods.isEmpty ? emptyView() : nil
        tableView.reloadData()
    }

    private func emptyView() -> UIView {
        let label = UILabel()
        label.text = "Nenhum alimento encontrado."
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }
}

extension FoodPickerViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter()
    }
}

extension FoodPickerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredFoods.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "picker") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "picker")
        let food = filteredFoods[indexPath.row]
        cell.textLabel?.text = food.name
        cell.detailTextLabel?.text = "\(food.measure.rawValue) • \(food.calories.formattedOneDecimalPTBR) kcal"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let food = filteredFoods[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        onSelectFood?(food)
        navigationController?.popViewController(animated: true)
    }
}

