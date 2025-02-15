//
//  WidgetEditorSaveButton.swift
//  Modulite
//
//  Created by Gustavo Munhoz Correa on 30/09/24.
//

import UIKit

class WidgetEditorSaveButton: UIButton {
    
    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    // MARK: - Setup
    
    private func setupButton() {
        self.configuration = ButtonFactory.mediumButtonConfiguration(
            titleKey: String.LocalizedKey.widgetEditorViewSaveWidgetButton,
            font: UIFont.spaceGrotesk(textStyle: .body, weight: .bold),
            image: UIImage(named: "custom.floppyDisk"),
            imagePadding: 10,
            imagePlacement: .leading,
            imagePointSize: 17,
            imageWeight: .regular,
            foregroundColor: .white,
            backgroundColor: .fiestaGreen,
            contentHorizontalAlignment: .center
        )
                
        self.layer.cornerRadius = 0
                
        self.configurationUpdateHandler = { button in
            UIView.animate(withDuration: 0.1) {
                if button.state == .highlighted {
                    button.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
                    button.imageView?.addSymbolEffect(.bounce)
                } else {
                    button.transform = .identity
                }
            }
        }
                
        self.contentHorizontalAlignment = .center
    }
    
    // MARK: - Appearance Updating
    
    func setToEditingState() {
        var config = self.configuration
        config?.attributedTitle = AttributedString(
            .localized(for: .save).uppercased(),
            attributes: AttributeContainer([
                .font: UIFont.spaceGrotesk(textStyle: .title3, weight: .bold),
                .foregroundColor: UIColor.white
            ])
        )
        self.configuration = config
    }
}
