unit Generic;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StrUtils, ExtCtrls, StdCtrls, pngimage, Math;

type
  TForm1 = class(TForm)
    editROM: TLabeledEdit;
    editMap: TLabeledEdit;
    editDPLC: TLabeledEdit;
    editPal1: TLabeledEdit;
    editPal2: TEdit;
    editPal3: TEdit;
    editPal4: TEdit;
    dlgOpen: TOpenDialog;
    chkDPLC: TCheckBox;
    btnUseAll: TButton;
    editROMloc: TEdit;
    editMaploc: TEdit;
    menuMap: TComboBox;
    editDPLCloc: TEdit;
    menuPal: TComboBox;
    editPal1loc: TEdit;
    editPal2loc: TEdit;
    editPal3loc: TEdit;
    editPal4loc: TEdit;
    editSpacing: TLabeledEdit;
    btnView: TButton;
    btnSave: TButton;
    dlgSave: TSaveDialog;
    img: TImage;
    editMapcount: TEdit;
    lblMapcountt: TLabel;
    procedure editROMClick(Sender: TObject);
    procedure editMapClick(Sender: TObject);
    procedure editDPLCClick(Sender: TObject);
    procedure editPal1Click(Sender: TObject);
    procedure editPal2Click(Sender: TObject);
    procedure editPal3Click(Sender: TObject);
    procedure editPal4Click(Sender: TObject);
    procedure chkDPLCClick(Sender: TObject);
    procedure btnUseAllClick(Sender: TObject);
    procedure btnViewClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure menuMapChange(Sender: TObject);
  private
    { Private declarations }
    procedure LoadFile(openthis: string; target: integer);
    function Explode(s, d: string; n: integer): string;
    procedure LoadPal(source, target: integer);
    procedure LoadFormat(f: integer);
    function GetM(a, s, mask: integer): integer;
    function GetM_U(a, s, mask: integer): integer;
    function GetD(a, s, mask: integer): integer;
    function GetD_U(a, s, mask: integer): integer;
    procedure DrawTile(a, p, x, y, xflip, yflip: integer);
    procedure DrawSprite(a, p, x, y, s, xflip, yflip: integer);
    procedure DrawMap(a, x, y: integer);
    function BitShift(i: integer): integer;
    function FixLoc(s: string): string;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  myfile: file;
  inifile: textfile;
  gfxarray, gfxarray2, maparray, dplcarray, palarray: array of byte;
  palarray2: array[0..63] of TColor;
  PNG: TPNGImage;
  formatlist: array[0..100] of string;
  mapindex: array[0..255] of integer;
  imgsize, spacing, bgcolor, bgcolor2, mapcount, sprcount_size, spr_size, x_, x_size, x_mask,
    y_, y_size, y_mask, dim_, dim_size, dim_mask, tile_, tile_size, tile_mask,
    xflip_, xflip_size, xflip_mask, yflip_, yflip_size, yflip_mask,
    palette_, palette_size, palette_mask, priority_, priority_size, priority_mask,
    dplccount_size, dplc_size, q_, q_size, q_mask, gfx_, gfx_size, gfx_mask: integer;

implementation

{$R *.dfm}

{ File stuff }

procedure TForm1.LoadFile(openthis: string; target: integer); // Open file and copy to array.
begin
  if FileExists(openthis) then
    begin
    AssignFile(myfile,openthis); // Get file.
    FileMode := fmOpenRead;
    Reset(myfile,1); // Read only.
    if target = 0 then
      begin
      SetLength(gfxarray,FileSize(myfile));
      BlockRead(myfile,gfxarray[0],FileSize(myfile)); // Copy file to graphics array.
      end
    else if target = 1 then
      begin
      SetLength(maparray,FileSize(myfile));
      BlockRead(myfile,maparray[0],FileSize(myfile)); // Copy file to mappings array.
      end
    else if target = 2 then
      begin
      SetLength(dplcarray,FileSize(myfile));
      BlockRead(myfile,dplcarray[0],FileSize(myfile)); // Copy file to DPLC array.
      end
    else if target = 3 then
      begin
      SetLength(palarray,FileSize(myfile));
      BlockRead(myfile,palarray[0],FileSize(myfile)); // Copy file to palette array.
      end;
    CloseFile(myfile); // Close file.
    end;
end;

{ String operations }

function TForm1.Explode(s, d: string; n: integer): string; // Get part of a string using delimiter.
var n2: integer;
begin
  if (AnsiPos(d,s) = 0) and ((n = 0) or (n = -1)) then result := s // Output full string if delimiter not found.
  else
    begin
    if n > -1 then // Check for negative substring.
      begin
      s := s+d;
      n2 := n;
      end
    else
      begin
      d := AnsiReverseString(d);
      s := AnsiReverseString(s)+d; // Reverse string for negative.
      n2 := (n*-1)-1;
      end;
    while n2 > 0 do
      begin
      Delete(s,1,AnsiPos(d,s)+Length(d)-1); // Trim earlier substrings and delimiters.
      dec(n2);
      end;
    Delete(s,AnsiPos(d,s),Length(s)-AnsiPos(d,s)+1); // Trim later substrings and delimiters.
    if n < 0 then s := AnsiReverseString(s); // Un-reverse string if negative.
    result := s;
  end;
end;

function TForm1.FixLoc(s: string): string; // Add $ sign to addresses and clear them if invalid.
var i: integer;
begin
  if (Copy(s,1,1) <> '$') and (s <> '0') then s := '$'+s; // Add hex sign if missing.
  if TryStrtoInt(s,i) = true then result := s // Output string if it's a valid number.
  else result := '0'; // Output 0 if it's not.
end;

{ Form management. }

procedure TForm1.FormCreate(Sender: TObject);
var inifile: textfile;
  s: string;
  f: integer;
label noini;
begin
  Application.Title := 'HiveSprite';
  bgcolor := 0;
  bgcolor2 := 0;
  if not FileExists(ExtractFilePath(Application.ExeName)+'hivesprite.ini') then
    begin
    ShowMessage('ini file not found.');
    btnView.Enabled := false;
    goto noini;
    end;
  AssignFile(inifile,ExtractFilePath(Application.ExeName)+'hivesprite.ini'); // Open ini file.
  Reset(inifile);
  f := 0;
  while not eof(inifile) do
    begin
    ReadLn(inifile,s);
    if AnsiPos('=',s) <> 0 then
      begin
      if Explode(s,'=',0) = 'bgcolor' then
        begin
        bgcolor := StrtoInt(Explode(s,'=',1)); // Get background colour.
        bgcolor := (bgcolor shr 16)+(bgcolor and $FF00)+((bgcolor and $FF) shl 16); // Convert RBG to TColor BGR.
        end
      else if Explode(s,'=',0) = 'bgcolor2' then
        begin
        bgcolor2 := StrtoInt(Explode(s,'=',1)); // Get background colour.
        bgcolor2 := (bgcolor2 shr 16)+(bgcolor2 and $FF00)+((bgcolor2 and $FF) shl 16); // Convert RBG to TColor BGR.
        end
      else
        begin
        menuMap.Items.Add(Explode(s,'=',0)); // Add mappings format.
        menuMap.ItemIndex := 0;
        formatlist[f] := Explode(s,'=',1); // Get variables.
        inc(f);
        end;
      end;
    end;
  LoadFormat(0); // Load format variables.
  CloseFile(inifile);
  noini:
end;

procedure TForm1.LoadFormat(f: integer); // Load mappings format variables from strings from ini.
begin
  sprcount_size := StrtoInt(Explode(formatlist[f],'|',0));
  spr_size := StrtoInt(Explode(formatlist[f],'|',1));
  x_ := StrtoInt(Explode(Explode(formatlist[f],'|',2),':',0));
  x_size := StrtoInt(Explode(Explode(formatlist[f],'|',2),':',1));
  x_mask := StrtoInt(Explode(Explode(formatlist[f],'|',2),':',2));
  y_ := StrtoInt(Explode(Explode(formatlist[f],'|',3),':',0));
  y_size := StrtoInt(Explode(Explode(formatlist[f],'|',3),':',1));
  y_mask := StrtoInt(Explode(Explode(formatlist[f],'|',3),':',2));
  dim_ := StrtoInt(Explode(Explode(formatlist[f],'|',4),':',0));
  dim_size := StrtoInt(Explode(Explode(formatlist[f],'|',4),':',1));
  dim_mask := StrtoInt(Explode(Explode(formatlist[f],'|',4),':',2));
  tile_ := StrtoInt(Explode(Explode(formatlist[f],'|',5),':',0));
  tile_size := StrtoInt(Explode(Explode(formatlist[f],'|',5),':',1));
  tile_mask := StrtoInt(Explode(Explode(formatlist[f],'|',5),':',2));
  xflip_ := StrtoInt(Explode(Explode(formatlist[f],'|',6),':',0));
  xflip_size := StrtoInt(Explode(Explode(formatlist[f],'|',6),':',1));
  xflip_mask := StrtoInt(Explode(Explode(formatlist[f],'|',6),':',2));
  yflip_ := StrtoInt(Explode(Explode(formatlist[f],'|',7),':',0));
  yflip_size := StrtoInt(Explode(Explode(formatlist[f],'|',7),':',1));
  yflip_mask := StrtoInt(Explode(Explode(formatlist[f],'|',7),':',2));
  palette_ := StrtoInt(Explode(Explode(formatlist[f],'|',8),':',0));
  palette_size := StrtoInt(Explode(Explode(formatlist[f],'|',8),':',1));
  palette_mask := StrtoInt(Explode(Explode(formatlist[f],'|',8),':',2));
  priority_ := StrtoInt(Explode(Explode(formatlist[f],'|',9),':',0));
  priority_size := StrtoInt(Explode(Explode(formatlist[f],'|',9),':',1));
  priority_mask := StrtoInt(Explode(Explode(formatlist[f],'|',9),':',2));
  dplccount_size := StrtoInt(Explode(formatlist[f],'|',10));
  dplc_size := StrtoInt(Explode(formatlist[f],'|',11));
  q_ := StrtoInt(Explode(Explode(formatlist[f],'|',12),':',0));
  q_size := StrtoInt(Explode(Explode(formatlist[f],'|',12),':',1));
  q_mask := StrtoInt(Explode(Explode(formatlist[f],'|',12),':',2));
  gfx_ := StrtoInt(Explode(Explode(formatlist[f],'|',13),':',0));
  gfx_size := StrtoInt(Explode(Explode(formatlist[f],'|',13),':',1));
  gfx_mask := StrtoInt(Explode(Explode(formatlist[f],'|',13),':',2));
end;

procedure TForm1.menuMapChange(Sender: TObject);
begin
  LoadFormat(menuMap.ItemIndex); // Load format variables.
end;

procedure TForm1.editDPLCClick(Sender: TObject);
begin
  if dlgOpen.Execute then editDPLC.Text := dlgOpen.FileName;
end;

procedure TForm1.editMapClick(Sender: TObject);
begin
  if dlgOpen.Execute then editMap.Text := dlgOpen.FileName;
end;

procedure TForm1.editPal1Click(Sender: TObject);
begin
  if dlgOpen.Execute then
  begin
  editPal1.Text := dlgOpen.FileName;
  editPal2.Enabled := true;
  end;
end;

procedure TForm1.editPal2Click(Sender: TObject);
begin
  if dlgOpen.Execute and (editPal2.Enabled = true) then
  begin
  editPal2.Text := dlgOpen.FileName;
  editPal3.Enabled := true;
  end;
end;

procedure TForm1.editPal3Click(Sender: TObject);
begin
  if dlgOpen.Execute and (editPal3.Enabled = true) then
  begin
  editPal3.Text := dlgOpen.FileName;
  editPal4.Enabled := true;
  end;
end;

procedure TForm1.editPal4Click(Sender: TObject);
begin
  if dlgOpen.Execute and (editPal4.Enabled = true) then editPal4.Text := dlgOpen.FileName;
end;

procedure TForm1.editROMClick(Sender: TObject);
begin
  if dlgOpen.Execute then editROM.Text := dlgOpen.FileName;
end;

procedure TForm1.btnUseAllClick(Sender: TObject);
begin
  if editROM.Text <> '' then
    begin
    editMap.Text := editROM.Text;
    editPal1.Text := editROM.Text;
    editPal2.Enabled := true;
    if editDPLC.Enabled = true then editDPLC.Text := editROM.Text;
    end;
end;

procedure TForm1.chkDPLCClick(Sender: TObject);
begin
  if chkDPLC.Checked = true then editDPLC.Enabled := true
  else editDPLC.Enabled := false;
end;

procedure TForm1.btnViewClick(Sender: TObject);
var i, j, maploc, dplcloc, entries, q, lastgfx: integer;
label files_missing;
begin
  PNG.Free;
  spacing := StrtoInt(editSpacing.Text);
  imgsize := spacing*16;
  PNG := TPNGImage.CreateBlank(COLOR_RGB,8,imgsize,imgsize); // Create PNG.
  for i := 0 to (imgsize*imgsize)-1 do
    if Odd((i mod imgsize) div spacing) xor Odd((i div imgsize) div spacing) then
      PNG.Pixels[i mod imgsize,i div imgsize] := bgcolor // Fill background.
    else PNG.Pixels[i mod imgsize,i div imgsize] := bgcolor2;
  if (editROM.Text = '') or (editMap.Text = '') or (editPal1.Text = '') then // Check file fields.
    begin
    ShowMessage('Files not selected.');
    goto files_missing;
    end;
  LoadFile(editROM.Text,0); // Load graphics file.
  LoadFile(editMap.Text,1); // Load mappings file.
  LoadFile(editDPLC.Text,2); // Load DPLC file.
  LoadFile(editPal1.Text,3); // Load palette file.
  editROMloc.Text := FixLoc(editROMloc.Text);
  editMaploc.Text := FixLoc(editMaploc.Text);
  editDPLCloc.Text := FixLoc(editDPLCloc.Text);
  editPal1loc.Text := FixLoc(editPal1loc.Text);
  editPal2loc.Text := FixLoc(editPal2loc.Text);
  editPal3loc.Text := FixLoc(editPal3loc.Text);
  editPal4loc.Text := FixLoc(editPal4loc.Text);
  // Graphics (no DPLC)
  if (editDPLC.Text = '') or (chkDPLC.Enabled = false) then
    begin
    SetLength(gfxarray2,Length(gfxarray)-StrtoInt(editROMloc.Text));
    Move(gfxarray[StrtoInt(editROMloc.Text)],gfxarray2[0],Length(gfxarray2));
    end;
  // Palette
  for i := 0 to 63 do palarray2[i] := 0; // Clear palette.
  LoadPal(StrtoInt(editPal1loc.Text),0); // Load 1st palette.
  if editPal2loc.Text <> '0' then LoadPal(StrtoInt(editPal2loc.Text),16); // Load 2nd palette.
  if editPal3loc.Text <> '0' then LoadPal(StrtoInt(editPal3loc.Text),32); // Load 3rd palette.
  if editPal4loc.Text <> '0' then LoadPal(StrtoInt(editPal4loc.Text),48); // Load 4th palette.
  if editPal2.Text <> '' then
    begin
    LoadFile(editPal2.Text,3);
    LoadPal(0,16); // Load 2nd palette from another file.
    end;
  if editPal3.Text <> '' then
    begin
    LoadFile(editPal3.Text,3);
    LoadPal(0,32); // Load 3rd palette from another file.
    end;
  if editPal4.Text <> '' then
    begin
    LoadFile(editPal4.Text,3);
    LoadPal(0,48); // Load 4th palette from another file.
    end;
  for i := 0 to 63 do PNG.Pixels[i,0] := palarray2[i]; // Draw palette to image.
  // Mappings
  for i := 0 to 255 do mapindex[i] := 0; // Clear mappings index.
  maploc := StrtoInt(editMaploc.Text);
  if editMapcount.Text = '0' then
    mapcount := GetM(maploc,2,$FFFF) div 2 // Assume 1st in index is 1st listed.
  else
    begin
    if TryStrtoInt(editMapcount.Text,i) = true then mapcount := Min(i,256) // Check number is valid, limited to 256.
    else
      begin
      editMapcount.Text := '0';
      mapcount := GetM(maploc,2,$FFFF) div 2;
      end;
    end;
  for i := 0 to mapcount-1 do mapindex[i] := GetM(maploc+(i*2),2,$FFFF)+maploc; // Populate index.
  for i := 0 to mapcount-1 do
    begin
    if (editDPLC.Text <> '') and (chkDPLC.Enabled = true) then // Load graphics if DPLC is used.
      begin
      dplcloc := StrtoInt(editDPLCloc.Text);
      dplcloc := dplcloc+GetD(dplcloc+(i*2),2,$FFFF)+dplccount_size; // Jump to relevant DPLC entry.
      lastgfx := 0;
      entries := GetD_U(dplcloc-dplccount_size,dplccount_size,$FFFF); // Number of entries in DPLC.
      SetLength(gfxarray2,entries*16*$20); // Max size of graphics loaded.
      for j := 0 to entries-1 do
        begin
        q := ((GetD_U(dplcloc+q_,q_size,q_mask) shr BitShift(q_mask))+1)*$20; // Get quantity of tiles.
        Move(gfxarray[StrtoInt(editROMloc.Text)+(GetD_U(dplcloc+gfx_,gfx_size,gfx_mask)*$20)],
          gfxarray2[lastgfx],q); // Copy tiles to gfxarray2.
        lastgfx := lastgfx+q; // Save position in gfxarray2.
        dplcloc := dplcloc+dplc_size; // Next item in DPLC.
        end;
      end;
    DrawMap(mapindex[i],((i and $f)*spacing)+(spacing div 2),((i shr 4)*spacing)+(spacing div 2)); // Draw all sprites.
    end;
  img.Height := imgsize;
  img.Width := imgsize;
  img.Canvas.Draw(0,0,PNG); // Draw on screen.
  btnSave.Enabled := true;
  files_missing:
end;

procedure TForm1.LoadPal(source, target: integer); // Load & convert palette to TColor.
const lumin: array[0..31] of byte = (0,0,52,52,87,87,116,116,144,144,172,172,206,206,255,255, // Real
    0,0,32,32,64,64,96,96,128,128,160,160,192,192,224,224); // Genecyst
var i, r, g, b: integer;
begin
  for i := 0 to 15 do
    begin
    r := lumin[palarray[source+(i*2)+1] and $f]; // Red
    g := lumin[(palarray[source+(i*2)+1] and $f0) shr 4]; // Green
    b := lumin[palarray[source+(i*2)] and $f]; // Blue
    palarray2[target+i] := (b shl 16)+(g shl 8)+r; // Combine as TColor.
    end;
end;

function TForm1.GetM(a, s, mask: integer): integer; // Get bytes from mappings array.
var b, i: integer;
begin
  b := 0;
  for i := 0 to s-1 do
    begin
    b := b shl 8; // Move earlier bytes up.
    b := b+maparray[a+i]; // Add next byte to end.
    end;
  b := b and mask; // Apply bitmask.
  if b < $80 shl (8*(s-1)) then result := b
  else result := b-($100 shl (8*(s-1))); // Convert to negative if sign found.
end;

function TForm1.GetM_U(a, s, mask: integer): integer; // Get bytes from mappings array (unsigned).
var b, i: integer;
begin
  b := 0;
  for i := 0 to s-1 do
    begin
    b := b shl 8; // Move earlier bytes up.
    b := b+maparray[a+i]; // Add next byte to end.
    end;
  result := b and mask; // Apply bitmask.
end;

function TForm1.GetD(a, s, mask: integer): integer; // Get bytes from DPLC array.
var b, i: integer;
begin
  b := 0;
  for i := 0 to s-1 do
    begin
    b := b shl 8; // Move earlier bytes up.
    b := b+dplcarray[a+i]; // Add next byte to end.
    end;
  b := b and mask; // Apply bitmask.
  if b < $80 shl (8*(s-1)) then result := b
  else result := b-($100 shl (8*(s-1))); // Convert to negative if sign found.
end;

function TForm1.GetD_U(a, s, mask: integer): integer; // Get bytes from DPLC array (unsigned).
var b, i: integer;
begin
  b := 0;
  for i := 0 to s-1 do
    begin
    b := b shl 8; // Move earlier bytes up.
    b := b+dplcarray[a+i]; // Add next byte to end.
    end;
  result := b and mask; // Apply bitmask.
end;

procedure TForm1.DrawTile(a, p, x, y, xflip, yflip: integer);
label drawnothing;
var i, j, z: integer;
  buffer: array[0..63] of TColor;
begin
  if (x < 0) or (y < 0) or (x+8 > imgsize) or (y+8 > imgsize) then goto drawnothing; // Check tile is fully within image.
  for i := 0 to 31 do
    begin
    if gfxarray2[a+i] shr 4 = 0 then buffer[i*2] := 1 // Copy transparent pixels to buffer.
    else buffer[i*2] := palarray2[(gfxarray2[a+i] shr 4)+(p*16)]; // Copy opaque pixels to buffer.
    if gfxarray2[a+i] and $f = 0 then buffer[(i*2)+1] := 1
    else buffer[(i*2)+1] := palarray2[(gfxarray2[a+i] and $f)+(p*16)];
    end;
  if xflip = 1 then // Flip pixels in buffer horizontally.
    for i := 0 to 7 do
      for j := 0 to 3 do
        begin
        z := buffer[(i*8)+j];
        buffer[(i*8)+j] := buffer[(i*8)+7-j];
        buffer[(i*8)+7-j] := z;
        end;
  if yflip = 1 then // Flip pixels in buffer vertically.
    for i := 0 to 7 do
      for j := 0 to 3 do
        begin
        z := buffer[(j*8)+i];
        buffer[(j*8)+i] := buffer[((7-j)*8)+i];
        buffer[((7-j)*8)+i] := z;
        end;
  for i := 0 to 7 do
    for j := 0 to 7 do
      if buffer[i+(j*8)] <> 1 then PNG.Pixels[x+i,y+j] := buffer[i+(j*8)]; // Copy buffer to image.
  drawnothing:
end;

procedure TForm1.DrawSprite(a, p, x, y, s, xflip, yflip: integer);
var i, j, k, w, h, x_start, x_diff, y_start, y_diff: integer;
begin
  w := s shr 2;
  h := s and 3;
  k := 0;
  if xflip = 0 then
    begin
    x_start := x;
    x_diff := 8;
    end
  else
    begin
    x_start := x+(w*8);
    x_diff := -8;
    end;
  if yflip = 0 then
    begin
    y_start := y;
    y_diff := 8;
    end
  else
    begin
    y_start := y+(h*8);
    y_diff := -8;
    end;
  for i := 0 to w do
    for j := 0 to h do
      begin
      DrawTile(a+(k*32),p,x_start+(i*x_diff),y_start+(j*y_diff),xflip,yflip);
      inc(k);
      end;
end;

procedure TForm1.DrawMap(a, x, y: integer);
var sprcount, pos, xflip, yflip, priority, k: integer;
label loophi;
begin
  sprcount := GetM_U(a,sprcount_size,$FFFF); // Sprite count.
  k := 0;
  loophi:
  pos := a+sprcount_size+(sprcount*spr_size)-spr_size; // Start at last sprite.
  while pos >= a+sprcount_size do
    begin
    if GetM_U(pos+xflip_,xflip_size,xflip_mask) = 0 then xflip := 0
    else xflip := 1;
    if GetM_U(pos+yflip_,yflip_size,yflip_mask) = 0 then yflip := 0
    else yflip := 1;
    if GetM_U(pos+priority_,priority_size,priority_mask) = 0 then priority := 0
    else priority := 1;
    if k = priority then
      DrawSprite(GetM_U(pos+tile_,tile_size,tile_mask)*$20,
        GetM_U(pos+palette_,palette_size,palette_mask) shr BitShift(palette_mask),
        x+GetM(pos+x_,x_size,x_mask),
        y+GetM(pos+y_,y_size,y_mask),
        GetM_U(pos+dim_,dim_size,dim_mask),
        xflip,yflip);
    pos := pos-spr_size; // Next sprite.
    end;
  inc(k);
  if k < 2 then goto loophi; // Repeat for hi priority sprites (they will be drawn on top).
end;

function TForm1.BitShift(i: integer): integer; // Find lowest bit which is set.
var b: integer;
begin
  b := 0;
  while i and 1 <> 1 do // Check if lowest bit is set.
    begin
    i := i shr 1; // Next bit.
    inc(b);
    if b = 16 then break; // Stop after 16.
    end;
  result := b;
end;

procedure TForm1.btnSaveClick(Sender: TObject);
var mypng: string;
begin
  if dlgSave.Execute then
    begin
    if ExtractFileExt(dlgSave.FileName) = '.png' then mypng := dlgSave.FileName
    else mypng := dlgSave.FileName+'.png'; // Add extension if needed.
    PNG.SaveToFile(mypng); // Save PNG.
    end;
end;

end.
