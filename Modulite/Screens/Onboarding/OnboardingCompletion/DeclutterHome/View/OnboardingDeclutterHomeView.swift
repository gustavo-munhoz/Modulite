//
//  OnboardingDeclutterHomeView.swift
//  Modulite
//
//  Created by Gustavo Munhoz Correa on 31/10/24.
//

import UIKit
import SnapKit

class OnboardingDeclutterHomeView: UIView {
    
    var onGotItButtonPressed: (() -> Void)?
    
    // MARK: - Subviews
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private(set) lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.numberOfLines = -1
        view.lineBreakMode = .byWordWrapping
        
        view.attributedText = NSAttributedString(
            string: .localized(for: OnboardingLocalizedTexts.onboardingDeclutterTitle),
            attributes: [
                .font: UIFont.spaceGrotesk(textStyle: .largeTitle, weight: .bold),
                .foregroundColor: UIColor.fiestaGreen,
                .kern: -0.4
            ]
        )
        
        return view
    }()
    
    private(set) lazy var textBox: OnboardingNumberedTutorial = {
        let view = OnboardingNumberedTutorial()
        
        view.setup(
            number: 3,
            attributedText: CustomizedTextFactory.createMarkdownTextWithAsterisk(
                with: .localized(for: OnboardingLocalizedTexts.onboardingDeclutterText)
            )
        )
        
        view.setRemovesTutorialButton(true)
        
        return view
    }()

    private(set) lazy var allSetButton: UIButton = {
        let button = ButtonFactory.mediumButton(
            titleKey: OnboardingLocalizedTexts.onboardingDeclutterGotIt,
            image: UIImage(systemName: "arrow.right"),
            imagePlacement: .trailing
        )
        
        button.addTarget(self, action: #selector(didPressGotItButton), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .whiteTurnip
        setupScrollView()
        addSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Actions
    @objc private func didPressGotItButton() {
        onGotItButtonPressed?()
    }
    
    // MARK: - Setup Methods
    
    private func setupScrollView() {
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
    }
    
    func addSubviews() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(textBox)
        contentView.addSubview(allSetButton)
    }
    
    func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(32)
        }
        
        textBox.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.left.right.equalTo(titleLabel)
        }
        
        allSetButton.snp.makeConstraints { make in
            make.top.equalTo(textBox.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-32)
        }
    }
}
