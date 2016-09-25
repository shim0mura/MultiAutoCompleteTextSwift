//
//  ViewController.swift
//  MultiAutoCompleteTextSwiftExample
//
//  Created by Tatsuhiko Shimomura on 2016/09/25.
//  Copyright © 2016年 Tatsuhiko Shimomura. All rights reserved.
//

import UIKit
import MultiAutoCompleteTextSwift

class ViewController: UIViewController {

    @IBOutlet weak var textField: MultiAutoCompleteTextField!
    
    @IBOutlet weak var inputText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //textField.autoCompleteTableView?.frame.origin.y = 100

        let words = [ "ruby", "rust", "mruby", "php", "perl", "python"]
        textField.autoCompleteStrings = words;
        
        let comparableWords = [
            MultiAutoCompleteToken(top: "C++", subTexts: "cplusplus", "cplapla"),
            MultiAutoCompleteToken(top: "Ocjective-C", subTexts: "objectivec"),
            MultiAutoCompleteToken("C")
        ]
        comparableWords.forEach {
            textField.autoCompleteTokens.append($0)
        }
        
        textField.onSelect = {[weak self] str, indexPath in
           self?.inputText.text = "Selected word: \(str)"
        }
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

