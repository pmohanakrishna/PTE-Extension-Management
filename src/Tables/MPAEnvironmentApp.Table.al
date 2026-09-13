table 66652 "MPA Environment App"
{
    Caption = 'MPA Environment App';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "App ID"; Guid)
        {
            Caption = 'App ID';
        }
        field(10; Name; Text[250])
        {
            Caption = 'Name';
        }
        field(11; Publisher; Text[250])
        {
            Caption = 'Publisher';
        }
        field(12; Version; Text[30])
        {
            Caption = 'Version';
        }
        field(13; State; Text[30])
        {
            Caption = 'State';
        }
        field(14; "App Type"; Text[30])
        {
            Caption = 'App Type';
        }
        field(15; "Can Be Uninstalled"; Boolean)
        {
            Caption = 'Can Be Uninstalled';
        }
        field(20; "Available Update Version"; Text[30])
        {
            Caption = 'Available Update Version';
        }
    }

    keys
    {
        key(PK; "App ID")
        {
            Clustered = true;
        }
        key(ByName; Name) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Name, Publisher, Version) { }
    }
}
