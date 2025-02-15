//
//  UILabel+AppNameConfiguration.swift
//  Modulite
//
//  Created by Gustavo Munhoz Correa on 27/08/24.
//

import UIKit
import WidgetStyling

extension UILabel {
    func applyConfiguration(_ config: ModuleTextConfiguration) {
        if let textCase = config.textCase { setText(toCase: textCase) }
        
        if config.shouldRemoveSpaces { removeSpaces() }
        
        let attributedString = NSMutableAttributedString(string: text ?? "")
        
        font = config.font
        textColor = config.textColor
        textAlignment = config.textAlignment ?? .center
        
        if let rawColor = config.shadowColor {
            let shadowColor = rawColor.withAlphaComponent(config.shadowOpacity ?? 1)
            let shadow = NSShadow()
            shadow.shadowColor = shadowColor
            shadow.shadowBlurRadius = config.shadowBlurRadius ?? 0
            shadow.shadowOffset = config.shadowOffset ?? .zero
            
            attributedString.addAttribute(
                .shadow,
                value: shadow,
                range: NSRange(location: 0, length: attributedString.length)
            )
        }
        
        if let letterSpacing = config.letterSpacing {
            attributedString.addAttribute(
                .kern,
                value: letterSpacing,
                range: NSRange(location: 0, length: attributedString.length)
            )
        }
        
        if let prefix = config.prefix {
            attributedString.insert(NSAttributedString(string: prefix), at: 0)
        }
        
        if !(attributedString.length == 0) {
            attributedText = attributedString
        }
    }
    
    private func removeSpaces() {
        text = text?.filter { $0 != " " }
    }
    
    private func setText(toCase textCase: String.TextCase) {
        switch textCase {
        case .upper:
            text = text?.uppercased()
        case .lower:
            text = text?.lowercased()
        case .camel:
            text = text?.camelCased()
        case .capitalized:
            text = text?.capitalized
        @unknown default:
            break
        }
    }
}
