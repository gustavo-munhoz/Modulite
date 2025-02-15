//
//  Builder.swift
//  WidgetStyling
//
//  Created by Gustavo Munhoz Correa on 05/11/24.
//

import Foundation

protocol Builder {
    associatedtype Product
    func build() throws -> Product
}
