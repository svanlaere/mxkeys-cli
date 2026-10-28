unit mxkeys_notify;

{$mode objfpc}{$H+}

interface

function Notify(
  const Title: string;
  const MessageText: string;
  out ErrorText: string
): Boolean;

implementation

{$IFDEF LINUX}

uses
  mxkeys_notify_linux;

function Notify(
  const Title: string;
  const MessageText: string;
  out ErrorText: string
): Boolean;
begin
  Result := LinuxNotify(
    Title,
    MessageText,
    ErrorText
  );
end;

{$ENDIF}

{$IFDEF WINDOWS}

uses
  mxkeys_notify_windows;

function Notify(
  const Title: string;
  const MessageText: string;
  out ErrorText: string
): Boolean;
begin
  Result := WindowsNotify(
    Title,
    MessageText,
    ErrorText
  );
end;

{$ENDIF}

{$IFNDEF LINUX}
  {$IFNDEF WINDOWS}
    {$FATAL Unsupported operating system}
  {$ENDIF}
{$ENDIF}

end.
