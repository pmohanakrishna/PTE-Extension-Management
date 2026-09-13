permissionset 66650 "MPA Deploy Admin"
{
    Caption = 'MPA Deploy Admin';
    Assignable = true;

    // Deliberately not added to any Microsoft permission set and deliberately
    // not extending D365 BASIC. Anyone holding this can push code into the
    // environment, so assignment should be a conscious act.

    Permissions =
        tabledata "MPA Deploy Setup" = RIMD,
        tabledata "MPA Deploy Log" = RIM,
        tabledata "NAV App Setting" = RIM,
        tabledata "Event Subscription" = R,
        table "MPA Deploy Setup" = X,
        table "MPA Deploy Log" = X,
        table "MPA Environment App" = X,
        table "MPA App Operation" = X,
        page "MPA Deploy Setup" = X,
        page "MPA Upload And Deploy" = X,
        page "MPA Uninstall Extension" = X,
        page "MPA Deploy Log" = X,
        page "MPA Environment Apps" = X,
        page "MPA App Operations" = X,
        page "MPA Operation Detail" = X,
        page "MPA Extension Settings" = X,
        codeunit "MPA Deploy Auth" = X,
        codeunit "MPA Deploy Client" = X;
}
