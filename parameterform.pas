unit ParameterForm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TfrmParameter }

  TfrmParameter = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    cbbKind: TComboBox;
    cbbName: TComboBox;
    chkNotEncoded: TCheckBox;
    edtValue: TEdit;
    lblKind: TLabel;
    lblValue: TLabel;
    lblName: TLabel;
    procedure btnOKClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  frmParameter: TfrmParameter;

implementation

{$R *.lfm}

{ TfrmParameter }

{
COOKIE
GET/POST
URL-SEGMENT
HEADER
BODY
FILE
QUERY

}
procedure TfrmParameter.btnOKClick(Sender: TObject);
begin
  if Trim(cbbName.Text) = '' then
  begin
    MessageDlg('Insert name of param!', mtError, [mbOK], 0);
    exit;
  end;
  ModalResult := mrOk;
end;

procedure TfrmParameter.FormCreate(Sender: TObject);
begin
  cbbKind.ItemIndex := 1;
  edtValue.Text := '';
  cbbName.Text := '';
  chkNotEncoded.Checked := False;
end;

end.
