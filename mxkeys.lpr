program mxkeys;

{$mode objfpc}{$H+}

uses
  SysUtils,
  mxkeys_transport,
  mxkeys_hidpp,
  mxkeys_config,
  mxkeys_notify;

procedure ShowStatus(
  const Info: TMXDeviceInfo
);
begin
  if Info.Name <> '' then
    WriteLn(
      'Device: ',
      Info.Name
    );

  WriteLn(
    'Battery: ',
    Info.BatteryPercent,
    '%'
  );

  WriteLn(
    'State: ',
    BatteryStateText(
      Info.BatteryState
    )
  );

  WriteLn(
    'Slot: ',
    Info.Slot
  );

  WriteLn(
    'Transport: ',
    TransportDescription
  );
end;

function HasParameter(
  const Parameter: string
): Boolean;
var
  I: Integer;
begin
  Result := False;

  for I := 1 to ParamCount do
  begin
    if SameText(
      ParamStr(I),
      Parameter
    ) then
      Exit(True);
  end;
end;

function BatteryIsLow(
  const Info: TMXDeviceInfo
): Boolean;
begin
  Result :=
    (Info.BatteryPercent >= 0) and
    (Info.BatteryPercent <= WarningThreshold) and
    (Info.BatteryState = bsDischarging);
end;

procedure ShowBatteryNotification(
  const Info: TMXDeviceInfo
);
var
  ErrorText: string;
begin
  ErrorText := '';

  if not Notify(
    Info.Name,
    Format(
      'Battery is low: %d%%.',
      [Info.BatteryPercent]
    ),
    ErrorText
  ) then
  begin
    if ErrorText <> '' then
      WriteLn(
        StdErr,
        ErrorText
      );
  end;
end;

procedure ShowTestNotification(
  const Info: TMXDeviceInfo
);
var
  ErrorText: string;
begin
  ErrorText := '';

  if not Notify(
    Info.Name,
    Format(
      'Battery is at %d%%.',
      [Info.BatteryPercent]
    ),
    ErrorText
  ) then
  begin
    if ErrorText <> '' then
      WriteLn(
        StdErr,
        ErrorText
      );
  end;
end;

procedure Run;
var
  Info: TMXDeviceInfo;
  ErrorText: string;
  ShowStatusRequested: Boolean;
  TestNotificationRequested: Boolean;
  DiagnosticMode: Boolean;
begin
  Info := Default(TMXDeviceInfo);
  ErrorText := '';

  if HasParameter(
    '--list-hid'
  ) then
  begin
    TransportListHidInterfaces;
    Exit;
  end;

  ShowStatusRequested :=
    HasParameter(
      '--status'
    );

  TestNotificationRequested :=
    HasParameter(
      '--test-notification'
    );

  DiagnosticMode :=
    ShowStatusRequested or
    TestNotificationRequested;

  if not TransportOpen(
    ErrorText
  ) then
  begin
    if DiagnosticMode and
       (ErrorText <> '') then
      WriteLn(
        StdErr,
        ErrorText
      );

    Exit;
  end;

  try
    if not FindMXKeysS(
      Info,
      ErrorText
    ) then
    begin
      if DiagnosticMode and
         (ErrorText <> '') then
        WriteLn(
          StdErr,
          ErrorText
        );

      Exit;
    end;

    if ShowStatusRequested then
      ShowStatus(
        Info
      );

    if TestNotificationRequested then
    begin
      ShowTestNotification(
        Info
      );

      Exit;
    end;

    if BatteryIsLow(
      Info
    ) then
      ShowBatteryNotification(
        Info
      );

  finally
    TransportClose;
  end;
end;

begin
  Run;
end.