//
//  Enum.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/19/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

enum RoomPosition: Int {
    case Arena = 0
    case StandA
    case StandB
    case StandC
    case StandD
    case StandE
    case StandF
    case StandG
    
    func label() -> String {
        switch self {
        case .Arena:
            return "アリーナ"
        case .StandA:
            return "立ち見A"
        case .StandB:
            return "立ち見B"
        case .StandC:
            return "立ち見C"
        case .StandD:
            return "立ち見D"
        case .StandE:
            return "立ち見E"
        case .StandF:
            return "立ち見F"
        case .StandG:
            return "立ち見G"
        }
    }
    
    func shortLabel() -> String {
        switch self {
        case .Arena:
            return "ア"
        case .StandA:
            return "A"
        case .StandB:
            return "B"
        case .StandC:
            return "C"
        case .StandD:
            return "D"
        case .StandE:
            return "E"
        case .StandF:
            return "F"
        case .StandG:
            return "G"
        }
    }
}

