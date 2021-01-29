//
//  EduVPN_UITests_macOS.swift
//  EduVPN-UITests-macOS
//
//  Created by Johan Kool on 16/12/2020.
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

class EduVPNUITestsmacOS: XCTestCase {

    var interruptionMonitor: NSObjectProtocol!
    var alertButtonToClick: String?
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
        
        interruptionMonitor = addUIInterruptionMonitor(withDescription: "“APP_NAME” Wants to Use “example.com” to Sign In") { (alert) -> Bool in
            if let alertButtonToClick = self.alertButtonToClick, alert.buttons[alertButtonToClick].exists {
                alert.buttons[alertButtonToClick].click()
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

        // When I click "Add" button
        whenIClickButton(app, label: "Add")
        
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

        guard let demoCredentials = testServerCredentialsmacOS.demoInstituteAccessServerCredentials else {
            throw XCTSkip("No credentials provided for Demo Institute Access server")
        }

        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I click "Add" button
        whenIClickButton(app, label: "Add")
        
        // Then I should see search field with "Search for your institute" placeholder
        thenIShouldSeeSearchFieldWithPlaceholder(app, placeholder: "Search for your institute...")
        
        // When I search for "Demo"
        whenISearchFor(app, query: "Demo")
        
        // Then I should see "Institute Access" label
        thenIShouldSeeLabel(app, label: "Institute Access")
        
        // Then I should see "Demo" cell
        thenIShouldSeeCell(app, label: "Demo")
        
        // When I click "Demo" cell
        whenIClickCell(app, label: "Demo")
        
        // When I authenticate with Demo
        whenIAuthenticateWithDemo(app, credentials: demoCredentials)
    }
    
    func testAddSecureInternet() {
        // Scenarion: Adding a provider for secure internet
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I click "Add" button
        whenIClickButton(app, label: "Add")
        
        // Then I should see search field with "Search for your institute" placeholder
        thenIShouldSeeSearchFieldWithPlaceholder(app, placeholder: "Search for your institute...")
        
        // When I search for "Surf"
        whenISearchFor(app, query: "Surf")
        
        // Then I should see "Secure Internet" label
        thenIShouldSeeLabel(app, label: "Secure Internet")
        
        // Then I should see "SURFnet bv" cell
        thenIShouldSeeCell(app, label: "SURFnet bv")
        
        // When I click "SURFnet bv" cell
        whenIClickCell(app, label: "SURFnet bv")
        
        // When I wait 3 seconds
        whenIWait(time: 3)
        
        // Then I should see webpage with host "idp.surfnet.nl"
        thenIShouldSeeWebpageWithHost(host: "idp.surfnet.nl")
        
        // When I click "Cancel" button
        whenIClickButton(app, label: "Cancel")
        
        // Then I should see "Secure Internet" label
        thenIShouldSeeLabel(app, label: "Secure Internet")
        
        // Then I should see "SURFnet bv" cell
        thenIShouldSeeCell(app, label: "SURFnet bv")
    }
    
    func testAddCustomServer() throws {
        // Scenario: A custom server can be added and connected to

        guard let customCredentials = testServerCredentialsmacOS.customServerCredentials else {
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
        
        // When I click "https:// + host" cell
        whenIClickCell(app, label: "https://" + customCredentials.host + "/")
        
        // Then I might see webpage with host "host"
        let (_, safari) = thenIMightSeeWebpageWithHost(host: customCredentials.host)
        
        // Then I might see "Sign In" label
        let needLogin = thenIMightSeeLabel(safari, label: "Sign In")
     
        if needLogin {
            // When I start typing in the "Username" textfield
            whenIStartTypingInTheTextfield(safari, label: "Username")
            
            // When I type "********"
            whenIType(safari, text: customCredentials.username)
            
            // When I start typing in the secure "Password" textfield
            whenIStartTypingInTheSecureTextfield(safari, label: "Password")
            
            // When I type "********"
            whenIType(safari, text: customCredentials.password)
            
            // When I click "Sign In" button
            whenIClickButton(safari, label: "Sign In")
            
            // When I wait 10 seconds
            whenIWait(time: 10)
        }
            
        // Then I might see "Approve Application" label
        let needApproval = thenIMightSeeLabel(safari, label: "Approve Application")
        
        if needApproval {
        
            // Then I should see webpage with host "host"
            thenIShouldSeeWebpageWithHost(host: customCredentials.host)
            
            // Then I should see "Approve Application" label
            thenIShouldSeeLabel(safari, label: "Approve Application")
            
            // When I click "Approve" button
            whenIClickButton(safari, label: "Approve")
        
            // When I wait 10 seconds
            whenIWait(time: 10)
        }
        
        // Then I should see "Other servers" label
        thenIShouldSeeLabel(app, label: "Other servers")
        
        // Then I should see "https:// + host" cell
        thenIShouldSeeCell(app, label: "https://" + customCredentials.host + "/")
        
        // When I click "https:// + host" cell
        whenIClickCell(app, label: "https://" + customCredentials.host + "/")
        
        // When I click "Allow" button in system alert
        whenIClickButtonInSystemAlert(app, label: "Allow")
                
        // Then I should see "host" label
        thenIShouldSeeLabel(app, label: customCredentials.host)
        
        // Then I should see "Connected" label
        thenIShouldSeeLabel(app, label: "Connected", timeout: 10)
        
        // Then I should see connection switch on
        thenIShouldSeeConnectionSwitch(app, isOn: true)
        
        // Then I should see "Connection info" label
        thenIShouldSeeLabel(app, label: "Connection info") // FIXME: iOS capitalizes "info"
        
        // When I click "Connection info" label
        whenIClickLabel(app, label: "Connection info")
               
        // Then I should see "DURATION" label
        thenIShouldSeeLabel(app, label: "DURATION")
        
        // Then I should see "DATA TRANSFERRED" label
        thenIShouldSeeLabel(app, label: "DATA TRANSFERRED")
        
        // Then I should see "ADDRESS" label
        thenIShouldSeeLabel(app, label: "ADDRESS")
        
        // Then I should see "PROFILE" label
        thenIShouldSeeLabel(app, label: "PROFILE")
        
        // Then I should see "Hide connection info" button
        thenIShouldSeeButton(app, label: "Hide connection info")
        
        // When I click "Close" button
        whenIClickButton(app, label: "Hide connection info")
        
        // When I wait 1 second
        whenIWait(time: 1)
        
        // Then I should not see "DURATION" label
        thenIShouldNotSeeLabel(app, label: "DURATION")

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
        
        // When I show contextual menu for "Demo" cell
        whenIShowContextualMenuForCell(app, label: "Demo")
        
        // Then I should see "Delete" contextual menu item
        thenIShouldSeeContextualMenuItem(app, label: "Delete")
        
        // When I choose "Delete" contextual menu item
        whenIChooseContextualMenuItem(app, label: "Delete")
        
        // Then I should not see "Demo" cell
        thenIShouldNotSeeCell(app, label: "Demo")
    }
    
    func testConnectVPN() throws {
        // Scenario: Should be able to setup connection

        guard let demoCredentials = testServerCredentialsmacOS.demoInstituteAccessServerCredentials else {
            throw XCTSkip("No credentials provided for Demo Institute Access server")
        }

        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I click "Demo" cell
        whenIClickCell(app, label: "Demo")
        
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
        
        // When I wait 3 seconds
        whenIWait(time: 3)
        
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
        
        // When I click "Preferences" button
        whenIClickButton(app, label: "Preferences")
                        
        // Then I should see "Connection log" label
        thenIShouldSeeLabel(app, label: "Connection log") // FIXME: iOS capitalizes Log, should this be the same?
        
        // Then I should see "View Log" button
        thenIShouldSeeButton(app, label: "View Log")
        
        // When I click "View Log" button
        whenIClickButton(app, label: "View Log")
        
        // Then I should see "com.apple.Console" app active
        thenIShouldSeeAppActive(bundleIdentifier: "com.apple.Console")
    }
    
    func testPreferences() {
        // Scenario: Preferences should be available
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // When I click "Preferences" button
        whenIClickButton(app, label: "Preferences")
        
        // Then I should see "Preferences" label
        thenIShouldSeeLabel(app, label: "Preferences")
        
        // Then I should see "Connect using TCP only" checkbox
        thenIShouldSeeCheckbox(app, label: "Connect using TCP only")
        
        // Then I should see "Connection log" label
        thenIShouldSeeLabel(app, label: "Connection log") // FIXME: iOS capitalizes Log, should this be the same?
        
        // Then I should see "View Log" button
        thenIShouldSeeButton(app, label: "View Log")
        
        // Then I should see "Show in menu bar" checkbox
        thenIShouldSeeCheckbox(app, label: "Show in menu bar")
                  
        // Then I should see "Show in Dock" checkbox
        thenIShouldSeeCheckbox(app, label: "Show in Dock")
        
        // When I click "Done" button
        whenIClickButton(app, label: "Done")

        // Then I should see "Preferences" button
        thenIShouldSeeButton(app, label: "Preferences")
    }

    func testHelp() {
        // Scenario: Help should be available
        
        // Given I launched a configured app
        let app = givenILaunchedAConfiguredApp()
        
        // Then I should see "Help" button
        thenIShouldSeeButton(app, label: "Help")
        
        // When I click "Help" button
        whenIClickButton(app, label: "Help")
        
        // Then I should see webpage with host "eduvpn.org"
        thenIShouldSeeWebpageWithHost(host: "eduvpn.org")
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

private extension EduVPNUITestsmacOS {
    
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
    
    private func thenIShouldSeeLabel(_ app: XCUIApplication, label: String, timeout: TimeInterval = 3) {
        let labelElement = app.staticTexts[label]
        _ = labelElement.waitForExistence(timeout: timeout)
        XCTAssert(labelElement.exists)
    }
    
    private func thenIShouldNotSeeLabel(_ app: XCUIApplication, label: String) {
        let labelElement = app.staticTexts[label]
        XCTAssert(labelElement.exists == false || labelElement.isHittable == false)
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
    
    @discardableResult
    private func thenIShouldSeeWebpageWithHost(_ safari: XCUIApplication = XCUIApplication(bundleIdentifier: "com.apple.Safari"), host: String) -> XCUIApplication {
        let textFieldElement = safari.textFields["WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"]
        _ = textFieldElement.waitForExistence(timeout: 3)
        XCTAssert((textFieldElement.value as? String)?.contains(host) ?? false)
        return safari
    }
    
    @discardableResult
    private func thenIMightSeeWebpageWithHost(_ safari: XCUIApplication = XCUIApplication(bundleIdentifier: "com.apple.Safari"), host: String) -> (Bool, XCUIApplication) {
        let textFieldElement = safari.textFields["WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"]
        _ = textFieldElement.waitForExistence(timeout: 3)
        let webpageSeen = (textFieldElement.value as? String)?.contains(host) ?? false
        return (webpageSeen, safari)
    }
    
    private func thenIShouldSeeConnectionSwitch(_ app: XCUIApplication, isOn: Bool) {
        let switchElement = app.checkBoxes["Connection"]
        XCTAssert(switchElement.exists)
        if let value = switchElement.value as? Bool {
            XCTAssert(value == isOn)
        } else {
            XCTFail("Checkbox value is not a boolean")
        }
    }
    
    private func thenIShouldSeeCheckbox(_ app: XCUIApplication, label: String, isOn: Bool? = nil) {
        let checkboxElement = app.checkBoxes[label]
        XCTAssert(checkboxElement.exists)
        if let isOn = isOn {
            XCTAssert(checkboxElement.isSelected == isOn)
        }
    }
    
    private func thenIShouldSeeContextualMenuItem(_ app: XCUIApplication, label: String) {
        let menuItemElement = app.menuItems[label]
        XCTAssert(menuItemElement.exists)
    }

    private func thenIShouldSeeAppActive(bundleIdentifier: String) {
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        XCTAssert(app.state == .runningForeground)
    }
    
    // MARK: - When
    
    private func whenIStartTypingInTheSearchField(_ app: XCUIApplication) {
        app.searchFields.firstMatch.click()
    }
    
    private func whenIStartTypingInTheTextfield(_ app: XCUIApplication, label: String) {
        let textFieldElement = app.textFields[label]
        _ = textFieldElement.waitForExistence(timeout: 3)
        textFieldElement.click()
    }
    
    private func whenIStartTypingInTheSecureTextfield(_ app: XCUIApplication, label: String) {
        let textFieldElement = app.secureTextFields[label]
        _ = textFieldElement.waitForExistence(timeout: 3)
        textFieldElement.click()
    }
    
    private func whenISearchFor(_ app: XCUIApplication, query: String) {
        app.searchFields.firstMatch.click()
        app.typeText(query)
    }
    
    private func whenIClearTheSearchField(_ app: XCUIApplication) {
        app.searchFields.firstMatch.buttons["cancel"].click()
    }
    
    private func whenIClickCell(_ app: XCUIApplication, label: String) {
        let cellElement = app.cells[label].firstMatch
        cellElement.click()
    }
    
    private func whenIClickButton(_ app: XCUIApplication, label: String) {
        let buttonElement = app.buttons[label].firstMatch
        buttonElement.click()
    }

    private func whenIClickLabel(_ app: XCUIApplication, label: String) {
        let labelElement = app.staticTexts[label].firstMatch
        labelElement.click()
    }
    
    private func whenIClickLink(_ app: XCUIApplication, label: String) {
        let linkElement = app.links[label].firstMatch
        _ = linkElement.waitForExistence(timeout: 3)
        if linkElement.exists {
            linkElement.click()
        }
    }
    
    private func whenIType(_ app: XCUIApplication, text: String) {
        app.typeText(text)
    }
    
    private func whenIToggleConnectionSwitch(_ app: XCUIApplication) {
        let switchElement = app.checkBoxes["Connection"]
        switchElement.click()
    }
    
    private func whenIShowContextualMenuForCell(_ app: XCUIApplication, label: String) {
        let cellElement = app.cells[label].firstMatch
        cellElement.rightClick()
    }
    
    private func whenIChooseContextualMenuItem(_ app: XCUIApplication, label: String) {
        let menuItemElement = app.windows.menuItems[label]
        menuItemElement.click()
    }
    
    private func whenIWait(time: TimeInterval) {
        Thread.sleep(forTimeInterval: time)
    }
    
    private func whenIClickButtonInSystemAlert(_ app: XCUIApplication, label: String) {
        alertButtonToClick = label
        Thread.sleep(forTimeInterval: 3)
        app.activate() // Interaction with app needed for some reasone
    }

    private func whenIAuthenticateWithDemo(
        _ app: XCUIApplication,
        credentials: DemoInstituteAccessServerCredentials) {

        // When I wait 3 seconds
        whenIWait(time: 3)
        
        // Then I might see webpage with host "engine.surfconext.nl"
        let (needChoice, safari) = thenIMightSeeWebpageWithHost(host: "engine.surfconext.nl")
        
        if needChoice {
            // When I click "eduID (NL)" link
            whenIClickLink(safari, label: "eduID (NL)")
            
            // When I wait 3 seconds
            whenIWait(time: 3)
        }
        
        // Then I might see webpage with host "login.eduid.nl"
        let (needLogin, _) = thenIMightSeeWebpageWithHost(safari, host: "login.eduid.nl")
        
        if needLogin {
            // When I click "Type a password." link
            whenIClickLink(safari, label: "Type a password.")
            
            // When I start typing in the "e.g. user@gmail.com" textfield
            whenIStartTypingInTheTextfield(safari, label: "e.g. user@gmail.com")
            
            // When I type "********"
            whenIType(safari, text: credentials.username)
            
            // When I start typing in the secure "Password" textfield
            whenIStartTypingInTheSecureTextfield(safari, label: "Password")
            
            // When I type "********"
            whenIType(safari, text: credentials.password)
            
            // When I click "Login" link
            whenIClickLink(safari, label: "Login")
            
            // When I wait 10 seconds
            whenIWait(time: 10)
        }
        
        // Then I might see "Approve Application" label
        let needApproval = thenIMightSeeLabel(safari, label: "Approve Application")
        
        if needApproval {
            
            // Then I should see webpage with host "host"
            thenIShouldSeeWebpageWithHost(safari, host: "demo.eduvpn.nl")
            
            // When I click "Approve" button
            whenIClickButton(safari, label: "Approve")
        }
    }
    
}
