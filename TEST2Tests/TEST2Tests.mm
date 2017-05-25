//
//  TEST2Tests.m
//  TEST2Tests
//
//  Created by RossSong on 2017. 5. 23..
//
//

#import <XCTest/XCTest.h>
#import "TEST2Controller.h"

@interface TEST2Tests : XCTestCase

@property (strong, nonatomic) TEST2Controller *controller;
@end

@implementation TEST2Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.controller = [[TEST2Controller alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    self.controller = nil;
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testSetup {
    [self.controller setup];
}

- (void)testSetupArrayEffects {
    [self.controller setupArrayEffects];
    XCTAssert(8 == self.controller.arrayEffects.count);
    
    NSString *string = self.controller.arrayEffects[0];
    XCTAssert([string isEqualToString:@"moon.jpg"]);
    
    string = self.controller.arrayEffects[1];
    XCTAssert([string isEqualToString:@"Ahn.jpg"]);
    
    string = self.controller.arrayEffects[2];
    XCTAssert([string isEqualToString:@"DonaldTrump.jpeg"]);
    
    string = self.controller.arrayEffects[3];
    XCTAssert([string isEqualToString:@"joker.jpg"]);
    
    string = self.controller.arrayEffects[4];
    XCTAssert([string isEqualToString:@"Abe.jpeg"]);
    
    string = self.controller.arrayEffects[5];
    XCTAssert([string isEqualToString:@"young_moon.jpeg"]);
    
    string = self.controller.arrayEffects[6];
    XCTAssert([string isEqualToString:@"test.jpg"]);
    
    string = self.controller.arrayEffects[7];
    XCTAssert([string isEqualToString:@"jung.png"]);
}

@end
