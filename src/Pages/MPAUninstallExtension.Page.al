page 66656 "MPA Uninstall Extension"
{
    Caption = 'Uninstall Extension';
    PageType = StandardDialog;
    ApplicationArea = All;
    Permissions = tabledata "MPA Deploy Setup" = r;

    layout
    {
        area(Content)
        {
            group(Extension)
            {
                Caption = 'Extension';

                field(AppName; AppName)
                {
                    ApplicationArea = All;
                    Caption = 'Name';
                    Editable = false;
                    ToolTip = 'Specifies the extension to uninstall.';
                }
                field(AppPublisher; AppPublisher)
                {
                    ApplicationArea = All;
                    Caption = 'Publisher';
                    Editable = false;
                    ToolTip = 'Specifies the publisher of the extension.';
                }
                field(AppVersion; AppVersion)
                {
                    ApplicationArea = All;
                    Caption = 'Version';
                    Editable = false;
                    ToolTip = 'Specifies the installed version of the extension.';
                }
                field(EnvironmentName; EnvironmentName)
                {
                    ApplicationArea = All;
                    Caption = 'Environment';
                    Editable = false;
                    ToolTip = 'Specifies the environment the extension is uninstalled from.';
                }
            }
            group(Options)
            {
                Caption = 'Options';

                field(DeleteData; DeleteData)
                {
                    ApplicationArea = All;
                    Caption = 'Delete extension data';
                    ToolTip = 'Specifies whether the data owned by the extension is permanently deleted. This cannot be undone.';
                }
            }
        }
    }

    var
        AppId: Guid;
        AppName: Text;
        AppPublisher: Text;
        AppVersion: Text;
        EnvironmentName: Text;
        DeleteData: Boolean;
        ConfirmDeleteDataQst: Label 'This permanently deletes all data owned by %1 in environment %2 and cannot be undone.\\Continue?', Comment = '%1 = extension name, %2 = environment name';

    trigger OnOpenPage()
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        EnvironmentName := EnvironmentInformation.GetEnvironmentName();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        DeployClient: Codeunit "MPA Deploy Client";
    begin
        if CloseAction <> Action::OK then
            exit(true);

        if DeleteData and not Confirm(ConfirmDeleteDataQst, false, AppName, EnvironmentName) then
            exit(false);

        DeployClient.UninstallApp(AppId, AppName, DeleteData, false);
        exit(true);
    end;

    procedure SetExtension(NewAppId: Guid; NewName: Text; NewPublisher: Text; NewVersion: Text)
    begin
        AppId := NewAppId;
        AppName := NewName;
        AppPublisher := NewPublisher;
        AppVersion := NewVersion;
    end;
}
