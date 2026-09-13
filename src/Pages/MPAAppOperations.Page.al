page 66654 "MPA App Operations"
{
    Caption = 'Extension Installation Status';
    PageType = List;
    ApplicationArea = All;
    SourceTable = "MPA App Operation";
    SourceTableTemporary = true;
    SourceTableView = sorting("Created On") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Operations)
            {
                field("App Name"; Rec."App Name")
                {
                    ApplicationArea = All;
                    StyleExpr = 'StrongAccent';
                    ToolTip = 'Specifies the extension the operation applies to. Choose the value to see the full status detail.';

                    trigger OnDrillDown()
                    begin
                        ShowDetail();
                    end;
                }
                field("App Publisher"; Rec."App Publisher")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the publisher of the extension.';
                }
                field("App ID"; Rec."App ID")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies the unique identifier of the extension.';
                }
                field("Operation Type"; Rec."Operation Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the operation was an install, update, or uninstall.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current status of the operation.';
                }
                field("Schedule Kind"; Rec."Schedule Kind")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when a scheduled operation is due to run.';
                }
                field("Source Version"; Rec."Source Version")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the version installed before the operation started.';
                }
                field("Target Version"; Rec."Target Version")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the version the operation installs.';
                }
                field("Created On"; Rec."Created On")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the operation was created.';
                }
                field("Started On"; Rec."Started On")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the operation began running.';
                }
                field("Completed On"; Rec."Completed On")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the operation finished.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user or service principal that requested the operation.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
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
                ToolTip = 'Reloads the operations from the admin center API.';

                trigger OnAction()
                begin
                    Reload();
                end;
            }
            action(ShowDetails)
            {
                ApplicationArea = All;
                Caption = 'Details';
                Image = ViewDetails;
                ToolTip = 'Shows the full status detail for the selected operation.';

                trigger OnAction()
                begin
                    ShowDetail();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ShowDetails_Promoted; ShowDetails) { }
                actionref(Refresh_Promoted; Refresh) { }
            }
        }
    }

    var
        TempSourceApp: Record "MPA Environment App" temporary;
        SourceAppId: Guid;
        SourceAppName: Text;
        SourceKind: Option Environment,Scheduled,App;

    procedure Load(var TempAppOperation: Record "MPA App Operation" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if TempAppOperation.FindSet() then
            repeat
                Rec := TempAppOperation;
                Rec.Insert();
            until TempAppOperation.Next() = 0;

        if Rec.FindFirst() then;
    end;

    procedure SetEnvironmentSource(var TempEnvironmentApp: Record "MPA Environment App" temporary)
    var
        SavedAppId: Guid;
    begin
        SourceKind := SourceKind::Environment;

        // Copying moves the caller's cursor to the last row, so put it back.
        SavedAppId := TempEnvironmentApp."App ID";

        TempSourceApp.Reset();
        TempSourceApp.DeleteAll();
        if TempEnvironmentApp.FindSet() then
            repeat
                TempSourceApp := TempEnvironmentApp;
                TempSourceApp.Insert();
            until TempEnvironmentApp.Next() = 0;

        if TempEnvironmentApp.Get(SavedAppId) then;
    end;

    procedure SetScheduledSource()
    begin
        SourceKind := SourceKind::Scheduled;
    end;

    procedure SetAppSource(NewAppId: Guid; NewAppName: Text)
    begin
        SourceKind := SourceKind::App;
        SourceAppId := NewAppId;
        SourceAppName := NewAppName;
    end;

    local procedure Reload()
    var
        TempAppOperation: Record "MPA App Operation" temporary;
        DeployClient: Codeunit "MPA Deploy Client";
        CurrentView: Text;
        CurrentEntryNo: Integer;
    begin
        CurrentView := Rec.GetView();
        CurrentEntryNo := Rec."Entry No.";

        case SourceKind of
            SourceKind::Environment:
                DeployClient.LoadEnvironmentOperations(TempSourceApp, TempAppOperation);
            SourceKind::Scheduled:
                DeployClient.LoadScheduledPteOperations(TempAppOperation);
            SourceKind::App:
                DeployClient.LoadAppOperations(SourceAppId, SourceAppName, TempAppOperation);
        end;

        Load(TempAppOperation);

        Rec.SetView(CurrentView);
        if not Rec.Get(CurrentEntryNo) then
            if Rec.FindFirst() then;

        CurrPage.Update(false);
    end;

    local procedure ShowDetail()
    var
        TempAppOperation: Record "MPA App Operation" temporary;
        OperationDetail: Page "MPA Operation Detail";
    begin
        TempAppOperation := Rec;
        TempAppOperation.Insert();

        case SourceKind of
            SourceKind::Environment:
                OperationDetail.SetEnvironmentRefresh(TempSourceApp);
            SourceKind::Scheduled:
                OperationDetail.SetScheduledRefresh();
            SourceKind::App:
                OperationDetail.SetAppRefresh(SourceAppId, SourceAppName);
        end;

        OperationDetail.SetOperation(TempAppOperation);
        OperationDetail.RunModal();

        Reload();
    end;
}
