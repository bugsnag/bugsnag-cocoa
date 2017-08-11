//
//  BugsnagSystemInfo.h
//  Pods
//
//  Created by Jamie Lynch on 11/08/2017.
//
//

#import <Foundation/Foundation.h>

#define KSSystemField_AppStartTime "app_start_time"
#define KSSystemField_AppUUID "app_uuid"
#define KSSystemField_BootTime "boot_time"
#define KSSystemField_BundleID "CFBundleIdentifier"
#define KSSystemField_BundleName "CFBundleName"
#define KSSystemField_BundleShortVersion "CFBundleShortVersionString"
#define KSSystemField_BundleVersion "CFBundleVersion"
#define KSSystemField_CPUArch "cpu_arch"
#define KSSystemField_CPUType "cpu_type"
#define KSSystemField_CPUSubType "cpu_subtype"
#define KSSystemField_BinaryCPUType "binary_cpu_type"
#define KSSystemField_BinaryCPUSubType "binary_cpu_subtype"
#define KSSystemField_DeviceAppHash "device_app_hash"
#define KSSystemField_Executable "CFBundleExecutable"
#define KSSystemField_ExecutablePath "CFBundleExecutablePath"
#define KSSystemField_Jailbroken "jailbroken"
#define KSSystemField_KernelVersion "kernel_version"
#define KSSystemField_Machine "machine"
#define KSSystemField_Memory "memory"
#define KSSystemField_Model "model"
#define KSSystemField_OSVersion "os_version"
#define KSSystemField_ParentProcessID "parent_process_id"
#define KSSystemField_ProcessID "process_id"
#define KSSystemField_ProcessName "process_name"
#define KSSystemField_Size "size"
#define KSSystemField_SystemName "system_name"
#define KSSystemField_SystemVersion "system_version"
#define KSSystemField_TimeZone "time_zone"
#define KSSystemField_BuildType "build_type"

@interface BugsnagSystemInfo : NSObject // TODO remove unused methods etc

/** Get the system info.
 *
 * @return The system info.
 */
+ (NSDictionary*) systemInfo;
+ (NSString*) deviceAndAppHash;
+ (NSString *)modelName;
+ (NSString *)modelNumber;
+ (NSNumber *)usableMemory;

@end
