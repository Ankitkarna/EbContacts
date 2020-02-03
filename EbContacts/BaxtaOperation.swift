//
//  BaxtaOperation.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/20/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import Foundation

public protocol OperationQueueable {
    func start()
    var onFinish: ((Error?) -> Void)? { get set }
}

enum OperationState: String {
    case ready
    case executing
    case finished
    
    var keyPath: String {
        return "is\(self.rawValue.capitalized)"
    }
}

class BaxtaOperation: Operation {
    
    /// The story synchronizer
    private var queueable: OperationQueueable
    
    /// The identifier for this operation
    let operationIdentifier: String
    
    var error: Error?
    
    /// Initializer
    init(queueable: OperationQueueable) {
        self.queueable = queueable
        self.operationIdentifier = UUID().uuidString
    }
    
    /// Trigger for when the states are changed
    var operationState: OperationState = .ready {
        willSet {
            self.willChangeValue(forKey: operationState.keyPath)
            self.willChangeValue(forKey: newValue.keyPath)
        }
        didSet {
            self.didChangeValue(forKey: oldValue.keyPath)
            self.didChangeValue(forKey: operationState.keyPath)
        }
    }
    
    /// The main operation method
    override func main() {
        
        //check if opertaion is cancelled, if cancelled then return else continue
        guard !isCancelled else { return }
        
        //start the sync
        self.operationState = .executing
        queueable.onFinish = { [weak self] (error) in
            self?.operationFinished(error: error)
        }
        queueable.start()
    }
    
    private func operationFinished(error: Error?) {
        self.error = error
        self.operationState = .finished
    }
    
    /// Operation inherited
    override var isFinished: Bool { return operationState == .finished }
    override var isExecuting: Bool { return operationState == .executing }
    override var isReady: Bool { return super.isReady && operationState == .ready }
    override var isAsynchronous: Bool { return true }
}
