//
//  HourlyXAxisRenderer.swift
//  ZeroPark
//
//  Created by Marcin Zbijowski on 15/12/2017.
//  Copyright © 2017 CodeWise sp. z o.o. Sp. k. All rights reserved.
//

import UIKit
import Charts

@objc(HourlyXAxisRenderer)
open class HourlyXAxisRenderer: XAxisRenderer {

    private class func roundToNextSignificant(number: Double) -> Double
    {
        if number.isInfinite || number.isNaN || number == 0
        {
            return number
        }

        let d = ceil(log10(number < 0.0 ? -number : number))
        let pw = 1 - Int(d)
        let magnitude = pow(Double(10.0), Double(pw))
        let shifted = round(number * magnitude)
        return shifted / magnitude
    }

    private class func nextUp(_ number: Double) -> Double
    {
        if number.isInfinite || number.isNaN
        {
            return number
        }
        else
        {
            return number + Double.ulpOfOne
        }
    }

    /// Sets up the axis values. Computes the desired number of labels between the two given extremes.
    @objc open override func computeAxisValues(min: Double, max: Double)
    {
        guard let axis = self.axis else { return }
        let yMin = min
        let yMax = max

        let labelCount = axis.labelCount
        let range = abs(yMax - yMin)

        if labelCount == 0 || range <= 0 || range.isInfinite
        {
            axis.entries = [Double]()
            axis.centeredEntries = [Double]()
            return
        }

        // Find out how much spacing (in y value space) between axis values
        let rawInterval = range / Double(labelCount)
        var interval = round(rawInterval / 3600) * 3600

        // If granularity is enabled, then do not allow the interval to go below specified granularity.
        // This is used to avoid repeated values when rounding values for display.
        if axis.granularityEnabled
        {
            interval = interval < axis.granularity ? axis.granularity : interval
        }

        // Normalize interval
        let intervalMagnitude = HourlyXAxisRenderer.roundToNextSignificant(number: pow(10.0, Double(Int(log10(interval)))))
        let intervalSigDigit = Int(interval / intervalMagnitude)
        if intervalSigDigit > 5
        {
            // Use one order of magnitude higher, to avoid intervals like 0.9 or 90
            interval = floor(10.0 * Double(intervalMagnitude))
        }

        var n = axis.centerAxisLabelsEnabled ? 1 : 0

        // force label count
        if axis.isForceLabelsEnabled
        {
            interval = Double(range) / Double(labelCount - 1)

            // Ensure stops contains at least n elements.
            axis.entries.removeAll(keepingCapacity: true)
            axis.entries.reserveCapacity(labelCount)

            var v = yMin
            for _ in 0 ..< labelCount
            {
                axis.entries.append(v)
                v += interval
            }

            n = labelCount
        }
        else
        {
            // no forced count

            var first = interval == 0.0 ? 0.0 : ceil((yMin) / interval) * interval
            if axis.centerAxisLabelsEnabled
            {
                first -= interval
            }

            let last = interval == 0.0 ? 0.0 : HourlyXAxisRenderer.nextUp(floor(yMax / interval) * interval)
            if interval != 0.0 && last != first
            {
                for _ in stride(from: first, through: last, by: interval)
                {
                    n += 1
                }
            }

            // Ensure stops contains at least n elements.
            axis.entries.removeAll(keepingCapacity: true)
            axis.entries.reserveCapacity(labelCount)

            var f = first
            var i = 0
            while i < n
            {
                if f == 0.0
                {
                    // Fix for IEEE negative zero case (Where value == -0.0, and 0.0 == -0.0)
                    f = 0.0
                }

                axis.entries.append(Double(f))

                f += interval
                i += 1
            }
        }

        // set decimals
        if interval < 1
        {
            axis.decimals = Int(ceil(-log10(interval)))
        }
        else
        {
            axis.decimals = 0
        }

        if axis.centerAxisLabelsEnabled
        {
            axis.centeredEntries.reserveCapacity(n)
            axis.centeredEntries.removeAll()

            let offset: Double = interval / 2.0

            for i in 0 ..< n
            {
                axis.centeredEntries.append(axis.entries[i] + offset)
            }
        }
    }


}
