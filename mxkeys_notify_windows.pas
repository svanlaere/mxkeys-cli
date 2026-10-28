unit mxkeys_notify_windows;

{$mode objfpc}{$H+}

interface

function WindowsNotify(
  const Title: string;
  const MessageText: string;
  out ErrorText: string
): Boolean;

implementation

uses
  Windows,
  SysUtils;

const
  NOTIFICATION_TIME_SECONDS = 10;

function PowerShellQuote(
  const Value: string
): string;
begin
  Result :=
    '''' +
    StringReplace(
      Value,
      '''',
      '''''',
      [rfReplaceAll]
    ) +
    '''';
end;

function WindowsNotify(
  const Title: string;
  const MessageText: string;
  out ErrorText: string
): Boolean;
var
  StartupInfo: TStartupInfoW;
  ProcessInfo: TProcessInformation;
  Command: UnicodeString;
  PowerShellCommand: string;
  ExitCode: DWORD;
begin
  Result := False;
  ErrorText := '';

  PowerShellCommand :=
    'Add-Type -AssemblyName System.Windows.Forms; ' +
    '$n=New-Object System.Windows.Forms.NotifyIcon; ' +
    '$n.Icon=[System.Drawing.SystemIcons]::Information; ' +
    '$n.BalloonTipTitle=' +
      PowerShellQuote(Title) + '; ' +
    '$n.BalloonTipText=' +
      PowerShellQuote(MessageText) + '; ' +
    '$n.Visible=$true; ' +
    '$n.ShowBalloonTip(' +
      IntToStr(NOTIFICATION_TIME_SECONDS * 1000) + '); ' +
    'Start-Sleep -Seconds ' +
      IntToStr(NOTIFICATION_TIME_SECONDS) + '; ' +
    '$n.Dispose();';

  Command :=
    'powershell.exe ' +
    '-NoProfile ' +
    '-NonInteractive ' +
    '-WindowStyle Hidden ' +
    '-Command "' +
    UnicodeString(PowerShellCommand) +
    '"';

  FillChar(
    StartupInfo,
    SizeOf(StartupInfo),
    0
  );

  StartupInfo.cb :=
    SizeOf(StartupInfo);

  StartupInfo.dwFlags :=
    STARTF_USESHOWWINDOW;

  StartupInfo.wShowWindow :=
    SW_HIDE;

  FillChar(
    ProcessInfo,
    SizeOf(ProcessInfo),
    0
  );

  if not CreateProcessW(
    nil,
    PWideChar(Command),
    nil,
    nil,
    False,
    CREATE_NO_WINDOW,
    nil,
    nil,
    StartupInfo,
    ProcessInfo
  ) then
  begin
    ErrorText :=
      Format(
        'Unable to start Windows notification. Error %d.',
        [GetLastError]
      );

    Exit;
  end;

  try
    WaitForSingleObject(
      ProcessInfo.hProcess,
      INFINITE
    );

    if not GetExitCodeProcess(
      ProcessInfo.hProcess,
      ExitCode
    ) then
    begin
      ErrorText :=
        Format(
          'Unable to read Windows notification exit code. Error %d.',
          [GetLastError]
        );

      Exit;
    end;

    if ExitCode <> 0 then
    begin
      ErrorText :=
        Format(
          'Windows notification failed with exit code %d.',
          [ExitCode]
        );

      Exit;
    end;

    Result := True;

  finally
    CloseHandle(
      ProcessInfo.hThread
    );

    CloseHandle(
      ProcessInfo.hProcess
    );
  end;
end;

end.
