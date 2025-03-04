//
//  ModelExports.swift
//  SpeechPOC
//
//  Created automatically
//

import Foundation
import SwiftUI

// This file provides common model types and configurations

// GradientConfiguration for tag display
struct GradientConfiguration {
    var startColor: Color
    var endColor: Color
    var direction: Direction
    
    enum Direction {
        case horizontal
        case vertical
        case diagonal
    }
    
    static let defaultConfig = GradientConfiguration(
        startColor: Color.blue,
        endColor: Color.purple,
        direction: .horizontal
    )
} 