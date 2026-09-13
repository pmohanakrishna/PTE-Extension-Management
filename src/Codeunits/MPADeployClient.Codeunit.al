codeunit 66651 "MPA Deploy Client"
{
    Permissions = tabledata "MPA Deploy Log" = rim;

    var
        // Contract: https://learn.microsoft.com/dynamics365/business-central/dev-itpro/administration/administration-center-api_app_management
        // The pteInstall endpoint was introduced in admin center API v2.29.
        EnvironmentUrlTok: Label 'https://api.businesscentral.dynamics.com/admin/%1/applications/%2/environments/%3', Locked = true;
        // Not Environment Information.GetApplicationFamily(), which returns the localization family such as W1 or US.
        ApplicationFamilyTok: Label 'BusinessCentral', Locked = true;
        UploadFieldNameTok: Label 'extensionFile', Locked = true;
        BearerTok: Label 'Bearer %1', Locked = true;
        UploadOperationTxt: Label 'Upload', Locked = true;
        UninstallOperationTxt: Label 'Uninstall', Locked = true;
        NotSaaSErr: Label 'The Business Central admin center API is only available online. This page cannot be used on-premises.';
        AppIdParseErr: Label 'The app ID returned for %1 could not be read.\\Raw response for this extension:\\%2', Comment = '%1 = extension name, %2 = raw JSON object';
        ProductionTxt: Label 'Production';
        SandboxTxt: Label 'Sandbox';
        ImmediateTxt: Label 'Immediate';
        UpdateWindowTxt: Label 'Update window';
        NextMinorTxt: Label 'Next minor version';
        NextMajorTxt: Label 'Next major version';
        EulaNotAcceptedErr: Label 'Accept the publisher terms of use and privacy policy before deploying. The admin center API rejects uploads that do not accept them.';
        NoFileErr: Label 'Select an .app file first.';
        CallFailedErr: Label 'The admin center API returned %1 %2.\\%3', Comment = '%1 = status code, %2 = reason phrase, %3 = response body';
        SendFailedTxt: Label 'The request could not be sent. Check that outbound HTTP calls are allowed for this extension.';
        ConnectionOkMsg: Label 'Connection succeeded. Environment %1 is a %2 environment with %3 installed extensions.', Comment = '%1 = environment name, %2 = environment type, %3 = count of apps';
        DeploySuccessMsg: Label 'Extension installation is in progress. Please check the Extension Installation Status page for updates.';
        SelfUpgradeMsg: Label 'The uploaded package is this extension. The deployment tool will restart while it upgrades itself, so reopen the page afterwards.';
        UninstallSuccessMsg: Label 'Uninstall accepted for %1. Operation ID %2.', Comment = '%1 = app name, %2 = operation id';

    /// <summary>
    /// Uploads a .app package to the target environment and schedules its installation.
    /// </summary>
    /// <param name="FileName">Original file name of the package.</param>
    /// <param name="FileInStream">Stream holding the .app package contents.</param>
    /// <param name="DeploySchedule">When the uploaded package should be installed.</param>
    /// <param name="SyncMode">Schema synchronisation mode applied during install.</param>
    /// <param name="LanguageId">Windows language ID used for the install, or zero for the default.</param>
    /// <param name="InstallDependencies">Install or update missing dependencies instead of failing on them.</param>
    /// <param name="AcceptEula">Acceptance of the publisher licence terms. The API rejects the upload without it.</param>
    procedure UploadAndSchedule(FileName: Text; var FileInStream: InStream; DeploySchedule: Enum "MPA Deploy Schedule"; SyncMode: Enum "MPA Sync Mode"; LanguageId: Integer; InstallDependencies: Boolean; AcceptEula: Boolean)
    var
        DeploySetup: Record "MPA Deploy Setup";
        DeployAuth: Codeunit "MPA Deploy Auth";
        EnvironmentInformation: Codeunit "Environment Information";
        CurrentModule: ModuleInfo;
        ResponseText: Text;
        ReasonPhrase: Text;
        StatusCode: Integer;
        OperationId: Text;
        UploadedAppId: Text;
    begin
        if FileName = '' then
            Error(NoFileErr);

        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        if not AcceptEula then
            Error(EulaNotAcceptedErr);

        StatusCode := PostPackage(
            BuildUrl(DeploySetup, '/apps/pteInstall'),
            DeployAuth.GetAccessToken(),
            FileName,
            FileInStream,
            DeploySchedule,
            SyncMode,
            LanguageId,
            InstallDependencies,
            ResponseText,
            ReasonPhrase);

        OperationId := ReadJsonText(ResponseText, 'id');
        UploadedAppId := ReadJsonText(ResponseText, 'appId');
        LogAttempt(UploadOperationTxt, FileName, EnvironmentInformation.GetEnvironmentName(), StatusCode, OperationId, ResponseText);

        if not IsSuccess(StatusCode) then
            Error(CallFailedErr, StatusCode, ReasonPhrase, ResponseText);

        NavApp.GetCurrentModuleInfo(CurrentModule);
        if UploadedAppId = FormatGuid(CurrentModule.Id()) then
            Message(SelfUpgradeMsg);

        Message(DeploySuccessMsg);
    end;

    /// <summary>
    /// Uninstalls an app from the target environment, optionally deleting the data it owns.
    /// </summary>
    procedure UninstallApp(AppId: Guid; AppName: Text; DeleteData: Boolean; UninstallDependents: Boolean)
    var
        DeploySetup: Record "MPA Deploy Setup";
        EnvironmentInformation: Codeunit "Environment Information";
        RequestBody: JsonObject;
        BodyText: Text;
        ResponseText: Text;
        ReasonPhrase: Text;
        StatusCode: Integer;
        OperationId: Text;
    begin
        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        RequestBody.Add('useEnvironmentUpdateWindow', false);
        RequestBody.Add('uninstallDependents', UninstallDependents);
        RequestBody.Add('deleteData', DeleteData);
        RequestBody.WriteTo(BodyText);

        StatusCode := SendRequest(
            'POST',
            BuildUrl(DeploySetup, StrSubstNo('/apps/%1/uninstall', FormatGuid(AppId))),
            BodyText,
            ResponseText,
            ReasonPhrase);

        OperationId := ReadJsonText(ResponseText, 'id');
        LogAttempt(UninstallOperationTxt, AppName, EnvironmentInformation.GetEnvironmentName(), StatusCode, OperationId, ResponseText);

        if not IsSuccess(StatusCode) then
            Error(CallFailedErr, StatusCode, ReasonPhrase, ResponseText);

        Message(UninstallSuccessMsg, AppName, OperationId);
    end;

    /// <summary>
    /// Loads the apps installed on the target environment, including any available updates.
    /// </summary>
    procedure LoadInstalledApps(var TempEnvironmentApp: Record "MPA Environment App" temporary)
    var
        DeploySetup: Record "MPA Deploy Setup";
        AppArray: JsonArray;
        AppToken: JsonToken;
        AppObject: JsonObject;
        RawApp: Text;
    begin
        TempEnvironmentApp.Reset();
        TempEnvironmentApp.DeleteAll();

        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        AppArray := GetValueArray(BuildUrl(DeploySetup, '/apps'));
        foreach AppToken in AppArray do begin
            AppObject := AppToken.AsObject();
            TempEnvironmentApp.Init();
            TempEnvironmentApp."App ID" := JsonGuid(AppObject, 'appId');
            if IsNullGuid(TempEnvironmentApp."App ID") then
                TempEnvironmentApp."App ID" := JsonGuid(AppObject, 'id');
            TempEnvironmentApp.Name := CopyStr(JsonText(AppObject, 'name'), 1, MaxStrLen(TempEnvironmentApp.Name));
            TempEnvironmentApp.Publisher := CopyStr(JsonText(AppObject, 'publisher'), 1, MaxStrLen(TempEnvironmentApp.Publisher));
            TempEnvironmentApp.Version := CopyStr(JsonText(AppObject, 'version'), 1, MaxStrLen(TempEnvironmentApp.Version));
            TempEnvironmentApp.State := CopyStr(JsonText(AppObject, 'state'), 1, MaxStrLen(TempEnvironmentApp.State));
            TempEnvironmentApp."App Type" := CopyStr(JsonText(AppObject, 'appType'), 1, MaxStrLen(TempEnvironmentApp."App Type"));
            TempEnvironmentApp."Can Be Uninstalled" := JsonBool(AppObject, 'canBeUninstalled');

            if IsNullGuid(TempEnvironmentApp."App ID") then begin
                AppObject.WriteTo(RawApp);
                Error(AppIdParseErr, TempEnvironmentApp.Name, CopyStr(RawApp, 1, 1500));
            end;

            TempEnvironmentApp.Insert();
        end;

        ApplyAvailableUpdates(DeploySetup, TempEnvironmentApp);
    end;

    /// <summary>
    /// Loads install, update, and uninstall operations recorded for a single app.
    /// </summary>
    procedure LoadAppOperations(AppId: Guid; AppName: Text; var TempAppOperation: Record "MPA App Operation" temporary)
    var
        DeploySetup: Record "MPA Deploy Setup";
        OperationArray: JsonArray;
        OperationToken: JsonToken;
        OperationObject: JsonObject;
        EntryNo: Integer;
    begin
        TempAppOperation.Reset();
        TempAppOperation.DeleteAll();

        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        OperationArray := GetValueArray(BuildUrl(DeploySetup, StrSubstNo('/apps/%1/operations', FormatGuid(AppId))));
        foreach OperationToken in OperationArray do begin
            OperationObject := OperationToken.AsObject();
            EntryNo += 1;
            TempAppOperation.Init();
            TempAppOperation."Entry No." := EntryNo;
            TempAppOperation."Operation ID" := JsonGuid(OperationObject, 'id');
            TempAppOperation."App ID" := AppId;
            TempAppOperation."App Name" := CopyStr(AppName, 1, MaxStrLen(TempAppOperation."App Name"));
            TempAppOperation."Operation Type" := CopyStr(JsonText(OperationObject, 'type'), 1, MaxStrLen(TempAppOperation."Operation Type"));
            TempAppOperation.Status := CopyStr(JsonText(OperationObject, 'status'), 1, MaxStrLen(TempAppOperation.Status));
            TempAppOperation."Source Version" := CopyStr(JsonText(OperationObject, 'sourceVersion'), 1, MaxStrLen(TempAppOperation."Source Version"));
            TempAppOperation."Target Version" := CopyStr(JsonText(OperationObject, 'targetVersion'), 1, MaxStrLen(TempAppOperation."Target Version"));
            TempAppOperation."Created On" := JsonDateTime(OperationObject, 'createdOn');
            TempAppOperation."Started On" := JsonDateTime(OperationObject, 'startedOn');
            TempAppOperation."Completed On" := JsonDateTime(OperationObject, 'completedOn');
            TempAppOperation."Error Message" := CopyStr(JsonText(OperationObject, 'errorMessage'), 1, MaxStrLen(TempAppOperation."Error Message"));
            TempAppOperation.Insert();
        end;
    end;

    /// <summary>
    /// Loads per-tenant extension installs that are staged but have not run yet.
    /// </summary>
    procedure LoadScheduledPteOperations(var TempAppOperation: Record "MPA App Operation" temporary)
    var
        DeploySetup: Record "MPA Deploy Setup";
        OperationArray: JsonArray;
        OperationToken: JsonToken;
        OperationObject: JsonObject;
        ParametersObject: JsonObject;
        ParametersToken: JsonToken;
        EntryNo: Integer;
    begin
        TempAppOperation.Reset();
        TempAppOperation.DeleteAll();

        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        OperationArray := GetValueArray(BuildUrl(DeploySetup, '/apps/scheduledPteOperations'));
        foreach OperationToken in OperationArray do begin
            OperationObject := OperationToken.AsObject();
            EntryNo += 1;
            TempAppOperation.Init();
            TempAppOperation."Entry No." := EntryNo;
            TempAppOperation."Operation ID" := JsonGuid(OperationObject, 'id');
            TempAppOperation."App ID" := JsonGuid(OperationObject, 'appId');
            TempAppOperation."Operation Type" := CopyStr(JsonText(OperationObject, 'type'), 1, MaxStrLen(TempAppOperation."Operation Type"));
            TempAppOperation.Status := CopyStr(JsonText(OperationObject, 'status'), 1, MaxStrLen(TempAppOperation.Status));
            TempAppOperation."Target Version" := CopyStr(JsonText(OperationObject, 'targetAppVersion'), 1, MaxStrLen(TempAppOperation."Target Version"));
            TempAppOperation."Schedule Kind" := CopyStr(NormalizeScheduleKind(JsonText(OperationObject, 'scheduleKind')), 1, MaxStrLen(TempAppOperation."Schedule Kind"));
            TempAppOperation."Created On" := JsonDateTime(OperationObject, 'createdOn');
            TempAppOperation."Created By" := CopyStr(JsonText(OperationObject, 'createdBy'), 1, MaxStrLen(TempAppOperation."Created By"));

            // The app name only appears in the nested request snapshot.
            if JsonTokenByName(OperationObject, 'parameters', ParametersToken) and ParametersToken.IsObject() then begin
                ParametersObject := ParametersToken.AsObject();
                TempAppOperation."App Name" := CopyStr(JsonText(ParametersObject, 'name'), 1, MaxStrLen(TempAppOperation."App Name"));
            end;

            TempAppOperation.Insert();
        end;
    end;

    /// <summary>
    /// Loads install, update, and uninstall operations recorded for the environment, newest first.
    /// </summary>
    procedure LoadEnvironmentOperations(var TempEnvironmentApp: Record "MPA Environment App" temporary; var TempAppOperation: Record "MPA App Operation" temporary)
    var
        DeploySetup: Record "MPA Deploy Setup";
        OperationArray: JsonArray;
        OperationToken: JsonToken;
        OperationObject: JsonObject;
        ParametersObject: JsonObject;
        ParametersToken: JsonToken;
        AppNameByApp: Dictionary of [Text, Text];
        AppPublisherByApp: Dictionary of [Text, Text];
        OperationType: Text;
        AppKey: Text;
        SavedAppId: Guid;
        EntryNo: Integer;
    begin
        TempAppOperation.Reset();
        TempAppOperation.DeleteAll();

        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        // Lookups below move the caller's cursor, so remember where it was.
        SavedAppId := TempEnvironmentApp."App ID";

        OperationArray := GetValueArray(BuildUrl(DeploySetup, '/operations'));
        foreach OperationToken in OperationArray do begin
            OperationObject := OperationToken.AsObject();
            OperationType := JsonText(OperationObject, 'type');

            // The endpoint also returns environment lifecycle operations such as copy and rename.
            if LowerCase(CopyStr(OperationType, 1, 14)) = 'environmentapp' then begin
                EntryNo += 1;
                TempAppOperation.Init();
                TempAppOperation."Entry No." := EntryNo;
                TempAppOperation."Operation ID" := JsonGuid(OperationObject, 'id');
                TempAppOperation."Operation Type" := CopyStr(OperationType, 1, MaxStrLen(TempAppOperation."Operation Type"));
                TempAppOperation.Status := CopyStr(JsonText(OperationObject, 'status'), 1, MaxStrLen(TempAppOperation.Status));
                TempAppOperation."Created On" := JsonDateTime(OperationObject, 'createdOn');
                TempAppOperation."Started On" := JsonDateTime(OperationObject, 'startedOn');
                TempAppOperation."Completed On" := JsonDateTime(OperationObject, 'completedOn');
                TempAppOperation."Created By" := CopyStr(JsonText(OperationObject, 'createdBy'), 1, MaxStrLen(TempAppOperation."Created By"));
                TempAppOperation."Error Message" := CopyStr(JsonText(OperationObject, 'errorMessage'), 1, MaxStrLen(TempAppOperation."Error Message"));

                if JsonTokenByName(OperationObject, 'parameters', ParametersToken) and ParametersToken.IsObject() then begin
                    ParametersObject := ParametersToken.AsObject();
                    TempAppOperation."App ID" := JsonGuid(ParametersObject, 'appId');
                    TempAppOperation."Target Version" := CopyStr(JsonText(ParametersObject, 'targetAppVersion'), 1, MaxStrLen(TempAppOperation."Target Version"));
                    TempAppOperation."Source Version" := CopyStr(JsonText(ParametersObject, 'sourceAppVersion'), 1, MaxStrLen(TempAppOperation."Source Version"));
                    TempAppOperation."Schedule Kind" := CopyStr(JsonText(ParametersObject, 'scheduleKind'), 1, MaxStrLen(TempAppOperation."Schedule Kind"));
                    if TempAppOperation."Schedule Kind" = '' then
                        TempAppOperation."Schedule Kind" := CopyStr(DeriveScheduleKind(ParametersObject), 1, MaxStrLen(TempAppOperation."Schedule Kind"));
                    TempAppOperation."Schedule Kind" := CopyStr(NormalizeScheduleKind(TempAppOperation."Schedule Kind"), 1, MaxStrLen(TempAppOperation."Schedule Kind"));
                    TempAppOperation."App Name" := CopyStr(JsonText(ParametersObject, 'name'), 1, MaxStrLen(TempAppOperation."App Name"));
                    TempAppOperation."App Publisher" := CopyStr(JsonText(ParametersObject, 'publisher'), 1, MaxStrLen(TempAppOperation."App Publisher"));
                end;

                // The operations endpoint carries no app name, so fall back to the installed list.
                if (TempAppOperation."App Name" = '') and TempEnvironmentApp.Get(TempAppOperation."App ID") then begin
                    TempAppOperation."App Name" := TempEnvironmentApp.Name;
                    TempAppOperation."App Publisher" := TempEnvironmentApp.Publisher;
                end;

                if (TempAppOperation."App Name" <> '') and not IsNullGuid(TempAppOperation."App ID") then begin
                    AppKey := FormatGuid(TempAppOperation."App ID");
                    if not AppNameByApp.ContainsKey(AppKey) then begin
                        AppNameByApp.Add(AppKey, TempAppOperation."App Name");
                        AppPublisherByApp.Add(AppKey, TempAppOperation."App Publisher");
                    end;
                end;

                TempAppOperation.Insert();
            end;
        end;

        FillMissingAppNames(TempAppOperation, AppNameByApp, AppPublisherByApp);

        if TempEnvironmentApp.Get(SavedAppId) then;
    end;

    /// <summary>
    /// Uninstall operations report no app name, so borrow it from another operation for the same app.
    /// </summary>
    local procedure FillMissingAppNames(var TempAppOperation: Record "MPA App Operation" temporary; AppNameByApp: Dictionary of [Text, Text]; AppPublisherByApp: Dictionary of [Text, Text])
    var
        AppKey: Text;
    begin
        TempAppOperation.Reset();
        if not TempAppOperation.FindSet(true) then
            exit;

        repeat
            if (TempAppOperation."App Name" = '') and not IsNullGuid(TempAppOperation."App ID") then begin
                AppKey := FormatGuid(TempAppOperation."App ID");
                if AppNameByApp.ContainsKey(AppKey) then begin
                    TempAppOperation."App Name" := CopyStr(AppNameByApp.Get(AppKey), 1, MaxStrLen(TempAppOperation."App Name"));
                    TempAppOperation."App Publisher" := CopyStr(AppPublisherByApp.Get(AppKey), 1, MaxStrLen(TempAppOperation."App Publisher"));
                    TempAppOperation.Modify();
                end;
            end;
        until TempAppOperation.Next() = 0;
    end;

    /// <summary>
    /// Returns the type of the current environment, either Sandbox or Production.
    /// </summary>
    procedure GetEnvironmentType(): Text
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        if EnvironmentInformation.IsProduction() then
            exit(ProductionTxt);
        exit(SandboxTxt);
    end;

    local procedure ApplyAvailableUpdates(var DeploySetup: Record "MPA Deploy Setup"; var TempEnvironmentApp: Record "MPA Environment App" temporary)
    var
        UpdateArray: JsonArray;
        UpdateToken: JsonToken;
        UpdateObject: JsonObject;
    begin
        UpdateArray := GetValueArray(BuildUrl(DeploySetup, '/apps/availableUpdates'));
        foreach UpdateToken in UpdateArray do begin
            UpdateObject := UpdateToken.AsObject();
            if TempEnvironmentApp.Get(JsonGuid(UpdateObject, 'appId')) then begin
                TempEnvironmentApp."Available Update Version" := CopyStr(JsonText(UpdateObject, 'version'), 1, MaxStrLen(TempEnvironmentApp."Available Update Version"));
                TempEnvironmentApp.Modify();
            end;
        end;
    end;

    /// <summary>
    /// Calls the environment and installed apps endpoints to confirm that authentication and routing work.
    /// </summary>
    procedure TestConnection()
    var
        DeploySetup: Record "MPA Deploy Setup";
        EnvironmentInformation: Codeunit "Environment Information";
        AppArray: JsonArray;
    begin
        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        AppArray := GetValueArray(BuildUrl(DeploySetup, '/apps'));

        Message(ConnectionOkMsg, EnvironmentInformation.GetEnvironmentName(), GetEnvironmentType(), AppArray.Count());
    end;

    local procedure PostPackage(Url: Text; AccessToken: SecretText; FileName: Text; var FileInStream: InStream; DeploySchedule: Enum "MPA Deploy Schedule"; SyncMode: Enum "MPA Sync Mode"; LanguageId: Integer; InstallDependencies: Boolean; var ResponseText: Text; var ReasonPhrase: Text): Integer
    var
        BodyTempBlob: Codeunit "Temp Blob";
        Client: HttpClient;
        RequestContent: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
        BodyInStream: InStream;
        Boundary: Text;
    begin
        CheckPlatformSupported();

        Boundary := 'MPADeployBoundary' + DelChr(Format(CreateGuid()), '=', '{}-');

        // BodyTempBlob must outlive the stream, so it is owned here rather than by the builder.
        BuildMultipartBody(FileName, FileInStream, Boundary, DeploySchedule, SyncMode, LanguageId, InstallDependencies, BodyTempBlob);
        BodyTempBlob.CreateInStream(BodyInStream, TextEncoding::Windows);

        RequestContent.WriteFrom(BodyInStream);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', StrSubstNo('multipart/form-data; boundary=%1', Boundary));

        RequestMessage.Content(RequestContent);
        RequestMessage.Method('POST');
        RequestMessage.SetRequestUri(Url);
        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', SecretStrSubstNo(BearerTok, AccessToken));

        if not Client.Send(RequestMessage, ResponseMessage) then begin
            ResponseText := SendFailedTxt;
            exit(0);
        end;

        ResponseMessage.Content().ReadAs(ResponseText);
        ReasonPhrase := ResponseMessage.ReasonPhrase();
        exit(ResponseMessage.HttpStatusCode());
    end;

    /// <summary>
    /// Assembles a multipart/form-data body around the binary package.
    /// Note on encoding: the stream is opened as Windows rather than UTF8 on purpose.
    /// A UTF8 OutStream writes a byte order mark, which lands in front of the first
    /// boundary and makes the server reject the body.
    /// </summary>
    local procedure BuildMultipartBody(FileName: Text; var FileInStream: InStream; Boundary: Text; DeploySchedule: Enum "MPA Deploy Schedule"; SyncMode: Enum "MPA Sync Mode"; LanguageId: Integer; InstallDependencies: Boolean; var BodyTempBlob: Codeunit "Temp Blob")
    var
        Language: Codeunit Language;
        BodyOutStream: OutStream;
        CRLF: Text[2];
    begin
        CRLF[1] := 13;
        CRLF[2] := 10;

        Clear(BodyTempBlob);
        BodyTempBlob.CreateOutStream(BodyOutStream, TextEncoding::Windows);

        WriteFormField(BodyOutStream, Boundary, CRLF, 'deploymentSchedule', ScheduleToApiValue(DeploySchedule));
        WriteFormField(BodyOutStream, Boundary, CRLF, 'syncMode', SyncModeToApiValue(SyncMode));
        WriteFormField(BodyOutStream, Boundary, CRLF, 'acceptIsvEula', 'true');
        WriteFormField(BodyOutStream, Boundary, CRLF, 'installOrUpdateNeededDependencies', LowerCase(Format(InstallDependencies, 0, 9)));

        if LanguageId <> 0 then
            WriteFormField(BodyOutStream, Boundary, CRLF, 'languageId', Language.GetCultureName(LanguageId));

        // The package itself.
        BodyOutStream.WriteText('--' + Boundary + CRLF);
        BodyOutStream.WriteText(
            'Content-Disposition: form-data; name="' + UploadFieldNameTok +
            '"; filename="' + SanitizeFileName(FileName) + '"' + CRLF);
        BodyOutStream.WriteText('Content-Type: application/octet-stream' + CRLF + CRLF);
        CopyStream(BodyOutStream, FileInStream);
        BodyOutStream.WriteText(CRLF);

        BodyOutStream.WriteText('--' + Boundary + '--' + CRLF);
    end;

    local procedure WriteFormField(var BodyOutStream: OutStream; Boundary: Text; CRLF: Text[2]; FieldName: Text; FieldValue: Text)
    begin
        BodyOutStream.WriteText('--' + Boundary + CRLF);
        BodyOutStream.WriteText('Content-Disposition: form-data; name="' + FieldName + '"' + CRLF + CRLF);
        BodyOutStream.WriteText(FieldValue + CRLF);
    end;

    local procedure SyncModeToApiValue(SyncMode: Enum "MPA Sync Mode"): Text
    begin
        case SyncMode of
            SyncMode::Add:
                exit('Add');
            SyncMode::ForceSync:
                exit('ForceSync');
        end;
    end;

    local procedure ScheduleToApiValue(DeploySchedule: Enum "MPA Deploy Schedule"): Text
    begin
        case DeploySchedule of
            DeploySchedule::Immediate:
                exit('Immediate');
            DeploySchedule::UpdateWindow:
                exit('UpdateWindow');
            DeploySchedule::NextMinorUpdate:
                exit('NextMinorUpdate');
            DeploySchedule::NextMajorUpdate:
                exit('NextMajorUpdate');
        end;
    end;

    local procedure SanitizeFileName(FileName: Text) Result: Text
    var
        Index: Integer;
        CharValue: Integer;
    begin
        for Index := 1 to StrLen(FileName) do begin
            CharValue := FileName[Index];
            if (CharValue >= 32) and (CharValue <= 126) and (CharValue <> 34) then
                Result += Format(FileName[Index])
            else
                Result += '_';
        end;
    end;

    local procedure CheckPlatformSupported()
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        if not EnvironmentInformation.IsSaaS() then
            Error(NotSaaSErr);
    end;

    local procedure BuildUrl(var DeploySetup: Record "MPA Deploy Setup"; Suffix: Text): Text
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        exit(StrSubstNo(
            EnvironmentUrlTok,
            DeploySetup."API Version",
            ApplicationFamilyTok,
            EnvironmentInformation.GetEnvironmentName()) + Suffix);
    end;

    local procedure GetValueArray(Url: Text) ValueArray: JsonArray
    var
        ResponseObject: JsonObject;
        ValueToken: JsonToken;
        ResponseText: Text;
        ReasonPhrase: Text;
        StatusCode: Integer;
    begin
        StatusCode := SendRequest('GET', Url, '', ResponseText, ReasonPhrase);

        if not IsSuccess(StatusCode) then
            Error(CallFailedErr, StatusCode, ReasonPhrase, ResponseText);
        if not ResponseObject.ReadFrom(ResponseText) then
            Error(CallFailedErr, StatusCode, ReasonPhrase, ResponseText);
        if not ResponseObject.Get('value', ValueToken) then
            exit;
        if not ValueToken.IsArray() then
            exit;

        exit(ValueToken.AsArray());
    end;

    local procedure SendRequest(Method: Text; Url: Text; BodyText: Text; var ResponseText: Text; var ReasonPhrase: Text): Integer
    var
        DeployAuth: Codeunit "MPA Deploy Auth";
        Client: HttpClient;
        RequestContent: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        RequestMessage: HttpRequestMessage;
        ResponseMessage: HttpResponseMessage;
    begin
        CheckPlatformSupported();

        RequestMessage.Method(Method);
        RequestMessage.SetRequestUri(Url);

        if BodyText <> '' then begin
            RequestContent.WriteFrom(BodyText);
            RequestContent.GetHeaders(ContentHeaders);
            ContentHeaders.Clear();
            ContentHeaders.Add('Content-Type', 'application/json');
            RequestMessage.Content(RequestContent);
        end;

        RequestMessage.GetHeaders(RequestHeaders);
        RequestHeaders.Add('Authorization', SecretStrSubstNo(BearerTok, DeployAuth.GetAccessToken()));

        if not Client.Send(RequestMessage, ResponseMessage) then begin
            ResponseText := SendFailedTxt;
            exit(0);
        end;

        ResponseMessage.Content().ReadAs(ResponseText);
        ReasonPhrase := ResponseMessage.ReasonPhrase();
        exit(ResponseMessage.HttpStatusCode());
    end;

    local procedure FormatGuid(Value: Guid): Text
    begin
        exit(DelChr(Format(Value), '=', '{}'));
    end;

    /// <summary>
    /// Update and uninstall operations report no scheduleKind, so infer it from the window flags they do report.
    /// </summary>
    local procedure DeriveScheduleKind(ParametersObject: JsonObject): Text
    begin
        if JsonHasValue(ParametersObject, 'ignoreUpgradeWindow') then
            if JsonBool(ParametersObject, 'ignoreUpgradeWindow') then
                exit(ImmediateTxt)
            else
                exit(UpdateWindowTxt);

        if JsonHasValue(ParametersObject, 'useEnvironmentUpdateWindow') then
            if JsonBool(ParametersObject, 'useEnvironmentUpdateWindow') then
                exit(UpdateWindowTxt)
            else
                exit(ImmediateTxt);

        exit('');
    end;

    local procedure NormalizeScheduleKind(Value: Text): Text
    begin
        case LowerCase(Value) of
            'immediate':
                exit(ImmediateTxt);
            'updatewindow', 'update window':
                exit(UpdateWindowTxt);
            'nextminorupdate':
                exit(NextMinorTxt);
            'nextmajorupdate':
                exit(NextMajorTxt);
            else
                exit(Value);
        end;
    end;

    local procedure JsonHasValue(SourceObject: JsonObject; PropertyName: Text): Boolean
    var
        PropertyToken: JsonToken;
    begin
        if not JsonTokenByName(SourceObject, PropertyName, PropertyToken) then
            exit(false);
        if not PropertyToken.IsValue() then
            exit(false);
        exit(not PropertyToken.AsValue().IsNull());
    end;

    local procedure JsonTokenByName(SourceObject: JsonObject; PropertyName: Text; var PropertyToken: JsonToken): Boolean
    var
        KeyName: Text;
    begin
        if SourceObject.Get(PropertyName, PropertyToken) then
            exit(true);

        // JsonObject.Get is case-sensitive, so fall back to a case-insensitive scan.
        foreach KeyName in SourceObject.Keys() do
            if LowerCase(KeyName) = LowerCase(PropertyName) then
                exit(SourceObject.Get(KeyName, PropertyToken));

        exit(false);
    end;

    local procedure JsonText(SourceObject: JsonObject; PropertyName: Text): Text
    var
        PropertyToken: JsonToken;
    begin
        if not JsonTokenByName(SourceObject, PropertyName, PropertyToken) then
            exit('');
        if not PropertyToken.IsValue() then
            exit('');
        if PropertyToken.AsValue().IsNull() then
            exit('');
        exit(PropertyToken.AsValue().AsText());
    end;

    local procedure JsonGuid(SourceObject: JsonObject; PropertyName: Text) Value: Guid
    var
        GuidText: Text;
    begin
        GuidText := DelChr(JsonText(SourceObject, PropertyName), '=', '{} ');
        if GuidText = '' then
            exit;

        // Which form Evaluate accepts varies, so try the XML form, then braced, then plain.
        if Evaluate(Value, GuidText, 9) then
            exit;
        if Evaluate(Value, '{' + GuidText + '}') then
            exit;
        if Evaluate(Value, GuidText) then
            exit;

        Clear(Value);
    end;

    local procedure JsonBool(SourceObject: JsonObject; PropertyName: Text): Boolean
    var
        PropertyToken: JsonToken;
    begin
        if not JsonTokenByName(SourceObject, PropertyName, PropertyToken) then
            exit(false);
        if not PropertyToken.IsValue() then
            exit(false);
        if PropertyToken.AsValue().IsNull() then
            exit(false);
        exit(PropertyToken.AsValue().AsBoolean());
    end;

    local procedure JsonDateTime(SourceObject: JsonObject; PropertyName: Text) Value: DateTime
    begin
        if not Evaluate(Value, JsonText(SourceObject, PropertyName), 9) then
            Clear(Value);
    end;

    local procedure IsSuccess(StatusCode: Integer): Boolean
    begin
        exit((StatusCode >= 200) and (StatusCode <= 299));
    end;

    local procedure ReadJsonText(ResponseText: Text; PropertyName: Text): Text
    var
        ResponseObject: JsonObject;
    begin
        if not ResponseObject.ReadFrom(ResponseText) then
            exit('');
        exit(JsonText(ResponseObject, PropertyName));
    end;

    local procedure LogAttempt(OperationType: Text; Subject: Text; EnvironmentName: Text; StatusCode: Integer; OperationId: Text; ResponseText: Text)
    var
        DeployLog: Record "MPA Deploy Log";
        ResponseOutStream: OutStream;
    begin
        DeployLog.Init();
        DeployLog."Entry No." := 0;
        DeployLog."Operation Type" := CopyStr(OperationType, 1, MaxStrLen(DeployLog."Operation Type"));
        DeployLog."File Name" := CopyStr(Subject, 1, MaxStrLen(DeployLog."File Name"));
        DeployLog."Environment Name" := CopyStr(EnvironmentName, 1, MaxStrLen(DeployLog."Environment Name"));
        DeployLog."Attempted At" := CurrentDateTime();
        DeployLog."Attempted By" := CopyStr(UserId(), 1, MaxStrLen(DeployLog."Attempted By"));
        DeployLog."HTTP Status" := StatusCode;
        DeployLog.Successful := IsSuccess(StatusCode);
        DeployLog."Operation ID" := CopyStr(OperationId, 1, MaxStrLen(DeployLog."Operation ID"));
        DeployLog.Response.CreateOutStream(ResponseOutStream, TextEncoding::UTF8);
        ResponseOutStream.WriteText(ResponseText);
        DeployLog.Insert(true);

        // Callers raise an error on failure, which would otherwise roll the audit entry back.
        Commit();
    end;
}
