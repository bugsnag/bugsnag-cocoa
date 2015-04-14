//
//  ViewController.swift
//  bugsnag-example
//
//  Created by Isaac Waller on 4/2/15.
//  Copyright (c) 2015 Isaac Waller. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        AnotherClass().crash()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

