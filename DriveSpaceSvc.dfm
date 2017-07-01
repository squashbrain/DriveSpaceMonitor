object DriveSpaceMonitorService: TDriveSpaceMonitorService
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = 'DriveSpaceMonitorService'
  Interactive = True
  AfterInstall = ServiceAfterInstall
  AfterUninstall = ServiceAfterUninstall
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 362
  Width = 515
end
