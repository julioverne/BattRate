#import <dlfcn.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <substrate.h>
#import <notify.h>

#define NSLog(...)

#define PLIST_PATH_Settings "/var/mobile/Library/Preferences/com.julioverne.battrate.plist"

static BOOL Enabled;

static BOOL isBlackScreen;
static BOOL onlyAC;

static int textColor;

static int kWidth = 40;
static int kHeight = 15;

static int kLocX = 5;
static int kLocY = 20;

static float kAlpha = 0.5f;
static float kAlphaText = 0.9f;
static float kRadius = 6;

static BOOL forceNewLocation;

static float kScreenW;
static float kScreenH;

static int intervalUp = 3;

@interface UIWindow ()
- (void)_setSecure:(BOOL)arg1;
@end
@interface UIApplication ()
- (UIDeviceOrientation)_frontMostAppOrientation;
@end

@interface BattRateWindow : UIWindow
@end
@implementation BattRateWindow
- (BOOL)_ignoresHitTest
{
	return YES;
}
+ (BOOL)_isSecure
{
	return YES;
}
@end

static NSString* getFormatMessage()
{
	@autoreleasepool {		
		NSDictionary *TweakPrefs = [[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:@{};
		return [TweakPrefs objectForKey:@"FormatMessage"]?:@"$Discharge mAh";
	}
}

@interface BattRate : NSObject
{
	UIWindow* springboardWindow;
	UILabel *label;
	UIView *backView;
	UIView *content;
}
@property (nonatomic, strong) UIWindow* springboardWindow;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIView *backView;
@property (nonatomic, strong) UIView *content;
+ (id)sharedInstance;
+ (BOOL)sharedInstanceExist;
+ (void)notifyOrientationChange;
- (void)firstload;
- (void)orientationChanged;
- (void)updateFrame;
@end

static void orientationChanged()
{
	[BattRate notifyOrientationChange];
}

static UIDeviceOrientation orientationOld;

@implementation BattRate
@synthesize springboardWindow, label, backView, content;
__strong static id _sharedObject;
+ (id)sharedInstance
{
	if (!_sharedObject) {
		_sharedObject = [[self alloc] init];
		[NSTimer scheduledTimerWithTimeInterval:intervalUp target:_sharedObject selector:@selector(update) userInfo:nil repeats:YES];
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("com.apple.springboard.screenchanged"), NULL, (CFNotificationSuspensionBehavior)0);
		CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, (CFNotificationCallback)&orientationChanged, CFSTR("UIWindowDidRotateNotification"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		
		[[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];

	}
	return _sharedObject;
}
+ (BOOL)sharedInstanceExist
{
	if (_sharedObject) {
		return YES;
	}
	return NO;
}
+ (void)notifyOrientationChange
{
	if([BattRate sharedInstanceExist]) {
		if (BattRate* NTShared = [BattRate sharedInstance]) {
			[NTShared orientationChanged];
		}
	}
}
- (void)firstload
{
	return;
}
-(id)init
{
	self = [super init];
	if(self != nil) {
		@try {
			kScreenW = [[UIScreen mainScreen] bounds].size.width;
			kScreenH = [[UIScreen mainScreen] bounds].size.height;
			
			springboardWindow = [[BattRateWindow alloc] initWithFrame:CGRectMake(0, 0, kWidth, kHeight)];
			springboardWindow.windowLevel = 9999999;
			[springboardWindow setHidden:NO];
			springboardWindow.alpha = 1;
			[springboardWindow _setSecure:YES];
			[springboardWindow setUserInteractionEnabled:NO];
			springboardWindow.layer.cornerRadius = kRadius;
			springboardWindow.layer.masksToBounds = YES;
			springboardWindow.layer.shouldRasterize  = NO;
			
			backView = [UIView new];
			backView.frame = CGRectMake(0, 0, springboardWindow.frame.size.width, springboardWindow.frame.size.height);
			backView.backgroundColor = [UIColor colorWithWhite: 0.50 alpha:1];
			backView.alpha = kAlpha; // 0.5f
			[(UIView *)springboardWindow addSubview:backView];
			
			content = [UIView new];
			content.alpha = kAlphaText;// 0.9f
			content.frame = CGRectMake(4, 0, springboardWindow.frame.size.width-8, springboardWindow.frame.size.height);
			label = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, content.frame.size.width, content.frame.size.height)];
			[self update];
			label.numberOfLines = 0;
			label.textColor = textColor==0?[UIColor whiteColor]:textColor==1?[UIColor blackColor]:[UIColor redColor];
			label.baselineAdjustment = (UIBaselineAdjustment)YES;
			label.adjustsFontSizeToFitWidth = YES;
			label.adjustsLetterSpacingToFitWidth = YES;
			label.textAlignment = NSTextAlignmentCenter;
			[content addSubview:label];
			[(UIView *)springboardWindow addSubview:content];
			
			[self orientationChanged];
			
		} @catch (NSException * e) {
			
		}
	}
	return self;
}
- (void)updateFrame
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateFrame) object:nil];
	[self performSelector:@selector(_updateFrame) withObject:nil afterDelay:0.3];
}
- (void)_updateFrame
{
	backView.alpha = kAlpha;
	content.alpha = kAlphaText;
	label.textColor = textColor==0?[UIColor whiteColor]:textColor==1?[UIColor blackColor]:[UIColor redColor];
	springboardWindow.layer.cornerRadius = kRadius;
	springboardWindow.frame = CGRectMake(0, 0, kWidth, kHeight);
	backView.frame = CGRectMake(0, 0, springboardWindow.frame.size.width, springboardWindow.frame.size.height);
	content.frame = CGRectMake(4, 0, springboardWindow.frame.size.width-8, springboardWindow.frame.size.height);
	label.frame = CGRectMake(0, 0, content.frame.size.width, content.frame.size.height);
	forceNewLocation = YES;
	[springboardWindow setHidden:NO];
	[self orientationChanged];
}

- (NSDictionary *)dicPrivateBatt
{
    static mach_port_t *s_kIOMasterPortDefault;
    static kern_return_t (*s_IORegistryEntryCreateCFProperties)(mach_port_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, UInt32 options);
    static mach_port_t (*s_IOServiceGetMatchingService)(mach_port_t masterPort, CFDictionaryRef matching CF_RELEASES_ARGUMENT);
    static CFMutableDictionaryRef (*s_IOServiceMatching)(const char *name);

    static CFMutableDictionaryRef g_powerSourceService;
    static mach_port_t g_platformExpertDevice;

    static BOOL foundSymbols = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void* handle = dlopen("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", RTLD_LAZY);
        s_IORegistryEntryCreateCFProperties = (kern_return_t (*)(mach_port_t, CFMutableDictionaryRef *, CFAllocatorRef, UInt32))dlsym(handle, "IORegistryEntryCreateCFProperties");
        s_kIOMasterPortDefault = (mach_port_t *)dlsym(handle, "kIOMasterPortDefault");
        s_IOServiceMatching =(CFMutableDictionaryRef (*)(const char *)) dlsym(handle, "IOServiceMatching");
        s_IOServiceGetMatchingService = (mach_port_t (*)(mach_port_t, CFDictionaryRef))dlsym(handle, "IOServiceGetMatchingService");
		
        if (s_IORegistryEntryCreateCFProperties && s_IOServiceMatching && s_IOServiceGetMatchingService) {
            g_powerSourceService = s_IOServiceMatching("IOPMPowerSource");
            g_platformExpertDevice = s_IOServiceGetMatchingService(*s_kIOMasterPortDefault, g_powerSourceService);
            foundSymbols = (g_powerSourceService && g_platformExpertDevice);
		}
    });
	
	

    if (! foundSymbols) return nil;
    
    CFMutableDictionaryRef prop = NULL;
    s_IORegistryEntryCreateCFProperties(g_platformExpertDevice, &prop, 0, 0);
    return prop ? ((NSDictionary *) CFBridgingRelease(prop)) : nil;
}

- (NSString *)timeFromSecs:(float)secs
{
    static NSDateComponentsFormatter *formatter = nil;
	if(!formatter) {
		formatter = [[NSDateComponentsFormatter alloc] init];
		formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
	}
	
    NSDate *now = [NSDate date];
	NSDate * date = [now dateByAddingTimeInterval:secs];
	
    NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitWeekOfMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond) fromDate:now toDate:date options:0];
	
    if (components.year > 0) {
        formatter.allowedUnits = NSCalendarUnitYear;
    } else if (components.month > 0) {
        formatter.allowedUnits = NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    } else if (components.weekOfMonth > 0) {
        formatter.allowedUnits = NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    } else if (components.day > 0) {
        formatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    } else if (components.hour > 0) {
        formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute;
    } else if (components.minute > 0) {
        formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
    } else {
        formatter.allowedUnits = NSCalendarUnitSecond;
    }
	
    return [NSString stringWithFormat:@"%@", [formatter stringFromDateComponents:components]];
}

- (void)update
{
	@autoreleasepool {
		
		BOOL canDisable = NO;
		
		canDisable = !Enabled || isBlackScreen;
		
		if(!canDisable) {
			if(onlyAC) {
				canDisable = [[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateUnplugged;
			}
		}
		
		if(canDisable) {
			if(springboardWindow && !springboardWindow.hidden) {
				[springboardWindow setHidden:YES];
			}
			return;
		}
		
		if(label&&springboardWindow) {
			
			[springboardWindow setHidden:NO];
			
			NSDictionary* dicBatt = [self dicPrivateBatt];
			
			//NSLog(@"** [BattRate]: dicPrivateBatt: %@", dicBatt);
			
			NSString* formatText = [getFormatMessage() copy];
			
			if([formatText rangeOfString:@"$Discharge"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$Discharge" withString:[NSString stringWithFormat:@"%@", dicBatt[@"InstantAmperage"]]];
			}
			
			if([formatText rangeOfString:@"$CycleCount"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$CycleCount" withString:[NSString stringWithFormat:@"%@", dicBatt[@"CycleCount"]]];
			}
			
			if([formatText rangeOfString:@"$DesignCapacity"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$DesignCapacity" withString:[NSString stringWithFormat:@"%@", dicBatt[@"DesignCapacity"]]];
			}
			
			if([formatText rangeOfString:@"$MaxCapacity"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$MaxCapacity" withString:[NSString stringWithFormat:@"%@", dicBatt[@"AppleRawMaxCapacity"]]];
			}
			if([formatText rangeOfString:@"$CurrentCapacity"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$CurrentCapacity" withString:[NSString stringWithFormat:@"%@", dicBatt[@"AppleRawCurrentCapacity"]]];
			}
			if([formatText rangeOfString:@"$AbsoluteCapacity"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$AbsoluteCapacity" withString:[NSString stringWithFormat:@"%@", dicBatt[@"AbsoluteCapacity"]]];
			}
			
			if([formatText rangeOfString:@"$Percent"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$Percent" withString:[NSString stringWithFormat:@"%@", dicBatt[@"CurrentCapacity"]]];
			}
			
			if([formatText rangeOfString:@"$BatteryVoltage"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$BatteryVoltage" withString:[NSString stringWithFormat:@"%.02f", [dicBatt[@"AppleRawBatteryVoltage"] intValue]/1000.0f]];
			}
			
			if([formatText rangeOfString:@"$BatteryTemperature"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$BatteryTemperature" withString:[NSString stringWithFormat:@"%.01f", [dicBatt[@"Temperature"] intValue]/100.0f]];
			}
			
			if([formatText rangeOfString:@"$TimeRemain"].location != NSNotFound) {
				float hoursLeft = 0.0f;
				float currentCapacity = [dicBatt[@"AppleRawCurrentCapacity"] floatValue];
				float maxCapacity = [dicBatt[@"AbsoluteCapacity"] floatValue];
				float currentDischargeRate = [dicBatt[@"InstantAmperage"] floatValue];
				if(currentDischargeRate > 0) {
					float remainCapacity = maxCapacity - currentCapacity;
					hoursLeft = remainCapacity / currentDischargeRate;
				} else if(currentDischargeRate < 0) {
					hoursLeft = currentCapacity / (currentDischargeRate * (-1));
				}
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$TimeRemain" withString:[self timeFromSecs:(hoursLeft * 3600)]];
			}
			
			if([formatText rangeOfString:@"$Line"].location != NSNotFound) {
				formatText = [formatText stringByReplacingOccurrencesOfString:@"$Line" withString:@"\n"];
			}
			
			label.text = formatText;
		}
	}
}
- (void)orientationChanged
{
	UIDeviceOrientation orientation = [[UIApplication sharedApplication] _frontMostAppOrientation];
	if(orientation == orientationOld && !forceNewLocation) {
		return;
	}
	forceNewLocation = NO;
	BOOL isLandscape;
	__block CGAffineTransform newTransform;
	__block int xLoc;
	__block int yLoc;
	#define DegreesToRadians(degrees) (degrees * M_PI / 180)
	switch (orientation) {
	case UIDeviceOrientationLandscapeRight: {			
			isLandscape = YES;
			yLoc = kLocX;
			xLoc = kLocY;
			newTransform = CGAffineTransformMakeRotation(-DegreesToRadians(90));
			break;
		}
	case UIDeviceOrientationLandscapeLeft: {
			isLandscape = YES;
			yLoc = (kScreenH-kWidth-kLocX);
			xLoc = (kScreenW-kHeight-kLocY);
			newTransform = CGAffineTransformMakeRotation(DegreesToRadians(90));
			break;
		}
		case UIDeviceOrientationPortraitUpsideDown: {
			isLandscape = NO;
			yLoc = (kScreenH-kHeight-kLocY);
			xLoc = kLocX;
			newTransform = CGAffineTransformMakeRotation(DegreesToRadians(180));
			break;
		}
		case UIDeviceOrientationPortrait:
	default: {
			isLandscape = NO;
			yLoc = kLocY;
			xLoc = (kScreenW-kWidth-kLocX);
			newTransform = CGAffineTransformMakeRotation(DegreesToRadians(0));
			break;
		}
    }
	[UIView animateWithDuration:0.3f animations:^{
		[springboardWindow setTransform:newTransform];
		CGRect frame = springboardWindow.frame;
		frame.origin.y = yLoc;
		frame.origin.x = xLoc;
		springboardWindow.frame = frame;
		orientationOld = orientation;
	} completion:nil];
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
	%orig;
	[[BattRate sharedInstance] firstload];	
}
%end

static void screenDisplayStatus(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo)
{
    uint64_t state;
    int token;
    notify_register_check("com.apple.iokit.hid.displayStatus", &token);
    notify_get_state(token, &state);
    notify_cancel(token);
    if(!state) {
		isBlackScreen = YES;
    } else {
		isBlackScreen = NO;
	}
}

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {		
		NSDictionary *TweakPrefs = [[[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSDictionary dictionary] copy];
		Enabled = (BOOL)[[TweakPrefs objectForKey:@"Enabled"]?:@YES boolValue];
		onlyAC = (BOOL)[[TweakPrefs objectForKey:@"onlyAC"]?:@NO boolValue];
		intervalUp = (int)[[TweakPrefs objectForKey:@"intervalUp"]?:@(3) intValue];
		int newtextColor = (int)[[TweakPrefs objectForKey:@"textColor"]?:@(0) intValue];
		int newkLocX = (int)[[TweakPrefs objectForKey:@"kLocX"]?:@(5) intValue];
		int newkLocY = (int)[[TweakPrefs objectForKey:@"kLocY"]?:@(20) intValue];
		int newkWidth = (int)[[TweakPrefs objectForKey:@"kWidth"]?:@(40) intValue];
		int newkHeight = (int)[[TweakPrefs objectForKey:@"kHeight"]?:@(15) intValue];
		float newkAlpha = (float)[[TweakPrefs objectForKey:@"kAlpha"]?:@(0.5) floatValue];
		float newkAlphaText = (float)[[TweakPrefs objectForKey:@"kAlphaText"]?:@(0.9) floatValue];
		float newkRadius = (float)[[TweakPrefs objectForKey:@"kRadius"]?:@(6) floatValue];
		
		BOOL needUpdateUI = NO;
		if(newkLocX!=kLocX || newkLocY!=kLocY || newkWidth!=kWidth || newkHeight!=kHeight || newkAlpha!=kAlpha || newkRadius!=kRadius || newtextColor!=textColor || newkAlphaText!=kAlphaText) {
			needUpdateUI = YES;
		}
		kLocX = newkLocX;
		kLocY = newkLocY;
		kWidth = newkWidth;
		kHeight = newkHeight;
		kAlpha = newkAlpha;
		kRadius = newkRadius;
		textColor = newtextColor;
		kAlphaText = newkAlphaText;
		if(needUpdateUI && [BattRate sharedInstanceExist]) {
			if (BattRate* NTShared = [BattRate sharedInstance]) {
				[NTShared updateFrame];
			}
		}
	}
}

%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, screenDisplayStatus, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, (CFNotificationSuspensionBehavior)0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.julioverne.battrate/Settings"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	settingsChanged(NULL, NULL, NULL, NULL, NULL);
	%init;
}