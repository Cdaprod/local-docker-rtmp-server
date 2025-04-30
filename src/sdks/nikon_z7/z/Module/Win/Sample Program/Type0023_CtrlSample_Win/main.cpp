//================================================================================================
// Copyright Nikon Corporation - All rights reserved
//
// View this file in a non-proportional font, tabs = 3
//================================================================================================

#include	<stdlib.h>
#include	<stdio.h>
#include	"Maid3.h"
#include	"Maid3d1.h"
#include	"CtrlSample.h"

LPMAIDEntryPointProc	g_pMAIDEntryPoint = NULL;
UCHAR	g_bFileRemoved = FALSE;
ULONG	g_ulCameraType = 0;	// CameraType

#if defined( _WIN32 )
	HINSTANCE	g_hInstModule = NULL;
#elif defined(__APPLE__)
	CFBundleRef gBundle = NULL;
#endif

//------------------------------------------------------------------------------------------------------------------------------------
//
int main()
{
#if defined( _WIN32 )
	char	ModulePath[MAX_PATH];
#elif defined(__APPLE__)
	char	ModulePath[PATH_MAX] = {0};
#endif
	LPRefObj	pRefMod = NULL;
	char	buf[256];
	ULONG	ulModID = 0, ulSrcID = 0;
	UWORD	wSel;
	BOOL	bRet;

	// Search for a Module-file like "Type0023.md3".
#if defined( _WIN32 )
	bRet = Search_Module( ModulePath );
#elif defined(__APPLE__)
	bRet = Search_Module( ModulePath );
#endif
	if ( bRet == FALSE ) {
		puts( "\"Type0023 Module\" is not found.\n" );
		return -1;
	}

	// Load the Module-file.
#if defined( _WIN32 )
	bRet = Load_Module( ModulePath );
#elif defined(__APPLE__)
	bRet = Load_Module( ModulePath );
#endif
	if ( bRet == FALSE ) {
		puts( "Failed in loading \"Type0023 Module\".\n" );
		return -1;
	}

	// Allocate memory for reference to Module object.
	pRefMod = (LPRefObj)malloc(sizeof(RefObj));
	if ( pRefMod == NULL ) {
		puts( "There is not enough memory." );
		return -1;
	}
	InitRefObj( pRefMod );

	// Allocate memory for Module object.
	pRefMod->pObject = (LPNkMAIDObject)malloc(sizeof(NkMAIDObject));
	if ( pRefMod->pObject == NULL ) {
		puts( "There is not enough memory." );
		if ( pRefMod != NULL )	free( pRefMod );
		return -1;
	}

	//	Open Module object
	pRefMod->pObject->refClient = (NKREF)pRefMod;
	bRet = Command_Open(	NULL,					// When Module_Object will be opend, "pParentObj" is "NULL".
								pRefMod->pObject,	// Pointer to Module_Object 
								ulModID );			// Module object ID set by Client
	if ( bRet == FALSE ) {
		puts( "Module object can't be opened.\n" );
		if ( pRefMod->pObject != NULL )	free( pRefMod->pObject );
		if ( pRefMod != NULL )	free( pRefMod );
		return -1;
	}

	//	Enumerate Capabilities that the Module has.
	bRet = EnumCapabilities( pRefMod->pObject, &(pRefMod->ulCapCount), &(pRefMod->pCapArray), NULL, NULL );
	if ( bRet == FALSE ) {
		puts( "Failed in enumeration of capabilities." );
		if ( pRefMod->pObject != NULL )	free( pRefMod->pObject );
		if ( pRefMod != NULL )	free( pRefMod );
		return -1;
	}

	//	Set the callback functions(ProgressProc, EventProc and UIRequestProc).
	bRet = SetProc( pRefMod );
	if ( bRet == FALSE ) {
		puts( "Failed in setting a call back function." );
		if ( pRefMod->pObject != NULL )	free( pRefMod->pObject );
		if ( pRefMod != NULL )	free( pRefMod );
		return -1;
	}

	//	Set the kNkMAIDCapability_ModuleMode.
	if( CheckCapabilityOperation( pRefMod, kNkMAIDCapability_ModuleMode, kNkMAIDCapOperation_Set )  ){
		bRet = Command_CapSet( pRefMod->pObject, kNkMAIDCapability_ModuleMode, kNkMAIDDataType_Unsigned, 
										(NKPARAM)kNkMAIDModuleMode_Controller, NULL, NULL);
		if ( bRet == FALSE ) {
			puts( "Failed in setting kNkMAIDCapability_ModuleMode." );
			return -1;
		}
	}

	// Module Command Loop
	do {
		printf( "\nSelect (1-6, 0)\n" );
		printf( " 1. Select Device            2. AsyncRate                3. IsAlive\n" );
		printf( " 4. Name                     5. ModuleType               6. Version\n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// Children
			{
#if defined(__APPLE__)
				CFAbsoluteTime duration = 1.0;
				CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
				do {
					// Run "main run loop" to pop "Device Added" event
					CFRunLoopRunInMode(kCFRunLoopDefaultMode,
									   0.01,
									   true);
				} while (CFAbsoluteTimeGetCurrent() - startTime <= duration);
#endif
				// Select Device
				ulSrcID = 0;	// 0 means Device count is zero. 
				bRet = SelectSource( pRefMod, &ulSrcID );
				if ( bRet == FALSE ) break;
				if( ulSrcID > 0 )
					bRet = SourceCommandLoop( pRefMod, ulSrcID );
			}
				break;
			case 2:// AsyncRate
				bRet = SetUnsignedCapability( pRefMod, kNkMAIDCapability_AsyncRate );
				break;
			case 3:// IsAlive
				bRet = SetBoolCapability( pRefMod, kNkMAIDCapability_IsAlive );
				break;
			case 4:// Name
				bRet = SetStringCapability( pRefMod, kNkMAIDCapability_Name );
				break;
			case 5:// ModuleType
				bRet = SetUnsignedCapability( pRefMod, kNkMAIDCapability_ModuleType );
				break;
			case 6:// Version
				bRet = SetUnsignedCapability( pRefMod, kNkMAIDCapability_Version );
				break;
			default:
				wSel = 0;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel > 0 && bRet == TRUE );

	// Close Module_Object
	bRet = Close_Module( pRefMod );
	if ( bRet == FALSE )
		puts( "Module object can not be closed.\n" );

	// Unload Module
#if defined( _WIN32 )
	FreeLibrary( g_hInstModule );
	g_hInstModule = NULL;
#elif defined(__APPLE__)
	if (gBundle != NULL)
	{
		CFBundleUnloadExecutable(gBundle);
		CFRelease(gBundle);
		gBundle = NULL;
	}
#endif

	// Free memory blocks allocated in this function.
	if ( pRefMod->pObject != NULL )	free( pRefMod->pObject );
	if ( pRefMod != NULL )	free( pRefMod );
	
	puts( "This sample program has terminated.\n" );
	return 0;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SourceCommandLoop( LPRefObj pRefMod, ULONG ulSrcID )
{
	LPRefObj	pRefSrc = NULL;
	char	buf[256];
	ULONG	ulItemID = 0;
	UWORD	wSel;
	BOOL	bRet = TRUE;

	pRefSrc = GetRefChildPtr_ID( pRefMod, ulSrcID );
	if ( pRefSrc == NULL ) {
		// Create Source object and RefSrc structure.
		if ( AddChild( pRefMod, ulSrcID ) == TRUE ) {
			printf("Source object is opened.\n");
		} else {
			printf("Source object can't be opened.\n");
			return FALSE;
		}
		pRefSrc = GetRefChildPtr_ID( pRefMod, ulSrcID );
	}

	// Get CameraType
	Command_CapGet( pRefSrc->pObject, kNkMAIDCapability_CameraType, kNkMAIDDataType_UnsignedPtr, (NKPARAM)&g_ulCameraType, NULL, NULL );

	// command loop
	do {
		printf( "\nSelect (1-9, 0)\n" );
		printf( " 1. Select Item Object       2. Camera settings(1)       3. Camera settings(2)\n" );
		printf( " 4. Movie Menu               5. Shooting Menu            6. Live View\n" );
		printf( " 7. Custom Menu              8. SB Menu                  9. Async\n" );
		printf( "10. Capture                 11. TerminateCapture        12. PreCapture\n" );
		printf( "13. CaptureAsync            14. AFCaptureAsync          15. DeviceReady\n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// Children
				// Select Item  Object
				ulItemID = 0;
				bRet = SelectItem( pRefSrc, &ulItemID );
				if( bRet == TRUE && ulItemID > 0 )
					bRet = ItemCommandLoop( pRefSrc, ulItemID );
				break;
			case 2:// Camera setting 1
				bRet = SetUpCamera1( pRefSrc );
				break;
			case 3:// Camera setting 2
				bRet = SetUpCamera2( pRefSrc );
				break;
			case 4:// Movie Menu
				bRet = SetMovieMenu(pRefSrc);
				break;
			case 5:// Shooting Menu
				bRet = SetShootingMenu(pRefSrc);
				break;
			case 6:// Live View
				bRet = SetLiveView( pRefSrc );
				break;
			case 7:// Custom Menu
				bRet = SetCustomSettings( pRefSrc );
				break;
			case 8:// SB Menu
				bRet = SetSBMenu( pRefSrc );
				break;
			case 9:// Async
				bRet = Command_Async( pRefMod->pObject );
				break;
			case 10:// Capture
				bRet = IssueProcess( pRefSrc, kNkMAIDCapability_Capture );
                if( bRet == TRUE )
                {
                    // Check SaveMedia
                    ULONG ulValue;
                    BOOL bRet2 = GetUnsignedCapability( pRefSrc, kNkMAIDCapability_SaveMedia, &ulValue );
                    if( bRet2 != FALSE && ulValue == 0 ) //Card
                    {
                        printf( "SaveMedia is Card. The addition of the Item Ofbject is not notified.\n" );
                        printf( "Enter '0' to exit.\n>" );
                        scanf( "%s", buf );
                    }
                }
				Command_Async( pRefSrc->pObject );
				break;
			case 11:// TerminateCapture
				bRet = TerminateCaptureCapability( pRefSrc );
				break;
			case 12:// PreCapture
				bRet = IssueProcess( pRefSrc, kNkMAIDCapability_PreCapture );
				break;
			case 13:// CaptureAsync
				bRet = IssueProcess( pRefSrc, kNkMAIDCapability_CaptureAsync );
				if (bRet == TRUE)
				{
					// Check SaveMedia
					ULONG ulValue;
					BOOL bRet2 = GetUnsignedCapability(pRefSrc, kNkMAIDCapability_SaveMedia, &ulValue);
					if (bRet2 != FALSE && ulValue == 0) //Card
					{
						printf("SaveMedia is Card. The addition of the Item Ofbject is not notified.\n");
						printf("Enter '0' to exit.\n>");
						scanf("%s", buf);
					}
				}
				break;
			case 14:// AFCaptureAsync
				bRet = IssueProcess( pRefSrc, kNkMAIDCapability_AFCaptureAsync );
				if( bRet == TRUE )
				{
					// Check SaveMedia
					ULONG ulValue;
					BOOL bRet2 = GetUnsignedCapability( pRefSrc, kNkMAIDCapability_SaveMedia, &ulValue );
					if( bRet2 != FALSE && ulValue == 0 ) //Card
					{
						printf( "SaveMedia is Card. The addition of the Item Ofbject is not notified.\n" );
						printf( "Enter '0' to exit.\n>" );
						scanf( "%s", buf );
					}
				}
				break;
			case 15:// DeviceReady
				bRet = IssueProcess( pRefSrc, kNkMAIDCapability_DeviceReady );
				break;
			default:
				wSel = 0;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
		WaitEvent();
	} while( wSel > 0 );

// Close Source_Object
	bRet = RemoveChild( pRefMod, ulSrcID );

	return TRUE;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SetUpCamera1( LPRefObj pRefSrc ) 
{
	char	buf[256];
	UWORD	wSel;
	BOOL	bRet = TRUE;

	do {
		// Wait for selection by user
		printf( "\nSelect the item you want to set up\n" );
		printf( " 1. IsAlive                  2. Name                      3. Interface\n" );
		printf( " 4. DataTypes                5. BatteryLevel              6. FlashMode\n" );
		printf( " 7. LockFocus                8. LockExposure              9. ExposureStatus\n" );
		printf( "10. ExposureMode            11. ShutterSpeed             12. Aperture\n" );
		printf( "13. FlexibleProgram         14. ExposureComp             15. MeteringMode\n" );
		printf( "16. FocusMode               17. FocusAreaMode            18. FocalLength\n" );
		printf( "19. ClockDateTime           20. SaveMedia                21. InternalFlashComp\n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// IsAlive
				bRet = SetBoolCapability( pRefSrc, kNkMAIDCapability_IsAlive );
				break;
			case 2:// Name
				bRet = SetStringCapability( pRefSrc, kNkMAIDCapability_Name );
				break;
			case 3:// Interface
				bRet = SetStringCapability( pRefSrc, kNkMAIDCapability_Interface );
				break;
			case 4:// DataTypes
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_DataTypes );
				break;
			case 5:// BatteryLevel
				bRet = SetIntegerCapability( pRefSrc, kNkMAIDCapability_BatteryLevel );
				break;
			case 6:// FlashMode
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_FlashMode );
				break;
			case 7:// LockFocus
				bRet = SetBoolCapability( pRefSrc, kNkMAIDCapability_LockFocus );
				break;
			case 8:// LockExposure
				bRet = SetBoolCapability( pRefSrc, kNkMAIDCapability_LockExposure );
				break;
			case 9:// ExposureStatus
				bRet = SetFloatCapability( pRefSrc, kNkMAIDCapability_ExposureStatus );
				break;
			case 10:// ExposureMode
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_ExposureMode );
				break;
			case 11:// ShutterSpeed(Exposure Time)
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_ShutterSpeed );
				break;
			case 12:// Aperture(F Number)
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_Aperture );
				break;
			case 13:// FlexibleProgram
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_FlexibleProgram );
				break;
			case 14:// ExposureCompensation
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_ExposureComp );
				break;
			case 15:// MeteringMode
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_MeteringMode );
				break;
			case 16:// FocusMode
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_FocusMode );
				break;
			case 17:// FocusAreaMode
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_FocusAreaMode );
				break;
			case 18:// FocalLength
				bRet = SetFloatCapability( pRefSrc, kNkMAIDCapability_FocalLength );
				break;
			case 19:// ClockDateTime
				bRet = SetDateTimeCapability( pRefSrc, kNkMAIDCapability_ClockDateTime );
				break;
			case 20:// SaveMedia
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_SaveMedia );
				break;
			case 21:// InternalFlashComp
				bRet = SetRangeCapability(pRefSrc, kNkMAIDCapability_InternalFlashComp);
				break;
 			default:
				wSel = 0;
				break;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel != 0 );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SetUpCamera2( LPRefObj pRefSrc ) 
{
	char	buf[256];
	UWORD	wSel;
	BOOL bRet = TRUE;

	do {
		// Wait for selection by user
		printf( "\nSelect the item you want to set up\n" );
		printf( " 1. LockCamera                          2. LensType\n" );
		printf( " 3. LensInfo                            4. UserComment\n");
		printf( " 5. EnableComment                       6. IsoControl\n");
		printf( " 7. NoiseReduction                      8. FlashISOAutoHighLimit\n");
		printf( " 9. FlickerReductionSetting            10. DiffractionCompensation\n");
		printf( "11. GetManualSettingLensData           12. ShootingMode\n");
		printf( "13. UserMode1                          14. UserMode2\n");
		printf( "15. UserMode3                          16. VibrationReduction\n");
		printf( "17. CameraType                         18. HDMIOutputDataDepth\n");
		printf( "19. HDRSaveIndividualImages            20. SaveCameraSetting\n");
		printf( "21. ExternalRecordingControl           22. MovieLogSetting\n");
		printf(" 0. Exit\n>");
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// LockCamera
				bRet = SetBoolCapability( pRefSrc, kNkMAIDCapability_LockCamera );
				break;
			case 2:// LensType
				bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_LensType);
				break;
			case 3:// LensInfo
				bRet = SetStringCapability( pRefSrc, kNkMAIDCapability_LensInfo );
				break;
			case 4:// UserComment
				bRet = SetStringCapability( pRefSrc, kNkMAIDCapability_UserComment );
				break;
			case 5:// EnableComment
				bRet = SetBoolCapability( pRefSrc, kNkMAIDCapability_EnableComment );
				break;
			case 6:// IsoControl 
				bRet = SetBoolCapability( pRefSrc, kNkMAIDCapability_IsoControl );
				break;
			case 7:// NoiseReduction 
				bRet = SetBoolCapability( pRefSrc, kNkMAIDCapability_NoiseReduction );
				break;
			case 8:// FlashISOAutoHighLimit
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_FlashISOAutoHighLimit );
				break;
			case 9:// FlickerReductionSetting
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_FlickerReductionSetting );
				break;
			case 10:// DiffractionCompensation
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_DiffractionCompensation );
				break;
			case 11:// GetManualSettingLensData
				bRet = GetManualSettingLensDataCapability(pRefSrc);
				break;
			case 12:// ShootingMode
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_ShootingMode);
				break;
			case 13:// UserMode1
				bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_UserMode1);
				break;
			case 14:// UserMode2
				bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_UserMode2);
				break;
			case 15:// UserMode3
				bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_UserMode3);
				break;
			case 16:// VibrationReduction
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_VibrationReduction);
				break;
			case 17:// CameraType
				bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_CameraType);
				break;
			case 18:// HDMIOutputDataDepth
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_HDMIOutputDataDepth);
				break;
			case 19:// HDRSaveIndividualImages
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_HDRSaveIndividualImages);
				break;
			case 20:// SaveCameraSetting
				bRet = IssueProcess(pRefSrc, kNkMAIDCapability_SaveCameraSetting);
				break;
			case 21:// ExternalRecordingControl
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_ExternalRecordingControl);
				break;
			case 22:// MovieLogSetting
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieLogSetting);
				break;


			default:
				wSel = 0;
				break;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel != 0 );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SetMovieMenu(LPRefObj pRefSrc)
{
	char	buf[256];
	UWORD	wSel;
	BOOL	bRet = TRUE;

	do {
		// Wait for selection by user
		printf("\nSelect the item you want to set up\n");
		printf(" 1. MoviePictureControl                  2. MoviePictureControlDataEx2\n");
		printf(" 3. DeleteMovieCustomPictureControl      4. MovieMeteringMode\n");
		printf(" 5. MovieActive_D_Lighting               6. MovieAttenuator\n");
		printf(" 7. MovieAutoDistortion                  8. MovieDiffractionCompensation\n");
		printf(" 9. MovieFileType                       10. MovieFocusMode\n");
		printf("11. MovieLogOutput                      12. MovieScreenSize\n");
		printf("13. MovieVibrationReduction             14. MovieVignetteControl\n");
		printf("15. RecordTimeCodes                     16. CountUpMethod\n");
		printf("17. DropFrame                           18. TimeCodeOrigin\n");
		printf("19. MovieAfAreaMode                     20. ElectronicVR\n");
		printf(" 0. Exit\n>");
		scanf("%s", buf);
		wSel = atoi(buf);

		switch (wSel)
		{
		case 1:// MoviePictureControl
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MoviePictureControl);
			break;
		case 2:// MoviePictureControlDataEx2 
			bRet = PictureControlDataCapability(pRefSrc, kNkMAIDCapability_MoviePictureControlDataEx2);
			break;
		case 3:// DeleteMovieCustomPictureControl
			bRet = DeleteCustomPictureControlCapability(pRefSrc, kNkMAIDCapability_DeleteMovieCustomPictureControl);
			break;
		case 4:// MovieMeteringMode
			bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_MovieMeteringMode);
			break;
		case 5:// MovieActive_D_Lighting
			bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_MovieActive_D_Lighting);
			break;
		case 6:// MovieAttenuator
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieAttenuator);
			break;
		case 7:// MovieAutoDistortion
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieAutoDistortion);
			break;
		case 8:// MovieDiffractionCompensation
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieDiffractionCompensation);
			break;
		case 9:// MovieFileType
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieFileType);
			break;
		case 10:// MovieFocusMode
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieFocusMode);
			break;
		case 11:// MovieLogOutput
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieLogOutput);
			break;
		case 12:// MovieScreenSize
			bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_MovieScreenSize);
			break;
		case 13:// MovieVibrationReduction
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieVibrationReduction);
			break;
		case 14:// MovieVignetteControl
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieVignetteControl);
			break;
		case 15:// RecordTimeCodes
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_RecordTimeCodes);
			break;
		case 16:// CountUpMethod
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_CountUpMethod);
			break;
		case 17:// DropFrame
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_DropFrame);
			break;
		case 18:// TimeCodeOrigin
			bRet = TimeCodeOriginCapability(pRefSrc);
			break;
		case 19:// MovieAfAreaMode
			bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieAfAreaMode);
			break;
		case 20:// ElectronicVR
			bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_ElectronicVR);
			break;

		default:
			wSel = 0;
			break;
		}
		if (bRet == FALSE) {
			printf("An Error occured. Enter '0' to exit.\n>");
			scanf("%s", buf);
			bRet = TRUE;
		}
	} while (wSel != 0);

	return bRet;
}

//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SetShootingMenu( LPRefObj pRefSrc ) 
{
	char	buf[256];
	UWORD	wSel;
	BOOL bRet = TRUE;

	do {
		// Wait for selection by user
		printf( "\nSelect the item you want to set up\n" );
		printf( " 1. CompressionLevel        2. ImageSize              3. RawImageSize\n" );
		printf( " 4. WBMode                  5. Sensitivity            6. WBTuneAuto\n" );
		printf( " 7. WBTuneIncandescent      8. WBFluorescentType      9. WBTuneFluorescent\n" );
		printf( "10. WBTuneSunny            11. WBTuneFlash           12. WBTuneShade\n" );
		printf( "13. WBTuneCloudy           14. WBPresetData          15. PictureControl\n" );
		printf( "16. PictureControlDataEx2  17. DeleteCustomPicCtrl   18. WBAutoType\n" );
		printf( "19. WBTuneNatural\n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// Compression Level
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_CompressionLevel );
				break;
			case 2:// ImageSize
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_ImageSize);
				break;
			case 3:// RawImageSize
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_RawImageSize);
				break;
			case 4:// WBMode
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_WBMode );
				break;
			case 5:// Sensitivity
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_Sensitivity );
				break;
			case 6:// WBTuneAuto
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_WBTuneAuto );
				break;
			case 7:// WBTuneIncandescent
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_WBTuneIncandescent );
				break;
			case 8:// WBFluorescentType
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_WBFluorescentType );
				break;
			case 9:// WBTuneFluorescent
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_WBTuneFluorescent );
				break;
			case 10:// WBTuneSunny 
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_WBTuneSunny );
				break;
			case 11:// WBTuneFlash
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_WBTuneFlash );
				break;
			case 12:// WBTuneShade
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_WBTuneShade );
				break;
			case 13:// WBTuneCloudy
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_WBTuneCloudy );
				break;
			case 14:// WBPresetData
				bRet = SetWBPresetDataCapability( pRefSrc );
				break;
			case 15:// PictureControl
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_PictureControl );
				break;
			case 16:// PictureControlDataEx2 
				bRet = PictureControlDataCapability(pRefSrc, kNkMAIDCapability_PictureControlDataEx2);
				break;
			case 17:// DeleteCustomPictureControl
				bRet = DeleteCustomPictureControlCapability(pRefSrc, kNkMAIDCapability_DeleteCustomPictureControl);
				break;
			case 18:// WBAutoType
				bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_WBAutoType);
				break;
			case 19:// WBTuneNatural
				bRet = SetRangeCapability(pRefSrc, kNkMAIDCapability_WBTuneNatural);
				break;
			default:
				wSel = 0;
				break;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel != 0 );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SetLiveView( LPRefObj pRefSrc ) 
{
	char	buf[256];
	UWORD	wSel;
	BOOL bRet = TRUE;

	do {
		// Wait for selection by user
		printf( "\nSelect the item you want to set up\n" );
		printf( " 1. LiveViewProhibit      2. LiveViewStatus             3. LiveViewImageSize\n" );
		printf( " 4. GetLiveViewImage      5. LiveViewImageStatus        6. MovRecInCardProhibit\n");
		printf( " 7. MovRecInCardStatus    8. LiveViewZoomArea           9. TrackingAFArea\n");
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			// ケース文でメニューの行き先を羅列するところ
			case 1:// LiveViewProhibit
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_LiveViewProhibit );
				break;
			case 2:// LiveViewStatus
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_LiveViewStatus );
				break;
			case 3:// LiveViewImageSize
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_LiveViewImageSize );
				break;
			case 4:// GetLiveViewImage
				bRet = GetLiveViewImageCapability( pRefSrc );
				break;
			case 5:// LiveViewImageStatus
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_LiveViewImageStatus);
				break;
			case 6:// MovRecInCardProhibit
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_MovRecInCardProhibit );
				break;
			case 7:// MovRecInCardStatus
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_MovRecInCardStatus );
				break;
			case 8:// LiveViewZoomArea
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_LiveViewZoomArea);
				break;
			case 9:// TrackingAFArea
				bRet = SetTrackingAFAreaCapability(pRefSrc);
				break;
			default:
				wSel = 0;
				break;

		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel != 0 );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SetCustomSettings( LPRefObj pRefSrc ) 
{
	char	buf[256];
	UWORD	wSel;
	BOOL bRet = TRUE;

	do {
		// Wait for selection by user
		printf("\nSelect a Custom Setting\n");
		printf( " 1. EVInterval                       2. BracketingVary\n" );
		printf( " 3. AFLockOnAcross                   4. FaceDetection\n" );
		printf( " 5. ExposureCompFlashUsed            6. ExpBaseHighlight\n");
		if ( g_ulCameraType == kNkMAIDCameraType_Z_7 || g_ulCameraType == kNkMAIDCameraType_Z_7_FU1 )
			printf( " 7. ElectronicFrontCurtainShutter    8. AFcPriority\n");
		else
			printf( " 7. ElectronicFrontCurtainShutterEx  8. AFcPriority\n");

		printf( " 9. ApplyLiveViewSetting            10. DetectionPeaking\n");
		printf( "11. HighlightBrightness             12. LowLightAF\n");
		printf( "13. MovieAfSpeed                    14. MovieAfSpeedWhenToApply\n");
		printf( "15. MovieAfTrackingSensitivity\n");
		

		printf(" 0. Exit\n>");
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// EVInterval
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_EVInterval );
				break;
			case 2:// BracketingVary
				bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_BracketingVary );
				break;
			case 3:// AFLockOnAcross
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_AFLockOnAcross );
				break;
			case 4:// FaceDetection
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_FaceDetection );
				break;
			case 5:// ExposureCompFlashUsed
				bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_ExposureCompFlashUsed );
				break;
			case 6:// ExpBaseHighlight
				bRet = SetRangeCapability( pRefSrc, kNkMAIDCapability_ExpBaseHighlight );
				break;
			case 7:// ElectronicFrontCurtainShutter
				   // ElectronicFrontCurtainShutterEx
				if (g_ulCameraType == kNkMAIDCameraType_Z_7 || g_ulCameraType == kNkMAIDCameraType_Z_7_FU1)
				{
					bRet = SetUnsignedCapability(pRefSrc, kNkMAIDCapability_ElectronicFrontCurtainShutter);
				}
				else
				{
					bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_ElectronicFrontCurtainShutterEx);
				}
				break;
			case 8:// AFcPriority
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_AFcPriority);
				break;
			case 9:// ApplyLiveViewSetting
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_ApplyLiveViewSetting);
				break;
			case 10:// DetectionPeaking
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_DetectionPeaking);
				break;
			case 11:// HighlightBrightness
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_HighlightBrightness);
				break;
			case 12:// LowLightAF
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_LowLightAF);
				break;
			case 13:// MovieAfSpeed
				bRet = SetRangeCapability(pRefSrc, kNkMAIDCapability_MovieAfSpeed);
				break;
			case 14:// MovieAfSpeedWhenToApply
				bRet = SetEnumCapability(pRefSrc, kNkMAIDCapability_MovieAfSpeedWhenToApply);
				break;
			case 15:// MovieAfTrackingSensitivity
				bRet = SetRangeCapability(pRefSrc, kNkMAIDCapability_MovieAfTrackingSensitivity);
				break;
			default:
				wSel = 0;
				break;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel != 0 );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL SetSBMenu( LPRefObj pRefSrc )
{
	char	buf[256];
	UWORD	wSel;
	BOOL bRet = TRUE;

	do {
		// Wait for selection by user
		printf( "\nSelect the item you want to set up\n" );
		printf( " 1. SBWirelessMode               2. SBWirelessMultipleFlashMode\n" );
		printf( " 3. SBUsableGroup                4. WirelessCLSEntryMode\n");
		printf( " 5. SBPINCode                    6. RadioMultipleFlashChannel\n");
		printf( " 7. OpticalMultipleFlashChannel  8. FlashRangeDisplay\n");
		printf( " 9. AllTestFiringDisable        10. SBSettingMemberLock\n");
		printf( "11. SBIntegrationFlashReady     12. GetSBHandles\n" );
		printf( "13. GetSBAttrDesc               14. SBAttrValue\n");
		printf( "15. GetSBGroupAttrDesc          16. SBGroupAttrValue\n");
		printf( "17. TestFlash\n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			// ケース文でメニューの行き先を羅列するところ
		case 1:// SBWirelessMode
			bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_SBWirelessMode );
			break;
		case 2:// SBWirelessMultipleFlashMode
			bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_SBWirelessMultipleFlashMode );
			break;
		case 3:// SBUsableGroup
			bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_SBUsableGroup );
			break;
		case 4:// WirelessCLSEntryMode
			bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_WirelessCLSEntryMode );
			break;
		case 5:// SBPINCode
			bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_SBPINCode );
			break; 
		case 6:// RadioMultipleFlashChannel
			bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_RadioMultipleFlashChannel );
			break;
		case 7:// OpticalMultipleFlashChannel
			bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_OpticalMultipleFlashChannel );
			break;
		case 8:// FlashRangeDisplay
			bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_FlashRangeDisplay );
			break;
		case 9:// AllTestFiringDisable
			bRet = SetUnsignedCapability( pRefSrc, kNkMAIDCapability_AllTestFiringDisable );
			break;
		case 10:// SBSettingMemberLock
			bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_SBSettingMemberLock );
			break;
		case 11:// SBIntegrationFlashReady
			bRet = SetEnumCapability( pRefSrc, kNkMAIDCapability_SBIntegrationFlashReady );
			break;
		case 12:// GetSBHandles
			bRet = GetSBHandlesCapability( pRefSrc );
			break;
		case 13:// GetSBAttrDesc
			bRet = GetSBAttrDescCapability( pRefSrc );
			break;
		case 14:// SBAttrValue
			bRet = SBAttrValueCapability( pRefSrc );
			break;
		case 15:// GetSBGroupAttrDesc
			bRet = GetSBGroupAttrDescCapability( pRefSrc );
			break;
		case 16:// SBGroupAttrValue
			bRet = SBGroupAttrValueCapability( pRefSrc );
			break;
		case 17:// TestFlash
			bRet = TestFlashCapability( pRefSrc );
			break;
			default:
				wSel = 0;
				break;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel != 0 );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL ItemCommandLoop( LPRefObj pRefSrc, ULONG ulItmID )
{
	ULONG	ulDataType = 0;
	LPRefObj	pRefItm = NULL;
	char	buf[256];
	UWORD	wSel;
	BOOL	bRet = TRUE;

	pRefItm = GetRefChildPtr_ID( pRefSrc, ulItmID );
	if ( pRefItm == NULL ) {
		// Create Item object and RefSrc structure.
		if ( AddChild( pRefSrc, ulItmID ) == TRUE ) {
			printf("Item object is opened.\n");
		} else {
			printf("Item object can't be opened.\n");
			return FALSE;
		}
		pRefItm = GetRefChildPtr_ID( pRefSrc, ulItmID );
	}

	// command loop
	do {
	
		printf( "\nSelect (1-7, 0)\n" );
		printf( " 1. Select Data Object       2. Delete                   3. IsAlive\n" );
		printf( " 4. Name                     5. DataTypes                6. DateTime\n" );
		printf( " 7. StoredBytes\n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// Show Children
				// Select Data Object
				ulDataType = 0;
				bRet = SelectData( pRefItm, &ulDataType );
				if ( bRet == FALSE )	return FALSE;
				if ( ulDataType == kNkMAIDDataObjType_Image )
				{
					// reset file removed flag
					g_bFileRemoved = FALSE;
					bRet = ImageCommandLoop( pRefItm, ulDataType );
					// If the image data was stored in DRAM, the item has been removed after reading image.
					if ( g_bFileRemoved ) {
						RemoveChild( pRefSrc, ulItmID );
						pRefItm = NULL;
					}
				}
				else if ( ulDataType == kNkMAIDDataObjType_Video )
				{
					// reset file removed flag
					g_bFileRemoved = FALSE;
					bRet = MovieCommandLoop( pRefItm, ulDataType );
					if ( g_bFileRemoved ) {
						RemoveChild( pRefSrc, ulItmID );
						pRefItm = NULL;
					}
				}
				else if ( ulDataType == kNkMAIDDataObjType_Thumbnail )
				{
					bRet = ThumbnailCommandLoop( pRefItm, ulDataType );
				}
				if ( bRet == FALSE )	return FALSE;
				break;
			case 2:// Delete
				ulDataType = 0;
				bRet = CheckDataType( pRefItm, &ulDataType );
				if ( bRet == FALSE )
				{
					puts( "Movie object is not supported.\n" );
					break;
				}
				bRet = DeleteDramCapability( pRefItm, ulItmID );
				if ( g_bFileRemoved )
				{
					// If Delete was succeed, Item object must be closed. 
					RemoveChild( pRefSrc, ulItmID );
					pRefItm = NULL;
				}
				break;
			case 3:// IsAlive
				bRet = SetBoolCapability( pRefItm, kNkMAIDCapability_IsAlive );
				break;
			case 4:// Name
				bRet = SetStringCapability( pRefItm, kNkMAIDCapability_Name );
				break;
			case 5:// DataTypes
				bRet = SetUnsignedCapability( pRefItm, kNkMAIDCapability_DataTypes );
				break;
			case 6:// DateTime
				bRet = SetDateTimeCapability( pRefItm, kNkMAIDCapability_DateTime );
				break;
			case 7:// StoredBytes
				bRet = SetUnsignedCapability( pRefItm, kNkMAIDCapability_StoredBytes );
				break;
			default:
				wSel = 0;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel > 0 && pRefItm != NULL );

	if ( pRefItm != NULL ) {
		// If the item object remains, close it and remove from parent link.
		bRet = RemoveChild( pRefSrc, ulItmID );
	}

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL ImageCommandLoop( LPRefObj pRefItm, ULONG ulDatID )
{
	LPRefObj	pRefDat = NULL;
	char	buf[256];
	UWORD	wSel;
	BOOL	bRet = TRUE;

	pRefDat = GetRefChildPtr_ID( pRefItm, ulDatID );
	if ( pRefDat == NULL ) {
		// Create Image object and RefSrc structure.
		if ( AddChild( pRefItm, ulDatID ) == TRUE ) {
			printf("Image object is opened.\n");
		} else {
			printf("Image object can't be opened.\n");
			return FALSE;
		}
		pRefDat = GetRefChildPtr_ID( pRefItm, ulDatID );
	}

	// command loop
	do {
		printf( "\nSelect (1-6, 0)\n" );
		printf( " 1. IsAlive                  2. Name                     3. StoredBytes\n" );
		printf( " 4. Pixels                   5. RawJpegImageStatus       6. Acquire\n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// IsAlive
				bRet = SetBoolCapability( pRefDat, kNkMAIDCapability_IsAlive );
				break;
			case 2:// Name
				bRet = SetStringCapability( pRefDat, kNkMAIDCapability_Name );
				break;
			case 3:// StoredBytes
				bRet = SetUnsignedCapability( pRefDat, kNkMAIDCapability_StoredBytes );
				break;
			case 4:// Show Pixels
				// Get to know how many pixels there are in this image.
				bRet = SetSizeCapability( pRefDat, kNkMAIDCapability_Pixels );
				break;
			case 5:// RawJpegImageStatus
				bRet = SetUnsignedCapability( pRefDat, kNkMAIDCapability_RawJpegImageStatus );
				break;
			case 6:// Acquire
				bRet = IssueAcquire(pRefDat);
				// The item has been possibly removed.
				break;
			default:
				wSel = 0;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel > 0 && g_bFileRemoved == FALSE );

// Close Image_Object
	bRet = RemoveChild( pRefItm, ulDatID );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL MovieCommandLoop( LPRefObj pRefItm, ULONG ulDatID )
{
	LPRefObj	pRefDat = NULL;
	char	buf[256];
	UWORD	wSel;
	BOOL	bRet = TRUE;

	pRefDat = GetRefChildPtr_ID( pRefItm, ulDatID );
	if ( pRefDat == NULL ) {
		// Create Movie object and RefSrc structure.
		if ( AddChild( pRefItm, ulDatID ) == TRUE ) {
			printf("Movie object is opened.\n");
		} else {
			printf("Movie object can't be opened.\n");
			return FALSE;
		}
		pRefDat = GetRefChildPtr_ID( pRefItm, ulDatID );
	}

	// command loop
	do {
		printf( "\nSelect (1-5, 0)\n" );
		printf( " 1. IsAlive                  2. Name                     3. StoredBytes\n" );
		printf( " 4. Pixels                   5. GetVideoImageEx		  6. GetRecordingInfo\n" );
		printf( " 0. Exit\n>" );
		scanf("%s", buf);
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// IsAlive
				bRet = SetBoolCapability( pRefDat, kNkMAIDCapability_IsAlive );
				break;
			case 2:// Name
				bRet = SetStringCapability( pRefDat, kNkMAIDCapability_Name );
				break;
			case 3:// StoredBytes
				bRet = SetUnsignedCapability( pRefDat, kNkMAIDCapability_StoredBytes );
				break;
			case 4:// Show Pixels
				// Get to know how many pixels there are in this image.
				bRet = SetSizeCapability( pRefDat, kNkMAIDCapability_Pixels );
				break;
			case 5:// GetVideoImageEx
				bRet = GetVideoImageExCapability(pRefDat, kNkMAIDCapability_GetVideoImageEx);
				// The item has been possibly removed.
				break;
			case 6:// GetRecordingInfo
				bRet = GetRecordingInfoCapability(pRefDat);
				break;
			default:
				wSel = 0;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel > 0 && g_bFileRemoved == FALSE );

// Close Movie_Object
	bRet = RemoveChild( pRefItm, ulDatID );

	return bRet;
}
//------------------------------------------------------------------------------------------------------------------------------------
//
BOOL ThumbnailCommandLoop( LPRefObj pRefItm, ULONG ulDatID )
{
	LPRefObj	pRefDat = NULL;
	char	buf[256];
	UWORD	wSel;
	BOOL	bRet = TRUE;

	pRefDat = GetRefChildPtr_ID( pRefItm, ulDatID );
	if ( pRefDat == NULL ) {
		// Create Thumbnail object and RefSrc structure.
		if ( AddChild( pRefItm, ulDatID ) == TRUE ) {
			printf("Thumbnail object is opened.\n");
		} else {
			printf("Thumbnail object can't be opened.\n");
			return FALSE;
		}
		pRefDat = GetRefChildPtr_ID( pRefItm, ulDatID );
	}

	// command loop
	do {
		printf( "\nSelect (1-5, 0)\n" );
		printf( " 1. IsAlive                  2. Name                     3. StoredBytes\n" );
		printf( " 4. Pixels                   5. Acquire \n" );
		printf( " 0. Exit\n>" );
		scanf( "%s", buf );
		wSel = atoi( buf );

		switch( wSel )
		{
			case 1:// IsAlive
				bRet = SetBoolCapability( pRefDat, kNkMAIDCapability_IsAlive );
				break;
			case 2:// Name
				bRet = SetStringCapability( pRefDat, kNkMAIDCapability_Name );
				break;
			case 3:// StoredBytes
				bRet = SetUnsignedCapability( pRefDat, kNkMAIDCapability_StoredBytes );
				break;
			case 4:// Pixels
				// Get to know how many pixels there are in this image.
				bRet = SetSizeCapability( pRefDat, kNkMAIDCapability_Pixels );
				break;
			case 5:// Acquire
				bRet = IssueAcquire( pRefDat );
				break;
			default:
				wSel = 0;
		}
		if ( bRet == FALSE ) {
			printf( "An Error occured. Enter '0' to exit.\n>" );
			scanf( "%s", buf );
			bRet = TRUE;
		}
	} while( wSel > 0 );

// Close Thumbnail_Object
	bRet = RemoveChild( pRefItm, ulDatID );

	return bRet;
}

//------------------------------------------------------------------------------------------------------------------------------------
//
