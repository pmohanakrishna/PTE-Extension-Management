page 66658 "MPA Extension Settings"
{
    Caption = 'Extension Settings';
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "NAV App Setting";
    InsertAllowed = false;
    DeleteAllowed = false;
    Permissions = tabledata "NAV App Setting" = rim;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("App ID"; Rec."App ID")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the unique identifier of the extension.';
                }
                field(AppName; AppName)
                {
                    ApplicationArea = All;
                    Caption = 'Name';
                    Editable = false;
                    ToolTip = 'Specifies the name of the extension.';
                }
                field(AppVersion; AppVersion)
                {
                    ApplicationArea = All;
                    Caption = 'Version';
                    Editable = false;
                    ToolTip = 'Specifies the installed version of the extension.';
                }
                field(AppPublisher; AppPublisher)
                {
                    ApplicationArea = All;
                    Caption = 'Publisher';
                    Editable = false;
                    ToolTip = 'Specifies the publisher of the extension.';
                }
                field(PublishedAs; PublishedAs)
                {
                    ApplicationArea = All;
                    Caption = 'Published As';
                    Editable = false;
                    ToolTip = 'Specifies whether the extension is a global Marketplace app, a per-tenant extension, or a development extension.';
                }
                field(AppState; AppState)
                {
                    ApplicationArea = All;
                    Caption = 'State';
                    Editable = false;
                    ToolTip = 'Specifies whether the extension is installed, updating, or pending an update.';
                }
                field("Allow HttpClient Requests"; Rec."Allow HttpClient Requests")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the extension may call external services over HTTP. This applies to per-tenant extensions and is a setting of this environment, not of the admin center.';

                    trigger OnValidate()
                    begin
                        CurrPage.SaveRecord();
                    end;
                }
            }
        }
    }

    var
        AppName: Text;
        AppPublisher: Text;
        AppVersion: Text;
        PublishedAs: Text;
        AppState: Text;

    procedure SetContext(NewName: Text; NewPublisher: Text; NewVersion: Text; NewPublishedAs: Text; NewState: Text)
    begin
        AppName := NewName;
        AppPublisher := NewPublisher;
        AppVersion := NewVersion;
        PublishedAs := NewPublishedAs;
        AppState := NewState;
    end;
}
