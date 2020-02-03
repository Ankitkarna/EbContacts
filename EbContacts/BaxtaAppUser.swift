//
//  BaxtaAppUser.swift
//  BaxtaContactFramework
//
//  Created by Ankit Karna on 1/29/20.
//  Copyright © 2020 Ankit Karna. All rights reserved.
//

import CoreData

public final class BaxtaAppUser: NSManagedObject {
    @NSManaged public var userId: String
    @NSManaged public var fullName: String
    @NSManaged public var userName: String?
    @NSManaged private var profilePhoto: String?
    
    public var profileURL: URL? {
        get {
            guard let profilePhoto = profilePhoto else { return nil }
            return URL(string: profilePhoto)
        }
        set {
            profilePhoto = newValue?.absoluteString
        }
        
    }
}

extension BaxtaAppUser: Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(keyPath: \BaxtaAppUser.fullName, ascending: true)]
    }
}
