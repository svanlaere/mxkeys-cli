unit mxkeys_config;

{$mode objfpc}{$H+}

interface

function WarningThreshold: Integer;

implementation

uses
  SysUtils;

function WarningThreshold: Integer;
var
  I: Integer;
  Value: Integer;
begin
  Result := 10;

  for I := 1 to ParamCount - 1 do
  begin
    if SameText(
      ParamStr(I),
      '--threshold'
    ) then
    begin
      if TryStrToInt(
        ParamStr(I + 1),
        Value
      ) and
        (Value >= 1) and
        (Value <= 50) then
        Exit(Value);
    end;
  end;
end;

end.
