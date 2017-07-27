//
//  CoreDataController.swift
//  ChiselLogViewer
//
//  Created by Bingo on 09/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Cocoa

class CoreDataController: NSObject {
    var databaseURL: URL?
    
    init(withBaseURL url: URL) {
        let databaseURL = url.appendingPathComponent(databaseFileName)
        self.databaseURL = databaseURL
    }
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "ThroughWall")
        if let _databaseURL = self.databaseURL {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: _databaseURL)]
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
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
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }()
    
    func getContext() -> NSManagedObjectContext {
        return persistentContainer.viewContext
    }
}
