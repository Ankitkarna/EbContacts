//
//  CountryCode.swift
//  BaxtaContactFramework
//
//  Created by Ankit Karna on 1/31/20.
//  Copyright © 2020 Ankit Karna. All rights reserved.
//

import Foundation

struct CountryInfo: Decodable {
    let countryCode: String
    let phoneCode: String
    let country: String
    
    enum CodingKeys: String, CodingKey {
        case countryCode = "code"
        case phoneCode = "dial_code"
        case country = "name"
    }
}
