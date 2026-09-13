page 66652 "MPA Deploy Log"
{
    Caption = 'MPA Deploy Log';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = History;
    SourceTable = "MPA Deploy Log";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Permissions = tabledata "MPA Deploy Log" = r;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Attempted At"; Rec."Attempted At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the deployment was attempted.';
                }
                field("Attempted By"; Rec."Attempted By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which user attempted the deployment.';
                }
                field("Operation Type"; Rec."Operation Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the attempt was a package upload or an uninstall.';
                }
                field("Environment Name"; Rec."Environment Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the target environment the attempt was made against.';
                }
                field("File Name"; Rec."File Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the package that was uploaded, or the extension that was uninstalled.';
                }
                field(Successful; Rec.Successful)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the admin center API accepted the upload.';
                }
                field("HTTP Status"; Rec."HTTP Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the HTTP status code returned by the admin center API.';
                }
                field("Operation ID"; Rec."Operation ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the operation ID you can use to track progress in the admin center.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ShowResponse)
            {
                ApplicationArea = All;
                Caption = 'Show Response';
                Image = ViewDetails;
                ToolTip = 'Shows the full response body returned by the admin center API.';

                trigger OnAction()
                var
                    ResponseText: Text;
                begin
                    ResponseText := Rec.GetResponseText();
                    if ResponseText = '' then
                        ResponseText := NoResponseMsg;
                    Message(ResponseText);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ShowResponse_Promoted; ShowResponse) { }
            }
        }
    }

    var
        NoResponseMsg: Label 'No response body was recorded for this entry.';
}
