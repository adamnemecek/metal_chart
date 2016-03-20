//
//  ViewController.swift
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/03.
//  Copyright © 2015年 freaks. All rights reserved.
//

import UIKit
import Metal
import FMChartSupport
import HealthKit

class ViewController: UIViewController {

	@IBOutlet var metalView: MetalView!
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    @IBOutlet var pinchRecognizer: UIPinchGestureRecognizer!
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    
	var chart : MetalChart = MetalChart()
	var chartConf : FMConfigurator? = nil
	let resource : FMDeviceResource = FMDeviceResource.defaultResource()!
    let animator : FMAnimator = FMAnimator()
	let store : HKHealthStore = HKHealthStore()
	var interpreter : FMGestureInterpreter? = nil
	var refDate : NSDate? = nil
	
	let seriesCapacity : UInt = 512
	var stepSeries : FMOrderedSeries? = nil
	var weightSeries : FMOrderedSeries? = nil
	var systolicSeries : FMOrderedSeries? = nil
	var diastolicSeries : FMOrderedSeries? = nil
	
	var stepBar : FMBarSeries? = nil
	var weightLine : FMLineSeries? = nil
	var systolicLine : FMLineSeries? = nil
	var diastolicLine : FMLineSeries? = nil
	
	var stepUpdater : FMProjectionUpdater? = nil;
	var weightUpdater : FMProjectionUpdater? = nil;
	var pressureUpdater : FMProjectionUpdater? = nil;
	
	override func viewDidLoad() {
		super.viewDidLoad()
        metalView.device = resource.device
        metalView.sampleCount = 1
        let v : Double = 0.9
        let alpha : Double = 1
        metalView.clearColor = MTLClearColorMake(v,v,v,alpha)
        metalView.addGestureRecognizer(tapRecognizer)
		
		setupChart()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		loadData()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func setupChart() {
		let engine = FMEngine(resource: resource)
		let fps = 0;
		let configurator : FMConfigurator = FMConfigurator(chart:chart, engine:engine, view:metalView, preferredFps: fps)
		chartConf = configurator
		chart.padding = RectPadding(left: 30, top: 30, right: 30, bottom: 30)
		chart.bufferHook = animator
		
		configurator.addPlotAreaWithColor(UIColor.whiteColor()).attributes.setCornerRadius(5)
        
		let restriction = FMDefaultInterpreterRestriction(scaleMin: CGSize(width: 1,height: 1), max: CGSize(width: 10,height: 1), translationMin: CGPoint(x: -0.5,y: -0), max: CGPoint(x: 48,y: 0))
		let interpreter = configurator.addInterpreterToPanRecognizer(panRecognizer, pinchRecognizer: pinchRecognizer, stateRestriction: restriction)
		self.interpreter = interpreter
		
		stepSeries = configurator.createSeries(seriesCapacity)
		weightSeries = configurator.createSeries(seriesCapacity)
		systolicSeries = configurator.createSeries(seriesCapacity)
		diastolicSeries = configurator.createSeries(seriesCapacity)
		
		let dateDim = 1
		let stepDim = 2
		let weightDim = 3
		let pressureDim = 4
		
		let dateUpdator = FMProjectionUpdater()
		let daySec : CGFloat = 24 * 60 * 60
		dateUpdator.addRestrictionToLast(FMSourceRestriction(minValue: -7 * daySec, maxValue: daySec, expandMin: true, expandMax: true))
		
		stepUpdater = FMProjectionUpdater()
		stepUpdater?.addRestrictionToLast(FMSourceRestriction(minValue: 0, maxValue: 2000, expandMin: true, expandMax: true))
		stepUpdater?.addRestrictionToLast(FMIntervalRestriction(anchor: 0, interval: 1000, shrinkMin: false, shrinkMax: false))
		
		weightUpdater = FMProjectionUpdater()
		weightUpdater?.addRestrictionToLast(FMSourceRestriction(minValue: 50, maxValue: 60, expandMin: false, expandMax: false))
		weightUpdater?.addRestrictionToLast(FMIntervalRestriction(anchor: 0, interval: 5, shrinkMin: false, shrinkMax: false))
		
		pressureUpdater = FMProjectionUpdater()
		pressureUpdater?.addRestrictionToLast(FMSourceRestriction(minValue: 60, maxValue: 120, expandMin: false, expandMax: false))
		pressureUpdater?.addRestrictionToLast(FMIntervalRestriction(anchor: 0, interval: 5, shrinkMin: false, shrinkMax: false))
 		
		let stepSpace : FMProjectionCartesian2D = configurator.spaceWithDimensionIds([dateDim,stepDim]) { (dimId) -> FMProjectionUpdater? in
			if(dimId == dateDim) {
				return dateUpdator
			}
			return self.stepUpdater
		}
		
		let weightSpace : FMProjectionCartesian2D = configurator.spaceWithDimensionIds([dateDim, weightDim]) { (dimId) -> FMProjectionUpdater? in
			return self.weightUpdater
		}
		
		let pressureSpace : FMProjectionCartesian2D = configurator.spaceWithDimensionIds([dateDim, pressureDim]) { (dimId) -> FMProjectionUpdater? in
			return self.pressureUpdater
		}
		
		stepBar = configurator.addBarToSpace(stepSpace, series: stepSeries!)
		weightLine = configurator.addLineToSpace(weightSpace, series: weightSeries!)
		systolicLine = configurator.addLineToSpace(pressureSpace, series: systolicSeries!)
		diastolicLine = configurator.addLineToSpace(pressureSpace, series: diastolicSeries!)
		
		stepBar?.attributes.setBarWidth(20)
		stepBar?.attributes.setCornerRadius(5, rt: 5, lb: 0, rb: 0)
		weightLine?.attributes.setWidth(5)
		weightLine?.attributes.enableOverlay = true
		systolicLine?.attributes.setColor(UIColor.redColor().colorWithAlphaComponent(0.3).vector())
		diastolicLine?.attributes.setColor(UIColor.greenColor().colorWithAlphaComponent(0.3).vector())
		
		let dateConf = FMBlockAxisConfigurator(relativePosition: 0, tickAnchor: 0, fixedInterval: daySec, minorTicksFreq: 0)
		let dateSize = CGSizeMake(30, 15)
		let dateFmt = NSDateFormatter()
		dateFmt.dateFormat = "M/d"
		let axis = configurator.addAxisToDimensionWithId(dateDim, belowSeries:false, configurator:dateConf, labelFrameSize: dateSize, labelBufferCount: 12) {
			(val, index, lastIndex, projection) -> [NSMutableAttributedString] in
			let date = NSDate(timeInterval: NSTimeInterval(val), sinceDate: self.refDate!)
			let str = dateFmt.stringFromDate(date)
			return [NSMutableAttributedString(string: str)]
		}
		let label = configurator.axisLabelsToAxis(axis!)!.first!
		label.setFont(UIFont.systemFontOfSize(9, weight: UIFontWeightThin))
		label.setFrameOffset(CGPointMake(0, 5))
		
		configurator.connectSpace([stepSpace, weightSpace, pressureSpace], toInterpreter: interpreter)
	}
	
	func loadData() {
		stepSeries?.info.clear()
		weightSeries?.info.clear()
		systolicSeries?.info.clear()
		diastolicSeries?.info.clear()
		
		stepUpdater?.clearSourceValues(false)
		weightUpdater?.clearSourceValues(false)
		pressureUpdater?.clearSourceValues(false)
		
		let refDate : NSDate = getStartOfDate(NSDate())
		self.refDate = refDate
		let interval : NSDateComponents = NSDateComponents()
		interval.day = 1
		let step = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)!
		let weight = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!
		let systolic = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodPressureSystolic)!
		let diastolic = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodPressureDiastolic)!
		
		let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
		
		let stepQuery = HKStatisticsCollectionQuery(quantityType: step, quantitySamplePredicate: nil, options: HKStatisticsOptions.CumulativeSum, anchorDate: refDate, intervalComponents: interval)
		stepQuery.initialResultsHandler = { query, results, eror in
			if let collection = results {
				for statistic in collection.statistics() {
					if let quantity = statistic.sumQuantity() {
						let value = quantity.doubleValueForUnit(HKUnit.countUnit())
						self.stepSeries?.addPoint(CGPointMake(CGFloat(statistic.startDate.timeIntervalSinceDate(refDate)), CGFloat(value)))
						self.stepUpdater?.addSourceValue(CGFloat(value), update: false)
					}
				}
				self.stepUpdater?.updateTarget()
				self.metalView.setNeedsDisplay()
			}
		}
		
		let kg = HKUnit.gramUnitWithMetricPrefix(HKMetricPrefix.Kilo)
		let weightQuery = HKSampleQuery(sampleType:weight, predicate: nil, limit: Int(seriesCapacity), sortDescriptors: [sort]) { (query, samples, error) -> Void in
			if let array = samples {
				for sample in (array as! [HKQuantitySample]) {
					let x = CGFloat(sample.startDate.timeIntervalSinceDate(refDate))
					let val = sample.quantity.doubleValueForUnit(kg)
					self.weightSeries?.addPoint(CGPointMake(x, CGFloat(val)))
					self.weightUpdater?.addSourceValue(CGFloat(val), update: false)
				}
				self.weightUpdater?.updateTarget()
				self.metalView.setNeedsDisplay()
			}
		}
		let mmHg = HKUnit.millimeterOfMercuryUnit()
		let systolicQuery = HKSampleQuery(sampleType:systolic, predicate: nil, limit: Int(seriesCapacity), sortDescriptors: [sort]) { (query, samples, error) -> Void in
			if let array = samples {
				for sample in (array as! [HKQuantitySample]) {
					let x = CGFloat(sample.startDate.timeIntervalSinceDate(refDate))
					let val = sample.quantity.doubleValueForUnit(mmHg)
					self.systolicSeries?.addPoint(CGPointMake(x, CGFloat(val)))
					self.pressureUpdater?.addSourceValue(CGFloat(val), update: false)
				}
				self.pressureUpdater?.updateTarget()
				self.metalView.setNeedsDisplay()
			}
		}
		let diastolicQuery = HKSampleQuery(sampleType:diastolic, predicate: nil, limit: Int(seriesCapacity), sortDescriptors: [sort]) { (query, samples, error) -> Void in
			if let array = samples {
				for sample in (array as! [HKQuantitySample]) {
					let x = CGFloat(sample.startDate.timeIntervalSinceDate(refDate))
					let val = sample.quantity.doubleValueForUnit(mmHg)
					self.diastolicSeries?.addPoint(CGPointMake(x, CGFloat(val)))
					self.pressureUpdater?.addSourceValue(CGFloat(val), update: false)
				}
				self.pressureUpdater?.updateTarget()
				self.metalView.setNeedsDisplay()
			}
		}
		store.executeQuery(stepQuery)
		store.executeQuery(weightQuery)
		store.executeQuery(systolicQuery)
		store.executeQuery(diastolicQuery)
	}
	
	let calendar : NSCalendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
	func getStartOfDate(date : NSDate) -> NSDate {
		let comp : NSDateComponents = calendar.components([.Year, .Month, .Day], fromDate: date)
		return calendar.dateFromComponents(comp)!
	}
    
    @IBAction func chartTapped(sender: UITapGestureRecognizer) {
//        let anim = FMBlockAnimation(duration: 0.5, delay: 0.1) { (progress) in
//            let alpha : CFloat = CFloat( 2 * fabs(0.5 - progress) )
//        }
//        animator.addAnimation(anim)
    }
    
}
