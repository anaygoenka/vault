//
//  Retention.swift
//  Vault
//
//  How long unpinned clips are kept. Pinned clips are kept forever.
//

import Foundation

enum Retention: String, CaseIterable, Identifiable, Codable {
    case hour, day, week, month, threeMonths, year, forever

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hour:        "1 Hour"
        case .day:         "1 Day"
        case .week:        "1 Week"
        case .month:       "1 Month"
        case .threeMonths: "3 Months"
        case .year:        "1 Year"
        case .forever:     "Forever"
        }
    }

    var shortLabel: String {
        switch self {
        case .hour:        "1h"
        case .day:         "1d"
        case .week:        "1w"
        case .month:       "1m"
        case .threeMonths: "3m"
        case .year:        "1y"
        case .forever:     "∞"
        }
    }

    var interval: TimeInterval? {
        let day: TimeInterval = 86_400
        switch self {
        case .hour:        return 3_600
        case .day:         return day
        case .week:        return day * 7
        case .month:       return day * 30
        case .threeMonths: return day * 91
        case .year:        return day * 365
        case .forever:     return nil
        }
    }

    /// Anything copied before this date is due to go.
    func cutoff(from now: Date = .now) -> Date? {
        interval.map { now.addingTimeInterval(-$0) }
    }
}
