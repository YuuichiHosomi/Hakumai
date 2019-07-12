//
//  ChatTests.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 1/4/15.
//  Copyright (c) 2015 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import XCTest

final class ChatTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testIsRawUserId() {
        XCTAssert(Chat.isRawUserId("123") == true, "")
        XCTAssert(Chat.isRawUserId("123a") == false, "")
        XCTAssert(Chat.isRawUserId(nil) == false, "")
    }

    func testIsUserComment() {
        XCTAssert(Chat.isUserComment(Premium.ippan) == true, "")
        XCTAssert(Chat.isUserComment(Premium.premium) == true, "")
        XCTAssert(Chat.isUserComment(Premium.bsp) == false, "")
        XCTAssert(Chat.isUserComment(Premium.system) == false, "")
        XCTAssert(Chat.isUserComment(nil) == false, "")
    }
}
