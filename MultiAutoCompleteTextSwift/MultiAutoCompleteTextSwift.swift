//
//  MultiAutoCompleteTextSwift.swift
//  MultiAutoCompleteTextSwift
//
//  Created by Tatsuhiko Shimomura on 2016/09/25.
//  Copyright © 2016年 Tatsuhiko Shimomura. All rights reserved.
//

import Foundation
import UIKit

public class MultiAutoCompleteTextField:UITextField {
    /// Manages the instance of tableview
    public var autoCompleteTableView:UITableView?
    /// Handles user selection action on autocomplete table view
    public var onSelect:(String, NSIndexPath) -> Void = {_,_ in}
    /// Handles textfield's textchanged
    public var onTextChange:(String) -> Void = {_ in}
    /// Font for the text suggestions
    public var autoCompleteTextFont = UIFont.systemFontOfSize(12)
    /// Color of the text suggestions
    public var autoCompleteTextColor = UIColor.blackColor()
    /// Used to set the height of cell for each suggestions
    public var autoCompleteCellHeight:CGFloat = 33.0
    /// The maximum visible suggestion
    public var maximumAutoCompleteCount = 3
    /// Used to set your own preferred separator inset
    public var autoCompleteSeparatorInset = UIEdgeInsetsZero
    /// Hides autocomplete tableview after selecting a suggestion
    public var hidesWhenSelected = true
    /// Hides autocomplete tableview when the textfield is empty
    public var hidesWhenEmpty:Bool?{
        didSet{
            assert(hidesWhenEmpty != nil, "hideWhenEmpty cannot be set to nil")
            autoCompleteTableView?.hidden = hidesWhenEmpty!
        }
    }
    /// Input words
    public var inputTextTokens:[String] = []
    private var targetToken:String = ""
    private var wordTokenizeChars = NSCharacterSet(charactersInString: " ,")
    private var autoCompleteEntries:[MultiAutoCompleteTokenComparable]? = []
    /// Suggest words shown in auto complete tableview
    public var autoCompleteTokens:[MultiAutoCompleteTokenComparable] = []
    /// AutoComplete tokenizer
    public var autoCompleteWordTokenizers:[String] = [] {
        didSet{
            wordTokenizeChars = NSCharacterSet(charactersInString: autoCompleteWordTokenizers.joinWithSeparator("")
            )
        }
    }
    /// Default input words in text field
    public var defaultText:String? {
        didSet{
            inputTextTokens = defaultText?.componentsSeparatedByCharactersInSet(wordTokenizeChars) ?? []
            self.text = defaultText
        }
    }
    /// The strings to be shown on as suggestions, setting the value of this automatically reload the tableview
    public var autoCompleteStrings:[String]?{
        didSet{
            autoCompleteStrings?.forEach{
                autoCompleteTokens.append(MultiAutoCompleteToken($0))
            }
        }
    }
    /// Add word manually
    public func addInputToken(token: String){
        if let text = self.text where !text.isEmpty {
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
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
        setupAutocompleteTable(superview!)
    }
    
    public override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        commonInit()
        if let superView = newSuperview {
            setupAutocompleteTable(superView)
        }
    }
    
    private func commonInit(){
        hidesWhenEmpty = true
        self.clearButtonMode = .Always
        self.addTarget(self, action: #selector(MultiAutoCompleteTextField.textFieldDidChange), forControlEvents: .EditingChanged)
        self.addTarget(self, action: #selector(MultiAutoCompleteTextField.textFieldDidEndEditing), forControlEvents: .EditingDidEnd)
        
    }
    
    private func setupAutocompleteTable(view:UIView){
        let screenSize = UIScreen.mainScreen().bounds.size
        
        view.layoutIfNeeded()

        let tableView = UITableView(frame: CGRectMake(self.frame.origin.x, self.frame.origin.y + CGRectGetHeight(self.frame) + self.frame.height, screenSize.width - (self.frame.origin.x * 2), 30.0))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = autoCompleteCellHeight
        tableView.hidden = hidesWhenEmpty ?? true
        view.addSubview(tableView)
        autoCompleteTableView = tableView
    }
    
    private func redrawTable(){
        if let autoCompleteTableView = autoCompleteTableView {
            var newFrame = autoCompleteTableView.frame
            newFrame.size.height = autoCompleteTableView.contentSize.height
            autoCompleteTableView.frame = newFrame
        }
    }
    
    //MARK: - Private Methods
    private func reload(){
        autoCompleteEntries = []

        inputTextTokens = text!.componentsSeparatedByCharactersInSet(wordTokenizeChars)

        if let lastToken = inputTextTokens.last where !lastToken.isEmpty {
            
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
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.autoCompleteTableView?.hidden =  self.hidesWhenEmpty! ? self.text!.isEmpty : false
        })
    }
    
    func textFieldDidEndEditing() {
        autoCompleteTableView?.hidden = true
    }
}

//MARK: - UITableViewDataSource - UITableViewDelegate
extension MultiAutoCompleteTextField: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = autoCompleteEntries != nil ? (autoCompleteEntries!.count > maximumAutoCompleteCount ? maximumAutoCompleteCount : autoCompleteEntries!.count) : 0
        return count
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "autocompleteCellIdentifier"
        var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        if cell == nil{
            cell = UITableViewCell(style: .Default, reuseIdentifier: cellIdentifier)
        }
        
        cell?.textLabel?.font = autoCompleteTextFont
        cell?.textLabel?.textColor = autoCompleteTextColor
        cell?.textLabel?.text = autoCompleteEntries![indexPath.row].topText
        
        cell?.contentView.gestureRecognizers = nil
        return cell!
    }
    
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath)
        
        if let selectedText = cell?.textLabel?.text {
                        
            if targetToken.isEmpty {
                self.text = selectedText
            }else{
                
                let regex: NSRegularExpression
                do {
                    let pattern = "\(targetToken)$"
                    regex = try NSRegularExpression(pattern: pattern, options: [])
                    
                    self.text = regex.stringByReplacingMatchesInString(self.text!, options: [], range: NSMakeRange(0, self.text!.characters.count), withTemplate: selectedText + " ")
                    
                } catch let error as NSError {
                    assertionFailure(error.localizedDescription)
                }
                
            }
            targetToken = ""
            inputTextTokens.popLast()
            inputTextTokens.append(selectedText)
            
            onSelect(selectedText, indexPath)
        }
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            tableView.hidden = self.hidesWhenSelected
        })
    }
    
    public func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if cell.respondsToSelector(Selector("setSeparatorInset:")){
            cell.separatorInset = autoCompleteSeparatorInset
        }
        if cell.respondsToSelector(Selector("setPreservesSuperviewLayoutMargins:")){
            cell.preservesSuperviewLayoutMargins = false
        }
        if cell.respondsToSelector(Selector("setLayoutMargins:")){
            cell.layoutMargins = autoCompleteSeparatorInset
        }
        
    }
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return autoCompleteCellHeight
    }
}

public protocol MultiAutoCompleteTokenComparable {
    var topText: String { get }
    func matchToken(searchString: String) -> Bool
}

public class MultiAutoCompleteToken: MultiAutoCompleteTokenComparable {
    
    public var topText: String
    var searchOptions: NSStringCompareOptions = .CaseInsensitiveSearch
    private var texts: [String] = []
    
    public init(top: String, subTexts: String...){
        self.topText = top
        self.texts.append(top)
        texts += subTexts
    }
    
    public init(_ top: String){
        self.topText = top
        self.texts.append(top)
    }
    
    public func matchToken(searchString: String) -> Bool {
        let result = self.texts.contains{
            let range = $0.rangeOfString(searchString, options: searchOptions, range: nil, locale: nil)
            return range != nil
        }
        
        return result
    }
    
}
