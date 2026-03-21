import UIKit

final class DashboardViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let dateLabel = UILabel()
    private var selectedDate = Calendar.current.startOfDay(for: Date())
    private var observer: NSObjectProtocol?

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Resumo"
        navigationItem.largeTitleDisplayMode = .always
        setupViews()
        bindStore()
        rebuildContent()
    }

    private func bindStore() {
        observer = NotificationCenter.default.addObserver(forName: .appStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.rebuildContent()
        }
    }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16

        dateLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        dateLabel.textAlignment = .center

        let prevButton = UIButton(type: .system)
        prevButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        prevButton.addTarget(self, action: #selector(previousDay), for: .touchUpInside)

        let nextButton = UIButton(type: .system)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextDay), for: .touchUpInside)

        let dateHeader = UIStackView(arrangedSubviews: [prevButton, dateLabel, nextButton])
        dateHeader.axis = .horizontal
        dateHeader.alignment = .center
        dateHeader.distribution = .fill

        prevButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        nextButton.widthAnchor.constraint(equalToConstant: 44).isActive = true

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        stackView.addArrangedSubview(dateHeader)
    }

    private func updateDateLabel() {
        dateLabel.text = selectedDate.shortBrazilianDate
    }

    @objc private func previousDay() {
        selectedDate = Calendar.current.startOfDay(for: selectedDate.addingDays(-1))
        rebuildContent()
    }

    @objc private func nextDay() {
        selectedDate = Calendar.current.startOfDay(for: selectedDate.addingDays(1))
        rebuildContent()
    }

    private func rebuildContent() {
        selectedDate = Calendar.current.startOfDay(for: selectedDate)
        updateDateLabel()

        while stackView.arrangedSubviews.count > 1 {
            let view = stackView.arrangedSubviews.last!
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let goals = AppStore.shared.goals
        let totals = AppStore.shared.totals(for: selectedDate)
        let dayLaunches = AppStore.shared.launches(for: selectedDate)

        if dayLaunches.isEmpty {
            stackView.addArrangedSubview(makeCard(title: "Sem lançamentos", value: "Não há lançamentos para esta data."))
        }

        stackView.addArrangedSubview(makeMacroBarsCard(goals: goals, totals: totals))
    }

    private func makeMacroBarsCard(goals: DailyGoals, totals: (calories: Int, proteins: Int, fats: Int, carbs: Int)) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16

        let titleLabel = UILabel()
        titleLabel.text = "Barras de progresso"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)

        let rows = UIStackView(arrangedSubviews: [
            makeBarRow(title: "Calorias", value: totals.calories, goal: goals.calories, unit: "kcal"),
            makeBarRow(title: "Proteínas", value: totals.proteins, goal: goals.proteins, unit: "g"),
            makeBarRow(title: "Gorduras", value: totals.fats, goal: goals.fats, unit: "g"),
            makeBarRow(title: "Carboidratos", value: totals.carbs, goal: goals.carbs, unit: "g")
        ])
        rows.axis = .vertical
        rows.spacing = 14

        let content = UIStackView(arrangedSubviews: [titleLabel, rows])
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func makeBarRow(title: String, value: Int, goal: Int, unit: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)

        let balance = goal - value
        let detailText: String
        if balance >= 0 {
            detailText = "\(value) / \(goal) \(unit) • faltam \(balance) \(unit)"
        } else {
            detailText = "\(value) / \(goal) \(unit) • excedido \(abs(balance)) \(unit)"
        }

        let valueLabel = UILabel()
        valueLabel.text = detailText
        valueLabel.font = .systemFont(ofSize: 15, weight: .regular)
        valueLabel.textColor = balance >= 0 ? .secondaryLabel : .systemRed
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 0

        let labels = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labels.axis = .horizontal
        labels.alignment = .top
        labels.distribution = .fillEqually
        labels.spacing = 8

        let progress = UIProgressView(progressViewStyle: .default)
        let progressValue: Float = goal > 0 ? min(Float(value) / Float(goal), 1.0) : 0
        progress.progress = progressValue
        progress.trackTintColor = .systemGray5
        progress.progressTintColor = balance < 0 ? .systemRed : .systemBlue
        progress.transform = CGAffineTransform(scaleX: 1, y: 2.2)

        let stack = UIStackView(arrangedSubviews: [labels, progress])
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }

    private func makeCard(title: String, value: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.text = title

        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: 18, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        valueLabel.text = value
        valueLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }
}
