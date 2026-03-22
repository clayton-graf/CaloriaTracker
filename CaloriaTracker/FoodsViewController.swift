import UIKit

final class FoodsViewController: UIViewController {
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
        title = "Alimentos"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFood))
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
        searchBar.delegate = self
        searchBar.placeholder = "Buscar alimento"
        searchBar.searchBarStyle = .minimal

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 84
        tableView.tableFooterView = UIView()
        tableView.keyboardDismissMode = .onDrag

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

    @objc private func addFood() {
        let editor = FoodEditorViewController(existing: nil)
        editor.onSave = { [weak self] food in
            AppStore.shared.addFood(food)
            self?.showToast(message: "Alimento salvo")
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    private func confirmDelete(_ food: FoodItem) {
        let message = "Ao excluir \"\(food.name)\", os lançamentos relacionados também serão removidos."
        let alert = UIAlertController(title: "Excluir alimento", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        alert.addAction(UIAlertAction(title: "Excluir", style: .destructive) { [weak self] _ in
            AppStore.shared.deleteFood(food)
            self?.showToast(message: "Alimento excluído")
        })
        present(alert, animated: true)
    }
}

extension FoodsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter()
    }
}

extension FoodsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredFoods.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "food") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "food")
        let food = filteredFoods[indexPath.row]
        cell.textLabel?.text = food.name
        cell.detailTextLabel?.text = "\(food.measure.rawValue) • \(food.calories.formattedOneDecimalPTBR) kcal • P \(food.proteins.formattedOneDecimalPTBR) • G \(food.fats.formattedOneDecimalPTBR) • C \(food.carbs.formattedOneDecimalPTBR)"
        cell.accessoryType = .none
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let food = filteredFoods[indexPath.row]

        let edit = UIContextualAction(style: .normal, title: "Editar") { [weak self] _, _, completion in
            let editor = FoodEditorViewController(existing: food)
            editor.onSave = { [weak self] updated in
                AppStore.shared.updateFood(updated)
                self?.showToast(message: "Alimento atualizado")
            }
            self?.navigationController?.pushViewController(editor, animated: true)
            completion(true)
        }
        edit.backgroundColor = .systemBlue

        let delete = UIContextualAction(style: .destructive, title: "Excluir") { [weak self] _, _, completion in
            self?.confirmDelete(food)
            completion(true)
        }

        let config = UISwipeActionsConfiguration(actions: [delete, edit])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}

final class FoodEditorViewController: UIViewController, UITextFieldDelegate {
    var onSave: ((FoodItem) -> Void)?

    private let existing: FoodItem?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    private let nameField = UITextField()
    private let measureButton = UIButton(type: .system)
    private let caloriesField = UITextField()
    private let proteinsField = UITextField()
    private let fatsField = UITextField()
    private let carbsField = UITextField()

    private var selectedMeasure: FoodMeasure

    init(existing: FoodItem?) {
        self.existing = existing
        self.selectedMeasure = existing?.measure ?? .weight100g
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = existing == nil ? "Novo alimento" : "Editar alimento"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Salvar", style: .done, target: self, action: #selector(saveTapped))
        setupViews()
        populateIfNeeded()
        installKeyboardDismissTap()
        applyIntegerKeyboardAccessory(to: [caloriesField, proteinsField, fatsField, carbsField])
    }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])

        configure(field: nameField, placeholder: "Nome do alimento", keyboard: .default)
        configure(field: caloriesField, placeholder: "Ex: 130,0", keyboard: .decimalPad)
        configure(field: proteinsField, placeholder: "Ex: 3,0", keyboard: .decimalPad)
        configure(field: fatsField, placeholder: "Ex: 0,3", keyboard: .decimalPad)
        configure(field: carbsField, placeholder: "Ex: 28,0", keyboard: .decimalPad)

        stackView.addArrangedSubview(makeLabeledField(title: "Nome", field: nameField))
        stackView.addArrangedSubview(makeMeasureField())
        stackView.addArrangedSubview(makeLabeledField(title: "Calorias", field: caloriesField))
        stackView.addArrangedSubview(makeLabeledField(title: "Proteínas", field: proteinsField))
        stackView.addArrangedSubview(makeLabeledField(title: "Gorduras", field: fatsField))
        stackView.addArrangedSubview(makeLabeledField(title: "Carboidratos", field: carbsField))
    }

    private func configure(field: UITextField, placeholder: String, keyboard: UIKeyboardType) {
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.delegate = self
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        if keyboard == .numberPad || keyboard == .decimalPad {
            field.textAlignment = .right
        }
    }

    private func makeLabeledField(title: String, field: UITextField) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func makeMeasureField() -> UIView {
        let label = UILabel()
        label.text = "Medida"
        label.font = .systemFont(ofSize: 17, weight: .semibold)

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.baseBackgroundColor = .secondarySystemBackground
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        measureButton.configuration = config
        measureButton.contentHorizontalAlignment = .leading
        measureButton.showsMenuAsPrimaryAction = true
        refreshMeasureButton()
        rebuildMeasureMenu()

        let stack = UIStackView(arrangedSubviews: [label, measureButton])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func rebuildMeasureMenu() {
        let actions = FoodMeasure.allCases.map { measure in
            UIAction(title: measure.rawValue, state: measure == selectedMeasure ? .on : .off) { [weak self] _ in
                self?.selectedMeasure = measure
                self?.refreshMeasureButton()
                self?.rebuildMeasureMenu()
            }
        }
        measureButton.menu = UIMenu(title: "Tipo de medida", children: actions)
    }

    private func refreshMeasureButton() {
        measureButton.configuration?.title = selectedMeasure.rawValue
        measureButton.configuration?.image = UIImage(systemName: "chevron.down")
        measureButton.configuration?.imagePlacement = .trailing
        measureButton.configuration?.imagePadding = 8
    }

    private func populateIfNeeded() {
        guard let existing else { return }
        nameField.text = existing.name
        caloriesField.text = existing.calories.formattedOneDecimalPTBR
        proteinsField.text = existing.proteins.formattedOneDecimalPTBR
        fatsField.text = existing.fats.formattedOneDecimalPTBR
        carbsField.text = existing.carbs.formattedOneDecimalPTBR
        refreshMeasureButton()
        rebuildMeasureMenu()
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == nameField { return true }
        if string.isEmpty { return true }

        let allowed = CharacterSet(charactersIn: "0123456789,.")
        guard string.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }

        let current = textField.text ?? ""
        guard let textRange = Range(range, in: current) else { return false }

        let updated = current.replacingCharacters(in: textRange, with: string)

        let commaCount = updated.filter { $0 == "," }.count
        let dotCount = updated.filter { $0 == "." }.count
        if commaCount + dotCount > 1 { return false }

        let normalized = updated.replacingOccurrences(of: ",", with: ".")
        if let sepIndex = normalized.firstIndex(of: ".") {
            let decimalPart = normalized[normalized.index(after: sepIndex)...]
            if decimalPart.count > 1 { return false }
        }

        return true
    }

    private func strictOneDecimal(_ text: String?) -> Double? {
        let value = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let normalized = value.replacingOccurrences(of: ",", with: ".")
        guard let number = Double(normalized) else { return nil }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count > 2 { return nil }
        if parts.count == 2 && parts[1].count > 1 { return nil }

        return number
    }

    @objc private func saveTapped() {
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !name.isEmpty else {
            showValidation(title: "Nome obrigatório", message: "Informe o nome do alimento.")
            return
        }

        if AppStore.shared.hasDuplicateFoodName(name, ignoring: existing?.id) {
            showValidation(title: "Alimento duplicado", message: "Já existe um alimento com esse nome.")
            return
        }

        guard
            let calories = strictOneDecimal(caloriesField.text),
            let proteins = strictOneDecimal(proteinsField.text),
            let fats = strictOneDecimal(fatsField.text),
            let carbs = strictOneDecimal(carbsField.text)
        else {
            showValidation(title: "Valores inválidos", message: "Calorias e macros devem ser números com no máximo uma casa decimal.")
            return
        }

        let food = FoodItem(
            id: existing?.id ?? UUID(),
            name: name,
            measure: selectedMeasure,
            calories: calories,
            proteins: proteins,
            fats: fats,
            carbs: carbs
        )

        onSave?(food)
        navigationController?.popViewController(animated: true)
    }

    private func showValidation(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

