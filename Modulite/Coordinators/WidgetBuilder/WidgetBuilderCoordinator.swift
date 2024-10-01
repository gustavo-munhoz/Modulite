//
//  WidgetBuilderCoordinator.swift
//  Modulite
//
//  Created by Gustavo Munhoz Correa on 09/09/24.
//

import UIKit

class WidgetBuilderCoordinator: Coordinator {
    
    // MARK: - Properties

    var children: [Coordinator] = []
    var router: Router
    
    let contentBuilder = WidgetContentBuilder()
    var configurationBuilder: WidgetConfigurationBuilder {
        let content = contentBuilder.build()
        
        if let config = injectedConfiguration {
            return WidgetConfigurationBuilder(
                content: content,
                configuration: config
            )
        }
        
        return WidgetConfigurationBuilder(content: content)
    }
    
    var currentWidgetCount: Int
    
    var onWidgetSave: ((ModuliteWidgetConfiguration) -> Void)?
    var onWidgetDelete: ((UUID) -> Void)?
    
    var injectedConfiguration: ModuliteWidgetConfiguration?
    
    // MARK: - Initializers
    
    init(router: Router) {
        self.currentWidgetCount = 0
        self.router = router
    }
    
    init(router: Router, currentWidgetCount: Int) {
        self.currentWidgetCount = currentWidgetCount
        self.router = router
    }
    
    init(router: Router, configuration: ModuliteWidgetConfiguration) {
        self.currentWidgetCount = 0
        self.router = router
        
        injectedConfiguration = configuration
        injectedConfiguration?.modules.sort(by: { $0.index < $1.index })
        
        contentBuilder.setWidgetName(configuration.name!)
        contentBuilder.setWidgetStyle(configuration.widgetStyle!)
        
        for module in injectedConfiguration!.modules {
            guard let appName = module.appName,
                  let url = module.associatedURLScheme else { continue }
            
            guard let appInfo = CoreDataPersistenceController.shared.fetchAppInfo(
                named: appName,
                urlScheme: url.absoluteString
            ) else { continue }
            
            contentBuilder.appendApp(appInfo)
        }
    }
    
    // MARK: - Presenting
    
    func present(animated: Bool, onDismiss: (() -> Void)?) {
        let viewController = WidgetSetupViewController.instantiate(delegate: self)
        
        if injectedConfiguration != nil {
            viewController.navigationItem.title = .localized(for: .widgetEditingNavigationTitle)
            viewController.loadDataFromContent(contentBuilder.build())
            viewController.setToWidgetEditingMode()
        }
        
        viewController.hidesBottomBarWhenPushed = true
         
        router.present(viewController, animated: animated, onDismiss: onDismiss)
    }
    
    private func presentBackAlertForViewController(
        _ parentViewController: UIViewController,
        message: String,
        discardAction: @escaping (() -> Void)
    ) {
        let alert = UIAlertController(
            title: .localized(for: .widgetEditingUnsavedChangesAlertTitle),
            message: message,
            preferredStyle: .alert
        )
        
        let keepEditingAction = UIAlertAction(
            title: .localized(for: .widgetEditingUnsavedChangesAlertActionKeepEditing),
            style: .cancel
        )
        
        let discardChangesAction = UIAlertAction(
            title: .localized(for: .widgetEditingUnsavedChangesAlertActionDiscard),
            style: .destructive
        ) { _ in
            discardAction()
        }
        
        alert.addAction(keepEditingAction)
        alert.addAction(discardChangesAction)
        
        parentViewController.present(alert, animated: true)
    }
}

// MARK: - WidgetSetupViewControllerDelegate
extension WidgetBuilderCoordinator: WidgetSetupViewControllerDelegate {
    func getPlaceholderName() -> String {
        .localized(
            for: .widgetSetupViewMainWidgetNamePlaceholder(number: currentWidgetCount + 1)
        )
    }
    
    func widgetSetupViewControllerDidPressNext(widgetName: String) {
        contentBuilder.setWidgetName(widgetName)
        
        let viewController = WidgetEditorViewController.instantiate(
            builder: configurationBuilder,
            delegate: self
        )
        
        if injectedConfiguration != nil {
            viewController.loadDataFromBuilder(configurationBuilder)
            viewController.navigationItem.title = .localized(for: .widgetEditingNavigationTitle)
            viewController.setIsEditingViewToTrue()
        }
        
        router.present(viewController, animated: true)
    }
    
    func widgetSetupViewControllerDidSelectWidgetStyle(
        _ controller: WidgetSetupViewController,
        style: WidgetStyle
    ) {
        contentBuilder.setWidgetStyle(style)
    }
    
    func widgetSetupViewControllerDidTapSearchApps(
        _ parentController: WidgetSetupViewController
    ) {
        let router = ModalNavigationRouter(parentViewController: parentController)
        
        let coordinator = SelectAppsCoordinator(
            delegate: self,
            selectedApps: contentBuilder.getCurrentApps(),
            router: router
        )
        
        presentChild(coordinator, animated: true) { [weak self] in
            guard let self = self else { return }
            
            parentController.setSetupViewHasAppsSelected(
                to: !self.contentBuilder.getCurrentApps().isEmpty
            )
            
            parentController.didFinishSelectingApps(
                apps: self.contentBuilder.getCurrentApps()
            )
        }
    }
    
    func widgetSetupViewControllerDidDeselectApp(
        _ controller: WidgetSetupViewController,
        app: AppInfo
    ) {
        contentBuilder.removeApp(app)
        
        if contentBuilder.getCurrentApps().isEmpty {
            controller.setSetupViewHasAppsSelected(to: false)
        }
        
        guard let config = injectedConfiguration else { return }
        guard let idx = config.modules.firstIndex(where: { $0.appName == app.name }) else {
            print("Tried to deselect an app that is not in injected configuration.")
            return
        }
        
        config.modules.replace(
            at: idx,
            with: ModuleConfiguration.empty(
                style: config.widgetStyle!,
                at: idx
            )
        )
    }
    
    func widgetSetupViewControllerDidPressBack(
        _ viewController: WidgetSetupViewController,
        didMakeChanges: Bool
    ) {
        if didMakeChanges {
            presentBackAlertForViewController(
                viewController,
                message: .localized(for: .widgetEditingUnsavedChangesAlertMessage)
            ) { [weak self] in
                self?.dismiss(animated: true)
            }
            
            return
        }
        
        dismiss(animated: true)
    }
}

// MARK: - SelectAppsViewControllerDelegate
extension WidgetBuilderCoordinator: SelectAppsViewControllerDelegate {
    func selectAppsViewControllerDidSelectApp(
        _ controller: SelectAppsViewController,
        didSelect app: AppInfo
    ) {
        contentBuilder.appendApp(app)
        
        guard let config = injectedConfiguration else { return }
        guard let idx = config.modules.firstIndex(where: { $0.appName == nil }) else {
            print("Tried selecting an app with maximum count selected.")
            return
        }
        
        config.modules.replace(
            at: idx,
            with: ModuleConfiguration(
                index: idx,
                appName: app.name,
                associatedURLScheme: app.urlScheme,
                selectedStyle: contentBuilder.getRandomModuleStyle(),
                selectedColor: nil
            )
        )
    }
    
    func selectAppsViewControllerDidDeselectApp(
        _ controller: SelectAppsViewController,
        didDeselect app: AppInfo
    ) {
        contentBuilder.removeApp(app)
        
        guard let config = injectedConfiguration else {return }
        guard let idx = config.modules.firstIndex(where: { $0.appName == app.name }) else {
            print("Tried to deselect an app that is not in injected configuration.")
            return
        }
        
        config.modules.replace(
            at: idx,
            with: ModuleConfiguration.empty(
                style: config.widgetStyle!,
                at: idx
            )
        )
    }
}

// MARK: - WidgetEditorViewControllerDelegate
extension WidgetBuilderCoordinator: WidgetEditorViewControllerDelegate {
    func widgetEditorViewController(
        _ viewController: WidgetEditorViewController,
        didSave widget: ModuliteWidgetConfiguration
    ) {
        onWidgetSave?(widget)
        dismiss(animated: true)
    }
    
    func widgetEditorViewController(
        _ viewController: WidgetEditorViewController,
        didDeleteWithId id: UUID
    ) {
        onWidgetDelete?(id)
        dismiss(animated: true)
    }
    
    func widgetEditorViewControllerDidPressBack(
        _ viewController: WidgetEditorViewController
    ) {
        presentBackAlertForViewController(
            viewController,
            message: .localized(for: .widgetCreatingUnsavedChangesAlertMessage)
        ) { [weak self] in
            self?.router.dismissTopViewController(animated: true)
        }
    }
}
