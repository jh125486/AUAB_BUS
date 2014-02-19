//
//  JHViewController.m
//  StraightBussing
//
//  Created by Jacob Hochstetler on 2/2/14.
//  Copyright (c) 2014 Jacob Hochstetler. All rights reserved.
//

#import "JHViewController.h"

@interface JHViewController ()
- (void)updateCurrentTimeElement:(NSNotification *)notif;
@end

@implementation JHViewController

- (void)viewDidLoad {
    NSString *stopsPath  = [[NSBundle mainBundle] pathForResource:@"379_stops"  ofType:@"json"];
    NSString *routesPath = [[NSBundle mainBundle] pathForResource:@"379_routes" ofType:@"json"];
    NSError* error;
    _stops = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:stopsPath]
                                             options:kNilOptions error:&error];
    _routes = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:routesPath]
                                              options:kNilOptions error:&error];
    
    QRootElement *_root = [[QRootElement alloc] init];
    
    _root.grouped = YES;
    _root.title = @"Straight Bussing";
    
    QSection *querySection = [[QSection alloc] initWithTitle:@"Str8 Bussin'"];
    _stopNumbers = [_stops $map:^(id stop) {
        return [(NSDictionary *)stop $for:@"number"];
    }];
    NSArray *stopNumbersAndNames = [_stops $map:^(id stop) {
        return [NSString stringWithFormat:@"#%@ - %@", [(NSDictionary *)stop $for:@"number"], [(NSDictionary *)stop $for:@"name"]];
    }];
    
    _fromStop = [[QRadioElement alloc] initWithItems:stopNumbersAndNames
                                            selected:-1
                                               title:@"From"];
    _fromTime = [[QDateTimeInlineElement alloc] initWithTitle:@"Time"
                                                         date:[NSDate date]
                                                      andMode:UIDatePickerModeTime];
    _toStop = [[QRadioElement alloc] initWithItems:stopNumbersAndNames
                                          selected:-1
                                             title:@"To"];
    
    QSection *resultSection = [[QSection alloc] initWithTitle:@"Bus"];
    QLabelElement *busColor = [[QLabelElement alloc] initWithTitle:@"Line color" Value:nil];
    QLabelElement *busWait = [[QLabelElement alloc] initWithTitle:@"Wait time" Value:nil];
    QLabelElement *busRide = [[QLabelElement alloc] initWithTitle:@"Ride time" Value:nil];
    _busColorLabel = busColor;
    _busRideLabel = busRide;
    _busWaitLabel = busWait;
    
    __weak typeof(self) weakSelf = self;

    _fromTime.onValueChanged = ^(QRootElement *element){
        [weakSelf calculateBusLine];
    };
    
    _fromStop.onValueChanged = ^(QRootElement *element){
        [weakSelf calculateBusLine];
    };

    _toStop.onValueChanged = ^(QRootElement *element){
        [weakSelf calculateBusLine];
    };

    [querySection addElement:_fromTime];
    [querySection addElement:_fromStop];
    [querySection addElement:_toStop];
    [resultSection addElement:busColor];
    [resultSection addElement:busWait];
    [resultSection addElement:busRide];
    [_root addSection:querySection];
    [_root addSection:resultSection];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateCurrentTimeElement:)
                                                 name:NOTIF_UpdateCurrentTime
                                               object:nil];
    self.root = _root;
    [self loadView];
    
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateCurrentTimeElement:(NSNotification *)notif {
    _fromTime.dateValue = [NSDate date];
    [self calculateBusLine];
    [self.quickDialogTableView reloadCellForElements:_fromTime, nil];
}

- (void)calculateBusLine {
    if (_fromStop.selected < 0 || _toStop.selected < 0)
        return;
    NSString * fromStop = [_stopNumbers $at:_fromStop.selected];
    NSDate * fromTime   = _fromTime.dateValue;
    NSString * toStop   = [_stopNumbers $at:_toStop.selected];
    
    NSUInteger minDelta        = NSUIntegerMax;
    NSInteger minRouteIndex   = -1;
    NSInteger minOnStopIndex  = -1;
    NSInteger minOffStopIndex = -1;
    
    NSDateComponents *startComponents = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:fromTime];
    NSUInteger timeSinceMidnightDelta = [startComponents hour] * MINUTES_PER_HOUR + [startComponents minute];
    NSUInteger timeDelta = timeSinceMidnightDelta;
    
    int routeIndex = 0;
    NSArray *stops;
    for (NSDictionary *route in _routes) {
        stops = [route $for:@"stops"]; // set the stops
        NSUInteger start = [[route $for:@"start"] unsignedIntegerValue];
        NSUInteger end = [[route $for:@"end"] unsignedIntegerValue];
        if (timeSinceMidnightDelta < start && timeSinceMidnightDelta < end) {
            timeDelta = timeSinceMidnightDelta + 1440;
        } else {
            timeDelta = timeSinceMidnightDelta;
        }
        NSUInteger onIndex = [stops indexOfObjectPassingTest:^BOOL(NSDictionary *routeStop, NSUInteger idx, BOOL *stop) {
            NSUInteger tempTime = [[routeStop $for:@"t"] unsignedIntegerValue];
            return (tempTime > timeDelta && [[routeStop $for:@"n"] isEqualToString:fromStop]);
        }];

        if (onIndex != NSNotFound) { // only proceed if a match is found
            NSUInteger offIndex = [stops indexOfObjectPassingTest:^BOOL(NSDictionary *routeStop, NSUInteger idx, BOOL *stop) {
                return (idx > onIndex && [[routeStop $for:@"n"] isEqualToString:toStop]);
            }];
            if (offIndex != NSNotFound) { // off stop is found
                NSDictionary *offStop = [stops $at:offIndex];
                NSUInteger tempTime = [[offStop $for:@"t"] unsignedIntegerValue];
                if (tempTime < minDelta) { // set earliest bus stop
                    minDelta        = tempTime;
                    minRouteIndex   = routeIndex;
                    minOnStopIndex  = onIndex;
                    minOffStopIndex = offIndex;
                }
            }
        }
        routeIndex++;
    }
    
    // set UILabels
    if (minRouteIndex >= 0) {
        NSDictionary *chosenRoute  = [_routes $at:minRouteIndex];
        NSString *chosenRouteColor = [chosenRoute $for:@"color"];
        NSDictionary *onStop       = [[chosenRoute $for:@"stops"] $at:minOnStopIndex];
        NSDictionary *offStop      = [[chosenRoute $for:@"stops"] $at:minOffStopIndex];
        NSInteger waitTimeMinutes = [[onStop $for:@"t"] unsignedIntegerValue] - timeDelta;
        NSInteger rideTimeMinutes = [[offStop $for:@"t"] unsignedIntegerValue] - [[onStop $for:@"t"] unsignedIntegerValue];
        _busColorLabel.value = chosenRouteColor;
        _busWaitLabel.value = $str(@"in about %ld mikes",  (long)waitTimeMinutes);
        _busRideLabel.value = $str(@"for about %ld mikes", (long)rideTimeMinutes);
    } else {
        _busColorLabel.value = @"...no route found";
        _busWaitLabel.value = nil;
        _busRideLabel.value = nil;
    }
    [self.quickDialogTableView reloadCellForElements:_busColorLabel, nil];
    [self.quickDialogTableView reloadCellForElements:_busWaitLabel, nil];
    [self.quickDialogTableView reloadCellForElements:_busRideLabel, nil];
}

@end
