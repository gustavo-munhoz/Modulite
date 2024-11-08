//
//  CoreDataPersistenceController.swift
//  Modulite
//
//  Created by Gustavo Munhoz Correa on 02/09/24.
//

import CoreData
import UIKit
import WidgetStyling

struct CoreDataPersistenceController {
    
    // MARK: - Properties
    static let shared = CoreDataPersistenceController()
    
    static var preview: CoreDataPersistenceController = {
        let result = CoreDataPersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        do {
            try viewContext.save()
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
        
        return result
    }()
    
    let container: NSPersistentContainer
    
    // MARK: - Setup methods
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WidgetData")
        
        guard let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String else {
            fatalError("Could not find App Group ID in Info.plist")
        }
        
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("Could not find App Group Container")
        }
        
        let storeURL = appGroupURL.appendingPathComponent("WidgetData.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        if inMemory {
            description.url = URL(filePath: "/dev/null")
        }
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error as? NSError {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.name = "viewContext"
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
    }
    
    func executeInitialSetup() {
        ensureDefaultSelectedColor()
        checkVersionAndPopulateIfNeeded()
    }
    
    private func ensureDefaultSelectedColor() {
        let fetchRequest = PersistentWidgetModule.basicFetchRequest()
        
        do {
            let results = try container.viewContext.fetch(fetchRequest)
            for object in results {
                if object.selectedColor == nil {
                    object.selectedColor = UIColor.clear
                }
            }
            
            if container.viewContext.hasChanges {
                try container.viewContext.save()
            }
        } catch {
            print("Failed to update objects with default selectedColor: \(error.localizedDescription)")
        }
    }

}

// MARK: - AppInfo
extension CoreDataPersistenceController {
    
    func fetchApps(predicate: NSPredicate? = nil) -> [AppData] {
        let request = PersistentAppData.prioritySortedFetchRequest()
        request.predicate = predicate
        do {
            let persistedApps = try container.viewContext.fetch(request)
            
            let apps = persistedApps.compactMap { AppData(persisted: $0) }
            
            return apps
            
        } catch {
            print("Error fetching apps: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchAppData(named name: String, urlScheme: String) -> AppData? {
        let predicate = NSPredicate(format: "name == %@ AND urlScheme == %@", name, urlScheme)
        let apps = CoreDataPersistenceController.shared.fetchApps(predicate: predicate)
        return apps.first
    }
    
    private func checkVersionAndPopulateIfNeeded() {
        guard let url = Bundle.main.url(forResource: "apps", withExtension: "json") else {
            fatalError("Failed to find apps.json")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let appsData = try JSONDecoder().decode(AppListData.self, from: data)
                        
            let currentVersion = UserDefaults.standard.integer(forKey: "appsDataVersion")
            
            guard appsData.version > currentVersion else {
                print("App data is already up to date with version \(currentVersion).")
                return
            }
            
            clearOldAppsData()
            
            appsData.apps.forEach { data in
                PersistentAppData.from(data: data, using: container.viewContext)
            }
            
            UserDefaults.standard.set(appsData.version, forKey: "appsDataVersion")
            
            print("Populated apps with \(appsData.apps.count) items.")
            
        } catch {
            print("Failed to populate appInfo table with error \(error.localizedDescription)")
        }
    }
    
    private func clearOldAppsData() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PersistentAppData.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try container.viewContext.execute(deleteRequest)
            print("Cleared old app data.")
        } catch {
            print("Failed to clear old app data with error \(error.localizedDescription)")
        }
    }
}

// MARK: - Widget persistence
extension CoreDataPersistenceController {
    func fetchMainWidgets(predicate: NSPredicate? = nil) -> [WidgetSchema] {
        let typePredicate = NSPredicate(format: "type == %@", WidgetType.main.rawValue)
        let combinedPredicate = combinePredicates(typePredicate, predicate)
        return fetchWidgets(with: combinedPredicate)
    }

    func fetchAuxWidgets(predicate: NSPredicate? = nil) -> [WidgetSchema] {
        let typePredicate = NSPredicate(format: "type == %@", WidgetType.auxiliary.rawValue)
        let combinedPredicate = combinePredicates(typePredicate, predicate)
        return fetchWidgets(with: combinedPredicate)
    }
    
    private func fetchWidgets(with predicate: NSPredicate?) -> [WidgetSchema] {
        let request = PersistentWidgetSchema.basicFetchRequest()
        request.predicate = predicate
        
        let sortDescriptor = NSSortDescriptor(key: "lastEditedAt", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            let persistedWidgets = try container.viewContext.fetch(request)
            let widgetSchemas = persistedWidgets.compactMap { persistedWidget in
                return WidgetSchema(persisted: persistedWidget)
            }
            
            return widgetSchemas
            
        } catch {
            print("Error fetching widgets: \(error.localizedDescription)")
            return []
        }
    }

    private func combinePredicates(
        _ first: NSPredicate,
        _ second: NSPredicate?
    ) -> NSPredicate {
        guard let second else { return first }
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [first, second])
    }
    
    func deleteWidget(withId id: UUID) {
        let context = container.viewContext
        let request = PersistentWidgetSchema.basicFetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            guard let widget = try context.fetch(request).first else {
                print("Widget with id \(id) not found.")
                return
            }
            
            context.delete(widget)
            
            try context.save()
            
            FileManagerImagePersistenceController.shared.deleteWidgetAndModules(widgetId: id)
            print("Widget with id \(id) deleted successfully from CoreData.")
            
        } catch {
            print("Error deleting widget from CoreData: \(error.localizedDescription)")
        }
    }
}

extension CoreDataPersistenceController {
    @discardableResult
    func registerOrUpdateWidget(
        _ schema: WidgetSchema,
        widgetImage: UIImage
    ) -> PersistentWidgetSchema {
        let context = container.viewContext
        let fetchRequest = PersistentWidgetSchema.basicFetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", schema.id as CVarArg)
        
        do {
            guard let existingWidget = try context.fetch(fetchRequest).first else {
                let newWidget = PersistentWidgetSchema.from(
                    schema: schema,
                    widgetImage: widgetImage,
                    using: context
                )
                
                print("Widget created successfully.")
                
                return newWidget
            }
            
            existingWidget.name = schema.name
            existingWidget.styleIdentifier = schema.widgetStyle.identifier
            
            let widgetImageUrl = FileManagerImagePersistenceController.shared.saveWidgetImage(
                image: widgetImage,
                for: existingWidget.id
            )
            
            existingWidget.previewImageUrl = widgetImageUrl
            
            if let modules = existingWidget.modules as? Set<PersistentWidgetModule> {
                for module in modules {
                    context.delete(module)
                }
            }
            
            var newModules: Set<PersistentWidgetModule> = []
            for module in schema.modules {
                let persistentModule = PersistentWidgetModule.from(
                    module: module,
                    widgetId: existingWidget.id,
                    using: context
                )
                
                newModules.insert(persistentModule)
            }
            
            existingWidget.modules = newModules as NSSet
            existingWidget.lastEditedAt = .now
            
            try context.save()
            
            print("Widget \(existingWidget.id) updated successfully.")
            return existingWidget
            
        } catch {
            print("Error registering or updating widget: \(error.localizedDescription)")
            fatalError("Failed to register or update widget.")
        }
    }
}
