table 66651 "MPA Deploy Log"
{
    Caption = 'MPA Deploy Log';
    DataClassification = CustomerContent;
    DrillDownPageId = "MPA Deploy Log";
    LookupPageId = "MPA Deploy Log";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(10; "File Name"; Text[250])
        {
            Caption = 'File Name';
            DataClassification = CustomerContent;
        }
        field(11; "Attempted At"; DateTime)
        {
            Caption = 'Attempted At';
            DataClassification = CustomerContent;
        }
        field(12; "Attempted By"; Code[50])
        {
            Caption = 'Attempted By';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = User."User Name";
        }
        field(13; "Operation Type"; Text[30])
        {
            Caption = 'Operation Type';
            DataClassification = SystemMetadata;
        }
        field(14; "Environment Name"; Text[50])
        {
            Caption = 'Environment Name';
            DataClassification = CustomerContent;
        }
        field(20; "HTTP Status"; Integer)
        {
            Caption = 'HTTP Status';
            DataClassification = SystemMetadata;
        }
        field(21; Successful; Boolean)
        {
            Caption = 'Successful';
            DataClassification = SystemMetadata;
        }
        field(22; "Operation ID"; Text[50])
        {
            Caption = 'Operation ID';
            DataClassification = SystemMetadata;
        }
        field(30; Response; Blob)
        {
            Caption = 'Response';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Attempted At", "File Name", Successful) { }
    }

    procedure GetResponseText() ResponseText: Text
    var
        ResponseInStream: InStream;
    begin
        Rec.CalcFields(Response);
        if not Rec.Response.HasValue() then
            exit('');
        Rec.Response.CreateInStream(ResponseInStream, TextEncoding::UTF8);
        ResponseInStream.ReadText(ResponseText);
    end;
}
