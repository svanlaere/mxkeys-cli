unit mxkeys_linux;

{$mode objfpc}{$H+}

interface

function LinuxHidOpen(out ErrorText: string): Boolean;
procedure LinuxHidClose;
function LinuxHidWrite(
  const Buffer;
  Count: Integer;
  out ErrorText: string
): Boolean;
function LinuxHidRead(
  var Buffer;
  MaxCount: Integer;
  out BytesRead: Integer;
  out ErrorText: string
): Boolean;
function LinuxHidDescription: string;

implementation

uses
  Classes,
  SysUtils,
  BaseUnix,
  Unix;

const
  SYS_HIDRAW = '/sys/class/hidraw';

var
  GHandle: cint = -1;
  GPath: string = '';

function ReadText(const FileName: string): string;
var
  F: TextFile;
  S: string;
begin
  Result := '';

  AssignFile(F, FileName);

  {$I-}
  Reset(F);
  {$I+}

  if IOResult <> 0 then
    Exit;

  try
    while not EOF(F) do
    begin
      ReadLn(F, S);
      Result := Result + S + LineEnding;
    end;
  finally
    CloseFile(F);
  end;
end;

function IsBoltHidpp(const Name: string): Boolean;
var
  UEvent: string;
  Stream: TFileStream;
  Buffer: array[0..255] of Byte;
  Count: LongInt;
  I: Integer;
  HasReport10: Boolean;
  HasReport11: Boolean;
  HasVendorPage: Boolean;
  DescriptorFile: string;
begin
  Result := False;

  UEvent := UpperCase(
    ReadText(SYS_HIDRAW + '/' + Name + '/device/uevent')
  );

  if Pos('HID_ID=0003:0000046D:0000C548', UEvent) = 0 then
    Exit;

  DescriptorFile :=
    SYS_HIDRAW + '/' + Name + '/device/report_descriptor';

  if not FileExists(DescriptorFile) then
    Exit;

  try
    Stream := TFileStream.Create(
      DescriptorFile,
      fmOpenRead or fmShareDenyNone
    );
  except
    Exit;
  end;

  try
    Count := Stream.Read(Buffer, SizeOf(Buffer));
  finally
    Stream.Free;
  end;

  HasReport10 := False;
  HasReport11 := False;
  HasVendorPage := False;

  if Count >= 2 then
  begin
    for I := 0 to Count - 2 do
    begin
      { Usage Page $FF00:
          06 00 FF
      }
      if (I + 2 < Count) and
         (Buffer[I] = $06) and
         (Buffer[I + 1] = $00) and
         (Buffer[I + 2] = $FF) then
        HasVendorPage := True;

      { Report ID $10 }
      if (Buffer[I] = $85) and
         (Buffer[I + 1] = $10) then
        HasReport10 := True;

      { Report ID $11 }
      if (Buffer[I] = $85) and
         (Buffer[I + 1] = $11) then
        HasReport11 := True;
    end;
  end;

  Result :=
    HasVendorPage and
    HasReport10 and
    HasReport11;
end;

function LinuxHidOpen(out ErrorText: string): Boolean;
var
  SearchRec: TSearchRec;
  DevicePath: string;
begin
  Result := False;
  ErrorText := '';

  LinuxHidClose;

  if FindFirst(
    SYS_HIDRAW + '/hidraw*',
    faDirectory,
    SearchRec
  ) = 0 then
  begin
    try
      repeat
        if ((SearchRec.Attr and faDirectory) <> 0) and
           IsBoltHidpp(SearchRec.Name) then
        begin
          DevicePath := '/dev/' + SearchRec.Name;

          GHandle := fpOpen(
            DevicePath,
            O_RDWR or O_NONBLOCK
          );

          if GHandle < 0 then
          begin
            ErrorText :=
              'Cannot open ' + DevicePath +
              ' (check udev permissions).';
            Exit;
          end;

          GPath := DevicePath;
          Result := True;
          Exit;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;

  ErrorText :=
    'Logi Bolt HID++ interface (046d:c548) not found.';
end;

procedure LinuxHidClose;
begin
  if GHandle >= 0 then
    fpClose(GHandle);

  GHandle := -1;
  GPath := '';
end;

function LinuxHidWrite(
  const Buffer;
  Count: Integer;
  out ErrorText: string
): Boolean;
var
  Written: Int64;
begin
  ErrorText := '';

  if GHandle < 0 then
  begin
    ErrorText := 'HID device is not open.';
    Exit(False);
  end;

  Written := fpWrite(
    GHandle,
    Buffer,
    Count
  );

  Result := Written = Count;

  if not Result then
    ErrorText := 'hidraw write failed.';
end;

function LinuxHidRead(
  var Buffer;
  MaxCount: Integer;
  out BytesRead: Integer;
  out ErrorText: string
): Boolean;
var
  ReadCount: Int64;
  Attempt: Integer;
begin
  Result := False;
  ErrorText := '';
  BytesRead := 0;

  if GHandle < 0 then
  begin
    ErrorText := 'HID device is not open.';
    Exit;
  end;

  {
    Device was opened O_NONBLOCK.

    Try for approximately two seconds:
      200 attempts × 10 ms.
  }
  for Attempt := 1 to 200 do
  begin
    ReadCount := fpRead(
      GHandle,
      Buffer,
      MaxCount
    );

    if ReadCount > 0 then
    begin
      BytesRead := Integer(ReadCount);
      Exit(True);
    end;

    Sleep(10);
  end;

  ErrorText := 'Timed out waiting for HID++ response.';
end;

function LinuxHidDescription: string;
begin
  Result := GPath;
end;

end.
