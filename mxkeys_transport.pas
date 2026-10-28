unit mxkeys_transport;

{$mode objfpc}{$H+}

interface

function TransportOpen(
  out ErrorText: string
): Boolean;

procedure TransportClose;

function TransportWrite(
  const Buffer;
  Count: Integer;
  out ErrorText: string
): Boolean;

function TransportRead(
  var Buffer;
  MaxCount: Integer;
  out BytesRead: Integer;
  out ErrorText: string
): Boolean;

function TransportDescription: string;

procedure TransportListHidInterfaces;

implementation

{$IFDEF WINDOWS}

uses
  mxkeys_windows;

function TransportOpen(
  out ErrorText: string
): Boolean;
begin
  Result :=
    WindowsHidOpen(
      ErrorText
    );
end;

procedure TransportClose;
begin
  WindowsHidClose;
end;

function TransportWrite(
  const Buffer;
  Count: Integer;
  out ErrorText: string
): Boolean;
begin
  Result :=
    WindowsHidWrite(
      Buffer,
      Count,
      ErrorText
    );
end;

function TransportRead(
  var Buffer;
  MaxCount: Integer;
  out BytesRead: Integer;
  out ErrorText: string
): Boolean;
begin
  Result :=
    WindowsHidRead(
      Buffer,
      MaxCount,
      BytesRead,
      ErrorText
    );
end;

function TransportDescription: string;
begin
  Result :=
    WindowsHidDescription;
end;

procedure TransportListHidInterfaces;
begin
  WindowsListHidInterfaces;
end;

{$ENDIF}

{$IFDEF LINUX}

uses
  mxkeys_linux;

function TransportOpen(
  out ErrorText: string
): Boolean;
begin
  Result :=
    LinuxHidOpen(
      ErrorText
    );
end;

procedure TransportClose;
begin
  LinuxHidClose;
end;

function TransportWrite(
  const Buffer;
  Count: Integer;
  out ErrorText: string
): Boolean;
begin
  Result :=
    LinuxHidWrite(
      Buffer,
      Count,
      ErrorText
    );
end;

function TransportRead(
  var Buffer;
  MaxCount: Integer;
  out BytesRead: Integer;
  out ErrorText: string
): Boolean;
begin
  Result :=
    LinuxHidRead(
      Buffer,
      MaxCount,
      BytesRead,
      ErrorText
    );
end;

function TransportDescription: string;
begin
  Result :=
    LinuxHidDescription;
end;

procedure TransportListHidInterfaces;
begin
  { Currently only needed for Windows diagnostics. }
end;

{$ENDIF}

{$IFNDEF WINDOWS}
  {$IFNDEF LINUX}
    {$FATAL Unsupported operating system}
  {$ENDIF}
{$ENDIF}

end.
