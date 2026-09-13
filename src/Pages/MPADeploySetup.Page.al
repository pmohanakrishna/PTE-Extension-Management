page 66650 "MPA Deploy Setup"
{
    Caption = 'MPA Deploy Setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "MPA Deploy Setup";
    InsertAllowed = false;
    DeleteAllowed = false;
    Permissions = tabledata "MPA Deploy Setup" = rimd;

    layout
    {
        area(Content)
        {
            group(Connection)
            {
                Caption = 'Entra Application';

                field("Client ID"; Rec."Client ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the application (client) ID of the Entra app registration used for service-to-service authentication.';
                }
                field(ClientSecret; ClientSecretMask)
                {
                    ApplicationArea = All;
                    Caption = 'Client Secret';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies the client secret. The value is stored encrypted in Isolated Storage and cannot be read back.';

                    trigger OnValidate()
                    begin
                        Rec.SetClientSecret(ClientSecretMask);
                        ClientSecretMask := '';
                        CurrPage.Update(false);
                    end;
                }
                field(SecretIsSet; Rec.HasClientSecret())
                {
                    ApplicationArea = All;
                    Caption = 'Secret Is Set';
                    Editable = false;
                    ToolTip = 'Specifies whether a client secret is currently stored.';
                }
            }
            group(Target)
            {
                Caption = 'Target Environment';

                field(EnvironmentName; EnvironmentName)
                {
                    ApplicationArea = All;
                    Caption = 'Environment Name';
                    Editable = false;
                    ToolTip = 'Specifies the environment that packages are deployed to. Deployment always targets the environment you are signed in to.';
                }
                field(EnvironmentType; EnvironmentType)
                {
                    ApplicationArea = All;
                    Caption = 'Environment Type';
                    Editable = false;
                    ToolTip = 'Specifies whether this is a sandbox or a production environment.';
                }
                field("API Version"; Rec."API Version")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the version of the admin center API to call.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection';
                Image = Setup;
                ToolTip = 'Requests an access token and lists the apps installed on the target environment.';

                trigger OnAction()
                var
                    DeployClient: Codeunit "MPA Deploy Client";
                begin
                    DeployClient.TestConnection();
                end;
            }
            action(OpenLog)
            {
                ApplicationArea = All;
                Caption = 'Deployment Log';
                Image = Log;
                RunObject = page "MPA Deploy Log";
                ToolTip = 'Opens the record of every deployment attempt made from this environment.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(TestConnection_Promoted; TestConnection) { }
                actionref(OpenLog_Promoted; OpenLog) { }
            }
        }
    }

    var
        ClientSecretMask: Text;
        EnvironmentName: Text;
        EnvironmentType: Text;

    trigger OnOpenPage()
    var
        DeployClient: Codeunit "MPA Deploy Client";
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        Rec.GetSetup();
        EnvironmentName := EnvironmentInformation.GetEnvironmentName();
        EnvironmentType := DeployClient.GetEnvironmentType();
    end;
}
