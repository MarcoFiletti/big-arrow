//
//  Big_ArrowUITests.swift
//  Big ArrowUITests
//
//  Created by Marco Filetti on 11/06/2018.
//  Copyright © 2018 Marco Filetti. All rights reserved.
//

import XCTest

class Big_ArrowUITests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAddAndDeleteDestinationPortrait() {
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        let app = XCUIApplication()
        let navbar = app.navigationBars["Big Arrow"]
        
        navbar.buttons["Add new destination"].tap()
        
        let searchText = "TestZero"
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText(searchText)
        
        let table = app.tables.firstMatch
        table.otherElements.element(boundBy: 0).tap()
        
        let nameField = app.textFields.element(matching: .any, identifier: "Name Field")
        XCTAssertEqual(searchText, nameField.value as? String, "Text field should match search")
        let insertButton = app.buttons["Add"].exists ? app.buttons["Add"] : app.buttons["Replace"]
        XCTAssert(insertButton.isEnabled, "We should be able to add a destination now")
        insertButton.tap()

        app.navigationBars["Master"].buttons["Big Arrow"].tap()
        
        deleteNewDestination(named: searchText)
        
    }
    
    func testAddAndDeleteDestinationLandscape() {
        XCUIDevice.shared.orientation = .landscapeRight
        sleep(1)
        let app = XCUIApplication()
        let navbar = app.navigationBars["Big Arrow"]
        navbar.buttons["Add new destination"].tap()
        app.maps.firstMatch.swipeDown()
        let destName = "TestXX"
        sleep(1)
        let nameField = app.textFields.element(matching: .any, identifier: "Name Field")
        nameField.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: (nameField.value as! String).count)
        nameField.typeText(deleteString)
        nameField.typeText(destName)
        let insertButton = app.buttons["Add"].exists ? app.buttons["Add"] : app.buttons["Replace"]
        XCTAssert(insertButton.isEnabled, "We should be able to add a destination now")
        insertButton.tap()
        let backButton = app.navigationBars["Master"].buttons["Big Arrow"]
        if backButton.exists {
            backButton.tap()
        }
        deleteNewDestination(named: destName)
    }
    
    
    /// We shouldn't be able to add a destination if there is no associated location.
    func testInvalidAddition() {
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        let app = XCUIApplication()
        let navbar = app.navigationBars["Big Arrow"]
        navbar.buttons["Add new destination"].tap()
        
        let nameField = app.textFields.element(matching: .any, identifier: "Name Field")
        nameField.tap()
        nameField.typeText("12345")
        
        let insertButton = app.buttons["Add"].exists ? app.buttons["Add"] : app.buttons["Replace"]
        
        // if there's an other map child (overlay with no label), we should be able to add. Otherwise not
        let isThereAnother = app.maps.firstMatch.children(matching: .other).matching(NSPredicate(format: "label.length == 0")).firstMatch.exists
        
        if !isThereAnother {
            XCTAssertFalse(insertButton.isEnabled, "We shouldn't be able to add a location unless the map was moved")
        } else {
            XCTAssertTrue(insertButton.isEnabled, "We should be able to add a location since the map was moved")
        }
    }
    
    func deleteNewDestination(named: String) {
        let app = XCUIApplication()
        let navbar = app.navigationBars["Big Arrow"]

        navbar.buttons["Edit"].tap()
        let tablesQuery = app.tables
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "Delete \(named)")
        let button = tablesQuery.buttons.element(matching: predicate).firstMatch
        button.tap()
        tablesQuery.buttons["Delete"].tap()
        navbar.buttons["Done"].tap()
        sleep(1)
    }
    
}
