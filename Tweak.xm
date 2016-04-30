@interface BCBatteryDevice : NSObject
@property (nonatomic, readonly, copy) NSString *identifier;
-(int)percentCharge;
- (void)setPercentCharge:(int)arg1;
@property (nonatomic, copy) NSString *name;
@end

@interface BCBatteryDeviceController : NSObject
+ (id)sharedInstance;
- (id)connectedDevices;
@end

static int realInternalPercentage = 0;

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