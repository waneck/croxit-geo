#ifndef STATIC_LINK
	#define IMPLEMENT_API
#endif
#include <hx/CFFI.h>
#include "croxit_events.h"
//http://developer.apple.com/library/ios/#documentation/CoreLocation/Reference/CLLocationManager_Class/CLLocationManager/CLLocationManager.html#//apple_ref/doc/uid/TP40007125
//http://stackoverflow.com/questions/459355/whats-the-easiest-way-to-get-the-current-location-of-an-iphone
//http://stackoverflow.com/questions/1862304/where-to-implement-cllocationmanager
//UIBackgroundModes -> https://developer.apple.com/library/IOs/#documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/AdvancedAppTricks/AdvancedAppTricks.html
//http://longweekendmobile.com/2010/07/22/iphone-background-gps-accurate-to-500-meters-not-enough-for-foot-traffic/
//http://tweetero.googlecode.com/svn/trunk/
//kCLLocationAccuracyBestForNavigation 
//http://stackoverflow.com/questions/9746675/cllocationmanager-responsiveness

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

@interface LocationManager : NSObject <CLLocationManagerDelegate>
{
@private
	double distanceFilter;
	int precisionMagnitude;
	int status;
@public
	CLLocationManager* locationManager;
}

- (void) startMonitoring;

- (void) stopMonitoring;

- (int) status;

@end


enum LocationManagerStatus { LMOff, LMInitializing, LMHasData, LMError, LMDeniedByUser };

LocationManager *global_location_manager = [[LocationManager alloc] init];
static BOOL initialized = NO;

AutoGCRoot *cgeo_mk_position;



@implementation LocationManager

- (id)retain
{
    return self;
}

- (unsigned)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
}

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

-(void)reset
{
	status = LMOff;
}

- (id)init
{
	if(initialized)
		return global_location_manager;
	
	self = [super init];
    if (!self)
	{
		if(global_location_manager)
			[global_location_manager release];
		return nil;
	}
	
	locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	locationManager.distanceFilter = 100;
	locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
	
	initialized = YES;
	[self reset];
    return self;
}

-(void)dealloc
{
	if(locationManager)
		[locationManager release];
	[super dealloc];
}



- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation  fromLocation:(CLLocation *)oldLocation
{
	if (!newLocation)
		return;
	
	CLLocationCoordinate2D coords = [newLocation coordinate];
	
	if (!cgeo_mk_position || !cgeo_mk_position->get())
		neko_error();
	
	value args = alloc_array(8);
	
	val_array_set_i(args, 0, alloc_float(coords.latitude));
	val_array_set_i(args, 1, alloc_float(coords.longitude));
	val_array_set_i(args, 2, alloc_float([newLocation altitude]));
	val_array_set_i(args, 3, alloc_float([newLocation horizontalAccuracy]));
	val_array_set_i(args, 4, alloc_float([newLocation verticalAccuracy]));
	val_array_set_i(args, 5, alloc_float([newLocation course]));
	val_array_set_i(args, 6, alloc_float([newLocation speed]));
	val_array_set_i(args, 7, alloc_float([[newLocation timestamp] timeIntervalSince1970]));
	
	status = LMHasData;
	value pos = val_call1(cgeo_mk_position->get(), args);
	value posarr = alloc_array(1);
	val_array_set_i(posarr, 0, pos);
	
	ngap_dispatch_event(alloc_string("cgeo_location_update"), posarr);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	int errornum = 0;
    if ([error domain] == kCLErrorDomain) 
	{
		switch ([error code]) 
		{
			case kCLErrorDenied:
				[self stopMonitoring];
				errornum = 1;
				status = LMDeniedByUser;
				break;
			case kCLErrorLocationUnknown:
				//recoverable error
				errornum = 2;
				break;
			default:
				[self stopMonitoring];
				status = LMError;
				break;
		}
	}
	
	value args = alloc_array(1);
	val_array_set_i(args, 0, alloc_int(errornum));
	val_array_set_i(args, 1, alloc_string([[error localizedDescription] UTF8String]));
	
	ngap_dispatch_event(alloc_string("cgeo_location_error"), args);
}

- (void) syncDistanceFilter
{
	if (distanceFilter <= 0.0)
		locationManager.distanceFilter = kCLDistanceFilterNone;
	else
		locationManager.distanceFilter = distanceFilter;
}

- (void) setDistanceFilter:(double) filter
{
	distanceFilter = filter;
}

- (void) syncPrecisionMagnitude
{
	switch(precisionMagnitude)
	{
	case -1:
		locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
		break;
	case 0:
		locationManager.desiredAccuracy = kCLLocationAccuracyBest;
		break;
	case 1:
		locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
		break;
	case 2:
		locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
		break;
	case 3:
		locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
		break;
	case 4:
		locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
		break;
	default:
		neko_error();
	}
}

- (void) setPrecisionMagnitude:(int) mag
{
	precisionMagnitude = mag;
}
- (void) stopMonitoring
{
	if (locationManager)
	{
		[locationManager stopUpdatingLocation];
	}
	[self reset];
}

- (void) startMonitoring
{
	[locationManager startUpdatingLocation];
}

- (int) status
{
	return status;
}

@end

value cgeo_set_active(value active, value purpose)
{
	val_check(active, bool);
	if (!val_is_null(purpose))
	{
		val_check(purpose, string);
		global_location_manager->locationManager.purpose = [NSString stringWithUTF8String:val_string(purpose)];
	}
	
	if (val_bool(active))
	{
		[global_location_manager startMonitoring];
	} else {
		[global_location_manager stopMonitoring];
	}
	
	return alloc_null();
}

DEFINE_PRIM(cgeo_set_active, 2);

value cgeo_set_active_significant(value active)
{
	val_check(active, bool);
	
	if (val_bool(active))
	{
		[global_location_manager->locationManager startMonitoringSignificantLocationChanges];
	} else {
		[global_location_manager->locationManager stopMonitoringSignificantLocationChanges];
	}
	
	return alloc_null();
}

DEFINE_PRIM(cgeo_set_active_significant, 1);

value cgeo_set_create_position(value mk_pos)
{
	
	val_check_function(mk_pos, 1);
	
	if (cgeo_mk_position && !val_is_null(cgeo_mk_position->get()))
	{
		delete cgeo_mk_position;
		cgeo_mk_position = NULL;
	}
	
	cgeo_mk_position = new AutoGCRoot(mk_pos);
	
	return alloc_null();
}

DEFINE_PRIM(cgeo_set_create_position, 1);

value cgeo_getset_precision(value precision)
{
	if (!val_is_null(precision))
	{
		val_check(precision, int);
		[global_location_manager setPrecisionMagnitude:val_int(precision)];
		if (![NSThread isMainThread]) {
			[global_location_manager performSelectorOnMainThread:@selector(syncPrecisionMagnitude) withObject:nil waitUntilDone:YES];
		} else {
			[global_location_manager syncPrecisionMagnitude];
		}
		
		return alloc_null();
	} else {
		int ret = 1000;
		int acc = [global_location_manager->locationManager desiredAccuracy];
		if (acc == kCLLocationAccuracyBestForNavigation)
			ret = -1;
		else if (acc == kCLLocationAccuracyBest)
			ret = 0;
		else if (acc == kCLLocationAccuracyNearestTenMeters)
			ret = 1;
		else if (acc == kCLLocationAccuracyHundredMeters)
			ret = 2;
		else if (acc == kCLLocationAccuracyKilometer)
			ret = 3;
		else if (acc == kCLLocationAccuracyThreeKilometers)
			ret = 4;
		return alloc_int(ret);
	}
}

DEFINE_PRIM(cgeo_getset_precision, 1);

value cgeo_getset_distfilter(value df)
{
	if (!val_is_null(df))
	{
		val_check(df, float);
		[global_location_manager setDistanceFilter:val_float(df)];
		if (![NSThread isMainThread]) {
			[global_location_manager performSelectorOnMainThread:@selector(syncDistanceFilter) withObject:nil waitUntilDone:YES];
		} else {
			[global_location_manager syncDistanceFilter];
		}
		
		return alloc_null();
	} else {
		return alloc_float([global_location_manager->locationManager distanceFilter]);
	}
}

DEFINE_PRIM(cgeo_getset_distfilter, 1);

value cgeo_status()
{
	return alloc_int([global_location_manager status]);
}

DEFINE_PRIM(cgeo_status, 0);

extern "C" 
{
	
	int nekogap_geo_register_prims() { return 0; }
	
}