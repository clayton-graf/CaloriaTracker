import UIKit

final class GoalsViewController: UIViewController, UITextFieldDelegate {
    private let stackView = UIStackView()
    private let caloriesField = UITextField()
    private let proteinsField = UITextField()
    private let fatsField = UITextField()
    private let carbsField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Metas"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Salvar", style: .done, target: self, action: #selector(saveGoals))
        setupLayout()
        loadValues()
        installKeyboardDismissTap()
        applyIntegerKeyboardAccessory(to: [caloriesField, proteinsField, fatsField, carbsField])
    }

    private func setupLayout() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        scroll.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20)
        ])

        [caloriesField, proteinsField, fatsField, carbsField].forEach { field in
            field.borderStyle = .roundedRect
            field.keyboardType = .numberPad
            field.delegate = self
            field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }

        stackView.addArrangedSubview(makeField(title: "Calorias", placeholder: "Ex: 2000", field: caloriesField))
        stackView.addArrangedSubview(makeField(title: "Proteínas", placeholder: "Ex: 150", field: proteinsField))
        stackView.addArrangedSubview(makeField(title: "Gorduras", placeholder: "Ex: 70", field: fatsField))
        stackView.addArrangedSubview(makeField(title: "Carboidratos", placeholder: "Ex: 250", field: carbsField))
    }

    private func makeField(title: String, placeholder: String, field: UITextField) -> UIView {
        field.placeholder = placeholder

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 18, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [label, field])
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func loadValues() {
        let goals = AppStore.shared.goals
        caloriesField.text = "\(goals.calories)"
        proteinsField.text = "\(goals.proteins)"
        fatsField.text = "\(goals.fats)"
        carbsField.text = "\(goals.carbs)"
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowed = CharacterSet.decimalDigits
        return string.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func strictInt(_ text: String?) -> Int? {
        let value = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.allSatisfy({ $0.isNumber }) else { return nil }
        return Int(value)
    }

    @objc private func saveGoals() {
        guard
            let calories = strictInt(caloriesField.text),
            let proteins = strictInt(proteinsField.text),
            let fats = strictInt(fatsField.text),
            let carbs = strictInt(carbsField.text)
        else {
            let invalid = UIAlertController(title: "Valores inválidos", message: "Todos os campos devem conter números inteiros.", preferredStyle: .alert)
            invalid.addAction(UIAlertAction(title: "OK", style: .default))
            present(invalid, animated: true)
            return
        }

        AppStore.shared.replaceGoals(DailyGoals(calories: calories, proteins: proteins, fats: fats, carbs: carbs))
        showToast(message: "Metas atualizadas")
    }
}
