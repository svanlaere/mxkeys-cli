unit mxkeys_windows;

{$mode objfpc}{$H+}

interface

function WindowsHidOpen(
  out ErrorText: string
): Boolean;

procedure WindowsHidClose;

function WindowsHidWrite(
  const Buffer;
  Count: Integer;
  out ErrorText: string
): Boolean;

function WindowsHidRead(
  var Buffer;
  MaxCount: Integer;
  out BytesRead: Integer;
  out ErrorText: string
): Boolean;

procedure WindowsListHidInterfaces;

function WindowsHidDescription: string;

implementation

uses
  Windows,
  SysUtils;

const
  LOGITECH_VENDOR_ID = $046D;
  BOLT_PRODUCT_ID = $C548;

  HID_USAGE_PAGE_VENDOR = $FF00;

  DIGCF_PRESENT = $00000002;
  DIGCF_DEVICEINTERFACE = $00000010;

  HIDP_STATUS_SUCCESS = $00110000;

  HID_READ_TIMEOUT_MS = 100;
  HID_WRITE_TIMEOUT_MS = 1000;

type
  THIDDAttributes = packed record
    Size: ULONG;
    VendorID: USHORT;
    ProductID: USHORT;
    VersionNumber: USHORT;
  end;

  PHIDDAttributes = ^THIDDAttributes;

  THIDPCaps = packed record
    Usage: USHORT;
    UsagePage: USHORT;
    InputReportByteLength: USHORT;
    OutputReportByteLength: USHORT;
    FeatureReportByteLength: USHORT;
    Reserved: array[0..16] of USHORT;
    NumberLinkCollectionNodes: USHORT;
    NumberInputButtonCaps: USHORT;
    NumberInputValueCaps: USHORT;
    NumberInputDataIndices: USHORT;
    NumberOutputButtonCaps: USHORT;
    NumberOutputValueCaps: USHORT;
    NumberOutputDataIndices: USHORT;
    NumberFeatureButtonCaps: USHORT;
    NumberFeatureValueCaps: USHORT;
    NumberFeatureDataIndices: USHORT;
  end;

  THIDPPreparsedData = Pointer;

  TSPDeviceInterfaceData = packed record
    cbSize: DWORD;
    InterfaceClassGuid: TGUID;
    Flags: DWORD;
    Reserved: ULONG_PTR;
  end;

  TSPDeviceInterfaceDetailDataW = packed record
    cbSize: DWORD;
    DevicePath: array[0..0] of WideChar;
  end;

  PSPDeviceInterfaceDetailDataW =
    ^TSPDeviceInterfaceDetailDataW;

function SetupDiGetClassDevsW(
  ClassGuid: PGUID;
  Enumerator: PWideChar;
  hwndParent: HWND;
  Flags: DWORD
): THandle; stdcall; external 'setupapi.dll';

function SetupDiEnumDeviceInterfaces(
  DeviceInfoSet: THandle;
  DeviceInfoData: Pointer;
  const InterfaceClassGuid: TGUID;
  MemberIndex: DWORD;
  var DeviceInterfaceData: TSPDeviceInterfaceData
): BOOL; stdcall; external 'setupapi.dll';

function SetupDiGetDeviceInterfaceDetailW(
  DeviceInfoSet: THandle;
  var DeviceInterfaceData: TSPDeviceInterfaceData;
  DeviceInterfaceDetailData: PSPDeviceInterfaceDetailDataW;
  DeviceInterfaceDetailDataSize: DWORD;
  RequiredSize: PDWORD;
  DeviceInfoData: Pointer
): BOOL; stdcall; external 'setupapi.dll';

function SetupDiDestroyDeviceInfoList(
  DeviceInfoSet: THandle
): BOOL; stdcall; external 'setupapi.dll';

procedure HidD_GetHidGuid(
  var HidGuid: TGUID
); stdcall; external 'hid.dll';

function HidD_GetAttributes(
  HidDeviceObject: THandle;
  Attributes: PHIDDAttributes
): BOOL; stdcall; external 'hid.dll';

function HidD_GetPreparsedData(
  HidDeviceObject: THandle;
  var PreparsedData: THIDPPreparsedData
): BOOL; stdcall; external 'hid.dll';

function HidD_FreePreparsedData(
  PreparsedData: THIDPPreparsedData
): BOOL; stdcall; external 'hid.dll';

function HidP_GetCaps(
  PreparsedData: THIDPPreparsedData;
  var Capabilities: THIDPCaps
): LONG; stdcall; external 'hid.dll';

var
  DeviceHandle: THandle = INVALID_HANDLE_VALUE;
  DeviceDescription: string = '';

  InputReportLength: Word = 0;
  OutputReportLength: Word = 0;

function IsBoltDevice(
  Handle: THandle
): Boolean;
var
  Attributes: THIDDAttributes;
begin
  FillChar(
    Attributes,
    SizeOf(Attributes),
    0
  );

  Attributes.Size :=
    SizeOf(Attributes);

  Result :=
    HidD_GetAttributes(
      Handle,
      @Attributes
    ) and
    (Attributes.VendorID = LOGITECH_VENDOR_ID) and
    (Attributes.ProductID = BOLT_PRODUCT_ID);
end;

function GetHidCaps(
  Handle: THandle;
  out Caps: THIDPCaps
): Boolean;
var
  PreparsedData: THIDPPreparsedData;
begin
  FillChar(
    Caps,
    SizeOf(Caps),
    0
  );

  PreparsedData := nil;

  if not HidD_GetPreparsedData(
    Handle,
    PreparsedData
  ) then
    Exit(False);

  try
    Result :=
      HidP_GetCaps(
        PreparsedData,
        Caps
      ) = HIDP_STATUS_SUCCESS;
  finally
    HidD_FreePreparsedData(
      PreparsedData
    );
  end;
end;

function IsHidppCollection(
  const Caps: THIDPCaps
): Boolean;
begin
  Result :=
    (Caps.UsagePage = HID_USAGE_PAGE_VENDOR) and
    (Caps.Usage = $0002) and
    (Caps.InputReportByteLength = 20) and
    (Caps.OutputReportByteLength = 20);
end;

function OpenDevicePath(
  const DevicePath: UnicodeString;
  DesiredAccess: DWORD;
  UseOverlapped: Boolean
): THandle;
var
  Flags: DWORD;
begin
  Flags := 0;

  if UseOverlapped then
    Flags :=
      FILE_FLAG_OVERLAPPED;

  Result :=
    CreateFileW(
      PWideChar(DevicePath),
      DesiredAccess,
      FILE_SHARE_READ or FILE_SHARE_WRITE,
      nil,
      OPEN_EXISTING,
      Flags,
      0
    );
end;

function GetInterfacePath(
  DeviceInfoSet: THandle;
  var InterfaceData: TSPDeviceInterfaceData;
  out DevicePath: UnicodeString
): Boolean;
var
  DetailData: PSPDeviceInterfaceDetailDataW;
  RequiredSize: DWORD;
begin
  Result := False;
  DevicePath := '';
  RequiredSize := 0;

  SetupDiGetDeviceInterfaceDetailW(
    DeviceInfoSet,
    InterfaceData,
    nil,
    0,
    @RequiredSize,
    nil
  );

  if RequiredSize = 0 then
    Exit;

  GetMem(
    DetailData,
    RequiredSize
  );

  try
    FillChar(
      DetailData^,
      RequiredSize,
      0
    );

    {$IFDEF CPU64}
    DetailData^.cbSize := 8;
    {$ELSE}
    DetailData^.cbSize := 6;
    {$ENDIF}

    if not SetupDiGetDeviceInterfaceDetailW(
      DeviceInfoSet,
      InterfaceData,
      DetailData,
      RequiredSize,
      nil,
      nil
    ) then
      Exit;

    DevicePath :=
      UnicodeString(
        PWideChar(
          @DetailData^.DevicePath[0]
        )
      );

    Result := True;
  finally
    FreeMem(
      DetailData
    );
  end;
end;

function TryOpenHidInterface(
  const DevicePath: UnicodeString
): Boolean;
var
  Handle: THandle;
  Caps: THIDPCaps;
begin
  Result := False;

  Handle :=
    OpenDevicePath(
      DevicePath,
      GENERIC_READ or GENERIC_WRITE,
      True
    );

  if Handle = INVALID_HANDLE_VALUE then
    Exit;

  try
    if not IsBoltDevice(
      Handle
    ) then
      Exit;

    if not GetHidCaps(
      Handle,
      Caps
    ) then
      Exit;

    if not IsHidppCollection(
      Caps
    ) then
      Exit;

    DeviceHandle := Handle;
    Handle := INVALID_HANDLE_VALUE;

    InputReportLength :=
      Caps.InputReportByteLength;

    OutputReportLength :=
      Caps.OutputReportByteLength;

    DeviceDescription :=
      Format(
        'Windows HID (Usage Page $%.4x, Usage $%.4x, input %d, output %d)',
        [
          Caps.UsagePage,
          Caps.Usage,
          InputReportLength,
          OutputReportLength
        ]
      );

    Result := True;
  finally
    if Handle <> INVALID_HANDLE_VALUE then
      CloseHandle(
        Handle
      );
  end;
end;

function WindowsHidOpen(
  out ErrorText: string
): Boolean;
var
  HidGuid: TGUID;
  DeviceInfoSet: THandle;
  InterfaceData: TSPDeviceInterfaceData;
  DevicePath: UnicodeString;
  Index: DWORD;
begin
  Result := False;
  ErrorText := '';

  WindowsHidClose;

  HidD_GetHidGuid(
    HidGuid
  );

  DeviceInfoSet :=
    SetupDiGetClassDevsW(
      @HidGuid,
      nil,
      0,
      DIGCF_PRESENT or
      DIGCF_DEVICEINTERFACE
    );

  if DeviceInfoSet = INVALID_HANDLE_VALUE then
  begin
    ErrorText :=
      Format(
        'Unable to enumerate Windows HID devices. Error %d.',
        [GetLastError]
      );

    Exit;
  end;

  try
    Index := 0;

    while True do
    begin
      FillChar(
        InterfaceData,
        SizeOf(InterfaceData),
        0
      );

      InterfaceData.cbSize :=
        SizeOf(InterfaceData);

      if not SetupDiEnumDeviceInterfaces(
        DeviceInfoSet,
        nil,
        HidGuid,
        Index,
        InterfaceData
      ) then
      begin
        if GetLastError = ERROR_NO_MORE_ITEMS then
          Break;

        ErrorText :=
          Format(
            'Unable to enumerate HID interface %d. Error %d.',
            [
              Index,
              GetLastError
            ]
          );

        Exit;
      end;

      if GetInterfacePath(
        DeviceInfoSet,
        InterfaceData,
        DevicePath
      ) then
      begin
        if TryOpenHidInterface(
          DevicePath
        ) then
          Exit(True);
      end;

      Inc(Index);
    end;

    ErrorText :=
      'Logitech Bolt HID++ interface was not found.';
  finally
    SetupDiDestroyDeviceInfoList(
      DeviceInfoSet
    );
  end;
end;

procedure WindowsHidClose;
begin
  if DeviceHandle <> INVALID_HANDLE_VALUE then
  begin
    CancelIo(
      DeviceHandle
    );

    CloseHandle(
      DeviceHandle
    );

    DeviceHandle :=
      INVALID_HANDLE_VALUE;
  end;

  DeviceDescription := '';
  InputReportLength := 0;
  OutputReportLength := 0;
end;

function WindowsHidWrite(
  const Buffer;
  Count: Integer;
  out ErrorText: string
): Boolean;
var
  Overlapped: TOverlapped;
  EventHandle: THandle;
  BytesWritten: DWORD;
  WaitResult: DWORD;
  LastError: DWORD;
begin
  Result := False;
  ErrorText := '';

  if DeviceHandle = INVALID_HANDLE_VALUE then
  begin
    ErrorText :=
      'Windows HID device is not open.';

    Exit;
  end;

  EventHandle :=
    CreateEventW(
      nil,
      True,
      False,
      nil
    );

  if EventHandle = 0 then
  begin
    ErrorText :=
      Format(
        'Unable to create HID write event. Error %d.',
        [GetLastError]
      );

    Exit;
  end;

  try
    FillChar(
      Overlapped,
      SizeOf(Overlapped),
      0
    );

    Overlapped.hEvent :=
      EventHandle;

    BytesWritten := 0;

    if not WriteFile(
      DeviceHandle,
      Buffer,
      Count,
      BytesWritten,
      @Overlapped
    ) then
    begin
      LastError :=
        GetLastError;

      if LastError <> ERROR_IO_PENDING then
      begin
        ErrorText :=
          Format(
            'Windows HID write failed. Error %d.',
            [LastError]
          );

        Exit;
      end;

      WaitResult :=
        WaitForSingleObject(
          EventHandle,
          HID_WRITE_TIMEOUT_MS
        );

      case WaitResult of
        WAIT_OBJECT_0:
          begin
            if not GetOverlappedResult(
              DeviceHandle,
              Overlapped,
              BytesWritten,
              False
            ) then
            begin
              ErrorText :=
                Format(
                  'Windows HID write failed. Error %d.',
                  [GetLastError]
                );

              Exit;
            end;
          end;

        WAIT_TIMEOUT:
          begin
            CancelIo(
              DeviceHandle
            );

            WaitForSingleObject(
              EventHandle,
              INFINITE
            );

            ErrorText :=
              'Windows HID write timed out.';

            Exit;
          end;

      else
        begin
          CancelIo(
            DeviceHandle
          );

          WaitForSingleObject(
            EventHandle,
            INFINITE
          );

          ErrorText :=
            Format(
              'Windows HID write wait failed. Error %d.',
              [GetLastError]
            );

          Exit;
        end;
      end;
    end;

    if BytesWritten <> DWORD(Count) then
    begin
      ErrorText :=
        Format(
          'Windows HID write incomplete: %d of %d bytes written.',
          [
            BytesWritten,
            Count
          ]
        );

      Exit;
    end;

    Result := True;
  finally
    CloseHandle(
      EventHandle
    );
  end;
end;

function WindowsHidRead(
  var Buffer;
  MaxCount: Integer;
  out BytesRead: Integer;
  out ErrorText: string
): Boolean;
var
  Overlapped: TOverlapped;
  EventHandle: THandle;
  ReadCount: DWORD;
  WaitResult: DWORD;
  LastError: DWORD;
begin
  Result := False;
  BytesRead := 0;
  ErrorText := '';

  if DeviceHandle = INVALID_HANDLE_VALUE then
  begin
    ErrorText :=
      'Windows HID device is not open.';

    Exit;
  end;

  EventHandle :=
    CreateEventW(
      nil,
      True,
      False,
      nil
    );

  if EventHandle = 0 then
  begin
    ErrorText :=
      Format(
        'Unable to create HID read event. Error %d.',
        [GetLastError]
      );

    Exit;
  end;

  try
    FillChar(
      Overlapped,
      SizeOf(Overlapped),
      0
    );

    Overlapped.hEvent :=
      EventHandle;

    ReadCount := 0;

    if not ReadFile(
      DeviceHandle,
      Buffer,
      MaxCount,
      ReadCount,
      @Overlapped
    ) then
    begin
      LastError :=
        GetLastError;

      if LastError <> ERROR_IO_PENDING then
      begin
        ErrorText :=
          Format(
            'Windows HID read failed. Error %d.',
            [LastError]
          );

        Exit;
      end;

      WaitResult :=
        WaitForSingleObject(
          EventHandle,
          HID_READ_TIMEOUT_MS
        );

      case WaitResult of
        WAIT_OBJECT_0:
          begin
            if not GetOverlappedResult(
              DeviceHandle,
              Overlapped,
              ReadCount,
              False
            ) then
            begin
              ErrorText :=
                Format(
                  'Windows HID read failed. Error %d.',
                  [GetLastError]
                );

              Exit;
            end;
          end;

        WAIT_TIMEOUT:
          begin
            CancelIo(
              DeviceHandle
            );

            WaitForSingleObject(
              EventHandle,
              INFINITE
            );

            BytesRead := 0;
            ErrorText := '';

            Exit(True);
          end;

      else
        begin
          CancelIo(
            DeviceHandle
          );

          WaitForSingleObject(
            EventHandle,
            INFINITE
          );

          ErrorText :=
            Format(
              'Windows HID read wait failed. Error %d.',
              [GetLastError]
            );

          Exit;
        end;
      end;
    end;

    BytesRead :=
      Integer(ReadCount);

    Result := True;
  finally
    CloseHandle(
      EventHandle
    );
  end;
end;

procedure WindowsListHidInterfaces;
var
  HidGuid: TGUID;
  DeviceInfoSet: THandle;
  InterfaceData: TSPDeviceInterfaceData;
  DevicePath: UnicodeString;
  Handle: THandle;
  Attributes: THIDDAttributes;
  Caps: THIDPCaps;
  Index: DWORD;
begin
  HidD_GetHidGuid(
    HidGuid
  );

  DeviceInfoSet :=
    SetupDiGetClassDevsW(
      @HidGuid,
      nil,
      0,
      DIGCF_PRESENT or
      DIGCF_DEVICEINTERFACE
    );

  if DeviceInfoSet = INVALID_HANDLE_VALUE then
  begin
    WriteLn(
      'Unable to enumerate HID devices. Error ',
      GetLastError,
      '.'
    );

    Exit;
  end;

  try
    WriteLn(
      'Logitech Bolt HID collections'
    );

    WriteLn;

    Index := 0;

    while True do
    begin
      FillChar(
        InterfaceData,
        SizeOf(InterfaceData),
        0
      );

      InterfaceData.cbSize :=
        SizeOf(InterfaceData);

      if not SetupDiEnumDeviceInterfaces(
        DeviceInfoSet,
        nil,
        HidGuid,
        Index,
        InterfaceData
      ) then
      begin
        if GetLastError = ERROR_NO_MORE_ITEMS then
          Break;

        WriteLn(
          'Enumeration failed at interface ',
          Index,
          '. Error ',
          GetLastError,
          '.'
        );

        Exit;
      end;

      if GetInterfacePath(
        DeviceInfoSet,
        InterfaceData,
        DevicePath
      ) then
      begin
        Handle :=
          OpenDevicePath(
            DevicePath,
            0,
            False
          );

        if Handle <> INVALID_HANDLE_VALUE then
        begin
          try
            FillChar(
              Attributes,
              SizeOf(Attributes),
              0
            );

            Attributes.Size :=
              SizeOf(Attributes);

            if HidD_GetAttributes(
              Handle,
              @Attributes
            ) and
              (Attributes.VendorID = LOGITECH_VENDOR_ID) and
              (Attributes.ProductID = BOLT_PRODUCT_ID) then
            begin
              WriteLn(
                'Interface ',
                Index
              );

              WriteLn(
                '  VID:        ',
                IntToHex(
                  Attributes.VendorID,
                  4
                )
              );

              WriteLn(
                '  PID:        ',
                IntToHex(
                  Attributes.ProductID,
                  4
                )
              );

              if GetHidCaps(
                Handle,
                Caps
              ) then
              begin
                WriteLn(
                  '  UsagePage:  $',
                  IntToHex(
                    Caps.UsagePage,
                    4
                  )
                );

                WriteLn(
                  '  Usage:      $',
                  IntToHex(
                    Caps.Usage,
                    4
                  )
                );

                WriteLn(
                  '  Input:      ',
                  Caps.InputReportByteLength,
                  ' bytes'
                );

                WriteLn(
                  '  Output:     ',
                  Caps.OutputReportByteLength,
                  ' bytes'
                );

                WriteLn(
                  '  Feature:    ',
                  Caps.FeatureReportByteLength,
                  ' bytes'
                );
              end
              else
                WriteLn(
                  '  Unable to read HID capabilities.'
                );

              WriteLn(
                '  Path:       ',
                UTF8Encode(
                  DevicePath
                )
              );

              WriteLn;
            end;
          finally
            CloseHandle(
              Handle
            );
          end;
        end;
      end;

      Inc(Index);
    end;
  finally
    SetupDiDestroyDeviceInfoList(
      DeviceInfoSet
    );
  end;
end;

function WindowsHidDescription: string;
begin
  if DeviceDescription <> '' then
    Result :=
      DeviceDescription
  else
    Result :=
      'Windows HID';
end;

end.
