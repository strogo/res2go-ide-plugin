//----------------------------------------
//
// Copyright © ying32. All Rights Reserved.
// 
// Licensed under Lazarus.modifiedLGPL
//
//----------------------------------------

{$if FPC_FULLVERSION < 30200}
   {$ERROR 'Requires FPC version>=3.2'}
{$endif}

unit res2gomain;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  LCLType,
  UITypes,
  StdCtrls,
  Buttons,
  Forms,
  LazIDEIntf,
  ProjectIntf,
  IDEMsgIntf,
  IDEExternToolIntf,
  FormEditingIntf,
  TypInfo,
  usupports,
  res2goresources,
  uLangBase,
  LResources,
  LazFileUtils,
  MacroIntf;

type


  { TMyIDEIntf }

  TMyIDEIntf = class
  private
    FEvents: array of TEventItem;

    FEnabledCovert: Boolean;
    FOutLang: TOutLang;
    FOutputPath: string;
    FPackageName: string;
    FReConvertRes: Boolean;
    FResFileName: string;
    FSaveGfmFile: Boolean;
    FUseDefaultWinAppRes: Boolean;
    FUseOriginalFileName: Boolean;


    function GetDefaultProjectParam: TProjParam;
    function GetLang: TLangBase;

    function GetProjectTitle: string;
    function GetRealOutputPackagePath: string;
    function GetRealOutputPath: string;
    function GetResFileName: string;
    function GetUseScaled: Boolean;

    procedure SaveComponents(ADesigner: TIDesigner; AUnitFileName, AOutPath: string);
    procedure OnWriteMethodProperty(Writer: TWriter; Instance: TPersistent; PropInfo: PPropInfo;
      const MethodValue, DefMethodValue: TMethod; var Handled: boolean);

    procedure CheckAndCreateDir;


    function GetProjectPath: string;
    function IsMainPackage: Boolean;
    procedure SetPackageName(AValue: string);
  public
    constructor Create;
    destructor Destroy; override;
    function onSaveAll(Sender: TObject): TModalResult;
    function onSaveEditorFile(Sender: TObject; aFile: TLazProjectFile; SaveStep: TSaveEditorFileStep; TargetFilename: string): TModalResult;
    function onProjectOpened(Sender: TObject; AProject: TLazProject): TModalResult;

    property EnabledConvert: Boolean read FEnabledCovert write FEnabledCovert;
    property OutputPath: string read FOutputPath write FOutputPath;
    property UseOriginalFileName: Boolean read FUseOriginalFileName write FUseOriginalFileName;
    property SaveGfmFile: Boolean read FSaveGfmFile write FSaveGfmFile;
    property OutLang: TOutLang read FOutLang write FOutLang;
    property PackageName: string read FPackageName write SetPackageName;
    property UseScaled: Boolean read GetUseScaled;
    property ProjectTitle: string read GetProjectTitle;
    property UseDefaultWinAppRes: Boolean read FUseDefaultWinAppRes write FUseDefaultWinAppRes;

    property DefaultProjectParam: TProjParam read GetDefaultProjectParam;


    property Lang: TLangBase read GetLang;

    property ProjectPath: string read GetProjectPath;
    property RealOutputPath: string read GetRealOutputPath;
    property RealOutputPackagePath: string read GetRealOutputPackagePath;



    property ReConvertRes: Boolean read FReConvertRes write FReConvertRes;
    property ResFileName: string read GetResFileName;
  end;

  // JITForms.pas
  TFakeJITMethod = class
  private
    FMethod: TMethod;
    FOwner: TObject;//TJITMethods;
    FTheClass: TClass;
    FTheMethodName: shortstring;
  public
    property TheMethodName: shortstring read FTheMethodName;
  end;


var
  MyIDEIntf: TMyIDEIntf;

procedure Register;

implementation

uses
  ugolang;

procedure Register;
begin
  if Assigned(LazarusIDE) then
  begin
    LazarusIDE.AddHandlerOnSavedAll(@MyIDEIntf.onSaveAll, True);
    LazarusIDE.AddHandlerOnSaveEditorFile(@MyIDEIntf.onSaveEditorFile, True);
    LazarusIDE.AddHandlerOnProjectOpened(@MyIDEIntf.onProjectOpened, True);
  end;
end;


procedure Init;
begin
  MyIDEIntf := TMyIDEIntf.Create;
end;

procedure UnInit;
begin
  if Assigned(LazarusIDE) then
    LazarusIDE.RemoveAllHandlersOfObject(MyIDEIntf);
  MyIDEIntf.Free;
  MyIDEIntf := nil;
end;


{ TMyIDEIntf }

procedure TMyIDEIntf.SaveComponents(ADesigner: TIDesigner; AUnitFileName,
  AOutPath: string);
var
  LWriter: TWriter;
  LDestroyDriver: Boolean;
  LStream: TMemoryStream;
  LGfmFileName, LOutFileName: string;
begin
  if Assigned(ADesigner) and Assigned(ADesigner.LookupRoot) then
  begin
    LStream := TMemoryStream.Create;
    try
      LDestroyDriver := False;
      LWriter := nil;
      try
        // 清空事件
        SetLength(FEvents, 0);
        LWriter := CreateLRSWriter(LStream, LDestroyDriver);
        LWriter.OnWriteMethodProperty := @OnWriteMethodProperty;
        LWriter.WriteDescendent(ADesigner.LookupRoot, nil);
      finally
        if LDestroyDriver then
          LWriter.Driver.Free;
        LWriter.Free;
      end;
      // 保存go文件及impl文件
      LOutFileName := AOutPath;
      if Self.UseOriginalFileName then
        LOutFileName += AUnitFileName
      else
        LOutFileName += ADesigner.LookupRoot.Name;

      // 保存文件
      Lang.SaveToFile(LOutFileName, ADesigner.LookupRoot, FEvents, LStream);

      // 保存gfm文件
      if Self.SaveGfmFile then
      begin
        LGfmFileName := AOutPath;
        if Self.UseOriginalFileName then
          LGfmFileName += AUnitFileName
        else
          LGfmFileName += ADesigner.LookupRoot.Name;

        LGfmFileName += '.gfm';
        LStream.Position := 0;
        LStream.SaveToFile(LGfmFileName);
      end;
    finally
      LStream.Free;
    end;
  end;
end;

function TMyIDEIntf.GetRealOutputPath: string;
begin
  Result := OutputPath;
  if Assigned(IDEMacros) then
  begin
    IDEMacros.SubstituteMacros(Result);
    if not FileNameIsAbsolute(Result) then
      Result := ProjectPath + Result;
  end else
  begin
    if not FileNameIsAbsolute(Result) then
       Result := ProjectPath + OutputPath;
  end;
  Result := AppendPathDelim(Result);
end;

function TMyIDEIntf.GetResFileName: string;
begin
  Result := ChangeFileExt(LazarusIDE.ActiveProject.ProjectInfoFile, '.res');
end;

function TMyIDEIntf.GetUseScaled: Boolean;
begin
  Result := True;
  if Assigned(LazarusIDE) and Assigned(LazarusIDE.ActiveProject) then
    Result := LazarusIDE.ActiveProject.Scaled;
end;

function TMyIDEIntf.GetLang: TLangBase;
begin
  Result := GoLang;
  case Self.FOutLang of
     olRust: ;
     olNim: ;
  end;
end;

function TMyIDEIntf.GetProjectTitle: string;
begin
  Result := '';
  if Assigned(LazarusIDE) and Assigned(LazarusIDE.ActiveProject) then
    Result := LazarusIDE.ActiveProject.Title;
end;

function TMyIDEIntf.GetDefaultProjectParam: TProjParam;
begin
  Result := TProjParam.Create(Self.RealOutputPath, Self.ProjectTitle, Self.UseScaled, Self.UseDefaultWinAppRes);
end;

function TMyIDEIntf.GetRealOutputPackagePath: string;
begin
  Result := Self.RealOutputPath;
  if not IsMainPackage then
    Result := AppendPathDelim(Result + PackageName);
end;

// FakeIsJITMethod
function FakeIsJITMethod(const aMethod: TMethod): boolean;
begin
  Result:= (aMethod.Data <> nil) and (aMethod.Code = nil) and (TObject(aMethod.Data).ClassType.ClassNameIs('TJITMethod'));
end;

procedure TMyIDEIntf.OnWriteMethodProperty(Writer: TWriter;
  Instance: TPersistent; PropInfo: PPropInfo; const MethodValue,
  DefMethodValue: TMethod; var Handled: boolean);

  function GetTypeName: string;
  begin
    Result := PropInfo^.Name;
    if Result.StartsWith('On') then
      Result := Copy(Result, 3, Length(Result) - 2);
  end;

var
  LMethodName, LComponentName: string;
  LEvent: TEventItem;
begin
  Handled := False;
  if (DefMethodValue.Data = MethodValue.Data) and (DefMethodValue.Code = MethodValue.Code) then
    Exit;

  LMethodName := '';
  LComponentName := '';
  if Instance is TComponent then
     LComponentName := TComponent(Instance).Name;

  if FakeIsJITMethod(MethodValue) then
    LMethodName := TFakeJITMethod(MethodValue.Data).TheMethodName
  else if MethodValue.Code <> nil then
  begin
    LMethodName := Writer.LookupRoot.MethodName(MethodValue.Code);
    if LMethodName = '' then
      Exit;
  end;
  if LMethodName = '' then
    Exit;

  LEvent.InstanceName := LComponentName;
  LEvent.EventName := LMethodName;
  LEvent.EventTypeName := GetTypeName;
  LEvent.EventParams := Lang.ToEventString(PropInfo);

  SetLength(FEvents, Length(FEvents) + 1);
  FEvents[High(FEvents)] := LEvent;

  //if Assigned(PropInfo) then
  //  Logs('LComponentName%s, LMethodName=%s, Event.Name=%s', [LComponentName, LMethodName, PropInfo^.Name]);
end;

procedure TMyIDEIntf.CheckAndCreateDir;
var
  LOutPath: string;
begin
  LOutPath := Self.RealOutputPath;
  if not SysUtils.DirectoryExists(LOutPath) then
    SysUtils.CreateDir(LOutPath);
  if not IsMainPackage then
  begin
    LOutPath := AppendPathDelim(LOutPath) + PackageName;
    if not SysUtils.DirectoryExists(LOutPath) then
      SysUtils.CreateDir(LOutPath);
  end;
end;



function TMyIDEIntf.GetProjectPath: string;
begin
  Result := '';
  if Assigned(LazarusIDE.ActiveProject) then
    Result := AppendPathDelim(LazarusIDE.ActiveProject.Directory);
   // Result := ExtractFilePath(LazarusIDE.ActiveProject.ProjectInfoFile);
end;

function TMyIDEIntf.IsMainPackage: Boolean;
begin
  Result := PackageName.IsEmpty or PackageName.Equals('main');
end;

procedure TMyIDEIntf.SetPackageName(AValue: string);
begin
  if FPackageName=AValue then Exit;
  FPackageName:=AValue;
  Lang.PackageName:=FPackageName;
end;

constructor TMyIDEIntf.Create;
begin
  inherited Create;
end;

destructor TMyIDEIntf.Destroy;
begin
  inherited Destroy;
end;

function TMyIDEIntf.onSaveAll(Sender: TObject): TModalResult;
begin
  if EnabledConvert then
  begin
    ClearMsg;
    CheckAndCreateDir;
    Lang.ConvertProjectFile(DefaultProjectParam);
    if ReConvertRes and (not UseDefaultWinAppRes) then
    begin
      ReConvertRes := False;
      Lang.ConvertResource(ResFileName, RealOutputPath);
    end;
  end;
  Result := mrOk;
end;

function TMyIDEIntf.onSaveEditorFile(Sender: TObject; aFile: TLazProjectFile;
  SaveStep: TSaveEditorFileStep; TargetFilename: string): TModalResult;
var
  LDesigner: TIDesigner;
begin
  if SaveStep = sefsAfterWrite then
  begin
    if EnabledConvert then
    begin
      ClearMsg;
      CheckAndCreateDir;
      LDesigner := LazarusIDE.GetDesignerWithProjectFile(aFile, False);
      if Assigned(LDesigner) and Assigned(LDesigner.LookupRoot) then
        SaveComponents(LDesigner, GetFileNameWithoutExt(TargetFilename), RealOutputPackagePath);
    end;
  end;
  Result := mrOk;
end;

function TMyIDEIntf.onProjectOpened(Sender: TObject; AProject: TLazProject): TModalResult;
begin

  //Logs('GetCompilerFilename=%s', [LazarusIDE.GetCompilerFilename]);
  //Logs('GetFPCompilerFilename=%s', [LazarusIDE.GetFPCompilerFilename]);
  //Logs('ActiveProject.Directory=%s', [LazarusIDE.ActiveProject.Directory]);
  Result := mrOk;
end;


initialization
  Init;

finalization
  UnInit;

end.

