unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  StdCtrls, ParameterForm, fphttpclient, fpjson, jsonparser, URIParser,
  httpprotocol, opensslsockets, IniFiles, base64, Clipbrd, StrUtils;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btnAddParam: TButton;
    btnPaste: TButton;
    btnEditParam: TButton;
    btnDeleteParam: TButton;
    btnLoad: TButton;
    cbbMethod: TComboBox;
    cbbMethodAuth: TComboBox;
    cbbUrl: TComboBox;
    cbbContentType: TComboBox;
    cbbUserAgent: TComboBox;
    edtUsername: TEdit;
    edtPassword: TEdit;
    edtResource: TEdit;
    edtUsernameKey: TEdit;
    edtPasswordKey: TEdit;
    edtClientID: TEdit;
    edtClientSecret: TEdit;
    edtAccessToken: TEdit;
    edtRequestToken: TEdit;
    gbRequest: TGroupBox;
    gbResponse: TGroupBox;
    il16: TImageList;
    Label1: TLabel;
    lblRequestParameters: TLabel;
    lblResource: TLabel;
    lblResponseMessage: TLabel;
    lblMethod: TLabel;
    lblMethod1: TLabel;
    lblPassword1: TLabel;
    lblClientSecret: TLabel;
    lblRequestToken: TLabel;
    lblUrl: TLabel;
    lblContentType: TLabel;
    lblBody: TLabel;
    lblUserAgent: TLabel;
    lblUsername: TLabel;
    lblPassword: TLabel;
    lblUsername1: TLabel;
    lblClientID: TLabel;
    lblAccessToken: TLabel;
    lvParameters: TListView;
    mmoBodyRequest: TMemo;
    mmoHeaders: TMemo;
    mmoLog: TMemo;
    mmoBodyResponse: TMemo;
    pgcRequest: TPageControl;
    pgcResponse: TPageControl;
    Splitter1: TSplitter;
    sbStatus: TStatusBar;
    tsDebug: TTabSheet;
    tlbMain: TToolBar;
    btnSendRequest: TToolButton;
    ToolButton1: TToolButton;
    btnNewRequest: TToolButton;
    btnLoadRequest: TToolButton;
    btnSaveRequest: TToolButton;
    ToolButton2: TToolButton;
    tsAuthentication: TTabSheet;
    tsTabularData: TTabSheet;
    tsConnection: TTabSheet;
    tsParameters: TTabSheet;
    tsBody: TTabSheet;
    tsRequest: TTabSheet;
    tsHeaders: TTabSheet;
    procedure btnAddParamClick(Sender: TObject);
    procedure btnDeleteParamClick(Sender: TObject);
    procedure btnEditParamClick(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnLoadRequestClick(Sender: TObject);
    procedure btnNewRequestClick(Sender: TObject);
    procedure btnPasteClick(Sender: TObject);
    procedure btnSaveRequestClick(Sender: TObject);
    procedure btnSendRequestClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lvParametersDblClick(Sender: TObject);
  private
    FFilename: string;
    HTCResource: TFPHTTPClient;
    procedure AddHeaderCookie();
    procedure AddHeaders();
    procedure AddParameter(var Item: TListItem; AKind, AName, AValue: string; NotEncripted: boolean);
    procedure LoadRawRequest(FileValue: string);
  public
    function ConfigConnection: string;
    procedure ClearResponse();
    procedure SaveToFile(Filename: string);
    procedure LoadFromFile(Filename: string);
  end;

var
  frmMain: TfrmMain;
  AppDir: string;

const
  ENUM_METHOD: array of string = ('POST', 'PUT', 'GET', 'DELETE', 'PATCH');

implementation

{$R *.lfm}

{ TfrmMain }

procedure Debug(Value: string);
begin
  //OutputDebugString(PChar(Value));
  frmMain.mmoLog.Lines.Add(Value);
  //SendMessage(frmMain.mmoLog.Handle, EM_LINESCROLL, 0, frmMain.mmoLog.Lines.Count);
  frmMain.mmoLog.SelStart := Length(frmMain.mmoLog.Text);
end;

function SLPos(Sub, Value: string; const IgnoreCase: boolean = False): boolean;
begin
  if IgnoreCase then
    Result := Pos(Sub.ToLower, Value.ToLower) > 0
  else
    Result := Pos(Sub, Value) > 0;
end;


function SLMultiPos(Sub: array of string; Value: string; const IgnoreCase: boolean = False): boolean;
var
  Tmp: string;
begin
  Result := True;
  for Tmp in sub do
  begin
    Result := SLPos(tmp, Value, IgnoreCase);
    if not Result then Exit;
  end;
end;

function Explode(Delimiter: char; Value: string; const TrimSpace: boolean = False): TStringList;
begin

  Result := TStringList.Create;
  Result.Delimiter := Delimiter;
  Result.StrictDelimiter := True;
  Result.DelimitedText := Value;
  if TrimSpace then
    Result.Text := Trim(Result.Text);
end;

function Implode(Delimiter: char; StringList: TStrings): string;
begin

  StringList.Delimiter := Delimiter;
  StringList.QuoteChar := #0;
  Result := StringList.DelimitedText;
end;

procedure SetPanelText(Text: string; PanelIndex: integer = 0; const Space: integer = 0);
var
  W: integer;
begin
  with frmMain.sbStatus do
  begin
    Canvas.Font := frmMain.sbStatus.Font;
    Panels[PanelIndex].Text := Text;
    W := Canvas.TextWidth(Text + ' ');
    Panels[PanelIndex].Width := W + 20 + Space;
    Update;
  end;
end;

function TfrmMain.ConfigConnection: string;
var
  P: string;
begin
  HTCResource.UserName := edtUsername.Text;
  HTCResource.Password := edtPassword.Text;
  Result := cbbUrl.Text;
  if (Result = '') then
    raise Exception.Create('Need a URL to perform request');
  P := LowerCase(ParseUri(Result, False).Protocol);
  if (P <> 'http') and (P <> 'https') then
    Result := 'http://' + Result;
  Result := IncludeHTTPPathDelimiter(Result);

  Debug(Result);
end;

procedure TfrmMain.AddHeaders();
var

  Item: TListItem;
  Value: string;
begin

  for Item in lvParameters.Items do
  begin
    if Item.Caption <> 'HEADER' then Continue;

    if StrToBool(Item.SubItems[2]) then
      HTCResource.AddHeader(Item.SubItems[0], EncodeStringBase64(Item.SubItems[1]))
    else
      HTCResource.AddHeader(Item.SubItems[0], Item.SubItems[1]);

  end;

end;

procedure TfrmMain.AddHeaderCookie();
var
  List: TStringList;
  Item: TListItem;
  Value: string;
begin
  List := TStringList.Create;
  for Item in lvParameters.Items do
  begin
    if Item.Caption <> 'COOKIE' then Continue;

    List.Add(' ' + Item.SubItems[0] + '=' + Item.SubItems[1]);
  end;

  if List.Count > 0 then
  begin
    Value := Implode(';', List);
    Value := Value.Trim;
    HTCResource.AddHeader('Cookie', Value);
  end;
  List.Free;
end;

procedure TfrmMain.AddParameter(var Item: TListItem; AKind, AName, AValue: string; NotEncripted: boolean);

begin
  if Item = nil then
  begin
    Item := lvParameters.Items.Add;
    Item.Caption := AKind;
    Item.SubItems.Add(AName);
    Item.SubItems.Add(AValue);
    Item.SubItems.Add(BoolToStr(NotEncripted, True));
  end
  else
  begin
    Item.Caption := AKind;
    Item.SubItems[0] := AName;
    Item.SubItems[1] := AValue;
    Item.SubItems[2] := BoolToStr(NotEncripted, True);
  end;

end;

procedure TfrmMain.LoadRawRequest(FileValue: string);
var
  Temp, List: TStringList;
  Key, Value: string;
  I, X: integer;
  Item: TListItem;
  S: string;
begin
  List := TStringList.Create;
  List.NameValueSeparator := ':';

  if FileExists(FileValue) then
    List.LoadFromFile(FileValue)
  else
    List.Text := FileValue;

  if trim(List.Text) = '' then Exit;


  Temp := Explode(' ', List[0]);
  if Temp.Count = 3 then
  begin
    cbbMethod.ItemIndex := cbbMethod.Items.IndexOf(UpperCase(Temp[0]));
    cbbUrl.Text := Temp[1];
  end;
  Temp.Free;

  //HEADER
  X := 0;
  for I := 1 to List.Count - 1 do
  begin
    S := trim(List[I]);

    if S = '' then
    begin
      X := I + 1;
      Break;
    end;

    Item := nil;
    Key := List.Names[I];
    Value := List.ValueFromIndex[I].Trim;

    case AnsiIndexStr(Key.ToLower, ['content-type', 'user-agent', 'cookie']) of
      0: cbbContentType.Text := Value;
      1: cbbUserAgent.Text := Value;
      2: AddParameter(Item, 'COOKIE', Key, Value, False);
      else
        AddParameter(Item, 'HEADER', Key, Value, False);
    end;
  end;

  //BODY
  mmoBodyRequest.Clear;
  for I := X to List.Count - 1 do
  begin
    S := List[I];
    mmoBodyRequest.Lines.Add(s);
  end;

  List.Free;
  //BODY
end;

procedure TfrmMain.ClearResponse();
begin
  mmoHeaders.Clear;
  mmoBodyResponse.Clear;
  mmoLog.Clear;

  lblResponseMessage.Caption := 'Response Message:';

  SetPanelText('', 2, 20);
  pgcResponse.ActivePageIndex := 0;
end;

procedure SaveComboBox(ComboBox: TComboBox);
var
  List: TStringList;
  Value, Section: string;
  I, Count: integer;
begin
  List := TStringList.Create;
  List.Text := LowerCase(ComboBox.Items.Text).Trim;
  Value := Trim(ComboBox.Text);
  if Value.Length > 0 then
  begin
    if List.IndexOf(LowerCase(Value)) = -1 then
      ComboBox.Items.Insert(0, Value);
  end;
  List.Free;

  Section := Copy(ComboBox.Name, 4, Length(ComboBox.Name));
  with TIniFile.Create(AppDir + 'LazRestDebugger.dat', TEncoding.UTF8) do
  begin

    Count := ReadInteger(Section, 'Count', 0);
    for I := 0 to Count - 1 do DeleteKey(Section, 'Value|' + I.ToString);


    Count := ComboBox.Items.Count;
    WriteInteger(Section, 'Count', Count);
    for I := 0 to Count - 1 do WriteString(Section, 'Value|' + I.ToString, ComboBox.Items[I]);

    Free;
  end;
end;


procedure TfrmMain.LoadFromFile(Filename: string);
var
  I, Count: integer;
  Item: TListItem;
begin

  with TIniFile.Create(Filename, TEncoding.UTF8) do
  begin

    //REQUEST
    cbbMethod.ItemIndex := ReadInteger('Request', 'Method', 0);
    cbbUrl.Text := ReadString('Request', 'Url', '');
    cbbContentType.Text := ReadString('Request', 'ContentType', 'application/json');
    mmoBodyRequest.Text := DecodeStringBase64(ReadString('Request', 'Body', ''));

    //AUTH
    cbbMethodAuth.ItemIndex := ReadInteger('Authentication', 'Method', 0);
    edtUsername.Text := ReadString('Authentication', 'Username', '');
    edtPassword.Text := ReadString('Authentication', 'Password', '');
    edtUsernameKey.Text := ReadString('Authentication', 'UsernameKey', '');
    edtPasswordKey.Text := ReadString('Authentication', 'PasswordKey', '');
    edtClientID.Text := ReadString('Authentication', 'ClientID', '');
    edtClientSecret.Text := ReadString('Authentication', 'ClientSecret', '');
    edtAccessToken.Text := ReadString('Authentication', 'AccessToken', '');
    edtRequestToken.Text := ReadString('Authentication', 'RequestToken', '');

    //PARAMETERS
    edtResource.Text := ReadString('Parameters', 'Resource', '');
    Count := ReadInteger('Parameters', 'ParametersCount', 0);
    lvParameters.Clear;

    for I := 0 to Count - 1 do
    begin
      Item := lvParameters.Items.Add;
      Item.Caption := ReadString('Parameters|' + I.ToString, 'Kind', 'GET/POST');
      Item.SubItems.Add(ReadString('Parameters|' + I.ToString, 'Name', ''));
      Item.SubItems.Add(ReadString('Parameters|' + I.ToString, 'Value', ''));
      Item.SubItems.Add(ReadString('Parameters|' + I.ToString, 'NotEncoded', 'False'));
    end;

    //CONNECTION
    cbbUserAgent.Text := ReadString('Connection', 'UserAgent', 'Lazarus RESTClient/1.0');
    Free;
  end;
end;

procedure TfrmMain.SaveToFile(Filename: string);
var
  I, Count: integer;
  Item: TListItem;
begin

  with TIniFile.Create(Filename, TEncoding.UTF8) do
  begin
    //REQUEST
    WriteInteger('Request', 'Method', cbbMethod.ItemIndex);
    WriteString('Request', 'Url', cbbUrl.Text);
    WriteString('Request', 'ContentType', cbbContentType.Text);
    WriteString('Request', 'Body', EncodeStringBase64(mmoBodyRequest.Text));

    //AUTH
    WriteInteger('Authentication', 'Method', cbbMethodAuth.ItemIndex);
    WriteString('Authentication', 'Username', edtUsername.Text);
    WriteString('Authentication', 'Password', edtPassword.Text);
    WriteString('Authentication', 'UsernameKey', edtUsernameKey.Text);
    WriteString('Authentication', 'PasswordKey', edtPasswordKey.Text);
    WriteString('Authentication', 'ClientID', edtClientID.Text);
    WriteString('Authentication', 'ClientSecret', edtClientSecret.Text);
    WriteString('Authentication', 'AccessToken', edtAccessToken.Text);
    WriteString('Authentication', 'RequestToken', edtRequestToken.Text);

    //PARAMETERS
    Count := lvParameters.Items.Count;
    WriteString('Parameters', 'Resource', edtResource.Text);
    WriteInteger('Parameters', 'ParametersCount', Count);

    for I := 0 to Count - 1 do
    begin
      Item := lvParameters.Items[I];
      WriteString('Parameters|' + I.ToString, 'Kind', Item.Caption);
      WriteString('Parameters|' + I.ToString, 'Name', Item.SubItems[0]);
      WriteString('Parameters|' + I.ToString, 'Value', Item.SubItems[1]);
      WriteString('Parameters|' + I.ToString, 'NotEncoded', Item.SubItems[2]);
    end;

    //CONNECTION
    WriteString('Connection', 'UserAgent', cbbUserAgent.Text);
    Free;
  end;
end;


procedure TfrmMain.FormCreate(Sender: TObject);
begin
  AppDir := ExtractFilePath(Application.ExeName);
  HTCResource := TFPHTTPClient.Create(Self);
  pgcRequest.ActivePageIndex := 0;
  pgcResponse.ActivePageIndex := 0;

  btnNewRequestClick(nil);

  if FileExists(AppDir + 'LazRestDebuggerUrls.dat') then
    cbbUrl.Items.LoadFromFile(AppDir + 'LazRestDebuggerUrls.dat');
end;

procedure TfrmMain.lvParametersDblClick(Sender: TObject);
begin
  btnEditParamClick(nil);
end;

procedure TfrmMain.btnSendRequestClick(Sender: TObject);
var
  Url: string;
  Response: TStringStream;
  //MEASURE
  FunctStart: QWord;
  FunctDiff: QWord;
  FunctTime: string;

var
  postJson: TJSONObject;
  Parser: TJSONParser;
begin
  ClearResponse();

  HTCResource := TFPHTTPClient.Create(Self);
  Url := cbbUrl.Text;
  if cbbUrl.Items.IndexOf(Url) = -1 then
  begin
    cbbUrl.Items.Insert(0, Url);
    cbbUrl.Items.SaveToFile(AppDir + 'LazRestDebuggerUrls.dat');
  end;

  ///  Url := ConfigConnection;
  HTCResource.AddHeader('User-Agent', cbbUserAgent.Text);
  HTCResource.AddHeader('Content-Type', cbbContentType.Text);
  //HTCResource.AddHeader('Accept', 'application/json, text/plain; q=0.9, text/html;q=0.8,');
  AddHeaders();
  AddHeaderCookie();

  //HTCResource.AddHeader('Authorization', 'Basic REVNMjEwMTc1Okdlbm5haW8xMCE=');

  // Parser := TJSONParser.Create(mmoBodyRequest.Text);
  //postJson := Parser.Parse as TJSONObject;

  if (edtUsername.Text <> '') and (edtPassword.Text <> '') then
  begin
    HTCResource.UserName := edtUsername.Text;
    HTCResource.Password := edtPassword.Text;

  end;

  HTCResource.RequestBody := TRawByteStringStream.Create(mmoBodyRequest.Text);

  //HTCResource.RequestBody := TStringStream.Create(postJson.AsJSON);
  Debug(HTCResource.RequestHeaders.Text);
  Response := TStringStream.Create('');
  Screen.Cursor := crHourGlass;
  try
    FunctStart := getTickCount64;
    try
      HTCResource.Post(Url, Response);

      mmoHeaders.Lines.AddStrings(HTCResource.ResponseHeaders);
      lblResponseMessage.Caption := 'Response ' + HTCResource.ResponseStatusText + ' Code is ' + IntToStr(HTCResource.ResponseStatusCode);

      lblResponseMessage.Font.Color := clRed;
      if HTCResource.ResponseStatusCode = 200 then
        lblResponseMessage.Font.Color := clGreen;

      Response.SaveToFile('LazRestDebugger.Reponse.txt');
      mmoBodyResponse.Text := Response.DataString;
    except
      on E: Exception do
      begin
        lblResponseMessage.Caption := ('Something bad happened : ' + E.Message);
        lblResponseMessage.Font.Color := clRed;
      end;
    end;
  finally

    FunctDiff := GetTickCount64 - FunctStart;

    Screen.Cursor := crDefault;
    HTCResource.RequestBody.Free;
    HTCResource.Free;
    Response.Free;
  end;


  SetPanelText('Execute Time: ' + TimeToStr(FunctDiff / 24 / 60 / 60 / 1000), 2);


  Debug(lblResponseMessage.Caption);
end;

procedure TfrmMain.btnNewRequestClick(Sender: TObject);
begin
  if Sender <> nil then
    if MessageDlg('Save current session?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then  btnSaveRequestClick(nil);

  pgcRequest.ActivePageIndex := 0;
  pgcResponse.ActivePageIndex := 0;

  FFilename := '';

  cbbMethod.ItemIndex := 0;
  cbbUrl.Text := '';
  cbbContentType.ItemIndex := 0;
  mmoBodyRequest.Text := '';

  cbbMethodAuth.ItemIndex := 0;
  edtUsername.Text := '';
  edtPassword.Text := '';
  edtUsernameKey.Text := '';
  edtPasswordKey.Text := '';
  edtClientID.Text := '';
  edtClientSecret.Text := '';
  edtAccessToken.Text := '';
  edtRequestToken.Text := '';

  edtResource.Text := '';
  lvParameters.Clear;

  ClearResponse();

  SetPanelText('', 0, 20);
  SetPanelText('New Request', 1);
  SetPanelText('', 2, 20);
end;

procedure TfrmMain.btnPasteClick(Sender: TObject);
var
  List: TStringList;
  Key, Value: string;
  I: integer;
  Item: TListItem;
begin
  List := TStringList.Create;
  List.Text := Clipboard.AsText;

  if Trim(List.Text) = '' then
  begin
    MessageDlg('Empty clipboard!', mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg(PChar('Do you parse this parameter?'#13#10 + List.Text), mtConfirmation, [mbYes, mbNo], 0) = mrNo then  Exit;

  List.NameValueSeparator := ':';
  List.Text := Clipboard.AsText;


  for I := 0 to List.Count - 1 do
  begin
    Key := List.Names[I];
    Value := List.ValueFromIndex[I].Trim;

    Item := nil;
    AddParameter(Item, 'HEADER', Key, Value, False);

  end;

end;

procedure TfrmMain.btnLoadRequestClick(Sender: TObject);
begin

  with TOpenDialog.Create(nil) do
  begin
    DefaultExt := '*.lrd';
    Filter := 'LazarusRestDebug (*.lrd)|*.lrd';
    if not Execute then exit;

    FFilename := FileName;
    Free;

  end;

  ClearResponse();

  LoadFromFile(FFilename);

  SetPanelText(FFilename, 0);
  SetPanelText('Loaded At: ' + DateTimeToStr(Now), 1);
  SetPanelText('', 2, 20);
end;

procedure TfrmMain.btnAddParamClick(Sender: TObject);
var
  Item: TListItem;
begin
  frmParameter := TfrmParameter.Create(Self);
  with frmParameter do
  begin
    if ShowModal = mrOk then
    begin
      Item := nil;
      AddParameter(Item, cbbKind.Text, cbbName.Text, edtValue.Text, chkNotEncoded.Checked);
      //Item := lvParameters.Items.Add;
      //Item.Caption := frmParameter.cbbKind.Text;
      //Item.SubItems.Add(frmParameter.cbbName.Text);
      //Item.SubItems.Add(frmParameter.edtValue.Text);
      //Item.SubItems.Add(BoolToStr(frmParameter.chkNotEncoded.Checked, True));

    end;
    Free;
  end;
end;

procedure TfrmMain.btnDeleteParamClick(Sender: TObject);
begin
  if lvParameters.Selected = nil then exit;

  if MessageDlg('Do you want delete the selected parameter?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    lvParameters.Selected.Delete;
  end;

end;

procedure TfrmMain.btnEditParamClick(Sender: TObject);

var
  Item: TListItem;
begin
  if lvParameters.Selected = nil then exit;


  frmParameter := TfrmParameter.Create(Self);
  with frmParameter do
  begin
    cbbKind.ItemIndex := frmParameter.cbbKind.Items.IndexOf(lvParameters.Selected.Caption);
    cbbName.Text := lvParameters.Selected.SubItems[0];
    edtValue.Text := lvParameters.Selected.SubItems[1];
    chkNotEncoded.Checked := StrToBoolDef(lvParameters.Selected.SubItems[2], False);


    if ShowModal = mrOk then
    begin
      Item := lvParameters.Selected;
      AddParameter(Item, cbbKind.Text, cbbName.Text, edtValue.Text, chkNotEncoded.Checked);
      //lvParameters.Selected.Caption := cbbKind.Text;
      //lvParameters.Selected.SubItems[0] := cbbName.Text;
      //lvParameters.Selected.SubItems[1] := edtValue.Text;
      //lvParameters.Selected.SubItems[2] := BoolToStr(chkNotEncoded.Checked, True);

    end;
    Free;

  end;
end;

procedure TfrmMain.btnLoadClick(Sender: TObject);
begin
  with TOpenDialog.Create(nil) do
  begin
    DefaultExt := '*.*';
    Filter := 'All Files|*.*';
    if not Execute then exit;

    LoadRawRequest(FileName);
    Free;

  end;
end;

procedure TfrmMain.btnSaveRequestClick(Sender: TObject);
begin
  if not FileExists(FFilename) then
    with TSaveDialog.Create(nil) do
    begin
      DefaultExt := '*.lrd';
      Filter := 'LazarusRestDebug (*.lrd)|*.lrd';
      if not Execute then exit;

      FFilename := FileName;
      Free;

    end;

  SaveToFile(FFilename);

  SaveComboBox(cbbUrl);
  SaveComboBox(cbbContentType);
  SaveComboBox(cbbUserAgent);

  SetPanelText(FFilename, 0);
  SetPanelText('Saved At: ' + DateTimeToStr(Now), 1);
  SetPanelText('', 2, 20);

end;

end.
