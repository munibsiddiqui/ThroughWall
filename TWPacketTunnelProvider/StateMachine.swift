//
//  StateMachine.swift
//  ThroughWall
//
//  Created by Bingo on 17/06/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Foundation

class State {
    private var events = [String: (String, (() -> Void)?)]()

    private func isEventlreadyExist(eName: String) -> Bool {
        if events.keys.contains(eName) {
            return true
        }
        return false
    }

    func addEvent(withName eName: String, andToState tName: String, andProcess process: (() -> Void)?) -> Bool {
        if isEventlreadyExist(eName: eName) {
            return false
        }
        events[eName] = (tName, process)
        return true
    }

    func getEvent(withName eName: String) -> (String, (() -> Void)?)? {
        if isEventlreadyExist(eName: eName) {
            return events[eName]
        }
        return nil
    }

}

class StateMachine {
    private var states = [String: State]()
    private let lock = NSLock()
    private var currentState = State()
    private func isStateAlreadyExist(sName: String) -> Bool {
        if states.keys.contains(sName) {
            return true
        }
        return false
    }

    private func isStatesAlreadyExist(sNames: [String]) -> Bool {
        for sName in sNames {
            if isStateAlreadyExist(sName: sName) {
                return true
            }
        }
        return false
    }

    private func addState(withName sName: String, shouldCheckDumplicate check: Bool) -> Bool {
        if check {
            if isStateAlreadyExist(sName: sName) {
                return false
            }
        }
        states[sName] = State()
        return true
    }

    func addState(withName sName: String) -> Bool {
        return addState(withName: sName, shouldCheckDumplicate: true)
    }

    func addStates(withNames sNames: [String]) -> Bool {
        if isStatesAlreadyExist(sNames: sNames) {
            return false
        }
        for sName in sNames {
            let _ = addState(withName: sName, shouldCheckDumplicate: false)
        }
        return true
    }

    func addEvent(fromState fState: String, toState tState: String, withName eName: String, andProcess process: (() -> Void)?) -> Bool {
        guard let fs = states[fState], let _ = states[tState] else {
            return false
        }
        return fs.addEvent(withName: eName, andToState: tState, andProcess: process)
    }

    func triger(event eName: String) -> Bool {
        var result: Bool
        var process: (() -> Void)?
        lock.lock()
        if let (tState, _process) = currentState.getEvent(withName: eName){
            process = _process
            result = true
            currentState = states[tState]!
        } else {
            result = false
        }
        lock.unlock()
        process?()
        return result
    }
}
