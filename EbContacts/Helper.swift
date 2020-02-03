//
//  Helper.swift
//  BaxtaContactFramework
//
//  Created by Ankit Karna on 1/28/20.
//  Copyright © 2020 Ankit Karna. All rights reserved.
//

import Foundation

class Helper {
    static func performOnMainThread(_ function: @escaping () -> Void) {
        if Thread.isMainThread {
            function()
        } else {
            DispatchQueue.main.async {
                function()
            }
        }
    }
}
