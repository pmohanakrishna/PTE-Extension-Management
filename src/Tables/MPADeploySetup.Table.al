table 66650 "MPA Deploy Setup"
{
    Caption = 'MPA Deploy Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        // Numbers 10-31 were used by earlier fields. Never reuse a field number:
        // upgrade maps data by number, not by name.
        field(40; "Client ID"; Guid)
        {
            Caption = 'Application (Client) ID';
            DataClassification = CustomerContent;
        }
        field(41; "Client Secret Key"; Guid)
        {
            // Only the Isolated Storage lookup key lives in the table.
            // The secret itself never touches a table field.
            Caption = 'Client Secret Key';
            DataClassification = SystemMetadata;
        }
        field(42; "API Version"; Text[10])
        {
            Caption = 'API Version';
            DataClassification = CustomerContent;
            InitValue = 'v2.29';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        MissingSecretErr: Label 'Enter the client secret on the MPA Deploy Setup page before deploying.';

    procedure GetSetup()
    begin
        if Rec.Get() then
            exit;
        Rec.Init();
        Rec.Insert(true);
    end;

    procedure SetClientSecret(NewSecret: Text)
    begin
        if IsNullGuid(Rec."Client Secret Key") then begin
            Rec."Client Secret Key" := CreateGuid();
            Rec.Modify(true);
        end;

        if NewSecret = '' then begin
            if IsolatedStorage.Contains(Format(Rec."Client Secret Key"), DataScope::Module) then
                IsolatedStorage.Delete(Format(Rec."Client Secret Key"), DataScope::Module);
            exit;
        end;

        if not IsolatedStorage.SetEncrypted(Format(Rec."Client Secret Key"), NewSecret, DataScope::Module) then
            IsolatedStorage.Set(Format(Rec."Client Secret Key"), NewSecret, DataScope::Module);
    end;

    procedure GetClientSecret() Secret: SecretText
    begin
        if IsNullGuid(Rec."Client Secret Key") then
            exit;
        if not IsolatedStorage.Get(Format(Rec."Client Secret Key"), DataScope::Module, Secret) then
            Clear(Secret);
    end;

    procedure HasClientSecret(): Boolean
    begin
        if IsNullGuid(Rec."Client Secret Key") then
            exit(false);
        exit(IsolatedStorage.Contains(Format(Rec."Client Secret Key"), DataScope::Module));
    end;

    procedure TestReady()
    begin
        Rec.TestField("Client ID");
        Rec.TestField("API Version");
        if not Rec.HasClientSecret() then
            Error(MissingSecretErr);
    end;
}
