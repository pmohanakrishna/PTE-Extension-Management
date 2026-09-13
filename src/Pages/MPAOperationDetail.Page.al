page 66657 "MPA Operation Detail"
{
    Caption = 'Extension Installation Status Detail';
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "MPA App Operation";
    SourceTableTemporary = true;
    DataCaptionExpression = TitleTxt;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("App Name"; Rec."App Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the extension the operation applies to.';
                }
                field("App Publisher"; Rec."App Publisher")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the publisher of the extension.';
                }
                field("Target Version"; Rec."Target Version")
                {
                    ApplicationArea = All;
                    Caption = 'App Version';
                    ToolTip = 'Specifies the version the operation installs.';
                }
                field("App ID"; Rec."App ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique identifier of the extension.';
                }
                field("Schedule Kind"; Rec."Schedule Kind")
                {
                    ApplicationArea = All;
                    Caption = 'Schedule';
                    ToolTip = 'Specifies when the operation is due to run.';
                }
                field("Started On"; Rec."Started On")
                {
                    ApplicationArea = All;
                    Caption = 'Started Date';
                    ToolTip = 'Specifies when the operation began running.';
                }
                field("Completed On"; Rec."Completed On")
                {
                    ApplicationArea = All;
                    Caption = 'Completed Date';
                    ToolTip = 'Specifies when the operation finished.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the current status of the operation.';
                }
                field(Summary; SummaryTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Summary';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Specifies a short description of the outcome.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user or service principal that requested the operation.';
                }
            }
            group(ErrorDetails)
            {
                Caption = 'Error Details';
                Visible = HasError;

                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    Caption = 'Error Details';
                    MultiLine = true;
                    ShowCaption = false;
                    ToolTip = 'Specifies the failure detail reported by the admin center API.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                Image = Refresh;
                ToolTip = 'Reloads this operation from the admin center API.';

                trigger OnAction()
                begin
                    Reload();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(Refresh_Promoted; Refresh) { }
            }
        }
    }

    var
        TempRefreshApp: Record "MPA Environment App" temporary;
        RefreshAppId: Guid;
        RefreshAppName: Text;
        RefreshKind: Option Environment,Scheduled,App;
        SummaryTxt: Text;
        StatusStyle: Text;
        TitleTxt: Text;
        HasError: Boolean;
        SucceededTxt: Label 'Operation completed successfully.';
        RunningTxt: Label 'Operation is running.';
        ScheduledTxt: Label 'Operation is scheduled and has not started yet.';
        FailedTxt: Label 'Operation failed.';
        InstallTitleTxt: Label 'Deploying Extension ''%1'' published by ''%2''', Comment = '%1 = extension name, %2 = publisher';
        UninstallTitleTxt: Label 'Uninstalling Extension ''%1'' published by ''%2''', Comment = '%1 = extension name, %2 = publisher';
        UpdateTitleTxt: Label 'Updating Extension ''%1'' published by ''%2''', Comment = '%1 = extension name, %2 = publisher';
        GenericTitleTxt: Label 'Extension Operation for ''%1''', Comment = '%1 = extension name';

    trigger OnAfterGetRecord()
    begin
        SetPresentation();
    end;

    procedure SetOperation(var TempAppOperation: Record "MPA App Operation" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();
        Rec := TempAppOperation;
        Rec.Insert();
        SetPresentation();
    end;

    local procedure SetPresentation()
    begin
        HasError := Rec."Error Message" <> '';
        SetTitle();

        case LowerCase(Rec.Status) of
            'succeeded':
                begin
                    SummaryTxt := SucceededTxt;
                    StatusStyle := 'Favorable';
                end;
            'running':
                begin
                    SummaryTxt := RunningTxt;
                    StatusStyle := 'Ambiguous';
                end;
            'scheduled', 'queued':
                begin
                    SummaryTxt := ScheduledTxt;
                    StatusStyle := 'Ambiguous';
                end;
            'failed', 'canceled':
                begin
                    SummaryTxt := FailedTxt;
                    StatusStyle := 'Unfavorable';
                end;
            else begin
                SummaryTxt := Rec.Status;
                StatusStyle := 'Standard';
            end;
        end;

        if Rec."Error Message" <> '' then
            SummaryTxt := Rec."Error Message";
    end;

    local procedure SetTitle()
    var
        DisplayName: Text;
        OperationType: Text;
    begin
        DisplayName := Rec."App Name";
        if DisplayName = '' then
            DisplayName := Format(Rec."App ID");

        if Rec."App Publisher" = '' then begin
            TitleTxt := StrSubstNo(GenericTitleTxt, DisplayName);
            exit;
        end;

        OperationType := LowerCase(Rec."Operation Type");
        case true of
            StrPos(OperationType, 'uninstall') > 0:
                TitleTxt := StrSubstNo(UninstallTitleTxt, DisplayName, Rec."App Publisher");
            StrPos(OperationType, 'update') > 0:
                TitleTxt := StrSubstNo(UpdateTitleTxt, DisplayName, Rec."App Publisher");
            StrPos(OperationType, 'install') > 0:
                TitleTxt := StrSubstNo(InstallTitleTxt, DisplayName, Rec."App Publisher");
            else
                TitleTxt := StrSubstNo(GenericTitleTxt, DisplayName);
        end;
    end;

    procedure SetEnvironmentRefresh(var TempEnvironmentApp: Record "MPA Environment App" temporary)
    var
        SavedAppId: Guid;
    begin
        RefreshKind := RefreshKind::Environment;

        SavedAppId := TempEnvironmentApp."App ID";

        TempRefreshApp.Reset();
        TempRefreshApp.DeleteAll();
        if TempEnvironmentApp.FindSet() then
            repeat
                TempRefreshApp := TempEnvironmentApp;
                TempRefreshApp.Insert();
            until TempEnvironmentApp.Next() = 0;

        if TempEnvironmentApp.Get(SavedAppId) then;
    end;

    procedure SetScheduledRefresh()
    begin
        RefreshKind := RefreshKind::Scheduled;
    end;

    procedure SetAppRefresh(NewAppId: Guid; NewAppName: Text)
    begin
        RefreshKind := RefreshKind::App;
        RefreshAppId := NewAppId;
        RefreshAppName := NewAppName;
    end;

    local procedure Reload()
    var
        TempAppOperation: Record "MPA App Operation" temporary;
        DeployClient: Codeunit "MPA Deploy Client";
        OperationId: Guid;
    begin
        OperationId := Rec."Operation ID";

        // Must re-read the same endpoint the list used; the per-app endpoint returns fewer fields.
        case RefreshKind of
            RefreshKind::Environment:
                DeployClient.LoadEnvironmentOperations(TempRefreshApp, TempAppOperation);
            RefreshKind::Scheduled:
                DeployClient.LoadScheduledPteOperations(TempAppOperation);
            RefreshKind::App:
                begin
                    if IsNullGuid(RefreshAppId) then
                        exit;
                    DeployClient.LoadAppOperations(RefreshAppId, RefreshAppName, TempAppOperation);
                end;
        end;

        TempAppOperation.SetRange("Operation ID", OperationId);
        if not TempAppOperation.FindFirst() then
            exit;

        SetOperation(TempAppOperation);
        CurrPage.Update(false);
    end;
}
