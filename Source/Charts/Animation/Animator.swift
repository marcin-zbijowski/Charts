//
//  Animator.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif

@objc(ChartAnimatorDelegate)
public protocol AnimatorDelegate
{
    /// Called when the Animator has stepped.
    func animatorUpdated(_ animator: Animator)
    
    /// Called when the Animator has stopped.
    func animatorStopped(_ animator: Animator)
}

@objc(ChartAnimator)
open class Animator: NSObject
{
    public enum Dimension: Int {
        case x, y, h
    }

    public struct State
    {
        var phase:      Double       = 1.0
        var duration:   TimeInterval = 0.0
        var startTime:  TimeInterval = 0.0
        var endTime:    TimeInterval = 0.0
        var enabled:    Bool         = false
        var easing:     ChartEasingFunctionBlock?

        mutating func updatePhase(currentTime: TimeInterval) {
            var elapsed = currentTime - startTime
            if elapsed > duration
            {
                elapsed = duration
            }
            self.phase = easing?(elapsed, duration) ?? Double(elapsed / duration)
        }
    }

    fileprivate var animatedDimensions: [Dimension: State] = [:]

    open weak var delegate: AnimatorDelegate?
    open var updateBlock: (() -> Void)?
    open var stopBlock: (() -> Void)?
    
    /// the phase that is animated and influences the drawn values on the x-axis
    open var phaseX: Double {
        return animatedDimensions[.x]?.phase ?? 1.0
    }

    /// the phase that is animated and influences the drawn values on the y-axis
    open var phaseY: Double {
        return animatedDimensions[.y]?.phase ?? 1.0
    }
    
    fileprivate var _displayLink: NSUIDisplayLink?

    fileprivate var _endTime: TimeInterval {
        return animatedDimensions.reduce(0) { (m, animation) -> TimeInterval in
            return max(m, animation.1.endTime)
        }
    }
    
    public override init()
    {
        super.init()
    }
    
    deinit
    {
        stop()
    }
    
    open func stop()
    {
        if _displayLink != nil
        {
            _displayLink?.remove(from: RunLoop.main, forMode: RunLoopMode.commonModes)
            _displayLink = nil
            
            disableAllAnimations()

            // If we stopped an animation in the middle, we do not want to leave it like this
            if hasUnfinishedAnimations()
            {
                finishAllAnimations()

                if (delegate != nil)
                {
                    delegate!.animatorUpdated(self)
                }
                if (updateBlock != nil)
                {
                    updateBlock!()
                }
            }

            if delegate != nil
            {
                delegate!.animatorStopped(self)
            }
            if stopBlock != nil
            {
                stopBlock?()
            }
        }
    }

    open func phase(dimension: Dimension) -> Double {
        return animatedDimensions[dimension]?.phase ?? 1.0
    }

    fileprivate func hasUnfinishedAnimations() -> Bool {
        return animatedDimensions.reduce(false) { (has, animation) -> Bool in
            return has || animation.1.phase != 1.0
        }
    }

    fileprivate func hasEnabledAnimations() -> Bool {
        return animatedDimensions.reduce(true, { (has, animation) -> Bool in
            return has || animation.1.enabled
        })
    }

    fileprivate func disableAllAnimations() {
        for (dim, _) in animatedDimensions {
            animatedDimensions[dim]?.enabled = false
        }
    }

    fileprivate func finishAllAnimations() {
        for (dim, _) in animatedDimensions {
            animatedDimensions[dim]?.enabled = false
            animatedDimensions[dim]?.phase = 1.0
        }
    }

    
    fileprivate func updateAnimationPhases(_ currentTime: TimeInterval)
    {
        for (dim, _) in animatedDimensions {
            guard let enabled = animatedDimensions[dim]?.enabled , enabled else { continue }
            var elapsed = currentTime - animatedDimensions[dim]!.startTime
            if elapsed > animatedDimensions[dim]!.duration
            {
                elapsed = animatedDimensions[dim]!.duration
            }
            animatedDimensions[dim]!.updatePhase(currentTime: currentTime)
        }
    }
    
    @objc fileprivate func animationLoop()
    {
        let currentTime: TimeInterval = CACurrentMediaTime()
        
        updateAnimationPhases(currentTime)
        
        if delegate != nil
        {
            delegate!.animatorUpdated(self)
        }
        if updateBlock != nil
        {
            updateBlock!()
        }
        
        if currentTime >= _endTime
        {
            stop()
        }
    }

    open func animate(dimension: Dimension, duration: TimeInterval, easing: ChartEasingFunctionBlock?) {
        let startTime = CACurrentMediaTime()
        let endTime = startTime + duration

        let animation = State(phase: 0.0, duration: duration, startTime: startTime, endTime: endTime, enabled: duration > 0.0, easing: easing)

        animatedDimensions[dimension] = animation

        // Take care of the first frame if rendering is already scheduled...
        updateAnimationPhases(startTime)

        if hasEnabledAnimations()
        {
            if _displayLink == nil
            {
                _displayLink = NSUIDisplayLink(target: self, selector: #selector(animationLoop))
                _displayLink?.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
            }
        }
    }

    open func animate(dimension: Dimension, duration: TimeInterval, easingOption: ChartEasingOption) {
        animate(dimension: dimension, duration: duration, easing: easingFunctionFromOption(easingOption))
    }

    open func animate(dimension: Dimension, duration: TimeInterval) {
        animate(dimension: dimension, duration: duration, easingOption: .easeInOutSine)
    }

    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingX: an easing function for the animation on the x axis
    /// - parameter easingY: an easing function for the animation on the y axis
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easingX: ChartEasingFunctionBlock?, easingY: ChartEasingFunctionBlock?)
    {
        stop()
        
        animate(dimension: .x, duration: xAxisDuration, easing: easingX)
        animate(dimension: .y, duration: yAxisDuration, easing: easingY)
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingOptionX: the easing function for the animation on the x axis
    /// - parameter easingOptionY: the easing function for the animation on the y axis
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easingOptionX: ChartEasingOption, easingOptionY: ChartEasingOption)
    {
        animate(dimension: .x, duration: xAxisDuration, easing: easingFunctionFromOption(easingOptionX))
        animate(dimension: .y, duration: yAxisDuration, easing: easingFunctionFromOption(easingOptionY))
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easing: an easing function for the animation
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easing: ChartEasingFunctionBlock?)
    {
        animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration, easingX: easing, easingY: easing)
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingOption: the easing function for the animation
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval, easingOption: ChartEasingOption)
    {
        animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration, easing: easingFunctionFromOption(easingOption))
    }
    
    /// Animates the drawing / rendering of the chart on both x- and y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter yAxisDuration: duration for animating the y axis
    open func animate(xAxisDuration: TimeInterval, yAxisDuration: TimeInterval)
    {
        animate(xAxisDuration: xAxisDuration, yAxisDuration: yAxisDuration, easingOption: .easeInOutSine)
    }
    
    /// Animates the drawing / rendering of the chart the x-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter easing: an easing function for the animation
    open func animate(xAxisDuration: TimeInterval, easing: ChartEasingFunctionBlock?)
    {
        animate(dimension: .x, duration: xAxisDuration, easing: easing)
    }
    
    /// Animates the drawing / rendering of the chart the x-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    /// - parameter easingOption: the easing function for the animation
    open func animate(xAxisDuration: TimeInterval, easingOption: ChartEasingOption)
    {
        animate(xAxisDuration: xAxisDuration, easing: easingFunctionFromOption(easingOption))
    }
    
    /// Animates the drawing / rendering of the chart the x-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter xAxisDuration: duration for animating the x axis
    open func animate(xAxisDuration: TimeInterval)
    {
        animate(xAxisDuration: xAxisDuration, easingOption: .easeInOutSine)
    }
    
    /// Animates the drawing / rendering of the chart the y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easing: an easing function for the animation
    open func animate(yAxisDuration: TimeInterval, easing: ChartEasingFunctionBlock?)
    {
        animate(dimension: .y, duration: yAxisDuration, easing: easing)
    }
    
    /// Animates the drawing / rendering of the chart the y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter yAxisDuration: duration for animating the y axis
    /// - parameter easingOption: the easing function for the animation
    open func animate(yAxisDuration: TimeInterval, easingOption: ChartEasingOption)
    {
        animate(yAxisDuration: yAxisDuration, easing: easingFunctionFromOption(easingOption))
    }
    
    /// Animates the drawing / rendering of the chart the y-axis with the specified animation time.
    /// If `animate(...)` is called, no further calling of `invalidate()` is necessary to refresh the chart.
    /// - parameter yAxisDuration: duration for animating the y axis
    open func animate(yAxisDuration: TimeInterval)
    {
        animate(yAxisDuration: yAxisDuration, easingOption: .easeInOutSine)
    }
}
