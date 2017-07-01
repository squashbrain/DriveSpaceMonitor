unit DriveSpaceSvc;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs;

const
    cPushoverURL = 'https://api.pushover.net/1/messages.json';
    cConfigFileName = 'DriveMonitor.ini';


type
  TDriveSpaceMonitorService = class(TService)
    procedure ServiceExecute(Sender: TService);
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceAfterUninstall(Sender: TService);
  private
    FDriveMonitorIniFile:String;
    FPushUSERKey:String;
    FPushAPIToken:String;
    FPushDevice:String;
    FMachineName:string;
    FMessageTitle:string;

    //Event logger
    procedure WriteLogToEventLogger(const Msg: string);
    //Send a Pushover message with the drives list provided
    function SendPushoverMsg(ADriveList:TStringList): boolean;
  public
    function GetServiceController: TServiceController; override;
  end;

var
  DriveSpaceMonitorService: TDriveSpaceMonitorService;

implementation

uses
   System.IniFiles, System.DateUtils, System.Win.Registry, IdHTTP, IdSSLOpenSSL, IdSSLOpenSSLHeaders;

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  DriveSpaceMonitorService.Controller(CtrlCode);
end;

function TDriveSpaceMonitorService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TDriveSpaceMonitorService.ServiceAfterInstall(Sender: TService);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;

    if Reg.OpenKey('\SYSTEM\CurrentControlSet\Services\' + Name, True) then
      Reg.WriteString('Description', 'Service used to monitor drive space.');

  finally
    Reg.Free;
  end;
end;

procedure TDriveSpaceMonitorService.ServiceAfterUninstall(Sender: TService);
begin
//
end;

procedure TDriveSpaceMonitorService.ServiceCreate(Sender: TObject);
begin
//
end;

procedure TDriveSpaceMonitorService.ServiceExecute(Sender: TService);
var
  DriveMonitorIni:TMemIniFile;
  CriticalDrivesList:TStringList;
  DriveList:TStringList;
  drvIdx:Integer;

  PercentFullTrigger:Integer;
  CheckIntervalSeconds:Integer;
  LastSentDate:TDateTime;

  PercentFull : TLargeInteger;
  Drive : string;
  FreeBytes : TLargeInteger;
  FreeSize     : TLargeInteger;
  TotalSize    : TLargeInteger;
begin
  //Check drive space here
  while not Terminated do
  begin
    CheckIntervalSeconds := 2000;

    if FileExists(FDriveMonitorIniFile) then
    begin
      DriveMonitorIni := TMemIniFile.Create(FDriveMonitorIniFile);
      try
        DriveList := TStringList.Create;
        CriticalDrivesList := TStringList.Create;
        try
          DriveList.Delimiter := ',';
          DriveList.StrictDelimiter := True;

          //local setttings
          DriveList.DelimitedText := DriveMonitorIni.ReadString('ServiceSettings', 'Drives', 'D:\');
          PercentFullTrigger := DriveMonitorIni.ReadInteger('ServiceSettings', 'PercentFullTrigger', 70);
          CheckIntervalSeconds := DriveMonitorIni.ReadInteger('ServiceSettings', 'CheckIntervalSeconds', 2) * 1000;
          LastSentDate := DriveMonitorIni.ReadDate('XmitStatus', 'LastSent', Yesterday);

          //class global settings
          FMachineName := DriveMonitorIni.ReadString('ServiceSettings', 'MachineName', 'RIS Production');
          FMessageTitle := DriveMonitorIni.ReadString('ServiceSettings', 'MessageTitle', 'Drive Space Monitor');
          FPushUSERKey := DriveMonitorIni.ReadString('PushoverSettings', 'UserKey', '8s0d8f9sd8f');
          FPushAPIToken := DriveMonitorIni.ReadString('PushoverSettings', 'APITokenKey', 'ljasdlkjaslkdjklajsd');
          FPushDevice := DriveMonitorIni.ReadString('PushoverSettings', 'DeviceName', 'mydevice');


          //we only need to send notifications once a day
          if LastSentDate <= Yesterday then
          begin
            //loop drives from ini file
            for drvIdx := 0 to DriveList.Count - 1 do
            begin
              Drive := StringReplace(DriveList[drvIdx], '"','',[rfReplaceAll]);
              Drive := Copy(Drive, 1, 2);

              //get disk space info from drive
              if GetDiskFreeSpaceEx(PWideChar(Drive), FreeBytes, Totalsize, @FreeSize ) then
              begin
                PercentFull := Round((Totalsize - FreeBytes) / Totalsize * 100);

                //do we have enough space on this drive percentage wise?
                if PercentFull >= PercentFullTrigger then
                  CriticalDrivesList.Values[DriveList[drvIdx]] := IntToStr(PercentFull) +'%';
              end;
            end;


            //Now send a single pushover with all drives with space problems
            if (CriticalDrivesList.Count > 0) and SendPushoverMsg(CriticalDrivesList) then
              DriveMonitorIni.WriteDate('XmitStatus', 'LastSent', Now);
          end;

        finally
          DriveList.Free;
          CriticalDrivesList.Free;
        end;

      finally
        DriveMonitorIni.UpdateFile;
        DriveMonitorIni.Free;
      end;
    end;

    //make sure we dont loop too fast
    if CheckIntervalSeconds < 1000 then
      CheckIntervalSeconds := 1000;
    Sleep(CheckIntervalSeconds);
    ServiceThread.ProcessRequests(False);
  end;
end;

procedure TDriveSpaceMonitorService.ServiceShutdown(Sender: TService);
begin
//
end;

procedure TDriveSpaceMonitorService.ServiceStart(Sender: TService; var Started: Boolean);
var
   DriveMonitorIni : TMemIniFile;
begin
  Started := True;

  //Set the path to the OpenSSL lib files
  try
    IdOpenSSLSetLibPath(ExtractFilePath (ParamStr (0)));
  except
    On E:Exception do
    begin
      WriteLogToEventLogger(E.Message);
      ServiceThread.Terminate;
    end;
  end;

  //Set the path to the config file
  FDriveMonitorIniFile := IncludeTrailingPathDelimiter( ExtractFilePath (ParamStr (0)))  + cConfigFileName;
  //Create the user a generic config file if it doesnt exist
  if not FileExists(FDriveMonitorIniFile) then
  begin
    WriteLogToEventLogger('Missing valid config file: ' + cConfigFileName);

    DriveMonitorIni := TMemIniFile.Create(FDriveMonitorIniFile);
    try
      DriveMonitorIni.WriteString('ServiceSettings', 'Drives', 'C:\,D:\,E:\');
      DriveMonitorIni.WriteInteger('ServiceSettings', 'PercentFullTrigger', 70);
      DriveMonitorIni.WriteString('ServiceSettings', 'MachineName', 'DB Server');
      DriveMonitorIni.WriteString('ServiceSettings', 'MessageTitle', 'Drive Space Monitor');
      DriveMonitorIni.WriteInteger('ServiceSettings', 'CheckIntervalSeconds', 2);
      DriveMonitorIni.WriteString('PushoverSettings', 'UserKey', '8s0d8f9sd8f');
      DriveMonitorIni.WriteString('PushoverSettings', 'APITokenKey', 'ljasdlkjaslkdjklajsd');
      DriveMonitorIni.WriteString('PushoverSettings', 'DeviceName', 'mydevice');
    finally
      DriveMonitorIni.UpdateFile;
      DriveMonitorIni.Free;
    end;
  end;
end;

procedure TDriveSpaceMonitorService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
//
end;

procedure TDriveSpaceMonitorService.WriteLogToEventLogger(const Msg: string);
var
  FEventLog: TEventLogger;
begin
  FEventLog := TEventLogger.Create(DisplayName);
  try
    FEventLog.LogMessage(Msg, EVENTLOG_ERROR_TYPE, 0, 0);
  finally
    FreeAndNil(FEventLog);
  end;
end;

function TDriveSpaceMonitorService.SendPushoverMsg(ADriveList:TStringList): boolean;
var
  myIdHTTP:TIdHTTP;
  postData: TStringList;
  SSLIO: TIdSSLIOHandlerSocketOpenSSL;
  sResponse: string;
  drvIdx:Integer;
  msg:string;
begin
  Result := False;

  if Assigned(ADriveList) then
  begin
    myIdHTTP := TIdHTTP.Create(nil);
    try
      myIdHTTP.HandleRedirects := True;
      myIdHTTP.Request.ContentType := 'application/x-www-form-urlencoded';
      myIdHTTP.Request.ContentLength := -1;
      myIdHTTP.Request.ContentRangeEnd := -1;
      myIdHTTP.Request.ContentRangeStart := -1;
      myIdHTTP.Request.ContentRangeInstanceLength := -1;
      myIdHTTP.Request.Accept := 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
      myIdHTTP.Request.BasicAuthentication := False;
      myIdHTTP.Request.UserAgent := 'Mozilla/3.0 (compatible; DriveSpaceMonitor)';
      myIdHTTP.Request.Ranges.Units := 'bytes';
      myIdHTTP.HTTPOptions := [hoForceEncodeParams, hoNonSSLProxyUseConnectVerb];

      try
        //setup the SSL
        SSLIO := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
        myIdHTTP.IOHandler := SSLIO;
        SSLIO.SSLOptions.Method := sslvTLSv1;
        SSLIO.SSLOptions.Mode := sslmUnassigned;

        PostData := TStringList.Create;
        try
          //Prepare the Msg to send
          msg := '*ALERT* - System Critical!'+ #10 + 'Low disk space on ['+FMachineName +']' + #10;
          for drvIdx := 0 to ADriveList.Count - 1 do
          begin
            //Build msg to send
            msg := msg + 'Drive [<b>' + ADriveList.Names[drvIdx] + '</b>] is <b>'+ADriveList.ValueFromIndex[drvIdx]+'</b> full!';

            if drvIdx < ADriveList.Count - 1 then
              msg := msg + #10;
          end;

          //prepare the post data
          PostData.StrictDelimiter := true;
          PostData.Add('token='+FPushAPIToken);
          PostData.Add('user='+FPushUSERKey);
          PostData.Add('message='+msg);
          postData.Add('device='+FPushDevice);
          postData.Add('title='+FMessageTitle);
          postData.Add('url=');
          postData.Add('url_title=');
          postData.Add('priority=1');
          postData.Add('timestamp=');
          postData.Add('sound=1');
          postData.Add('html=1');

          try
            sResponse := myIdHTTP.Post(cPushoverURL, PostData);
          except
            On E: EIdHTTPProtocolException do
              WriteLogToEventLogger('Unexpected Protocol Error Sending Pushover ' + E.ErrorMessage);

            On E:Exception do
              WriteLogToEventLogger('Unexpected Protocol Error Sending Pushover ' + E.Message);
          end;
        finally
          PostData.Free;
        end;
      except
        on E:Exception do
          WriteLogToEventLogger('HTTP SSL error: '+E.Message);
      end;
    finally
      Result := myIdHTTP.ResponseCode = 200;
      myIdHTTP.Free;
    end;
  end;
end;

end.
