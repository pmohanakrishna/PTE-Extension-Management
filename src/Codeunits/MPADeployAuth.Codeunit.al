codeunit 66650 "MPA Deploy Auth"
{
    Access = Internal;

    var
        AuthorityUrlTok: Label 'https://login.microsoftonline.com/%1/oauth2/v2.0/token', Locked = true;
        ScopeTok: Label 'https://api.businesscentral.dynamics.com/.default', Locked = true;
        TokenErr: Label 'Could not get an access token for the admin center API. Check the Entra app registration, the client secret, and that admin consent has been granted.\\%1', Comment = '%1 = error reported by the identity provider';

    /// <summary>
    /// Acquires a service-to-service access token for the Business Central admin center API
    /// using the client credentials flow.
    /// </summary>
    procedure GetAccessToken(): SecretText
    var
        DeploySetup: Record "MPA Deploy Setup";
        OAuth2: Codeunit OAuth2;
        AzureADTenant: Codeunit "Azure AD Tenant";
        Scopes: List of [Text];
        AccessToken: SecretText;
    begin
        DeploySetup.GetSetup();
        DeploySetup.TestReady();

        Scopes.Add(ScopeTok);

        // The Entra tenant GUID, not Tenant Information.GetTenantId(), which returns the BC tenant identifier.
        if not OAuth2.AcquireTokenWithClientCredentials(
            DelChr(Format(DeploySetup."Client ID"), '=', '{}'),
            DeploySetup.GetClientSecret(),
            StrSubstNo(AuthorityUrlTok, AzureADTenant.GetAadTenantId()),
            '',
            Scopes,
            AccessToken)
        then
            Error(TokenErr, OAuth2.GetLastErrorMessage());

        if AccessToken.IsEmpty() then
            Error(TokenErr, OAuth2.GetLastErrorMessage());

        exit(AccessToken);
    end;
}
