//
//  MycoLabWidgetBundle.swift
//  MycoLabWidget
//
//  Created for MycoLab on 03/11/2026.
//

import WidgetKit
import SwiftUI

@main
struct MycoLabWidgetBundle: WidgetBundle {
    var body: some Widget {
        MycoLabClimateWidget()
        MycoLiveActivityWidget()
    }
}
