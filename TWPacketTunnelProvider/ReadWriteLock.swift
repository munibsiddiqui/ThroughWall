//
//  ReadWriteLock.swift
//  ThroughWall
//
//  Created by Bingo on 03/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Foundation
import Darwin

class ReadWriteLock: NSObject {
    private var lock = pthread_rwlock_t()
    
    override init() {
        super.init()
        pthread_rwlock_init(&lock, nil)
    }
    
    deinit {
        pthread_rwlock_destroy(&lock)
    }
    
    func withReadLock(_ block: () -> Void)  {
        pthread_rwlock_rdlock(&lock)
        block()
        pthread_rwlock_unlock(&lock)
    }
    
    func withWriteLock(_ block: () -> Void)  {
        pthread_rwlock_wrlock(&lock)
        block()
        pthread_rwlock_unlock(&lock)
    }
    
}
