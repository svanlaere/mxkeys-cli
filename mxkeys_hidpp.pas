unit mxkeys_hidpp;

{$mode objfpc}{$H+}

interface

type
  TBatteryState = (
    bsUnknown,
    bsDischarging,
    bsCharging,
    bsSlowCharging,
    bsFull,
    bsError
  );

  TMXDeviceInfo = record
    Slot: Byte;
    Name: string;
    BatteryPercent: Integer;
    BatteryState: TBatteryState;
  end;

function FindMXKeysS(
  out Info: TMXDeviceInfo;
  out ErrorText: string
): Boolean;

function BatteryStateText(State: TBatteryState): string;

implementation

uses
  SysUtils,
  mxkeys_transport;

const
  { Device we are looking for. }
  MX_KEYS_S_DEVICE_NAME = 'MX Keys S';

  { HID++ report types. }
  HIDPP_REPORT_LONG = $11;
  HIDPP_REPORT_LONG_SIZE = 20;

  { HID++ software identifier.
    The low nibble is echoed in responses and lets us match
    responses to requests sent by this application. }
  HIDPP_SOFTWARE_ID = $0B;

  { HID++ ROOT feature index is always zero. }
  HIDPP_ROOT_FEATURE_INDEX = $00;

  { ROOT function 0: GetFeature. }
  HIDPP_ROOT_GET_FEATURE = $00;

  { HID++ error response feature/sub-ID. }
  HIDPP_ERROR = $FF;

  { HID++ 2.0 feature IDs. }
  HIDPP_FEATURE_DEVICE_NAME = $0005;
  HIDPP_FEATURE_UNIFIED_BATTERY = $1004;

  { Device Name feature functions. }
  HIDPP_DEVICE_NAME_GET_LENGTH = $00;
  HIDPP_DEVICE_NAME_GET_NAME = $01;

  { Unified Battery feature functions. }
  HIDPP_UNIFIED_BATTERY_GET_STATUS = $01;

  { Bolt receiver device slots. }
  HIDPP_FIRST_DEVICE_SLOT = 1;
  HIDPP_LAST_DEVICE_SLOT = 6;

  { Maximum number of unrelated HID++ packets to ignore while
    waiting for the response belonging to our request. }
  HIDPP_MAX_RESPONSE_ATTEMPTS = 20;

  { Transport may return a buffer larger than a HID++ long report. }
  TRANSPORT_BUFFER_SIZE = 64;

  { Long HID++ reports contain 16 parameter bytes. }
  HIDPP_LONG_PARAMETER_OFFSET = 4;
  HIDPP_LONG_PARAMETER_COUNT = 16;

type
  THidppReport =
    array[0..HIDPP_REPORT_LONG_SIZE - 1] of Byte;

  TTransportBuffer =
    array[0..TRANSPORT_BUFFER_SIZE - 1] of Byte;

procedure InitDeviceInfo(out Info: TMXDeviceInfo);
begin
  Info := Default(TMXDeviceInfo);

  Info.Name := '';
  Info.BatteryPercent := -1;
  Info.BatteryState := bsUnknown;
end;

procedure InitReport(out Report: THidppReport);
begin
  Report := Default(THidppReport);
end;

function IsMatchingResponse(
  const Buffer: TTransportBuffer;
  BytesRead: Integer;
  Slot: Byte
): Boolean;
begin
  Result :=
    (BytesRead >= 7) and
    (Buffer[0] = HIDPP_REPORT_LONG) and
    (Buffer[1] = Slot) and
    ((Buffer[3] and $0F) = HIDPP_SOFTWARE_ID);
end;

function IsErrorResponse(
  const Report: THidppReport
): Boolean;
begin
  Result := Report[2] = HIDPP_ERROR;
end;

function HidppErrorText(
  const Report: THidppReport
): string;
begin
  Result := Format(
    'HID++ error $%.2x',
    [Report[5]]
  );
end;

procedure CopyResponse(
  const Buffer: TTransportBuffer;
  BytesRead: Integer;
  out Report: THidppReport
);
var
  CopyCount: Integer;
begin
  InitReport(Report);

  CopyCount := BytesRead;

  if CopyCount > SizeOf(Report) then
    CopyCount := SizeOf(Report);

  if CopyCount > 0 then
    Move(
      Buffer[0],
      Report[0],
      CopyCount
    );
end;

procedure BuildRequest(
  Slot: Byte;
  FeatureIndex: Byte;
  FunctionIndex: Byte;
  Param0: Byte;
  Param1: Byte;
  Param2: Byte;
  out Report: THidppReport
);
begin
  InitReport(Report);

  Report[0] := HIDPP_REPORT_LONG;
  Report[1] := Slot;
  Report[2] := FeatureIndex;

  Report[3] :=
    (FunctionIndex shl 4) or
    HIDPP_SOFTWARE_ID;

  Report[4] := Param0;
  Report[5] := Param1;
  Report[6] := Param2;
end;

function Exchange(
  Slot: Byte;
  FeatureIndex: Byte;
  FunctionIndex: Byte;
  Param0: Byte;
  Param1: Byte;
  Param2: Byte;
  out Response: THidppReport;
  out ErrorText: string
): Boolean;
var
  Request: THidppReport;
  Buffer: TTransportBuffer;
  BytesRead: Integer;
  Attempt: Integer;
begin
  Result := False;
  ErrorText := '';

  InitReport(Response);
  InitReport(Request);
  Buffer := Default(TTransportBuffer);

  BuildRequest(
    Slot,
    FeatureIndex,
    FunctionIndex,
    Param0,
    Param1,
    Param2,
    Request
  );

  if not TransportWrite(
    Request,
    SizeOf(Request),
    ErrorText
  ) then
    Exit;

  for Attempt := 1 to HIDPP_MAX_RESPONSE_ATTEMPTS do
  begin
    Buffer := Default(TTransportBuffer);
    BytesRead := 0;

    if not TransportRead(
      Buffer,
      SizeOf(Buffer),
      BytesRead,
      ErrorText
    ) then
      Exit;

    if not IsMatchingResponse(
      Buffer,
      BytesRead,
      Slot
    ) then
      Continue;

    CopyResponse(
      Buffer,
      BytesRead,
      Response
    );

    if IsErrorResponse(Response) then
    begin
      ErrorText := HidppErrorText(Response);
      Exit;
    end;

    Exit(True);
  end;

  ErrorText := 'No matching HID++ response.';
end;

function GetFeatureIndex(
  Slot: Byte;
  FeatureID: Word;
  out Index: Byte;
  out ErrorText: string
): Boolean;
var
  Response: THidppReport;
begin
  Result := False;
  Index := 0;
  ErrorText := '';

  InitReport(Response);

  if not Exchange(
    Slot,
    HIDPP_ROOT_FEATURE_INDEX,
    HIDPP_ROOT_GET_FEATURE,
    Byte(FeatureID shr 8),
    Byte(FeatureID and $FF),
    0,
    Response,
    ErrorText
  ) then
    Exit;

  Index := Response[4];

  if Index = 0 then
  begin
    ErrorText := Format(
      'HID++ feature $%.4x is not supported.',
      [FeatureID]
    );
    Exit;
  end;

  Result := True;
end;

function GetDeviceNameLength(
  Slot: Byte;
  FeatureIndex: Byte;
  out NameLength: Byte;
  out ErrorText: string
): Boolean;
var
  Response: THidppReport;
begin
  Result := False;
  NameLength := 0;
  ErrorText := '';

  InitReport(Response);

  if not Exchange(
    Slot,
    FeatureIndex,
    HIDPP_DEVICE_NAME_GET_LENGTH,
    0,
    0,
    0,
    Response,
    ErrorText
  ) then
    Exit;

  NameLength := Response[4];

  Result := True;
end;

function GetDeviceNameChunk(
  Slot: Byte;
  FeatureIndex: Byte;
  Offset: Byte;
  out Chunk: RawByteString;
  out ErrorText: string
): Boolean;
var
  Response: THidppReport;
  I: Integer;
begin
  Result := False;
  Chunk := '';
  ErrorText := '';

  InitReport(Response);

  if not Exchange(
    Slot,
    FeatureIndex,
    HIDPP_DEVICE_NAME_GET_NAME,
    Offset,
    0,
    0,
    Response,
    ErrorText
  ) then
    Exit;

  for I :=
    HIDPP_LONG_PARAMETER_OFFSET to
    HIDPP_LONG_PARAMETER_OFFSET +
      HIDPP_LONG_PARAMETER_COUNT - 1 do
  begin
    if Response[I] = 0 then
      Break;

    Chunk := Chunk + AnsiChar(Response[I]);
  end;

  Result := True;
end;

function ReadDeviceName(
  Slot: Byte;
  out DeviceName: string;
  out ErrorText: string
): Boolean;
var
  FeatureIndex: Byte;
  NameLength: Byte;
  Offset: Integer;
  Chunk: RawByteString;
  RawName: RawByteString;
begin
  Result := False;
  DeviceName := '';
  ErrorText := '';

  if not GetFeatureIndex(
    Slot,
    HIDPP_FEATURE_DEVICE_NAME,
    FeatureIndex,
    ErrorText
  ) then
    Exit;

  if not GetDeviceNameLength(
    Slot,
    FeatureIndex,
    NameLength,
    ErrorText
  ) then
    Exit;

  if NameLength = 0 then
  begin
    ErrorText :=
      'HID++ device returned an empty device name.';
    Exit;
  end;

  RawName := '';
  Offset := 0;

  while Offset < NameLength do
  begin
    Chunk := '';

    if not GetDeviceNameChunk(
      Slot,
      FeatureIndex,
      Byte(Offset),
      Chunk,
      ErrorText
    ) then
      Exit;

    if Chunk = '' then
      Break;

    RawName := RawName + Chunk;

    Inc(
      Offset,
      Length(Chunk)
    );
  end;

  if Length(RawName) > NameLength then
    SetLength(
      RawName,
      NameLength
    );

  DeviceName := string(RawName);

  if DeviceName = '' then
  begin
    ErrorText :=
      'Unable to read HID++ device name.';
    Exit;
  end;

  Result := True;
end;

function DecodeBatteryState(
  Value: Byte
): TBatteryState;
begin
  case Value of
    0:
      Result := bsDischarging;

    1:
      Result := bsCharging;

    2:
      Result := bsSlowCharging;

    3:
      Result := bsFull;

    4:
      Result := bsError;

    else
      Result := bsUnknown;
  end;
end;

function ReadUnifiedBattery(
  Slot: Byte;
  FeatureIndex: Byte;
  out Info: TMXDeviceInfo;
  out ErrorText: string
): Boolean;
var
  Response: THidppReport;
begin
  Result := False;
  ErrorText := '';

  InitReport(Response);

  if not Exchange(
    Slot,
    FeatureIndex,
    HIDPP_UNIFIED_BATTERY_GET_STATUS,
    0,
    0,
    0,
    Response,
    ErrorText
  ) then
    Exit;

  Info.Slot := Slot;
  Info.BatteryPercent := Response[4];
  Info.BatteryState :=
    DecodeBatteryState(Response[6]);

  Result := True;
end;

function FindMXKeysS(
  out Info: TMXDeviceInfo;
  out ErrorText: string
): Boolean;
var
  Slot: Byte;
  DeviceName: string;
  NameError: string;
  BatteryFeatureIndex: Byte;
  BatteryError: string;
begin
  Result := False;
  ErrorText := '';

  InitDeviceInfo(Info);

  for Slot :=
    HIDPP_FIRST_DEVICE_SLOT to
    HIDPP_LAST_DEVICE_SLOT do
  begin
    DeviceName := '';
    NameError := '';

    {
      Identify the paired device before querying its battery.

      This prevents another Logitech device with Unified Battery
      support from being mistaken for the MX Keys S.
    }
    if not ReadDeviceName(
      Slot,
      DeviceName,
      NameError
    ) then
      Continue;

    if not SameText(
      DeviceName,
      MX_KEYS_S_DEVICE_NAME
    ) then
      Continue;

    {
      The MX Keys S has been found.

      Preserve its identity before querying optional features.
    }
    InitDeviceInfo(Info);

    Info.Slot := Slot;
    Info.Name := DeviceName;

    BatteryFeatureIndex := 0;
    BatteryError := '';

    if not GetFeatureIndex(
      Slot,
      HIDPP_FEATURE_UNIFIED_BATTERY,
      BatteryFeatureIndex,
      BatteryError
    ) then
    begin
      ErrorText :=
        'MX Keys S found, but Unified Battery ' +
        '(0x1004) is not available.';
      Exit;
    end;

    if not ReadUnifiedBattery(
      Slot,
      BatteryFeatureIndex,
      Info,
      BatteryError
    ) then
    begin
      ErrorText :=
        'MX Keys S found, but battery status ' +
        'could not be read: ' +
        BatteryError;
      Exit;
    end;

    {
      ReadUnifiedBattery only changes battery-related fields and
      Slot, but explicitly retain the identity we already established.
    }
    Info.Name := DeviceName;

    Exit(True);
  end;

  ErrorText :=
    'MX Keys S not found on the Logi Bolt receiver.';
end;

function BatteryStateText(
  State: TBatteryState
): string;
begin
  case State of
    bsDischarging:
      Result := 'discharging';

    bsCharging:
      Result := 'charging';

    bsSlowCharging:
      Result := 'slow charging';

    bsFull:
      Result := 'full';

    bsError:
      Result := 'error';

    else
      Result := 'unknown';
  end;
end;

end.
