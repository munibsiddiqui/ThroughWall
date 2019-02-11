//
//  CoreDataController.swift
//  ThroughWall
//
//  Created by Bin on 08/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import Foundation
import CoreData


class CoreDataController: NSObject {
    
    static let sharedInstance = CoreDataController()
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "ThroughWall")
        let url = CoreDataController.sharedInstance.getDatabaseUrl()
        container.persistentStoreDescriptions = [NSPersistentStoreDescription.init(url: url)]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    lazy var privateContext: NSManagedObjectContext = {
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.parent =  self.persistentContainer.viewContext
        
        return managedObjectContext
    }()
    
    func getDatabaseName() -> String {
        return "Record.sqlite"
    }
    
    func getDatabaseUrl() -> URL {
        var url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        url.appendPathComponent(getDatabaseName())
        return url
    }
    
    func getContext() -> NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func getPrivateContext() -> NSManagedObjectContext {
        return privateContext
    }
    
//    func backupDatabase(toURL url: URL) {
//        let migrationPSC = NSPersistentStoreCoordinator(managedObjectModel: persistentContainer.managedObjectModel)
//        migrationPSC.store
//        migrationPSC.migratePersistentStore(<#T##store: NSPersistentStore##NSPersistentStore#>, to: <#T##URL#>, options: <#T##[AnyHashable : Any]?#>, withType: <#T##String#>)
//    }
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func savePrivateContext() {
        if privateContext.hasChanges {
            do {
                try privateContext.save()
                self.getContext().performAndWait {
                    self.saveContext()
                }
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    
}
