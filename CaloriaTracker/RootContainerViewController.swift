import UIKit

final class RootContainerViewController: UIViewController {
    private let menuWidth: CGFloat = 280
    private let menuVC = SideMenuViewController()
    private let contentContainer = UIView()
    private let dimView = UIView()
    private var menuLeading: NSLayoutConstraint!
    private var currentNav: UINavigationController?
    private var isMenuOpen = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupContent()
        setupMenu()
        showSection(.dashboard)
    }

    private func setupMenu() {
        addChild(menuVC)
        menuVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuVC.view)
        menuVC.didMove(toParent: self)

        menuLeading = menuVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -menuWidth)

        NSLayoutConstraint.activate([
            menuLeading,
            menuVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            menuVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            menuVC.view.widthAnchor.constraint(equalToConstant: menuWidth)
        ])

        menuVC.onSelectSection = { [weak self] section in
            self?.showSection(section)
            self?.toggleMenu(open: false, animated: true)
        }
        menuVC.onRequestBackup = { [weak self] in
            self?.exportBackup()
        }
    }

    private func setupContent() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        dimView.alpha = 0
        dimView.isHidden = true
        dimView.isUserInteractionEnabled = false

        view.addSubview(contentContainer)
        view.addSubview(dimView)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDimTap))
        dimView.addGestureRecognizer(tap)
    }

    @objc private func handleDimTap() {
        toggleMenu(open: false, animated: true)
    }

    func toggleMenu(open: Bool? = nil, animated: Bool) {
        let targetOpen = open ?? !isMenuOpen
        isMenuOpen = targetOpen
        menuLeading.constant = targetOpen ? 0 : -menuWidth
        dimView.isHidden = false
        dimView.isUserInteractionEnabled = targetOpen

        let animations = {
            self.dimView.alpha = targetOpen ? 1 : 0
            self.view.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            if !targetOpen {
                self.dimView.isHidden = true
            }
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }

    private func showSection(_ section: AppSection) {
        let rootVC: UIViewController

        switch section {
        case .dashboard:
            rootVC = DashboardViewController()
        case .launches:
            rootVC = LaunchesViewController()
        case .foods:
            rootVC = FoodsViewController()
        case .goals:
            rootVC = GoalsViewController()
        }

        rootVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(handleMenuButton)
        )

        let nav = UINavigationController(rootViewController: rootVC)
        swapContent(to: nav)
    }

    @objc private func handleMenuButton() {
        toggleMenu(animated: true)
    }

    private func exportBackup() {
        do {
            let url = try AppStore.shared.backupFileURL()
            let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activity.popoverPresentationController {
                popover.sourceView = menuVC.view
                popover.sourceRect = CGRect(x: 32, y: 140, width: 1, height: 1)
            }
            toggleMenu(open: false, animated: true)
            currentNav?.present(activity, animated: true)
        } catch {
            toggleMenu(open: false, animated: true)
            let alert = UIAlertController(title: "Erro no backup", message: "Não foi possível gerar o arquivo de backup.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            currentNav?.present(alert, animated: true)
        }
    }

    private func swapContent(to nav: UINavigationController) {
        if let currentNav {
            currentNav.willMove(toParent: nil)
            currentNav.view.removeFromSuperview()
            currentNav.removeFromParent()
        }

        addChild(nav)
        nav.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(nav.view)
        NSLayoutConstraint.activate([
            nav.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            nav.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            nav.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            nav.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        nav.didMove(toParent: self)
        currentNav = nav
        view.bringSubviewToFront(dimView)
        view.bringSubviewToFront(menuVC.view)
    }
}
