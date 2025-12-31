{$A+,B-,D+,E+,F-,G+,I+,L-,N-,O-,P-,Q-,R-,S-,T-,V+,X+,Y+}
{$M 16384,0,655360}

program Matrix;

uses
  Crt, Dos;

{$I BUILD.INC}

const
  COLS = 80;
  ROWS = 50;
  VERSION: string = '1.0';

  MaxLevel = 15;

  LevelFG: array[0..MaxLevel] of Byte =
  (
    0,            { 0 off }
    8,8,8,        { 1..3 afterglow }
    2,2,2,2,2,2,  { 4..9 green }
    10,10,10,10,  { 10..13 light green }
    15,15         { 14..15 head-ish }
  );

  MatrixChars: string =
    #160#161#162#163#164#165#166#167#168#169 +
    #170#171#172#173#174#175#176#177#178#179 +
    #180#181#182#183#184#185#186#187#188#189 +
    #190#191#192#193#194#195#196#197#198#199 +
    #200#201#202#203#204#205#206#207#208#209 +
    #210#211#212#213#214#215#216#217#218#219 +
    #220#221#222#223;

  ShimmerSamples   = 90;
  ShimmerMinLevel  = 4;
  ShimmerMaxLevel  = 13;
  ShimmerChanceDiv = 3;

  FadeEveryTicks  = 6;
  MaxCatchUpTicks = 5;

  LogoHoldTicks = 36;
  DissolveTicks = 90;
  ShimmerLogoMinLevel = 10;

type
  TPhase = (phLogo, phDissolve, phMatrix);

  TTextCell = record
    Ch: Char;
    Attr: Byte;
  end;

  TStream = record
    HeadY: Integer;
    Len: Integer;
    SpeedBase: Byte;
    SpeedDrift: Shortint;
    Counter: Integer;
    Cooldown: Integer;
    Thickness: Byte;
  end;

  TRGB = record
    R, G, B: Byte;
  end;

  TFont = array[0..255, 0..7] of Byte;

var
  Screen: array[0..ROWS-1, 0..COLS-1] of TTextCell absolute $B800:0;
  CellCh: array[0..COLS-1, 0..ROWS-1] of Char;
  CellLev: array[0..COLS-1, 0..ROWS-1] of Byte;
  Streams: array[0..COLS-1] of TStream;
  OldMode, OldCurStart, OldCurEnd: Byte;
  OldDAC: array[0..15] of TRGB;
  OldFont, KatakanaFont: TFont;
  LastTick, CurrTick: Longint;
  FadeCounter: Byte;
  Phase: TPhase;
  PhaseTicks: Longint;
  Greeting: string[127];
  NoiseOffTick: Longint;
  FlagNoise, Noising: Boolean;

{ --- VGA BIOS helpers ------------------------------------------------------ }

procedure GetTicks(var ticks: Longint);
var
  regs: Registers;
begin
  regs.AH := $00;
  Intr($1A, regs);
  ticks:= (Longint(regs.CX) shl 16) or regs.DX;
end;

procedure GetColor(Index: Byte; var R, G, B: Byte);
begin
  Port[$3C7]:= Index;
  R:= Port[$3C9];
  G:= Port[$3C9];
  B:= Port[$3C9];
end;

procedure SetColor(Index, R, G, B: Byte);
begin
  Port[$3C8]:= Index;
  Port[$3C9]:= R;
  Port[$3C9]:= G;
  Port[$3C9]:= B;
end;

procedure GetFont(var F: TFont);
var
  regs: Registers;
  src: ^Byte;
  c, row: Integer;
begin
  regs.AX := $1130;
  regs.BH := $03;
  Intr($10, regs);

  src := Ptr(regs.ES, regs.BP);

  for c := 0 to 255 do
    for row := 0 to 7 do
    begin
      F[c,row] := src^;
      Inc(src);
    end;
end;

procedure SetFont(var F: TFont);
var
  regs: Registers;
begin
  regs.AX := $1100;   { Load user font }
  regs.BX := $0800;   { block 0 }
  regs.CX := 256;     { 256 chars }
  regs.DX := 0;       { start char }
  regs.ES := Seg(F);
  regs.BP := Ofs(F);
  Intr($10, regs);
end;

{ --------------------------------------------------------------------------- }

procedure BuildSymbols(var F: TFont);
  procedure G(code: Byte; b0,b1,b2,b3,b4,b5,b6,b7: Byte);
  begin
    F[code,0]:=b0; F[code,1]:=b1; F[code,2]:=b2; F[code,3]:=b3;
    F[code,4]:=b4; F[code,5]:=b5; F[code,6]:=b6; F[code,7]:=b7;
  end;
begin
  G($A0,$18,$24,$42,$7E,$42,$42,$42,$00);
  G($A1,$7E,$10,$10,$10,$10,$10,$7E,$00);
  G($A2,$7E,$42,$02,$1E,$02,$42,$7E,$00);
  G($A3,$7E,$40,$7C,$40,$40,$40,$7E,$00);
  G($A4,$3C,$42,$42,$42,$42,$42,$3C,$00);

  G($A5,$7E,$02,$1E,$02,$02,$42,$3C,$00);
  G($A6,$7E,$02,$3E,$02,$12,$22,$1C,$00);
  G($A7,$7E,$02,$04,$08,$10,$20,$7E,$00);
  G($A8,$7E,$40,$7C,$40,$4A,$44,$7E,$00);
  G($A9,$7E,$40,$40,$40,$40,$40,$7E,$00);

  G($AA,$7E,$08,$1C,$2A,$08,$08,$7E,$00);
  G($AB,$7E,$02,$1E,$02,$02,$7E,$00,$00);
  G($AC,$7E,$10,$10,$1C,$10,$10,$7E,$00);
  G($AD,$7E,$40,$7C,$40,$4E,$40,$7E,$00);
  G($AE,$7E,$08,$08,$08,$08,$08,$7E,$00);

  G($AF,$7E,$02,$1E,$02,$02,$02,$7E,$00);
  G($B0,$7E,$10,$7E,$10,$10,$10,$7E,$00);
  G($B1,$7E,$10,$10,$7E,$04,$08,$10,$00);
  G($B2,$7E,$40,$7E,$40,$40,$40,$7E,$00);
  G($B3,$7E,$04,$08,$10,$20,$20,$20,$00);

  G($B4,$7E,$10,$10,$10,$10,$10,$10,$00);
  G($B5,$7E,$40,$7E,$40,$40,$40,$7E,$00);
  G($B6,$3C,$42,$02,$1E,$02,$42,$3C,$00);
  G($B7,$7E,$40,$7C,$40,$44,$42,$7E,$00);
  G($B8,$7E,$40,$40,$40,$40,$40,$40,$00);

  G($B9,$42,$42,$42,$7E,$02,$02,$02,$00);
  G($BA,$7E,$40,$7C,$40,$40,$40,$40,$00);
  G($BB,$7E,$02,$02,$7E,$40,$40,$7E,$00);
  G($BC,$00,$02,$04,$08,$10,$20,$40,$00);
  G($BD,$42,$42,$7E,$42,$42,$42,$42,$00);

  G($BE,$7E,$42,$42,$42,$42,$02,$02,$00);
  G($BF,$7E,$40,$7E,$40,$7E,$40,$7E,$00);
  G($C0,$42,$42,$42,$7E,$40,$40,$40,$00);
  G($C1,$7E,$40,$7C,$40,$40,$7E,$00,$00);
  G($C2,$7E,$40,$40,$7E,$40,$40,$7E,$00);

  G($C3,$7E,$08,$1C,$2A,$08,$08,$08,$00);
  G($C4,$42,$42,$42,$7E,$10,$10,$10,$00);
  G($C5,$7E,$08,$08,$7E,$08,$08,$7E,$00);

  G($C6,$7E,$02,$1E,$02,$02,$7E,$00,$00);
  G($C7,$7E,$10,$10,$10,$10,$10,$18,$00);
  G($C8,$7E,$02,$04,$08,$10,$20,$7E,$00);
  G($C9,$7E,$40,$7C,$40,$44,$42,$7E,$00);
  G($CA,$7E,$40,$40,$40,$40,$40,$7E,$00);

  G($CB,$42,$42,$42,$42,$42,$42,$3C,$00);
  G($CC,$7E,$42,$42,$7E,$40,$40,$40,$00);
  G($CD,$7E,$02,$04,$18,$20,$40,$7E,$00);

  G($CE,$00,$18,$24,$3C,$24,$24,$00,$00);
  G($CF,$00,$3C,$08,$08,$08,$3C,$00,$00);
  G($D0,$00,$3C,$24,$04,$3C,$00,$00,$00);
  G($D1,$00,$3C,$20,$38,$20,$3C,$00,$00);
  G($D2,$00,$1C,$22,$22,$22,$1C,$00,$00);

  G($D3,$00,$3C,$08,$1C,$2A,$08,$00,$00);
  G($D4,$00,$22,$22,$3E,$08,$08,$00,$00);
  G($D5,$00,$3C,$08,$3C,$08,$3C,$00,$00);
  G($D6,$00,$3C,$08,$08,$1C,$00,$00,$00);

  G($D7,$00,$00,$00,$3C,$00,$00,$00,$00);
  G($D8,$00,$00,$18,$18,$00,$00,$00,$00);
  G($D9,$00,$14,$28,$00,$00,$00,$00,$00);
  G($DA,$00,$18,$18,$00,$00,$00,$00,$00);
  G($DB,$00,$00,$3C,$42,$42,$3C,$00,$00);

  G($DC,$00,$7E,$00,$7E,$00,$7E,$00,$00);
  G($DD,$00,$10,$38,$7C,$38,$10,$00,$00);
  G($DE,$00,$00,$7E,$42,$42,$7E,$00,$00);
  G($DF,$00,$3C,$42,$5A,$42,$3C,$00,$00);
end;

function RandMatrixChar: Char;
begin
  RandMatrixChar := MatrixChars[1 + Random(Length(MatrixChars))];
end;

function RandLen: Integer;
var
  r: Integer;
begin
  r := Random(100);
  if r < 20 then
    RandLen := 20 + Random(20)
  else if r < 80 then
    RandLen := 40 + Random(25)
  else
    RandLen := 65 + Random(30);
end;

function RandCooldown: Integer;
var
  r: Integer;
begin
  r := Random(100);
  if r < 70 then
    RandCooldown := 10 + Random(50)
  else if r < 90 then
    RandCooldown := 60 + Random(60)
  else
    RandCooldown := 120 + Random(160);
end;

function RandThickness: Byte;
var
  r: Integer;
begin
  r := Random(100);
  if r < 55 then
    RandThickness := 1
  else if r < 82 then
    RandThickness := 2
  else if r < 95 then
    RandThickness := 3
  else
    RandThickness := 4;
end;

function RandSpeedBase: Byte;
var
  r: Integer;
begin
  r := Random(100);
  if r < 15 then
    RandSpeedBase := 2 + Random(2)
  else if r < 70 then
    RandSpeedBase := 4 + Random(5)
  else if r < 92 then
    RandSpeedBase := 9 + Random(5)
  else
    RandSpeedBase := 14 + Random(7);
end;

procedure ClearAll;
var
  x, y: Integer;
begin
  for y := 0 to ROWS-1 do
    for x := 0 to COLS-1 do
    begin
      CellLev[x, y] := 0;
      CellCh[x, y] := #0;
      Screen[y, x].Ch := ' ';
      Screen[y, x].Attr := 0;
    end;
end;

procedure DrawCell(x, y: Integer);
var
  lev: Byte;
  fg: Byte;
begin
  lev := CellLev[x, y];
  if lev = 0 then
  begin
    Screen[y, x].Ch := ' ';
    Screen[y, x].Attr := 0;
    Exit;
  end;

  fg := LevelFG[lev];
  Screen[y, x].Ch := CellCh[x, y];
  Screen[y, x].Attr := fg;
end;

procedure Plot(x, y: Integer; ch: Char; lev: Integer);
begin
  if (x < 0) or (x >= COLS) or (y < 0) or (y >= ROWS) then Exit;
  if lev < 0 then lev := 0;
  if lev > MaxLevel then lev := MaxLevel;

  CellCh[x, y] := ch;
  CellLev[x, y] := Byte(lev);
  DrawCell(x, y);
end;

procedure DrawText(AText: string; ARow: Integer);
var
  col, i: Integer;
begin
  col:= (COLS - Length(AText)) div 2;
  if ARow > ROWS then ARow:= ROWS;
  for i:= 1 to Length(AText) do
    if AText[i] <> ' ' then
      Plot(col + (i-1), ARow, AText[i], 15);
end;


procedure BoostGreeting;
var
  x0, y0, i, c: Integer;
begin
  y0:= ROWS div 2;
  x0:= (COLS - Length(Greeting)) div 2;

  for i:= 1 to Length(Greeting) do
  begin
    if Greeting[i] = ' ' then Continue;
    c:= x0 + (i-1);
    if (c < 0) or (c >= COLS) then Continue;
    with Streams[c] do
    begin
      Cooldown:= 0;
      Counter:= SpeedBase;
      HeadY:= y0 - 1 - Random(3);
    end;
  end;
end;

procedure FadeStep;
var
  x, y: Integer;
begin
  for y := 0 to ROWS-1 do
    for x := 0 to COLS-1 do
      if CellLev[x, y] > 0 then
      begin
        Dec(CellLev[x, y]);
        DrawCell(x, y);
      end;
end;

procedure ShimmerStep;
var
  i, x, y: Integer;
begin
  for i := 1 to ShimmerSamples do
  begin
    if Random(ShimmerChanceDiv) <> 0 then
      Continue;

    x := Random(COLS);
    y := Random(ROWS);

    if (Phase = phDissolve) and (CellLev[x,y] < ShimmerLogoMinLevel) then Continue;

    if (CellLev[x, y] >= ShimmerMinLevel) and (CellLev[x, y] <= ShimmerMaxLevel) then
    begin
      CellCh[x, y] := RandMatrixChar;
      DrawCell(x, y);
    end;
  end;
end;

procedure ResetColumn(c: Integer);
begin
  with Streams[c] do
  begin
    HeadY := -Random(ROWS div 2 + 1);
    Len := RandLen;

    SpeedBase:= RandSpeedBase;
    SpeedDrift:= 0;

    Counter:= Random(Streams[c].SpeedBase + 1);

    Cooldown:= RandCooldown;
    Thickness:= RandThickness;
  end;
end;

procedure StepStreams;
var
  c, y, k, lev, effSpeed: Integer;
begin
  for c := 0 to COLS-1 do
    with Streams[c] do
    begin
      if Cooldown > 0 then
      begin
        Dec(Cooldown);
        Continue;
      end;

      { micro-variazione di velocit† raramente }
      if Random(120) = 0 then
        case Random(3) of
          0: SpeedDrift:= -1;
          1: SpeedDrift:= 0;
          2: SpeedDrift:= 1;
        end;

      effSpeed := SpeedBase + SpeedDrift;
      if effSpeed < 2 then effSpeed := 2;
      if effSpeed > 24 then effSpeed := 24;

      Inc(Counter);
      if Counter < effSpeed then
        Continue;
      Counter:= 0;

      Inc(HeadY);

      if HeadY - Len > ROWS + 2 then
      begin
        ResetColumn(c);
        Continue;
      end;

      y:= HeadY;

      if FlagNoise and (y = 0) and (Random(8) = 0) then
      begin
        Sound(70 + Random(80));
        Noising:= True;
        NoiseOffTick:= CurrTick + 1;
      end;

      { testa }
      if (y >= 0) and (y < ROWS) then
        Plot(c, y, RandMatrixChar, MaxLevel);

      { corpo: spessore variabile (1..4) }
      for k := 1 to Thickness do
      begin
        if (y - k < 0) or (y - k >= ROWS) then
          Continue;

        { livelli alti (cosç non muore in 4 righe): 12,10,8,6... }
        lev := MaxLevel - 1 - ((k - 1) * 2);
        if lev < 2 then lev := 2;

        Plot(c, y - k, RandMatrixChar, lev);
      end;

      { piccolo rinforzo di continuit† subito dopo il corpo }
      if (y - Thickness - 1 >= 0) and (y - Thickness - 1 < ROWS) then
        if CellLev[c, y - Thickness - 1] < 7 then
        begin
          CellLev[c, y - Thickness - 1] := 7;
          DrawCell(c, y - Thickness - 1);
        end;
    end;
  { end with }
end;

procedure ShowUsage;
begin
  Writeln('Matrix screensaver version ', VERSION, ' (built on ', BuildDate, ' at ' , BuildTime, ')');
  Writeln('Developed in Turbo Pascal by Mark Reds <marco@markreds.it>.');
  Writeln;
  Writeln('Usage: MATRIX [options] [<Greeting message>]');
  Writeln;
  Writeln('Options:');
  Writeln(' /? Show this help and terminate.');
  Writeln(' /N Enable noise sound via PC speaker.');
  Writeln;
  Writeln('Greeting message:');
  Writeln(' A custom greeting message to display at start.');
  Writeln;
  Writeln('Notes:');
  Writeln('- Command-line options are case-sensitive.');
  Writeln('- If not options are specified, the program runs with default settings.');
  Writeln;
  Writeln('Runtime controls:');
  Writeln(' <A> key shows about info at the bottom of the matrix.');
  Halt(0);
end;

procedure Init;
var
  i: Integer;
  s: string[127];
begin
  Randomize;

  Phase:= phLogo;
  PhaseTicks:= 0;
  FadeCounter := 0;
  Noising:= False;
  NoiseOffTick:= 0;
  FlagNoise:= False;
  Greeting:= 'MATRIX';

  { Parsing dei parametri della riga di comando }
  if ParamCount > 0 then
  begin
    s:= '';
    for i:= 1 to ParamCount do
    begin
      if Pos('/?', ParamStr(i)) > 0 then
        ShowUsage
      else if Pos('/N', ParamStr(i)) > 0 then
        FlagNoise:= True
      else
      begin
        if s <> '' then s:= s + ' ';
        s:= s + ParamStr(i);
      end;
      if s <> '' then
      begin
        if Length(s) > COLS then
          Greeting:= Copy(s, 1, COLS)
        else
          Greeting:= s;
      end;
    end;
  end;

  { Salva la modalitÖ video corrente }
  asm
    mov ah, $0F
    int $10
    mov [OldMode], al
  end;

  { Salva la posizione corrente del cursore }
  asm
    mov ah, $03
    mov bh, $00
    int $10
    mov [OldCurStart], ch
    mov [OldCurEnd], cl
  end;

  { Inizializza la modalitÖ video }
  asm
    mov ax, $0003
    int $10
  end;

  { Imposta il font 8x8 => 80x50 (VGA) }
  asm
    mov ax, $1112
    xor bl, bl
    int $10
  end;

  { Forza pagina 0 }
  asm
    mov ah, $05
    xor al, al
    int $10
  end;

  { Imposta il font }
  GetFont(OldFont);
  Move(OldFont, KatakanaFont, SizeOf(TFont));
  BuildSymbols(KatakanaFont);
  SetFont(KatakanaFont);

  { Salva la palette dei colori }
  for i:= 0 to 15 do
    GetColor(i, OldDAC[i].R, OldDAC[i].G, OldDAC[i].B);

  { Imposta la palette con i colori Matrix }
  SetColor(0, 0, 0, 0);
  SetColor(8, 0, 3, 0);
  SetColor(2, 0, 20, 0);
  SetColor(10, 0, 40, 0);
  SetColor(15, 18, 63, 18);

  { Nasconde il cursore }
  asm
    mov ah, $01
    mov ch, $20
    mov cl, $00
    int $10
  end;

  { Pulisce lo schermo }
  ClearAll;

  { Init streams }
  for i:= 0 to COLS-1 do
  begin
    ResetColumn(i);
    Streams[i].Cooldown:= Random(80);
  end;

  { Disegna la schermata del logo iniziale }
  DrawText(Greeting, ROWS div 2);
end;

procedure Run;
var
  ticks: Longint;
  ch: Char;
begin
  GetTicks(LastTick);

  repeat
    GetTicks(CurrTick);
    ticks:= CurrTick - LastTick;

    if ticks > 0 then
    begin
      if ticks > MaxCatchUpTicks then ticks := MaxCatchUpTicks;

      while ticks > 0 do
      begin
        Dec(ticks);
        Inc(PhaseTicks);

        case Phase of
          phLogo:
            begin
              if (PhaseTicks and 1) = 0 then ShimmerStep;
              if PhaseTicks >= LogoHoldTicks then
              begin
                Phase:= phDissolve;
                PhaseTicks:= 0;
              end;
            end;

          phDissolve:
            begin
              Inc(FadeCounter);
              if FadeCounter >= FadeEveryTicks then
              begin
                FadeCounter:= 0;
                FadeStep;
              end;

              ShimmerStep;

              if PhaseTicks >= DissolveTicks then
              begin
                BoostGreeting;
                Phase:= phMatrix;
                PhaseTicks:= 0;
              end;
            end;

          phMatrix:
            begin
              Inc(FadeCounter);
              if FadeCounter >= FadeEveryTicks then
              begin
                FadeCounter := 0;
                FadeStep;
              end;

              StepStreams;
              ShimmerStep;

              if Noising and (CurrTick >= NoiseOffTick) then
              begin
                NoSound;
                Noising:= False;
              end;
            end;
        end;
      end;

      if KeyPressed then
      begin
        ch:= ReadKey;
        if (ch = 'a') or (ch = 'A') then
        begin
          DrawText('Matrix screensaver version ' + VERSION, ROWS - 4);
          DrawText('Developed by Mark Reds', ROWS -  2);
        end
        else
          Break;
      end;

      LastTick := CurrTick;
    end;

  until False;
end;

procedure Done;
var
  c: Integer;
begin
  NoSound;

  { Ripristina il font originale }
  SetFont(OldFont);

  { Ripristina la palette dei colori }
  for c:= 0 to 15 do
    SetColor(c, OldDAC[c].R, OldDAC[c].G, OldDAC[c].B);

  { Ripristina la modalitÖ video precedente }
  asm
    xor ah, ah
    mov al, [OldMode]
    int $10
  end;

  { Ripristina la posizione precedente del cursore }
  asm
    mov ah, $01
    mov ch, [OldCurStart]
    mov cl, [OldCurEnd]
    int $10
  end;
end;

BEGIN
  Init;
  Run;
  Done;
END.
