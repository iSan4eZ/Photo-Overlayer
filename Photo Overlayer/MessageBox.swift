//
//  MessageBox.swift
//  Photo Overlayer
//
//  Created by Stas on 8/25/18.
//  Copyright © 2018 iSan4eZ. All rights reserved.
//

import UIKit

class MessageBox: NSObject {

    static func Show(view: UIViewController, message: String, title: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        print(message, title)
        view.present(alert, animated: true, completion: nil)
    }
    
    static func show(view: UIViewController, message: String, title: String, style: UIAlertController.Style) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        print(message, title)
        view.present(alert, animated: true, completion: nil)
    }
    
    static func show(view: UIViewController, message: String, title: String, buttonsTexts: String...) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        for button in buttonsTexts{
            alert.addAction(UIAlertAction(title: button, style: UIAlertAction.Style.default, handler: nil))
        }
        print(message, title)
        view.present(alert, animated: true, completion: nil)
    }
    
    static func show(view: UIViewController, message: String, title: String, style: UIAlertController.Style, buttonsTexts: String...) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        for button in buttonsTexts{
            alert.addAction(UIAlertAction(title: button, style: UIAlertAction.Style.default, handler: nil))
        }
        print(message, title)
        view.present(alert, animated: true, completion: nil)
    }
    
    static func show(view: UIViewController, message: String, title: String, buttons: UIAlertAction...) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        for button in buttons{
            alert.addAction(button)
        }
        print(message, title)
        view.present(alert, animated: true, completion: nil)
    }
    
    static func show(view: UIViewController, message: String, title: String, style: UIAlertController.Style, buttons: UIAlertAction...) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        for button in buttons{
            alert.addAction(button)
        }
        print(message, title)
        view.present(alert, animated: true, completion: nil)
    }
}
