//
//  MultiAutoCompleteTextSwift.swift
//  MultiAutoCompleteTextSwift
//
//  Created by Tatsuhiko Shimomura on 2016/09/25.
//  Copyright © 2016年 Tatsuhiko Shimomura. All rights reserved.
//

import Foundation
import UIKit

open class MultiAutoCompleteTextField:UITextField {
    /// Manages the instance of tableview
    open var autoCompleteTableView:UITableView?
    /// Handles user selection action on autocomplete table view
    open var onSelect:(String, IndexPath) -> Void = {_,_ in}
    /// Handles textfield's textchanged
    open var onTextChange:(String) -> Void = {_ in}
    /// Font for the text suggestions
    open var autoCompleteTextFont = UIFont.systemFont(ofSize: 12)
    /// Color of the text suggestions
    open var autoCompleteTextColor = UIColor.black
    /// Used to set the height of cell for each suggestions
    open var autoCompleteCellHeight:CGFloat = 33.0
    /// The maximum visible suggestion
    open var maximumAutoCompleteCount = 3
    /// Used to set your own preferred separator inset
    open var autoCompleteSeparatorInset = UIEdgeInsets.zero
    /// Hides autocomplete tableview after selecting a suggestion
    open var hidesWhenSelected = true
    /// Hides autocomplete tableview when the textfield is empty
    open var hidesWhenEmpty:Bool?{
        didSet{
            assert(hidesWhenEmpty != nil, "hideWhenEmpty cannot be set to nil")
            autoCompleteTableView?.isHidden = hidesWhenEmpty!
        }
    }
    /// Input words
    open var inputTextTokens:[String] = []
    fileprivate var targetToken:String = ""
    fileprivate var wordTokenizeChars = CharacterSet(charactersIn: " ,")
    fileprivate var autoCompleteEntries:[MultiAutoCompleteTokenComparable]? = []
    /// Suggest words shown in auto complete tableview
    open var autoCompleteTokens:[MultiAutoCompleteTokenComparable] = []
    /// AutoComplete tokenizer
    open var autoCompleteWordTokenizers:[String] = [] {
        didSet{
            wordTokenizeChars = CharacterSet(charactersIn: autoCompleteWordTokenizers.joined(separator: "")
            )
        }
    }
    /// Default input words in text field
    open var defaultText:String? {
        didSet{
            inputTextTokens = defaultText?.components(separatedBy: wordTokenizeChars) ?? []
            self.text = defaultText
        }
    }
    /// The strings to be shown on as suggestions, setting the value of this automatically reload the tableview
    open var autoCompleteStrings:[String]?{
        didSet{
            autoCompleteStrings?.forEach{
                autoCompleteTokens.append(MultiAutoCompleteToken($0))
            }
        }
    }
    /// Add word manually
    open func addInputToken(_ token: String){
        if let text = self.text , !text.isEmpty {
            self.text = text + "," + token + ","
        }else{
            self.text = token + ","
        }
        self.inputTextTokens.append(token)
    }
    
    
    //MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        setupAutocompleteTable(superview!)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
        setupAutocompleteTable(superview!)
    }
    
    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        commonInit()
        if let superView = newSuperview {
            setupAutocompleteTable(superView)
        }
    }
    
    fileprivate func commonInit(){
        hidesWhenEmpty = true
        self.clearButtonMode = .always
        self.addTarget(self, action: #selector(MultiAutoCompleteTextField.textFieldDidChange), for: .editingChanged)
        self.addTarget(self, action: #selector(MultiAutoCompleteTextField.textFieldDidEndEditing), for: .editingDidEnd)
        
    }
    
    fileprivate func setupAutocompleteTable(_ view:UIView){
        let screenSize = UIScreen.main.bounds.size
        
        view.layoutIfNeeded()

        let tableView = UITableView(frame: CGRect(x: self.frame.origin.x, y: self.frame.origin.y + self.frame.height + self.frame.height, width: screenSize.width - (self.frame.origin.x * 2), height: 30.0))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = autoCompleteCellHeight
        tableView.isHidden = hidesWhenEmpty ?? true
        view.addSubview(tableView)
        autoCompleteTableView = tableView
    }
    
    fileprivate func redrawTable(){
        if let autoCompleteTableView = autoCompleteTableView {
            var newFrame = autoCompleteTableView.frame
            newFrame.size.height = autoCompleteTableView.contentSize.height
            autoCompleteTableView.frame = newFrame
        }
    }
    
    //MARK: - Private Methods
    fileprivate func reload(){
        autoCompleteEntries = []

        inputTextTokens = text!.components(separatedBy: wordTokenizeChars)

        if let lastToken = inputTextTokens.last , !lastToken.isEmpty {
            
            targetToken = lastToken
            
            for i in 0..<autoCompleteTokens.count{
                let token = autoCompleteTokens[i]
                if token.matchToken(targetToken) && !inputTextTokens.contains(token.topText) {
                    autoCompleteEntries!.append(token)
                }
            }
        }
        autoCompleteTableView?.reloadData()
        redrawTable()
        
    }
    
    func textFieldDidChange(){
        guard let _ = text else {
            return
        }
        
        reload()
        onTextChange(text!)
        DispatchQueue.main.async(execute: { () -> Void in
            self.autoCompleteTableView?.isHidden =  self.hidesWhenEmpty! ? self.text!.isEmpty : false
        })
    }
    
    func textFieldDidEndEditing() {
        autoCompleteTableView?.isHidden = true
    }
}

//MARK: - UITableViewDataSource - UITableViewDelegate
extension MultiAutoCompleteTextField: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = autoCompleteEntries != nil ? (autoCompleteEntries!.count > maximumAutoCompleteCount ? maximumAutoCompleteCount : autoCompleteEntries!.count) : 0
        return count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "autocompleteCellIdentifier"
        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        if cell == nil{
            cell = UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
        }
        
        cell?.textLabel?.font = autoCompleteTextFont
        cell?.textLabel?.textColor = autoCompleteTextColor
        cell?.textLabel?.text = autoCompleteEntries![(indexPath as NSIndexPath).row].topText
        
        cell?.contentView.gestureRecognizers = nil
        return cell!
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        
        if let selectedText = cell?.textLabel?.text {
                        
            if targetToken.isEmpty {
                self.text = selectedText
            }else{
                
                let regex: NSRegularExpression
                do {
                    let pattern = "\(targetToken)$"
                    regex = try NSRegularExpression(pattern: pattern, options: [])
                    
                    self.text = regex.stringByReplacingMatches(in: self.text!, options: [], range: NSMakeRange(0, self.text!.characters.count), withTemplate: selectedText + " ")
                    
                } catch let error as NSError {
                    assertionFailure(error.localizedDescription)
                }
                
            }
            targetToken = ""
            let _ = inputTextTokens.popLast()
            inputTextTokens.append(selectedText)
            
            onSelect(selectedText, indexPath)
        }
        
        DispatchQueue.main.async(execute: { () -> Void in
            tableView.isHidden = self.hidesWhenSelected
        })
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if cell.responds(to: #selector(setter: UITableViewCell.separatorInset)){
            cell.separatorInset = autoCompleteSeparatorInset
        }
        if cell.responds(to: #selector(setter: UIView.preservesSuperviewLayoutMargins)){
            cell.preservesSuperviewLayoutMargins = false
        }
        if cell.responds(to: #selector(setter: UIView.layoutMargins)){
            cell.layoutMargins = autoCompleteSeparatorInset
        }
        
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return autoCompleteCellHeight
    }
}

public protocol MultiAutoCompleteTokenComparable {
    var topText: String { get }
    func matchToken(_ searchString: String) -> Bool
}

open class MultiAutoCompleteToken: MultiAutoCompleteTokenComparable {
    
    open var topText: String
    var searchOptions: NSString.CompareOptions = .caseInsensitive
    fileprivate var texts: [String] = []
    
    public init(top: String, subTexts: String...){
        self.topText = top
        self.texts.append(top)
        texts += subTexts
    }
    
    public init(_ top: String){
        self.topText = top
        self.texts.append(top)
    }
    
    open func matchToken(_ searchString: String) -> Bool {
        let result = self.texts.contains{
            let range = $0.range(of: searchString, options: searchOptions, range: nil, locale: nil)
            return range != nil
        }
        
        return result
    }
    
}
