//
//  Big_ArrowTests.swift
//  Big ArrowTests
//
//  Created by Marco Filetti on 29/11/2018.
//  Copyright © 2018 Marco Filetti. All rights reserved.
//

import XCTest
@testable import Big_Arrow

class Big_ArrowTests: XCTestCase {

    override func setUp() {
        self.continueAfterFailure = true
        // Put setup code here. This method is called before the invocation of each test method in the class.
        count = 0
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCourseToCompass() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        // starting at -5.625 (-22.5 / 4), N, adding 5.625 4 times
        // should push us up a step
        
        let compassVals: [Double: String] = [ 355:"N",
            360:"N",
            0:"N",
            5:"N",
            338:"N",
            180:"S",
            200:"S",
            160:"S",
            270:"W",
            272:"W",
            268:"W",
            90:"E",
            70:"E",
            100:"E",
            293:"NW",
            315:"NW",
            336:"NW",
            225:"SW",
            205:"SW",
            240:"SW",
            135:"SE",
            130:"SE",
            150:"SE",
            45:"NE",
            25:"NE",
            65:"NE"
        ]
        for item in compassVals {
            let computed = angleToCompass(item.key)
            XCTAssert(item.value == computed, "\(computed) should be \(item.value) for \(item.key)")
        }
    }
    
    var count = 0
    
    func testWeightedAverageTwoSamples() {
        var buff = RunningBuffer(size: 2)
        XCTAssertNil(buff.weightedMean())
        buff.addSample(10)
        buff.addSample(10)
        expectWeighted(buff, 10) // 0
        buff.addSample(350)
        expectWeighted(buff, 0) // 1
        buff.addSample(30)
        expectWeighted(buff, 10) // 2
        buff.addSample(180)
        buff.addSample(360)
        expectWeighted(buff, -90) // 3
        buff.addSample(90)
        buff.addSample(-90)
        expectWeighted(buff, 0) // 4
        buff.addSample(-90)
        buff.addSample(270)
        expectWeighted(buff, -90) // 5
        buff.addSample(-190)
        buff.addSample(190)
        expectWeighted(buff, 180) // 6
        buff.addSample(0)
        buff.addSample(180)
        expectWeighted(buff, 90) // 7
    }
    
    func testDistanceFormatter() {
        let prevOption = Options.Measurements.saved
        
        Options.Measurements.metricWithComma.save()
        distanceHelper(500, "500 m")
        distanceHelper(250, "250 m")
        distanceHelper(6100, "6,10 km")
        distanceHelper(12500, "12,5 km")
        
        Options.Measurements.metricWithDot.save()
        distanceHelper(500, "500 m")
        distanceHelper(250, "250 m")
        distanceHelper(6100, "6.10 km")
        distanceHelper(12500, "12.5 km")
        
        Options.Measurements.imperial.save()
        distanceHelper(274.33, "300 yd")
        distanceHelper(1609, "1.00 mi")
        distanceHelper(457.2, "500 yd")
        distanceHelper(48280.3, "30.0 mi")

        prevOption.save()
    }
    
    private func distanceHelper(_ distance: Double, _ expected: String) {
        let string = Formatters.format(distance: distance)
        XCTAssert(string == expected, "Expected '\(expected)' but got '\(string)'")
    }
    
    func testWeightedAverageThreeSamples() {
        var buff = RunningBuffer(size: 3)
        XCTAssertNil(buff.weightedMean())
        buff.addSample(10)
        buff.addSample(10)
        buff.addSample(10)
        expectWeighted(buff, 10) // 0
        buff.addSample(0)
        buff.addSample(180)
        buff.addSample(90)
        expectWeighted(buff, 90) // 1
        buff.addSample(360)
        buff.addSample(180)
        buff.addSample(90)
        expectWeighted(buff, 90) // 2
        buff.addSample(360)
        buff.addSample(180)
        buff.addSample(90)
        expectWeighted(buff, 90) // 3
        buff.addSample(315)
        buff.addSample(135)
        buff.addSample(45)
        expectWeighted(buff, 45) // 4
        buff.addSample(247.5)
        buff.addSample(69)
        buff.addSample(90)
        expectWeighted(buff, 91) // 5
        buff.addSample(260)
        buff.addSample(150)
        buff.addSample(180)
        expectWeighted(buff, -167) // 6
    }
    
    func expectWeighted(_ buffer: RunningBuffer, _ expected: Int) {
        guard let wm = buffer.angleMean() else {
            XCTFail("Test \(count): Buffer wm is nil")
            return
        }
        let rounded = Int(wm.rounded())
        XCTAssert(rounded == expected, "Test \(count): Buffer should be \(expected) but is \(rounded)")
        count += 1
    }

}
