page 66653 "MPA Environment Apps"
{
    Caption = 'Installed Extensions (Admin Center)';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "MPA Environment App";
    SourceTableTemporary = true;
    SourceTableView = sorting(Name);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Permissions = tabledata "MPA Deploy Setup" = ri,
                  tabledata "NAV App Setting" = rim,
                  tabledata "Event Subscription" = r;

    layout
    {
        area(Content)
        {
            repeater(Extensions)
            {
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    StyleExpr = 'StrongAccent';
                    ToolTip = 'Specifies the name of the extension. Choose the value to open its settings, where HttpClient requests can be allowed.';

                    trigger OnDrillDown()
                    begin
                        ShowExtensionSettings();
                    end;
                }
                field(Publisher; Rec.Publisher)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the publisher of the extension.';
                }
                field(Version; Rec.Version)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the version installed on the target environment.';
                }
                field("Available Update Version"; Rec."Available Update Version")
                {
                    ApplicationArea = All;
                    Style = Attention;
                    StyleExpr = Rec."Available Update Version" <> '';
                    ToolTip = 'Specifies the newer version available for this extension, if any.';
                }
                field(State; Rec.State)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the extension is installed, updating, or pending an update.';
                }
                field("App Type"; Rec."App Type")
                {
                    ApplicationArea = All;
                    Caption = 'Scope';
                    ToolTip = 'Specifies whether the extension is a global Marketplace app, a per-tenant extension, or a development extension.';
                }
                field("App ID"; Rec."App ID")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the unique identifier of the extension.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(Manage)
            {
                Caption = 'Manage';

                action(UploadExtension)
                {
                    ApplicationArea = All;
                    Caption = 'Upload Extension...';
                    Image = Import;
                    ToolTip = 'Uploads a per-tenant extension package and schedules its installation.';

                    trigger OnAction()
                    begin
                        Page.RunModal(Page::"MPA Upload And Deploy");
                        LoadApps();
                    end;
                }
                action(InstallationStatus)
                {
                    ApplicationArea = All;
                    Caption = 'Installation Status';
                    Image = ListPage;
                    ToolTip = 'Shows install, update, and uninstall operations recorded for this environment, newest first.';

                    trigger OnAction()
                    var
                        TempAppOperation: Record "MPA App Operation" temporary;
                        DeployClient: Codeunit "MPA Deploy Client";
                        AppOperations: Page "MPA App Operations";
                    begin
                        DeployClient.LoadEnvironmentOperations(Rec, TempAppOperation);
                        AppOperations.SetEnvironmentSource(Rec);
                        AppOperations.Load(TempAppOperation);
                        AppOperations.RunModal();

                        LoadApps();
                    end;
                }
                action(ScheduledInstalls)
                {
                    ApplicationArea = All;
                    Caption = 'Scheduled Installs';
                    Image = Timesheet;
                    ToolTip = 'Shows per-tenant extension installs that are staged for a later update window or release.';

                    trigger OnAction()
                    var
                        TempAppOperation: Record "MPA App Operation" temporary;
                        DeployClient: Codeunit "MPA Deploy Client";
                        AppOperations: Page "MPA App Operations";
                    begin
                        DeployClient.LoadScheduledPteOperations(TempAppOperation);
                        AppOperations.SetScheduledSource();
                        AppOperations.Load(TempAppOperation);
                        AppOperations.RunModal();

                        LoadApps();
                    end;
                }
                action(Uninstall)
                {
                    ApplicationArea = All;
                    Caption = 'Uninstall';
                    Image = Delete;
                    ToolTip = 'Uninstalls the selected extension, optionally deleting the data it owns.';

                    trigger OnAction()
                    begin
                        RunUninstall();
                    end;
                }
                action(SetUp)
                {
                    ApplicationArea = All;
                    Caption = 'Set up';
                    Image = Setup;
                    ToolTip = 'Opens the settings of the selected extension, where HttpClient requests can be allowed.';

                    trigger OnAction()
                    begin
                        ShowExtensionSettings();
                    end;
                }
                action(ConnectionSetup)
                {
                    ApplicationArea = All;
                    Caption = 'Connection Setup';
                    Image = ServiceSetup;
                    RunObject = page "MPA Deploy Setup";
                    ToolTip = 'Opens the Entra application settings used to call the admin center API.';
                }
                action(DeleteOrphanedData)
                {
                    ApplicationArea = All;
                    Caption = 'Delete Orphaned Extension Data';
                    Image = Delete;
                    ToolTip = 'Shows extensions that still hold data in this environment but are no longer installed, so the data can be deleted.';

                    trigger OnAction()
                    begin
                        // The page's source table is OnPrem-scoped, so it cannot be pre-filtered from here.
                        Page.Run(Page::"Delete Orphaned Extension Data");
                    end;
                }
                action(Refresh)
                {
                    ApplicationArea = All;
                    Caption = 'Refresh';
                    Image = Refresh;
                    ToolTip = 'Reloads the extension list from the admin center API.';

                    trigger OnAction()
                    begin
                        LoadApps();
                    end;
                }
            }
            group(Monitor)
            {
                Caption = 'History';

                action(AppOperations)
                {
                    ApplicationArea = All;
                    Caption = 'Operations';
                    Image = History;
                    ToolTip = 'Shows install, update, and uninstall operations recorded for the selected extension.';

                    trigger OnAction()
                    var
                        TempAppOperation: Record "MPA App Operation" temporary;
                        DeployClient: Codeunit "MPA Deploy Client";
                        AppOperations: Page "MPA App Operations";
                    begin
                        Rec.TestField("App ID");
                        DeployClient.LoadAppOperations(Rec."App ID", Rec.Name, TempAppOperation);
                        AppOperations.SetAppSource(Rec."App ID", Rec.Name);
                        AppOperations.Load(TempAppOperation);
                        AppOperations.RunModal();

                        LoadApps();
                    end;
                }
                action(EventSubscriptions)
                {
                    ApplicationArea = All;
                    Caption = 'Event Subscriptions';
                    Image = Event;
                    ToolTip = 'Shows the event subscriptions registered by the selected extension.';

                    trigger OnAction()
                    begin
                        ShowEventSubscriptions();
                    end;
                }
                action(DeploymentLog)
                {
                    ApplicationArea = All;
                    Caption = 'Deployment Log';
                    Image = Log;
                    RunObject = page "MPA Deploy Log";
                    ToolTip = 'Opens the local record of every deployment and uninstall attempt made from this environment.';
                }
                action(LearnMore)
                {
                    ApplicationArea = All;
                    Caption = 'Learn More';
                    Image = Info;
                    ToolTip = 'Opens the admin center app management documentation.';

                    trigger OnAction()
                    begin
                        Hyperlink(ApiDocsUrlTok);
                    end;
                }
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Manage';

                actionref(UploadExtension_Promoted; UploadExtension) { }
                actionref(InstallationStatus_Promoted; InstallationStatus) { }
                actionref(ScheduledInstalls_Promoted; ScheduledInstalls) { }
                actionref(Uninstall_Promoted; Uninstall) { }
                actionref(SetUp_Promoted; SetUp) { }
                actionref(Refresh_Promoted; Refresh) { }
            }
        }
    }

    var
        CannotUninstallErr: Label 'The admin center API reports that %1 cannot be uninstalled.', Comment = '%1 = extension name';
        CannotUninstallSelfErr: Label 'This extension cannot uninstall itself. Use the Business Central admin center instead.';
        PackageNotFoundErr: Label 'No published package was found in this environment for %1.', Comment = '%1 = extension name';
        ApiDocsUrlTok: Label 'https://learn.microsoft.com/dynamics365/business-central/dev-itpro/administration/administration-center-api_app_management', Locked = true;

    trigger OnOpenPage()
    begin
        LoadApps();
    end;

    local procedure LoadApps()
    var
        DeploySetup: Record "MPA Deploy Setup";
        DeployClient: Codeunit "MPA Deploy Client";
        CurrentView: Text;
        SelectedAppId: Guid;
    begin
        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        // Reloading resets the temporary table, so keep the user's sorting and row.
        CurrentView := Rec.GetView();
        SelectedAppId := Rec."App ID";

        DeployClient.LoadInstalledApps(Rec);

        Rec.SetView(CurrentView);
        if not Rec.Get(SelectedAppId) then
            if Rec.FindFirst() then;

        CurrPage.Update(false);
    end;

    local procedure ShowExtensionSettings()
    var
        NavAppSetting: Record "NAV App Setting";
        ExtensionSettings: Page "MPA Extension Settings";
    begin
        Rec.TestField("App ID");

        if not NavAppSetting.Get(Rec."App ID") then begin
            NavAppSetting.Init();
            NavAppSetting."App ID" := Rec."App ID";
            NavAppSetting.Insert();
        end;

        ExtensionSettings.SetContext(Rec.Name, Rec.Publisher, Rec.Version, Rec."App Type", Rec.State);
        ExtensionSettings.SetRecord(NavAppSetting);
        ExtensionSettings.Run();
    end;

    local procedure ShowEventSubscriptions()
    var
        EventSubscription: Record "Event Subscription";
        AppModule: ModuleInfo;
    begin
        Rec.TestField("App ID");

        // Event subscriptions are keyed on the package, not the app.
        if not NavApp.GetModuleInfo(Rec."App ID", AppModule) then
            Error(PackageNotFoundErr, Rec.Name);

        EventSubscription.SetRange("Originating Package ID", AppModule.PackageId());
        Page.Run(Page::"Event Subscriptions", EventSubscription);
    end;

    local procedure RunUninstall()
    var
        CurrentModule: ModuleInfo;
        UninstallExtension: Page "MPA Uninstall Extension";
    begin
        Rec.TestField("App ID");

        NavApp.GetCurrentModuleInfo(CurrentModule);
        if Rec."App ID" = CurrentModule.Id() then
            Error(CannotUninstallSelfErr);

        if not Rec."Can Be Uninstalled" then
            Error(CannotUninstallErr, Rec.Name);

        UninstallExtension.SetExtension(Rec."App ID", Rec.Name, Rec.Publisher, Rec.Version);
        UninstallExtension.RunModal();

        LoadApps();
    end;
}
