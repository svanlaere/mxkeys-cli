unit mxkeys_notify_linux;

{$mode objfpc}{$H+}

interface

function LinuxNotify(
  const Title: string;
  const MessageText: string;
  out ErrorText: string
): Boolean;

implementation

uses
  Classes,
  SysUtils,
  Process;

function LinuxNotify(
  const Title: string;
  const MessageText: string;
  out ErrorText: string
): Boolean;
var
  Process: TProcess;
begin
  Result := False;
  ErrorText := '';

  Process := TProcess.Create(nil);

  try
    Process.Executable := 'notify-send';

    Process.Parameters.Add('--app-name=MX Keys');
    Process.Parameters.Add('--expire-time=10000');
    Process.Parameters.Add(Title);
    Process.Parameters.Add(MessageText);

    Process.Options := [
      poWaitOnExit,
      poUsePipes
    ];

    try
      Process.Execute;
    except
      on E: Exception do
      begin
        ErrorText :=
          'Unable to send desktop notification: ' +
          E.Message;
        Exit;
      end;
    end;

    if Process.ExitStatus <> 0 then
    begin
      ErrorText := Trim(
        Process.Stderr.ReadAnsiString
      );

      if ErrorText = '' then
        ErrorText := Format(
          'notify-send exited with status %d.',
          [Process.ExitStatus]
        );

      Exit;
    end;

    Result := True;
  finally
    Process.Free;
  end;
end;

end.
