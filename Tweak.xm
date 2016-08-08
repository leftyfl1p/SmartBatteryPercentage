@interface BCBatteryDevice : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, copy) NSString *baseIdentifier; //9.1+; seems to give same info that identifier did on 9.0, although it still exists.
- (int)percentCharge;
- (void)setPercentCharge:(int)arg1;
@end

@interface BCBatteryDeviceController : NSObject
+ (id)sharedInstance;
- (id)connectedDevices;

//mine
- (void)updateDeviceReferences;

//handles percentage change 9.1+
//This method will call setPercentageCharge: for every connected device and notify the UI to update.
- (void)_handlePSChange;
@end

#define isiOS91Up (kCFCoreFoundationVersionNumber >= 1241.11)

static int realInternalPercentage = 0;
static int debugPercentage = 0;

//device references for 9.1+. 
static BCBatteryDevice *mainDevice = nil;
static BCBatteryDevice *caseDevice = nil;

%group iOS91Up

%hook BCBatteryDeviceController

- (id)init
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(BCBatteryDeviceControllerConnectedDevicesDidChange) name:@"BCBatteryDeviceControllerConnectedDevicesDidChange" object:nil];
	return %orig;
}

%new
- (void)BCBatteryDeviceControllerConnectedDevicesDidChange
{
	[self updateDeviceReferences];
	[self _handlePSChange];
}

//For whatever reason iterating through connnectedDevices inside setPercentageCharge: causes the entire device to hang on 9.3.
%new
- (void)updateDeviceReferences
{
	mainDevice = nil;
	caseDevice = nil;
	for(BCBatteryDevice *device in [self connectedDevices])
	{	
		if([[device baseIdentifier] isEqualToString:@"InternalBattery-0"])
		{
			mainDevice = device;
		}

		else if([[device name] isEqualToString:@"Case"])
		{
			caseDevice = device;
		}
	}

}

//debug
%new
- (void)simulateBatteryIncrease:(BOOL)increase
{
	increase? debugPercentage++ : debugPercentage--;
	[mainDevice setPercentCharge:0];
}

%end


%hook BCBatteryDevice

//overall this is a really weird place to do all of this stuff
- (void)setPercentCharge:(int)arg1
{
	//main device
	if([[self baseIdentifier] isEqualToString:@"InternalBattery-0"])
	{
		if(arg1 != 0) realInternalPercentage = arg1;
		//if(!caseDevice) HBLogDebug(@"no caseDevice present");

		//HBLogDebug(@"status:\n realInternalPercentage: %d\n [caseDevice percentCharge]: %d\n debugPercentage: %d", realInternalPercentage, [caseDevice percentCharge], debugPercentage);
		%orig(realInternalPercentage + (caseDevice ? [caseDevice percentCharge] : 0) + debugPercentage);

		//sending 0 is used to signal that the values have been updated.
		if(arg1 == 0) [[%c(BCBatteryDeviceController) sharedInstance] _handlePSChange];

		return;
	}

	//case device 
	else if([[self name] isEqualToString:@"Case"])
	{
		%orig;
		if(arg1 + realInternalPercentage != [mainDevice percentCharge])
		{
			/*
			Setting the device % charge to 0 is used as a way
			to notify the internal battery device that the
			case % value has been changed and it needs to be updated.
			*/
			[mainDevice setPercentCharge:0];
		}
		return;
	}

	//any other device (apple watch)
	return %orig;
}

%end


%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)arg1
{
	%orig;
	[[%c(BCBatteryDeviceController) sharedInstance] updateDeviceReferences];
	//Since this calls setPercentageCharge: for each connected device it will update the values
	[[%c(BCBatteryDeviceController) sharedInstance] _handlePSChange];
}

%end

%end//iOS91up group


%group iOS9

%hook BCBatteryDeviceController

-(id)init {

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(BCBatteryDeviceControllerConnectedDevicesDidChange) name:@"BCBatteryDeviceControllerConnectedDevicesDidChange" object:nil];

	return %orig;
}

%new
-(void)BCBatteryDeviceControllerConnectedDevicesDidChange {

	for(BCBatteryDevice *device in [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices]) {

		if([[device identifier] isEqualToString:@"InternalBattery-0"]) {

			/*
			setting the device % charge to 0 is used as a way
			to notify the internal battery device that the
			case % value has been changed and it needs to be updated.
			*/
			[device setPercentCharge:0];
		}

	}
}
%end


%hook BCBatteryDevice

- (void)setPercentCharge:(int)arg1 {
	
	int casePercentage = 0;

	//main battery
	if([[self identifier] isEqualToString:@"InternalBattery-0"]) {

		if(arg1 != 0) realInternalPercentage = arg1;

		for(BCBatteryDevice *device in [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices]) {
			
			//battery case.
			if([[device name] isEqualToString:@"Case"]) {
				casePercentage = [device percentCharge];
			}
		}

		if(arg1 == 0) {
			%orig(realInternalPercentage + casePercentage);
		} else {
			%orig(arg1 + casePercentage);
		}

	} else if ([[self name] isEqualToString:@"Case"]) {

		for(BCBatteryDevice *device in [[%c(BCBatteryDeviceController) sharedInstance] connectedDevices]) {

			if([[device identifier] isEqualToString:@"InternalBattery-0"]) {
				[device setPercentCharge:0];
			}
		}

		%orig;

	} else {
		%orig;
	}

}

%end

%end //iOS9 group


%ctor
{
	if(isiOS91Up) {
		%init(iOS91Up)
	} else {
		%init(iOS9);
	}
}