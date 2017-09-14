//
//  CoreDataController.swift
//  ThroughWall
//
//  Created by Bin on 08/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import Foundation
import CoreData
import CocoaLumberjack

class CoreDataController: NSObject {

    static let sharedInstance = CoreDataController()

    var toRefreshObjInMain = [NSManagedObject]()
    var toRefreshObjInPriv = [NSManagedObject]()
    let handleRefreshLock = NSLock()
    let maxCount = 20

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "ThroughWall")
        var url = CoreDataController.sharedInstance.getDatabaseUrl()
        url.appendPathComponent(databaseFileName)
        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions = [NSPersistentStoreDescription.init(url: url), description]

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
                //                fatalError("Unresolved error \(error), \(error.userInfo)")
                DDLogError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    lazy var privateContext: NSManagedObjectContext = {
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.parent = self.persistentContainer.viewContext

        return managedObjectContext
    }()


    func getDatabaseUrl() -> URL {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        url.appendPathComponent(databaseFolderName)

        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                // file exists and is a directory
//                DDLogVerbose("\(url) exists and is a directory")
            } else {
                // file exists and is not a directory
                do {
                    try fileManager.removeItem(at: url)
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    DDLogError("\(url) is not a directory, and recreate error. \(error)")
                }
            }
        } else {
            // file does not exist
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                DDLogVerbose("create folder \(url)")
            } catch {
                DDLogError("create folder \(url) failed. \(error)")
            }
        }

        return url
    }

    func getContext() -> NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func getPrivateContext() -> NSManagedObjectContext {
        return privateContext
    }

    func addToRefreshList(withObj obj: NSManagedObject, andContext context: NSManagedObjectContext) {
        handleRefreshLock.lock()
        if context == getContext() {
            if !toRefreshObjInMain.contains(obj) {
                toRefreshObjInMain.append(obj)
            }
            if toRefreshObjInMain.count >= maxCount {
                saveContext()
                for object in toRefreshObjInMain {
                    context.refresh(object, mergeChanges: false)
                }
                toRefreshObjInMain.removeAll()
                DDLogVerbose("obj removed")
            }
        } else if context == getPrivateContext() {
            if !toRefreshObjInPriv.contains(obj) {
                toRefreshObjInPriv.append(obj)
            }
            if toRefreshObjInPriv.count >= maxCount {
                savePrivateContext()
                for object in toRefreshObjInPriv {
                    context.refresh(object, mergeChanges: false)
                }
                toRefreshObjInPriv.removeAll()
            }
        }
        handleRefreshLock.unlock()
    }

    func closeCrashLogs() {
        let defaults = UserDefaults.init(suiteName: groupName)
        if let oldDate = defaults?.value(forKey: currentTime) as? Date {
            if Thread.current.isMainThread {
                self.closeCrashLogs(withDisconnectTime: oldDate)
            } else {
                DispatchQueue.main.sync {
                    self.closeCrashLogs(withDisconnectTime: oldDate)
                }
            }
        }
    }

    private func closeCrashLogs(withDisconnectTime disconnectTime: Date) {
        let fetch: NSFetchRequest<HostTraffic> = HostTraffic.fetchRequest()
        fetch.includesPropertyValues = false
        fetch.includesSubentities = false
        let context = self.getContext()

        do {
            let results = try context.fetch(fetch)
            for result in results {
                if result.disconnectTime == nil {
                    result.disconnectTime = disconnectTime
                    result.forceDisconnect = true
                    result.inProcessing = false
                }
            }
            saveContext()
        } catch {
            DDLogError("closeCrashLogs error: \(error)")
        }
    }


    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
                if let parent = context.parent {
                    parent.performAndWait {
                        self.saveContext(parent)
                    }
                }
            } catch {
                DDLogError("\(error)")
            }
        }
    }


    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                DDLogVerbose("context saved")
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //                let nserror = error as NSError
                //                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                DDLogError("Unresolved error \(error)")
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
                //                let nserror = error as NSError
                //                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                DDLogError("Unresolved error \(error)")
            }
        }
    }
}

