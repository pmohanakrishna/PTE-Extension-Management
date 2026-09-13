table 66653 "MPA App Operation"
{
    Caption = 'MPA App Operation';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(10; "Operation ID"; Guid)
        {
            Caption = 'Operation ID';
        }
        field(11; "App ID"; Guid)
        {
            Caption = 'App ID';
        }
        field(12; "App Name"; Text[250])
        {
            Caption = 'App Name';
        }
        field(13; "Operation Type"; Text[50])
        {
            Caption = 'Type';
        }
        field(14; Status; Text[30])
        {
            Caption = 'Status';
        }
        field(15; "Source Version"; Text[30])
        {
            Caption = 'Source Version';
        }
        field(16; "Target Version"; Text[30])
        {
            Caption = 'Target Version';
        }
        field(17; "Schedule Kind"; Text[30])
        {
            Caption = 'Schedule Kind';
        }
        field(20; "Created On"; DateTime)
        {
            Caption = 'Created On';
        }
        field(21; "Started On"; DateTime)
        {
            Caption = 'Started On';
        }
        field(22; "Completed On"; DateTime)
        {
            Caption = 'Completed On';
        }
        field(23; "Created By"; Text[250])
        {
            Caption = 'Created By';
        }
        field(30; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
        }
        field(40; "App Publisher"; Text[250])
        {
            Caption = 'App Publisher';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByCreatedOn; "Created On") { }
    }
}
