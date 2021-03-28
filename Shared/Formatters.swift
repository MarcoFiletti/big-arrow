//
//  Formatters.swift
//  Big Arrow
//
//  Created by Marco Filetti on 18/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import Foundation

class Formatters {
    
    // MARK: - Measurement formatters
    
    /// Two significant digits max
    static private(set) var medFormatter = MeasurementFormatter()

    /// Four significant digits max
    static private(set) var precFormatter = MeasurementFormatter()
    
    /// No fractional digits
    static private(set) var wholeFormatter = MeasurementFormatter()
    
    /// One fractional digit
    static private(set) var oneFormatter = MeasurementFormatter()
    
    /// Two fractional digits
    static private(set) var twoFormatter = MeasurementFormatter()
    
    // MARK: - Date Formatters
    
    /// TimeInterval formatter (2 min, 15 secs)
    static let shortTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        return formatter
    }()
    
    /// TimeInterval formatter (2min 15sec)
    static let briefTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .brief
        formatter.maximumUnitCount = 2
        return formatter
    }()
    
    /// Time interval formatter (2m 15s)
    static let abbrTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()
    
    // MARK: - Functions
    
    /// Updates the formatters locale based on the metric system preference
    static func updateFormatters() {
        medFormatter = makeMeasurementFormatter(minDigits: 0, maxDigits: 2, usesSignificant: true)
        precFormatter = makeMeasurementFormatter(minDigits: 0, maxDigits: 4, usesSignificant: true)
        wholeFormatter = makeMeasurementFormatter(minDigits: 0, maxDigits: 0, usesSignificant: false)
        oneFormatter = makeMeasurementFormatter(minDigits: 1, maxDigits: 1, usesSignificant: false)
        twoFormatter = makeMeasurementFormatter(minDigits: 2, maxDigits: 2, usesSignificant: false)
    }

    /// Formats using two significant digits.
    static func format(accuracy: Double) -> String {
        let m = Measurement(value: accuracy, unit: UnitLength.meters)
        return medFormatter.string(from: m)
    }
    
    /// Formats using:
    /// no decimal digits unless
    /// if ≥ 1 km or miles, 2 decimals
    /// if ≥ 10 km or miles but less than 100, 1 decimal
    static func format(distance: Double, splitAtFive: Bool = false) -> String {
        let fuzzyDist = FuzzyDistance(fromMetres: distance)
        let m = Measurement(value: distance, unit: UnitLength.meters)
        switch fuzzyDist {
        case .tenkilometric:
            return oneFormatter.string(from: m)
        case .kilometric, .fivekilometric:
            if splitAtFive && fuzzyDist == .fivekilometric {
                return oneFormatter.string(from: m)
            } else {
                return twoFormatter.string(from: m)
            }
        case .unimetric, .hundredkilometric:
            return wholeFormatter.string(from: m)
        }
    }
    
    /// Formats using two decimal points below 10 km/h or 10 mph
    /// or no decimal points above that
    static func format(speed: Double) -> String {
        let m = Measurement(value: speed, unit: UnitSpeed.metersPerSecond)
        if speed < 0 {
            return "-"
        } else {
            if LocationMaster.usesMetric {
                if speed >= 25/9 {
                    return wholeFormatter.string(from: m)
                } else {
                    return twoFormatter.string(from: m)
                }
            } else {
                if speed >= 4.4704 {
                    return wholeFormatter.string(from: m)
                } else {
                    return twoFormatter.string(from: m)
                }
            }
        }
    }
    
    /// Formats time briefly
    static func format(briefTime: TimeInterval) -> String {
        return briefTimeFormatter.string(from: briefTime)!
    }
    
    /// Formats time shortly
    static func format(shortTime: TimeInterval) -> String {
        return shortTimeFormatter.string(from: shortTime)!
    }

    /// Formats time abbreviated
    static func format(abbreviatedTime: TimeInterval) -> String {
        return abbrTimeFormatter.string(from: abbreviatedTime)!
    }
    
    /// Helper formatter creator
    private static func makeMeasurementFormatter(minDigits: Int, maxDigits: Int, usesSignificant: Bool) -> MeasurementFormatter {
        let mf = MeasurementFormatter()
        mf.unitOptions = .naturalScale
        if Options.Measurements.saved != .automatic {
            let customLocale: Locale
            switch Options.Measurements.saved {
            case .metricWithComma:
                customLocale = Locale(identifier: "it_IT")
            case .metricWithDot:
                customLocale = Locale(identifier: "en_AU")
            case .imperial:
                customLocale = Locale(identifier: "en_US")
            case .automatic:
                preconditionFailure("Impossible to get here")
            }
            mf.locale = customLocale
            mf.numberFormatter.locale = customLocale
        }
        mf.numberFormatter.usesSignificantDigits = usesSignificant
        if usesSignificant {
            mf.numberFormatter.minimumSignificantDigits = minDigits
            mf.numberFormatter.maximumSignificantDigits = maxDigits
        } else {
            mf.numberFormatter.minimumFractionDigits = minDigits
            mf.numberFormatter.maximumFractionDigits = maxDigits
        }
        return mf
    }
}

