unit RepeaterForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.ScrollBox, FMX.Memo, FMX.MultiView, FMX.Layouts, FMX.Controls.Presentation,
  IPPeerClient, IPPeerServer, System.Beacon, System.Bluetooth, CommonTypes,
  FMX.ListView.Types, FMX.ListView, FMX.Objects, System.Bluetooth.Components,
  System.Beacon.Components, System.Tether.Manager, System.Tether.AppProfile;

type
  TForm1 = class(TForm)
    ToolBar1: TToolBar;
    Label1: TLabel;
    Layout1: TLayout;
    MultiView1: TMultiView;
    Label2: TLabel;
    Memo1: TMemo;
    CheckBox1: TCheckBox;
    TetheringManager: TTetheringManager;
    TetheringAppProfile: TTetheringAppProfile;
    Beacon1: TBeacon;
    BluetoothLE1: TBluetoothLE;
    Layout2: TLayout;
    Layout3: TLayout;
    ToolBar2: TToolBar;
    ToolBar3: TToolBar;
    Label3: TLabel;
    Label4: TLabel;
    Layout4: TLayout;
    lblWeight: TLabel;
    Label5: TLabel;
    StatusBar1: TStatusBar;
    txtBLEStatus: TText;
    swcBLE: TSwitch;
    swcBeacon: TSwitch;
    lvBeacons: TListView;
    AniIndicator1: TAniIndicator;
    Timer1: TTimer;
    CheckBox2: TCheckBox;
    Text1: TText;
    procedure CheckBox1Change(Sender: TObject);
    procedure Beacon1BeaconEnter(const Sender: TObject; const ABeacon: IBeacon;
      const CurrentBeaconList: TBeaconList);
    procedure swcBeaconSwitch(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BluetoothLE1CharacteristicRead(const Sender: TObject;
      const ACharacteristic: TBluetoothGattCharacteristic;
      AGattStatus: TBluetoothGattStatus);
    procedure BluetoothLE1EndDiscoverDevices(const Sender: TObject;
      const ADeviceList: TBluetoothLEDeviceList);
    procedure swcBLESwitch(Sender: TObject);
    procedure Beacon1BeaconExit(const Sender: TObject; const ABeacon: IBeacon;
      const CurrentBeaconList: TBeaconList);
    procedure Timer1Timer(Sender: TObject);
    procedure Beacon1BeaconProximity(const Sender: TObject;
      const ABeacon: IBeacon; Proximity: TBeaconProximity);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure BluetoothLE1EndDiscoverServices(const Sender: TObject;
      const AServiceList: TBluetoothGattServiceList);
    procedure TetheringManagerPairedFromLocal(const Sender: TObject;
      const AManagerInfo: TTetheringManagerInfo);
  private
    FBeaconList: TBeaconList;

    procedure StartBeaconScan;
    procedure StopBeaconScan;
  private
    // Bluetooth LE ü�߰�
    FScaleDiscoverCount: Integer;
    FWeight: Single;
    FSendDataWeight: Single;

    FWahooDevice: TBluetoothLEDevice;
    FWeightGattService: TBluetoothGattService;
    FWeightMeasurementGattCharacteristic: TBluetoothGattCharacteristic;

    procedure StartScale;
    procedure StopScale;
  private
    procedure SendDataBeaconList(ABeaconList: TBeaconList);
    procedure SendDataScale(AWeight: Single);
  public
    { Public declarations }
  end;

const
  Weight_Service: TBluetoothUUID          = '{00001901-0000-1000-8000-00805F9B34FB}';
  Weight_Characteristic: TBluetoothUUID   = '{00002B01-0000-1000-8000-00805F9B34FB}';

var
  Form1: TForm1;

implementation

{$R *.fmx}

uses
  System.JSON;

procedure TForm1.FormCreate(Sender: TObject);
begin
  AniIndicator1.Visible := False;
  lblWeight.Text := '--';

  FWeight := 0;
  FSendDataWeight := 0;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
var
  Info: TTetheringProfileInfo;
begin
  Timer1.Enabled := False;

  for Info in TetheringManager.RemoteProfiles do
  begin
    TetheringAppProfile.Disconnect(Info);
  end;

  TetheringAppProfile.Enabled := False;
  TetheringManager.Enabled := False;
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
  if CheckBox1.IsChecked then
    MultiView1.Mode := TMultiViewMode.Panel
  ELSE
    MultiView1.Mode := TMultiViewMode.PlatformBehaviour;
end;

{$REGION 'Proximity(Beacon) �ڵ�'}

procedure TForm1.swcBeaconSwitch(Sender: TObject);
begin
  if swcBeacon.IsChecked then
    StartBeaconScan
  else
    StopBeaconScan;
end;

procedure TForm1.StartBeaconScan;
begin
  Beacon1.Enabled := True;
  Memo1.Lines.Add('[START] ���� ������ ���� ����');
end;

procedure TForm1.StopBeaconScan;
begin
  Beacon1.Enabled := False;
  FBeaconList := nil;
  Memo1.Lines.Add('[STOP] ���� ������ ���� ����');
end;

procedure TForm1.Beacon1BeaconEnter(const Sender: TObject;
  const ABeacon: IBeacon; const CurrentBeaconList: TBeaconList);
begin
  Memo1.Lines.Add(Format(' + (M:%d, m:%d) ����(%s)', [ABeacon.Major, ABeacon.Minor, ABeacon.Proximity.ToString]));
  FBeaconList := CurrentBeaconList;
end;

procedure TForm1.Beacon1BeaconExit(const Sender: TObject;
  const ABeacon: IBeacon; const CurrentBeaconList: TBeaconList);
begin
  Memo1.Lines.Add(Format(' - (M:%d, m:%d) ����(%s)', [ABeacon.Major, ABeacon.Minor, ABeacon.Proximity.ToString]));
  FBeaconList := CurrentBeaconList;
end;

procedure TForm1.Beacon1BeaconProximity(const Sender: TObject;
  const ABeacon: IBeacon; Proximity: TBeaconProximity);
begin
  if CheckBox2.IsChecked then
    Memo1.Lines.Add(Format(' > (M:%d, m:%d) ������ ����(%s)', [ABeacon.Major, ABeacon.Minor, ABeacon.Proximity.ToString]));
end;

{$ENDREGION}

{$REGION 'BLE Scale �ڵ�'}
procedure TForm1.swcBLESwitch(Sender: TObject);
begin
  if swcBLE.IsChecked then
    StartScale
  else
    StopScale;

//  BluetoothLE1.CurrentManager.
end;

procedure TForm1.StartScale;
begin
  try
    FScaleDiscoverCount := 0;

    lblWeight.Text := '--';
    BluetoothLE1.Enabled := True;
    AniIndicator1.Visible := True;
    BluetoothLE1.DiscoverDevices(1000);
    txtBLEStatus.Text := 'Discover deivce';

    Memo1.Lines.Add('��ġ�� ã���ϴ�.');
  except on E: Exception do
    Log.d('[E] StartScale(E: %s)', [E.Message]);
  end;
end;

procedure TForm1.StopScale;
begin
  If FWahooDevice <> nil then
    BluetoothLE1.UnSubscribeToCharacteristic(FWahooDevice, FWeightMeasurementGattCharacteristic);
  BluetoothLE1.Enabled := False;
end;

procedure TForm1.BluetoothLE1EndDiscoverDevices(const Sender: TObject;
  const ADeviceList: TBluetoothLEDeviceList);
var
  Device: TBluetoothLEDevice;
begin
  FWahooDevice := nil;
  for Device in ADeviceList do
  begin
    if Device.DeviceName.StartsWith('Wahoo') then
    begin
      FWahooDevice := Device;
      Break;
    end;
  end;

  if not Assigned(FWahooDevice) then
  begin
    if FScaleDiscoverCount < 3 then
    begin
      Inc(FScaleDiscoverCount);
      Memo1.Lines.Add(Format('��ġ�� ã���ϴ�.(%d)', [FScaleDiscoverCount]));
      BluetoothLE1.DiscoverDevices(1000);
      Exit;
      // ��õ�
    end;
    swcBLE.IsChecked := False;
    txtBLEStatus.Text := 'Not found device.';
    Memo1.Lines.Add('��ġ�� ã�� ���߽��ϴ�.');
    AniIndicator1.Visible := False;
    
    Exit;
  end;

  Memo1.Lines.Add(Format('''%s''�� ã�ҽ��ϴ�.', [FWahooDevice.DeviceName]));

  Memo1.Lines.Add('ü�� ���� ���񽺸� ã���ϴ�.');
  if not FWahooDevice.DiscoverServices then
    FWahooDevice.DiscoverServices;
end;

procedure TForm1.BluetoothLE1EndDiscoverServices(const Sender: TObject;
  const AServiceList: TBluetoothGattServiceList);
begin
  FWeightGattService := BluetoothLE1.GetService(FWahooDevice, Weight_SERVICE);

  if FWeightGattService <> nil then
  begin
    // get Weight Characteristic
    BluetoothLE1.GetCharacteristics(FWeightGattService);
    FWeightMeasurementGattCharacteristic :=
          BluetoothLE1.GetCharacteristic(FWeightGattService, Weight_CHARACTERISTIC);

    // �����ϸ� OnCharacteristicRead �̺�Ʈ�� �߻���
    if FWeightMeasurementGattCharacteristic <> nil then
      BluetoothLE1.SubscribeToCharacteristic(FWahooDevice, FWeightMeasurementGattCharacteristic);
    txtBLEStatus.Text := 'Connected device.';
    Memo1.Lines.Add('ü�߰�� ����Ǿ����ϴ�.');
  end
  else
  begin
    swcBLE.IsChecked := False;
    txtBLEStatus.Text := 'Service not found';
    Memo1.Lines.Add('ü�� ���� ���񽺸� ã�� �� �����ϴ�.');
  end;
  AniIndicator1.Visible := False;
end;

procedure TForm1.BluetoothLE1CharacteristicRead(const Sender: TObject;
  const ACharacteristic: TBluetoothGattCharacteristic;
  AGattStatus: TBluetoothGattStatus);
begin
  if AGattStatus = TBluetoothGattStatus.Success then
  begin
    // ���� ����Ʈ �� �ڿ��� �ι�����Ʈ���� ���(���� �ѹ���Ʈ �б�: shr 8)
      // �Ҽ��� ���ڸ��� ������ ���� > ���ڸ� �Ҽ��� �����: / 10
    FWeight := (ACharacteristic.GetValueAsInteger shr 8) / 10;;
    lblWeight.Text := Format('%3.1f',[FWeight]);
  end;
end;

{$ENDREGION}

procedure TForm1.TetheringManagerPairedFromLocal(const Sender: TObject;
  const AManagerInfo: TTetheringManagerInfo);
begin
  Memo1.Lines.Add('���ο� Ŭ���̾�Ʈ ����');
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  Beacon: IBeacon;
  Item: TListViewItem;
begin
  // ����Ʈ ǥ��
  if Assigned(FBeaconList) then
  begin
    lvBeacons.Items.Clear;
    for Beacon in FBeaconList do
    begin
      Item := lvBeacons.Items.Add;
      Item.Text := Format('M: %d, m: %d', [Beacon.Major, Beacon.Minor]);
      Item.Detail := Beacon.Distance.ToString;
    end;
    SendDataBeaconList(FBeaconList);
  end;

  SendDataScale(FWeight);

  Text1.Text := Format('%s(%d)', [FormatDateTime('HH:NN:SS', Now), TetheringAppProfile.ConnectedProfiles.Count]);
end;

procedure TForm1.SendDataBeaconList(ABeaconList: TBeaconList);
var
  Data: string;
  Profile: TTetheringProfileInfo;
begin
  if TetheringAppProfile.ConnectedProfiles.Count > 0 then
  begin
    for Profile in TetheringAppProfile.ConnectedProfiles do
    begin
      try
        Data := TBeaconListJSON.BeaconListToJSONStr(FBeaconList);

  //      Memo1.Lines.Add(Data);
        TetheringAppProfile.SendString(Profile, TBeaconDataName.BeaconList, Data);
      except on E: Exception do
        Log.d('[E] SendDataBeaconList(E: %s)', [E.Message]);
      end;
    end;
  end;
end;

procedure TForm1.SendDataScale(AWeight: Single);
var
  Profile: TTetheringProfileInfo;
begin
  if FSendDataWeight = AWeight then
    Exit;

  for Profile in TetheringAppProfile.ConnectedProfiles do
    TetheringAppProfile.SendString(Profile, TBeaconDataName.ScaleData, Format('%3.1f',[AWeight]));
end;

end.
