unit DataAccessModule;

interface

uses
  System.SysUtils, System.Classes, IPPeerClient, REST.Backend.KinveyProvider,
  REST.Backend.ServiceTypes, REST.Backend.MetaTypes, System.JSON,
  REST.Backend.KinveyServices, REST.Backend.Providers,
  REST.Backend.ServiceComponents, FMX.Types, FMX.Media, FMX.Notification,
  System.Beacon, System.Beacon.Components, REST.Backend.PushTypes,
  Data.Bind.Components, Data.Bind.ObjectScope, REST.Backend.BindSource;

const
  WARNNING_DISTANCE     = 1;    // ���� ��� �Ÿ�(m)
  WARNNING_REPORT_COUNT = 5;     // �����ڿ��� �����ؾ� �ϴ� Ƚ��(ȸ)

  SENDLOG_TERM_SEC  = 3;        // 3�ʿ� �ѹ� �α�����

type
  TdmDataAccess = class(TDataModule)
    KinveyProvider1: TKinveyProvider;
    BackendUsers1: TBackendUsers;
    BackendStorage1: TBackendStorage;
    NotificationCenter1: TNotificationCenter;
    MediaPlayer1: TMediaPlayer;
    Beacon1: TBeacon;
    Timer1: TTimer;
    BackendPush1: TBackendPush;
    procedure Beacon1BeaconEnter(const Sender: TObject; const ABeacon: IBeacon;
      const CurrentBeaconList: TBeaconList);
    procedure Beacon1BeaconExit(const Sender: TObject; const ABeacon: IBeacon;
      const CurrentBeaconList: TBeaconList);
    procedure Timer1Timer(Sender: TObject);
  private
    FUsername: string;
    FBeacon: IBeacon;
    FActive: Boolean;

    // �����Ÿ� �ȿ� ����
    FIsWarnnig: Boolean;  // ���Կ���
    FWarnTimes: Integer;  // ���� �� ȸ��

    FSendLogTerm: Integer;
    FIsSendLog: Boolean;  // �α� ���� ����

    FOnAlertStop: TNotifyEvent;
    FOnAlertStart: TNotifyEvent;

    procedure SetUsername(const Value: string);

    procedure SetActive(const Value: Boolean);

    // ���� �˸�(Ǫ�� �޽���)
    procedure FireNotification(const AMsg: string);
    procedure SendRemotePush(const AMsg, AWarning: string);

    // ���� ��� ���̷�
    procedure StartAlertSiren;
    procedure StopAlertSiren;

    // �������� ���� �α�
    procedure SendDangerZoneLog(const ADistance: Double);
    // �������� �����Ÿ� �̳� ���� �� �����ڿ� �˸�
    procedure SendPushEnterDangerZone;
    procedure SendPushExitDangerZone;
//    procedure SendDangerZonePushToAdmin(const ADistance: Double);

    procedure DoEnterBeacon;
    procedure DoExitBeacon;
    procedure DoStartAlert;
    procedure DoStopAlert;
  public
    { Public declarations }
    property Username: string read FUsername write SetUsername;

    property Active: Boolean read FActive write SetActive;
    procedure SetSendLog(const Value: Boolean);
    property Beacon: IBeacon read FBeacon;

    property OnAlertStart: TNotifyEvent read FOnAlertStart write FOnAlertStart;
    property OnAlertStop: TNotifyEvent read FOnAlertStop write FOnAlertStop;
  end;

var
  dmDataAccess: TdmDataAccess;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

uses
  System.IOUtils;

{ TdmDataAccess }

procedure TdmDataAccess.Beacon1BeaconEnter(const Sender: TObject;
  const ABeacon: IBeacon; const CurrentBeaconList: TBeaconList);
begin
  FBeacon := ABeacon;

  DoEnterBeacon;
end;

procedure TdmDataAccess.Beacon1BeaconExit(const Sender: TObject;
  const ABeacon: IBeacon; const CurrentBeaconList: TBeaconList);
begin
  FBeacon := nil;

  DoExitBeacon;
end;

procedure TdmDataAccess.DoEnterBeacon;
begin
  FireNotification('�ٹ濡 �������� �ֽ��ϴ�. ������ �������� �̵��ϼ���.');
  Timer1.Enabled := True;
end;

procedure TdmDataAccess.DoExitBeacon;
begin
  DoStopAlert;
  Timer1.Enabled := False;
end;

procedure TdmDataAccess.DoStartAlert;
begin
  FireNotification('���������� �����߽��ϴ�. ������ �������� �̵��ϼ���.');
  StartAlertSiren;

  if Assigned(FOnAlertStart) then
    FOnAlertStart(Self)
end;

procedure TdmDataAccess.DoStopAlert;
begin
  StopAlertSiren;

  if Assigned(FOnAlertStop) then
    FOnAlertStop(Self)
end;

procedure TdmDataAccess.FireNotification(const AMsg: string);
var
  Noti: TNotification;
begin
  Noti := NotificationCenter1.CreateNotification;
  try
    Noti.Name := '�������� ����';
    Noti.AlertBody := AMsg;
    Noti.EnableSound := True;
    Noti.AlertAction := 'Launch';
    Noti.HasAction := True;
    Noti.FireDate := Now();
    NotificationCenter1.ScheduleNotification(Noti);
  finally
    Noti.DisposeOf;
  end;
end;

// ���̷� �︮��
procedure TdmDataAccess.StartAlertSiren;
begin
  MediaPlayer1.FileName := TPath.Combine(TPath.GetDocumentsPath, 'alert.mp3');
  MediaPlayer1.Play;
end;

procedure TdmDataAccess.StopAlertSiren;
begin
  MediaPlayer1.Stop;
end;

procedure TdmDataAccess.Timer1Timer(Sender: TObject);
begin
  if not Assigned(FBeacon) then
  begin
    Timer1.Enabled := False;
    Exit;
  end;

  // �����Ÿ�(1m) ���� ���� �� ���
  if not FIsWarnnig then
  begin
    if FBeacon.Distance <= WARNNING_DISTANCE then
    begin
      DoStartAlert;
      FIsWarnnig := True;
    end;
  end;

  // �����Ÿ�(1m) ������ ���� �� ��� �ߴ�
  if FIsWarnnig then
  begin
    if FBeacon.Distance > WARNNING_DISTANCE then
    begin
      DoStopAlert;
      FIsWarnnig := False;
    end;
  end;

  // 3��(���� �ֱ�)���� ������������ �Ÿ��α� ����
  if FSendLogTerm = SENDLOG_TERM_SEC then
  begin
    SendDangerZoneLog(FBeacon.Distance);
    FSendLogTerm := 0;
  end
  else
    Inc(FSendLogTerm);

  // 5�� �̻� �ӹ��� ��� ������ ����
  if FIsWarnnig then
  begin
    Inc(FWarnTimes);
    if FWarnTimes = WARNNING_REPORT_COUNT then
      SendPushEnterDangerZone;
  end
  else
  begin
    // 5�� �̻� �ӹ��� �����ڿ� ���� �� ��� �ߴ� �˸�
    if FWarnTimes >= WARNNING_REPORT_COUNT then
      SendPushExitDangerZone;

    FWarnTimes := 0;
  end;
end;

// Ŭ���忡 �α� ���
procedure TdmDataAccess.SendDangerZoneLog(const ADistance: Double);
var
  JSON : TJSONObject;
  ACreatedObject: TBackendEntityValue;
begin
  if not FIsSendLog then
    Exit;

  JSON := TJSONObject.Create;
  JSON.AddPair('username', FUsername);
  JSON.AddPair('distance', ADistance.ToString);
  JSON.AddPair('datetime', FormatDateTime('YYYY-MM-DD HH:NN:SS', Now));
  JSON.AddPair('uuid', FBeacon.GUID.ToString);
  JSON.AddPair('major', FBeacon.Major.ToString);
  JSON.AddPair('minor', FBeacon.Minor.ToString);

  BackendStorage1.Storage.CreateObject('dangerzonelog', JSON, ACreatedObject);
end;

procedure TdmDataAccess.SendPushEnterDangerZone;
begin
  SendDangerZoneLog(FBeacon.Distance);
  SendRemotePush(Format('[%s] �������� ����', [FUsername]), 'ON');
end;

procedure TdmDataAccess.SendPushExitDangerZone;
begin
  SendRemotePush(Format('[%s] �������� ����', [FUsername]), 'OFF');
end;

// ���� Ǫ�� �޽��� ����
procedure TdmDataAccess.SendRemotePush(const AMsg, AWarning: string);
var
  Data: TPushData;
begin
  Data := TPushData.Create;
  try
    Data.Message      := AMsg;
    Data.GCM.Title    := '�������� ���� �溸';
    Data.GCM.Message  := AMsg;
    Data.Extras.Add('username', 'admin');
    Data.Extras.Add('worker', FUsername);
    Data.Extras.Add('warning', AWarning);

    BackEndPush1.PushData(Data);
  finally
    Data.Free;
  end;
end;

procedure TdmDataAccess.SetActive(const Value: Boolean);
begin
  if FActive = Value then
    Exit;

  FActive := Value;
  Beacon1.Enabled := Value;
end;

procedure TdmDataAccess.SetSendLog(const Value: Boolean);
begin
  FIsSendLog := Value;
end;

procedure TdmDataAccess.SetUsername(const Value: string);
begin
  FUsername := Value;
end;

end.
