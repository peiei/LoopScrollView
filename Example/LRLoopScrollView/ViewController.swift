//
//  ViewController.swift
//  LRLoopScrollView
//
//  Created by Ainiei on 2019/4/17.
//  Copyright © 2019 LR. All rights reserved.
//

import UIKit
import LRLoopScrollView


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        var urls = [String]()
        (1...4).forEach { name in
            let path = Bundle.main.url(forResource: name.description, withExtension: "jpg")!
            urls.append(path.absoluteString)
        }
        
        let scrollView = CycleScrollBannerView.init(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 100))
        scrollView.service = CycleScrollBannerService.init(urlArr: urls)
        
        self.view.addSubview(scrollView)
        
        scrollView.itemSelected.subscribe { (model) in
            print(model)
        }.disposed(by: scrollView.disposeBag)
        
        scrollView.center = view.center
    }


}

