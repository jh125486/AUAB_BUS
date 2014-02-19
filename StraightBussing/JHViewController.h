//
//  JHViewController.h
//  StraightBussing
//
//  Created by Jacob Hochstetler on 2/2/14.
//  Copyright (c) 2014 Jacob Hochstetler. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JH_Constants.h"

#define DATE_COMPONENTS (NSYearCalendarUnit| NSMonthCalendarUnit | NSDayCalendarUnit | NSWeekCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit | NSWeekdayCalendarUnit | NSWeekdayOrdinalCalendarUnit)
#define CURRENT_CALENDAR [NSCalendar currentCalendar]


@interface JHViewController : QuickDialogController

@property (strong, nonatomic) NSArray *routes;
@property (strong, nonatomic) NSArray *stops;
@property (strong, nonatomic) NSArray *stopNumbers;

@property (strong, nonatomic) QDateTimeInlineElement *fromTime;
@property (strong, nonatomic) QRadioElement *fromStop;
@property (strong, nonatomic) QRadioElement *toStop;
@property (weak, nonatomic) QLabelElement *busColorLabel;
@property (weak, nonatomic) QLabelElement *busWaitLabel;
@property (weak, nonatomic) QLabelElement *busRideLabel;

@end
