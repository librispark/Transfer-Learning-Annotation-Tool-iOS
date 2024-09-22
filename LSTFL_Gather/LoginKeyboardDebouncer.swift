//
//  Debouncer.swift
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 9/21/24.
//  Copyright © 2024 user. All rights reserved.
//

// Debouncer.swift
import Foundation

public class LoginKeyboardDebouncer {
    private var workItem: DispatchWorkItem?
    public var delay: TimeInterval
    
    // Initialize with a delay time
    public init(delay: TimeInterval) {
        self.delay = delay
    }
    
    // Debounced function that schedules a task after the specified delay
    public func debounce(_ action: @escaping () -> Void) {
        // Cancel the previously scheduled task if it exists
        workItem?.cancel()
        
        // Create a new task
        workItem = DispatchWorkItem(block: {
            action()
        })
        
        // Schedule the new task after the delay
        if let workItem = workItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
}

