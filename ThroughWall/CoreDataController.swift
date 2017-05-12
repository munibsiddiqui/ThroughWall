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
                DDLogVerbose("\(url) exists and is a directory")
            } else {
                // file exists and is not a directory
                do {
                    try fileManager.removeItem(at: url)
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                }catch{
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

    func backupDatabase(toURL url: URL) {

        let psc = NSPersistentStoreCoordinator(managedObjectModel: persistentContainer.managedObjectModel)
        let oldURL = getDatabaseUrl()
        print(oldURL)
        print(url)
        do {
            let oldStore = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: oldURL, options: nil)
            try psc.migratePersistentStore(oldStore, to: url, options: nil, withType: NSSQLiteStoreType)
        } catch {
            print(error)
        }
    }

    func mergerPieceBody(atURL url: URL) {
        DispatchQueue.main.async {
            self._mergerPieceBody(atURL: url)
        }
    }

    func _mergerPieceBody(atURL url: URL) {
        let container = NSPersistentContainer(name: "ThroughWall")
        container.persistentStoreDescriptions = [NSPersistentStoreDescription.init(url: url)]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        let context = container.viewContext

        let fetch: NSFetchRequest<HostTraffic> = HostTraffic.fetchRequest()
        fetch.includesPropertyValues = false
        fetch.includesSubentities = false

        do {
            let results = try context.fetch(fetch)
            for result in results {

                if let bodies = result.bodies {
                    var responseBody = Data()
                    var requestBody = Data()
                    if var _bodies = bodies.allObjects as? [PieceData] {
                        _bodies.sort() {
                            if $0.timeStamp!.timeIntervalSince1970 < $1.timeStamp!.timeIntervalSince1970 {
                                return true
                            } else {
                                return false
                            }
                        }
                        for body in _bodies {
                            if body.type == "respnose" {
                                responseBody.append((body.rawData as Data?) ?? Data())
                            } else if body.type == "request" {
                                requestBody.append((body.rawData as Data?) ?? Data())
                            }
                            context.delete(body)
                        }
                        saveContext(context)
                        if responseBody.count > 0 {
                            let response = PieceData(context: context)
                            response.rawData = responseBody as NSData?
                            response.timeStamp = Date() as NSDate?
                            response.type = "respnose"
                            //                        response.belongToTraffic = result
                            result.addToBodies(response)
                        }
                        if requestBody.count > 0 {
                            let request = PieceData(context: context)
                            request.rawData = requestBody as NSData?
                            request.timeStamp = Date() as NSDate?
                            request.type = "request"
                            //                        request.belongToTraffic = result
                            result.addToBodies(request)
                        }
                        saveContext(context)
                        //                    context.refresh(result, mergeChanges: false)
                    }

                } else {
                    context.refresh(result, mergeChanges: false)
                }
            }
        } catch {
            print(error)
        }
    }

    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print(error)
            }
        }
    }


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
