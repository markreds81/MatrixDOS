program BuildInc;

uses
  Dos;

var
  Y, D, M, Dow: Word;
  H, N, S, HS: Word;
  F: Text;

function Pad(n: Word): string;
var
  s: string;
begin
  Str(n:0, s);
  if Length(s) < 2 then
    s:= '0' + s;
  Pad:= s;
end;

BEGIN
  GetDate(Y, M, D, Dow);
  GetTime(H, N, S, HS);

  Assign(F, 'BUILD.INC');
  Rewrite(F);

  Writeln(F, 'const');
  Writeln(F, '  BuildDate = ''', Y, '-', Pad(M), '-', Pad(D), ''';');
  Writeln(F, '  BuildTime = ''', Pad(H), ':', Pad(N), ':', Pad(S), ''';');

  Close(F);
END.