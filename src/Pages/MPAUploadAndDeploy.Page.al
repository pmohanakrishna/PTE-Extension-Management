page 66655 "MPA Upload And Deploy"
{
    Caption = 'Upload And Deploy Extension';
    PageType = NavigatePage;
    ApplicationArea = All;
    Permissions = tabledata "MPA Deploy Setup" = ri;

    layout
    {
        area(Content)
        {
            // No groups: on a NavigatePage each top-level group renders an extra footer button.
            field(UploadHeading; UploadHeadingTxt)
            {
                ApplicationArea = All;
                Editable = false;
                ShowCaption = false;
                Style = Strong;
                ToolTip = 'Specifies the upload section.';
            }
            field(FileName; FileName)
            {
                ApplicationArea = All;
                Caption = 'Select .app file';
                Editable = false;
                ToolTip = 'Specifies the extension package to upload.';

                trigger OnAssistEdit()
                begin
                    SelectFile();
                end;
            }
            field(DeployHeading; DeployHeadingTxt)
            {
                ApplicationArea = All;
                Editable = false;
                ShowCaption = false;
                Style = Strong;
                ToolTip = 'Specifies the deployment section.';
            }
            field(DeploySchedule; DeploySchedule)
            {
                ApplicationArea = All;
                Caption = 'Deploy to';
                ToolTip = 'Specifies when the package is installed. A new extension must use the current version or the update window; the next minor and next major options apply only to updates of an installed extension.';
            }
            field(LanguageName; LanguageName)
            {
                ApplicationArea = All;
                Caption = 'Language';
                Editable = false;
                ToolTip = 'Specifies the language used during installation.';

                trigger OnAssistEdit()
                var
                    Language: Codeunit Language;
                begin
                    Language.LookupWindowsLanguageId(LanguageId);
                    LanguageName := Language.GetWindowsLanguageName(LanguageId);
                end;
            }
            field(SyncMode; SyncMode)
            {
                ApplicationArea = All;
                Caption = 'Schema Sync Mode';
                ToolTip = 'Specifies how schema changes are applied. Force Sync allows destructive schema changes and can delete data.';
            }
            field(InstallDependencies; InstallDependencies)
            {
                ApplicationArea = All;
                Caption = 'Install needed dependencies';
                ToolTip = 'Specifies whether missing dependencies are installed or updated automatically. If disabled, the deployment fails and the response lists what is missing.';
            }
            field(AcceptEula; AcceptEula)
            {
                ApplicationArea = All;
                Caption = 'By deploying this extension you accept the publisher terms of use and privacy policy';
                ToolTip = 'Specifies that you accept the publisher end-user licence terms for this extension. The admin center API rejects uploads without this.';

                trigger OnValidate()
                begin
                    CurrPage.Update(false);
                end;
            }
            field(ApiDocsLink; ApiDocsLinkTxt)
            {
                ApplicationArea = All;
                Editable = false;
                ShowCaption = false;
                Style = StrongAccent;
                ToolTip = 'Opens the admin center app management documentation.';

                trigger OnDrillDown()
                begin
                    Hyperlink(ApiDocsUrlTok);
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Deploy)
            {
                ApplicationArea = All;
                Caption = 'Deploy';
                Enabled = AcceptEula;
                InFooterBar = true;
                ToolTip = 'Uploads the package to the admin center API and schedules its installation.';

                trigger OnAction()
                var
                    DeployClient: Codeunit "MPA Deploy Client";
                    PackageInStream: InStream;
                begin
                    if FileName = '' then
                        Error(NoFileErr);

                    TempBlob.CreateInStream(PackageInStream, TextEncoding::Windows);
                    DeployClient.UploadAndSchedule(FileName, PackageInStream, DeploySchedule, SyncMode, LanguageId, InstallDependencies, AcceptEula);
                    CurrPage.Close();
                end;
            }
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                InFooterBar = true;
                ToolTip = 'Closes without uploading.';

                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        TempBlob: Codeunit "Temp Blob";
        DeploySchedule: Enum "MPA Deploy Schedule";
        SyncMode: Enum "MPA Sync Mode";
        FileName: Text;
        LanguageName: Text;
        LanguageId: Integer;
        AcceptEula: Boolean;
        InstallDependencies: Boolean;
        ApiDocsLinkTxt: Text;
        UploadHeadingTxt: Text;
        DeployHeadingTxt: Text;
        ApiDocsLinkLbl: Label 'Read more about managing apps with the admin center API';
        UploadHeadingLbl: Label 'Upload Extension';
        DeployHeadingLbl: Label 'Deploy Extension';
        ApiDocsUrlTok: Label 'https://learn.microsoft.com/dynamics365/business-central/dev-itpro/administration/administration-center-api_app_management', Locked = true;
        NoFileErr: Label 'Select an .app file first.';
        FileFilterTok: Label 'Extension packages (*.app)|*.app', Locked = true;
        SelectFileTxt: Label 'Select an extension package';

    trigger OnOpenPage()
    var
        DeploySetup: Record "MPA Deploy Setup";
        Language: Codeunit Language;
    begin
        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        ApiDocsLinkTxt := ApiDocsLinkLbl;
        UploadHeadingTxt := UploadHeadingLbl;
        DeployHeadingTxt := DeployHeadingLbl;

        LanguageId := Language.GetDefaultApplicationLanguageId();
        LanguageName := Language.GetWindowsLanguageName(LanguageId);
    end;

    local procedure SelectFile()
    var
        PackageInStream: InStream;
        PackageOutStream: OutStream;
        UploadedFileName: Text;
    begin
        if not UploadIntoStream(SelectFileTxt, '', FileFilterTok, UploadedFileName, PackageInStream) then
            exit;

        Clear(TempBlob);
        TempBlob.CreateOutStream(PackageOutStream, TextEncoding::Windows);
        CopyStream(PackageOutStream, PackageInStream);

        FileName := UploadedFileName;
        CurrPage.Update(false);
    end;
}
