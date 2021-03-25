//
//  EduVPN_UITests_iOS.swift
//  EduVPN-UITests-iOS
//
//  Created by Johan Kool on 09/12/2020.
//  Copyright © 2020 SURFNet. All rights reserved.
//

import XCTest

struct DemoInstituteAccessServerCredentials {
    let username: String
    let password: String
}

struct CustomServerCredentials {
    let host: String
    let username: String
    let password: String
}

struct TestServerCredentials {
    let demoInstituteAccessServerCredentials: DemoInstituteAccessServerCredentials?
    let customServerCredentials: CustomServerCredentials?
}

class EduVPNUITestsiOS: XCTestCase {

    var interruptionMonitor: NSObjectProtocol!
    var alertButtonToTap: String?
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
        interruptionMonitor = addUIInterruptionMonitor(withDescription: "“APP_NAME” Wants to Use “example.com” to Sign In") { (alert) -> Bool in
            if let alertButtonToTap = self.alertButtonToTap, alert.buttons[alertButtonToTap].exists {
                alert.buttons[alertButtonToTap].tap()
                return true
            }
            
            return false
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        removeUIInterruptionMonitor(interruptionMonitor)
    }

    func testFreshLaunch() throws {
        // Scenario: A fresh launch should open with the "Find your institute" search page
        
        // Given I launched a freshly installed app
        let app = givenILaunchedAFreshlyInstalledApp()

        // Then I should see screen with title "Add Server"
        thenIShouldSeeScreenWithTitle(app, title: "Add Server")
        
        // Then I should see "Find your institute" label
        thenIShouldSeeLabel(app, label: "Find your institute")
        
        // Then I should see search field with "Search for your institute" placeholder
        thenIShouldSeeSearchFieldWithPlaceholder(app, placeholder: "Search for your institute...")
    }
    
    func testSearching() {
        // Scenario: A fresh launch should open with the "Find your institute" search page
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // Then I should see "Add" button
        thenIShouldSeeButton(app, label: "Add")

        // When I tap "Add" button
        whenITapButton(app, label: "Add")

        // Then I should see screen with title "Add Server"
        thenIShouldSeeScreenWithTitle(app, title: "Add Server")
        
        // Then I should see "Find your institute" label
        thenIShouldSeeLabel(app, label: "Find your institute")
        
        // Then I should see search field with "Search for your institute" placeholder
        thenIShouldSeeSearchFieldWithPlaceholder(app, placeholder: "Search for your institute...")
        
        // When I start typing in the search field
        whenIStartTypingInTheSearchField(app)
        
        // Then I should see "Institute Access" label
        thenIShouldSeeLabel(app, label: "Institute Access")
        
        // Then I should see "Secure Internet" label
        thenIShouldSeeLabel(app, label: "Secure Internet")
        
        // When I search for "vsvsdkfb"
        whenISearchFor(app, query: "vsvsdkfb")
        
        // Then I should see "No results. Please check your search query." label
        thenIShouldSeeLabel(app, label: "No results. Please check your search query.")
        
        // When I clear the search field
        whenIClearTheSearchField(app)
        
        // Then I should see "Institute Access" label
        thenIShouldSeeLabel(app, label: "Institute Access")
        
        // When I search for "konijn"
        whenISearchFor(app, query: "konijn")
        
        // Then I should see "Secure Internet" label
        thenIShouldSeeLabel(app, label: "Secure Internet")
        
        // Then I should see "SURFnet bv" cell
        thenIShouldSeeCell(app, label: "SURFnet bv")
        
        // When I clear the search field
        whenIClearTheSearchField(app)
        
        // When I search for "Dem"
        whenISearchFor(app, query: "Dem")
        
        // Then I should see "Institute Access" label
        thenIShouldSeeLabel(app, label: "Institute Access")
        
        // Then I should see "Demo" cell
        thenIShouldSeeCell(app, label: "Demo")
    }
    
    func testAddInstituteAccess() throws {
        // Scenario: Adding a provider for institute access

        guard let demoCredentials = testServerCredentialsiOS.demoInstituteAccessServerCredentials else {
            throw XCTSkip("No credentials provided for Demo Institute Access server")
        }

        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I tap "Add" button
        whenITapButton(app, label: "Add")
        
        // Then I should see search field with "Search for your institute" placeholder
        thenIShouldSeeSearchFieldWithPlaceholder(app, placeholder: "Search for your institute...")
        
        // When I search for "Demo"
        whenISearchFor(app, query: "Demo")
        
        // Then I should see "Institute Access" label
        thenIShouldSeeLabel(app, label: "Institute Access")
        
        // Then I should see "Demo" cell
        thenIShouldSeeCell(app, label: "Demo")
        
        // When I tap "Demo" cell
        whenITapCell(app, label: "Demo")
        
        // When I authenticate with Demo
        whenIAuthenticateWithDemo(app, credentials: demoCredentials)
    }
    
    func testAddSecureInternet() {
        // Scenarion: Adding a provider for secure internet
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I tap "Add" button
        whenITapButton(app, label: "Add")
        
        // Then I should see search field with "Search for your institute" placeholder
        thenIShouldSeeSearchFieldWithPlaceholder(app, placeholder: "Search for your institute...")
        
        // When I search for "Surf"
        whenISearchFor(app, query: "Surf")
        
        // Then I should see "Secure Internet" label
        thenIShouldSeeLabel(app, label: "Secure Internet")
        
        // Then I should see "SURFnet bv" cell
        thenIShouldSeeCell(app, label: "SURFnet bv")
        
        // When I tap "SURFnet bv" cell
        whenITapCell(app, label: "SURFnet bv")
        
        // When I tap "Continue" button in system alert
        whenITapButtonInSystemAlert(app, label: "Continue")
        
        // When I wait 3 seconds
        whenIWait(time: 3)
        
        // Then I should see webpage with host "idp.surfnet.nl"
        thenIShouldSeeWebpageWithHost(app, host: "idp.surfnet.nl")
        
        // When I tap "Cancel" button
        whenITapButton(app, label: "Cancel")
        
        // Then I should see screen with title "Add Server"
        thenIShouldSeeScreenWithTitle(app, title: "Add Server")
    }
    
    func testAddCustomServer() throws {
        // Scenario: A custom server can be added and connected to

        guard let customCredentials = testServerCredentialsiOS.customServerCredentials else {
            throw XCTSkip("No credentials provided for custom server")
        }

        // Given I launched a freshly installed app
        let app = givenILaunchedAFreshlyInstalledApp()
        
        // Then I should see search field with "Search for your institute" placeholder
        thenIShouldSeeSearchFieldWithPlaceholder(app, placeholder: "Search for your institute...")
        
        // When I search for host
        whenISearchFor(app, query: customCredentials.host)
        
        // Then I should see "Add your own server" label
        thenIShouldSeeLabel(app, label: "Add your own server")
        
        // Then I should see "https:// + host" cell
        thenIShouldSeeCell(app, label: "https://" + customCredentials.host + "/")
        
        // When I tap "https:// + host" cell
        whenITapCell(app, label: "https://" + customCredentials.host + "/")
        
        // When I tap "Continue" button in system alert
        whenITapButtonInSystemAlert(app, label: "Continue")
        
        // Then I should see webpage with host "host"
        thenIShouldSeeWebpageWithHost(app, host: customCredentials.host)
        
        // When I start typing in the "Username" textfield
        whenIStartTypingInTheTextfield(app, label: "Username")
        
        // When I type "********"
        whenIType(app, text: customCredentials.username)
        
        // When I start typing in the secure "Password" textfield
        whenIStartTypingInTheSecureTextfield(app, label: "Password")
        
        // When I type "********"
        whenIType(app, text: customCredentials.password)
        
        // When I tap "Sign In" button
        whenITapButton(app, label: "Sign In")
        
        // When I wait 10 seconds
        whenIWait(time: 10)
        
        // Then I might see "Approve Application" label
        let needApproval = thenIMightSeeLabel(app, label: "Approve Application")
        
        if needApproval {
        
            // Then I should see webpage with host "host"
            thenIShouldSeeWebpageWithHost(app, host: customCredentials.host)
            
            // Then I should see "Approve Application" label
            thenIShouldSeeLabel(app, label: "Approve Application")
            
            // When I tap "Approve" button
            whenITapButton(app, label: "Approve")
        
            // When I wait 10 seconds
            whenIWait(time: 10)
        }
        
        // Then I should see "https:// + host" cell
        thenIShouldSeeCell(app, label: "https://" + customCredentials.host + "/")
        
        // When I tap "https:// + host" cell
        whenITapCell(app, label: "https://" + customCredentials.host + "/")
        
        // Then I should see screen with title "Connect to Server"
        thenIShouldSeeScreenWithTitle(app, title: "Connect to Server")
        
        // Then I should see "host" label
        thenIShouldSeeLabel(app, label: customCredentials.host)
        
        // Then I should see "Connected" label
        thenIShouldSeeLabel(app, label: "Connected", timeout: 10)
        
        // Then I should see connection switch on
        thenIShouldSeeConnectionSwitch(app, isOn: true)
        
        // Then I should see "Connection Info" label
        thenIShouldSeeLabel(app, label: "Connection Info")
        
        // When I tap "Connection Info" label
        whenITapLabel(app, label: "Connection Info")
        
        // Then I should see screen with title "Connection Info"
        thenIShouldSeeScreenWithTitle(app, title: "Connection Info")
        
        // Then I should see "DURATION" label
        thenIShouldSeeLabel(app, label: "DURATION")
        
        // Then I should see "DATA TRANSFERRED" label
        thenIShouldSeeLabel(app, label: "DATA TRANSFERRED")
        
        // Then I should see "ADDRESS" label
        thenIShouldSeeLabel(app, label: "ADDRESS")
        
        // Then I should see "PROFILE" label
        thenIShouldSeeLabel(app, label: "PROFILE")
        
        // Then I should see "Done" button
        thenIShouldSeeButton(app, label: "Done")
        
        // When I tap "Done" button
        whenITapButton(app, label: "Done")
        
        // Then I should see screen with title "Connect to Server"
        thenIShouldSeeScreenWithTitle(app, title: "Connect to Server")
        
        // Then I should see connection switch on
        thenIShouldSeeConnectionSwitch(app, isOn: true)
        
        // When I toggle connection switch
        whenIToggleConnectionSwitch(app)
        
        // Then I should see connection switch off
        thenIShouldSeeConnectionSwitch(app, isOn: false)
        
        // Then I should see "Not connected" label
        thenIShouldSeeLabel(app, label: "Not connected", timeout: 10)
    }
    
    func testRemovingProvider() {
        // Scenario: A provider can be removed
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // Then I should see "Demo" cell
        thenIShouldSeeCell(app, label: "Demo")
        
        // When I swipe left on "Demo" cell
        whenISwipeLeftOnCell(app, label: "Demo")
        
        // Then I should see "Delete" button
        thenIShouldSeeButton(app, label: "Delete")
        
        // When I tap "Delete" button
        whenITapButton(app, label: "Delete")
        
        // Then I should not see "Demo" cell
        thenIShouldNotSeeCell(app, label: "Demo")
    }
    
    func testConnectVPN() throws {
        // Scenario: Should be able to setup connection

        guard let demoCredentials = testServerCredentialsiOS.demoInstituteAccessServerCredentials else {
            throw XCTSkip("No credentials provided for Demo Institute Access server")
        }

        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I tap "Demo" cell
        whenITapCell(app, label: "Demo")
        
        // Then I should see screen with title "Connect to Server"
        thenIShouldSeeScreenWithTitle(app, title: "Connect to Server")
        
        // Then I should see "Demo" label
        thenIShouldSeeLabel(app, label: "Demo")
        
        // Then I might see "Not connected" label
        let needAuthentication = !thenIMightSeeLabel(app, label: "Not connected")
      
        if needAuthentication {
       
            // When I authenticate with Demo
            whenIAuthenticateWithDemo(app, credentials: demoCredentials)
            
        }
        
        // Then I should see "Not connected" label
        thenIShouldSeeLabel(app, label: "Not connected", timeout: 30)
        
        // Then I should see connection switch off
        thenIShouldSeeConnectionSwitch(app, isOn: false)
        
        // When I toggle the connection switch
        whenIToggleConnectionSwitch(app)
        
        // Then I should see "Demo" label
        thenIShouldSeeLabel(app, label: "Demo")

        // Then I should see "Connected" label
        thenIShouldSeeLabel(app, label: "Connected", timeout: 30)
        
        // Then I should see connection switch on
        thenIShouldSeeConnectionSwitch(app, isOn: true)
        
        // When I toggle the connection switch
        whenIToggleConnectionSwitch(app)
        
        // Then I should see "Not connected" label
        thenIShouldSeeLabel(app, label: "Not connected", timeout: 30)
        
        // Then I should see connection switch off
        thenIShouldSeeConnectionSwitch(app, isOn: false)
    }
    
    func testConnectionLog() {
        // Scenario: Should be able to see connection log
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I tap "Settings" button
        whenITapButton(app, label: "Settings")
        
        // Then I should see screen with title "Settings"
        thenIShouldSeeScreenWithTitle(app, title: "Settings")
        
        // Then I should see "LOGGING" header
        thenIShouldSeeHeader(app, label: "LOGGING")
        
        // Then I should see "Connection Log" label
        thenIShouldSeeLabel(app, label: "Connection Log")
        
        // When I tap "Connection Log" label
        whenITapLabel(app, label: "Connection Log")
        
        // Then I should see screen with title "Connection Log"
        thenIShouldSeeScreenWithTitle(app, title: "Connection Log")
    }
    
    func testSettings() {
        // Scenario: Settings should be available
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I tap "Settings" button
        whenITapButton(app, label: "Settings")
        
        // Then I should see screen with title "Settings"
        thenIShouldSeeScreenWithTitle(app, title: "Settings")
        
        // Then I should see "OPTIONS" header
        thenIShouldSeeHeader(app, label: "OPTIONS")
        
        // Then I should see "Connect using TCP only" label
        thenIShouldSeeLabel(app, label: "Connect using TCP only")
        
        // Then I should see "LOGGING" header
        thenIShouldSeeHeader(app, label: "LOGGING")
        
        // Then I should see "Connection Log" label
        thenIShouldSeeLabel(app, label: "Connection Log")
        
        // Then I should see "ABOUT" header
        thenIShouldSeeHeader(app, label: "ABOUT")
        
        // Then I should see "Source code" label
        thenIShouldSeeLabel(app, label: "Source code")
        
        // When I tap "Done" button
        whenITapButton(app, label: "Done")

        // Then I should see "Settings" button
        thenIShouldSeeButton(app, label: "Settings")
    }

    func testHelp() {
        // Scenario: Help should be available
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // Then I should see "Help" button
        thenIShouldSeeButton(app, label: "Help")
        
        // When I tap "Help" button
        whenITapButton(app, label: "Help")
        
        // Then I should see webpage with host "eduvpn.org"
        thenIShouldSeeWebpageWithHost(app, host: "eduvpn.org")
        
        // When I tap "Done" button
        whenITapButton(app, label: "Done")
        
        // Then I should see "Help" button
        thenIShouldSeeButton(app, label: "Help")
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
}

private extension EduVPNUITestsiOS {
    
    // MARK: - Given
    
    private func givenILaunchedTheApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("isUITesting")
        app.launch()
        return app
    }
    
    private func givenILaunchedAFreshlyInstalledApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("isUITesting")
        app.launchArguments.append("isUITestingFreshInstall")
        app.launch()
        return app
    }
    
    private func givenILaunchedAConfiguredApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("isUITesting")
        app.launchArguments.append("isUITestingConfigured")
        app.launch()
        return app
    }
    
    // MARK: - Then
    
    private func thenIShouldSeeScreenWithTitle(_ app: XCUIApplication, title: String) {
        let titleElement = app.navigationBars.staticTexts[title]
        XCTAssert(titleElement.exists)
    }
    
    private func thenIShouldSeeLabel(_ app: XCUIApplication, label: String, timeout: TimeInterval = 3) {
        let labelElement = app.staticTexts[label]
        _ = labelElement.waitForExistence(timeout: timeout)
        XCTAssert(labelElement.exists)
    }
    
    private func thenIMightSeeLabel(_ app: XCUIApplication, label: String) -> Bool {
        let labelElement = app.staticTexts[label]
        _ = labelElement.waitForExistence(timeout: 3)
        return labelElement.exists
    }
    
    private func thenIShouldSeeSearchFieldWithPlaceholder(_ app: XCUIApplication, placeholder: String) {
        let searchField = app.searchFields.firstMatch
        XCTAssert(searchField.exists)
        XCTAssert(searchField.placeholderValue == placeholder)
    }
    
    private func thenIShouldSeeButton(_ app: XCUIApplication, label: String) {
        let buttonElement = app.buttons[label]
        XCTAssert(buttonElement.exists)
    }
    
    private func thenIShouldSeeCell(_ app: XCUIApplication, label: String) {
        let cellElement = app.cells[label]
        XCTAssert(cellElement.exists)
    }
    
    private func thenIShouldSeeHeader(_ app: XCUIApplication, label: String) {
        let otherElement = app.otherElements[label]
        XCTAssert(otherElement.exists)
    }
    
    private func thenIShouldNotSeeCell(_ app: XCUIApplication, label: String) {
        let cellElement = app.cells[label]
        XCTAssert(cellElement.exists == false)
    }
    
    private func thenIShouldSeeAlert(_ app: XCUIApplication, title: String) {
        let alertElement = app.alerts[title]
        XCTAssert(alertElement.exists)
    }
    
    private func thenIShouldSeeWebpageWithHost(_ app: XCUIApplication, host: String) {
        let webViewElement = app.webViews.firstMatch
        _ = webViewElement.waitForExistence(timeout: 3)
        XCTAssert(webViewElement.exists)
        XCTAssert((app.buttons["URL"].value as? String)?.contains(host) ?? false)
    }
    
    private func thenIShouldSeeConnectionSwitch(_ app: XCUIApplication, isOn: Bool) {
        let switchElement = app.buttons["Connection"]
        XCTAssert(switchElement.exists)
        XCTAssert(switchElement.isSelected == isOn)
    }
    
    // MARK: - When
    
    private func whenIStartTypingInTheSearchField(_ app: XCUIApplication) {
        app.searchFields.firstMatch.tap()
    }
    
    private func whenIStartTypingInTheTextfield(_ app: XCUIApplication, label: String) {
        let textFieldElement = app.textFields[label]
        _ = textFieldElement.waitForExistence(timeout: 3)
        textFieldElement.tap()
    }
    
    private func whenIStartTypingInTheSecureTextfield(_ app: XCUIApplication, label: String) {
        let textFieldElement = app.secureTextFields[label]
        _ = textFieldElement.waitForExistence(timeout: 3)
        textFieldElement.tap()
    }
    
    private func whenISearchFor(_ app: XCUIApplication, query: String) {
        app.searchFields.firstMatch.tap()
        app.typeText(query)
    }
    
    private func whenIClearTheSearchField(_ app: XCUIApplication) {
        app.searchFields.firstMatch.buttons["Clear text"].tap()
    }
    
    private func whenITapCell(_ app: XCUIApplication, label: String) {
        let cellElement = app.cells[label].firstMatch
        cellElement.tap()
    }
    
    private func whenITapButton(_ app: XCUIApplication, label: String) {
        let buttonElement = app.buttons[label].firstMatch
        buttonElement.tap()
    }

    private func whenITapLabel(_ app: XCUIApplication, label: String) {
        let labelElement = app.staticTexts[label].firstMatch
        labelElement.tap()
    }
    
    private func whenITapLink(_ app: XCUIApplication, label: String) {
        let linkElement = app.links[label].firstMatch
        _ = linkElement.waitForExistence(timeout: 3)
        if linkElement.exists {
            linkElement.tap()
        }
    }
    
    private func whenIType(_ app: XCUIApplication, text: String) {
        app.typeText(text)
    }
    
    private func whenIToggleConnectionSwitch(_ app: XCUIApplication) {
        let switchElement = app.buttons["Connection"]
        switchElement.tap()
    }
    
    private func whenISwipeLeftOnCell(_ app: XCUIApplication, label: String) {
        let cellElement = app.cells[label]
        cellElement.swipeLeft()
    }
    
    private func whenIWait(time: TimeInterval) {
        Thread.sleep(forTimeInterval: time)
    }
    
    private func whenITapButtonInSystemAlert(_ app: XCUIApplication, label: String) {
        alertButtonToTap = label
        Thread.sleep(forTimeInterval: 3)
        app.swipeUp() // Interaction with app needed for some reasone
    }

    private func whenIAuthenticateWithDemo(
        _ app: XCUIApplication,
        credentials: DemoInstituteAccessServerCredentials) {

        // When I tap "Continue" button in system alert
        whenITapButtonInSystemAlert(app, label: "Continue")
        
        // When I wait 3 seconds
        whenIWait(time: 3)
        
        // Then I should see webpage with host "engine.surfconext.nl"
        thenIShouldSeeWebpageWithHost(app, host: "engine.surfconext.nl")
        
        // When I tap "eduID (NL)" link
        whenITapLink(app, label: "eduID (NL)")
        
        // When I wait 3 seconds
        whenIWait(time: 3)
        
        // Then I should see webpage with host "login.eduid.nl"
        thenIShouldSeeWebpageWithHost(app, host: "login.eduid.nl")
        
        // When I tap "Type a password." link
        whenITapLink(app, label: "Type a password.")
        
        // When I start typing in the "e.g. user@gmail.com" textfield
        whenIStartTypingInTheTextfield(app, label: "e.g. user@gmail.com")
        
        // When I type "********"
        whenIType(app, text: credentials.username)
        
        // When I start typing in the secure "Password" textfield
        whenIStartTypingInTheSecureTextfield(app, label: "Password")
        
        // When I type "********"
        whenIType(app, text: credentials.password)
        
        // When I tap "Done" button
        whenITapButton(app, label: "Done")
        
        // When I tap "Login" link
        whenITapLink(app, label: "Login")
        
        // When I wait 10 seconds
        whenIWait(time: 10)
        
        // Then I might see "Approve Application" label
        let needApproval = thenIMightSeeLabel(app, label: "Approve Application")
        
        if needApproval {
            
            // Then I should see webpage with host "host"
            thenIShouldSeeWebpageWithHost(app, host: "demo.eduvpn.nl")
            
            // When I tap "Approve" button
            whenITapButton(app, label: "Approve")
        }
    }
    
}
