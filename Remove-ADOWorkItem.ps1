﻿function Remove-ADOWorkItem
{
    <#
    .Synopsis
        Remove work items from Azure DevOps
    .Description
        Remove work item from Azure DevOps or Team Foundation Server.
    .Example
        Remove-ADOWorkItem -Organization StartAutomating -Project PSDevOps -ID 10
    .Example
        Remove-ADOWorkItem -Organization StartAutomating -Project PSDevOps -Query "Select [System.ID] from WorkItems Where [System.Title] = 'Test-WorkItem'" -PersonalAccessToken $pat -Confirm:$false
    .Link
        Invoke-ADORestAPI
    .Link
        https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/work%20items/delete?view=azure-devops-rest-5.1
    #>
    [CmdletBinding(DefaultParameterSetName='ByID', SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
    # The Organization
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [Alias('Org')]
    [string]
    $Organization,

    # The Project
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [string]
    $Project,

    # The Work Item ID
    [Parameter(Mandatory,ParameterSetName='ByID',ValueFromPipelineByPropertyName)]
    [string]
    $ID,

    # A query
    [Parameter(Mandatory,ParameterSetName='ByQuery',ValueFromPipelineByPropertyName)]
    [string]
    $Query,

    # The server.  By default https://dev.azure.com/.
    # To use against TFS, provide the tfs server URL (e.g. http://tfsserver:8080/tfs).
    [Parameter(ValueFromPipelineByPropertyName)]
    [uri]
    $Server = "https://dev.azure.com/",

    # The api version.  By default, 5.1.
    # If targeting TFS, this will need to change to match your server version.
    # See: https://docs.microsoft.com/en-us/azure/devops/integrate/concepts/rest-api-versioning?view=azure-devops
    [string]
    $ApiVersion = "5.1")

    dynamicParam { . $GetInvokeParameters -DynamicParameter }
    begin {
        #region Copy Invoke-ADORestAPI parameters
        $invokeParams = . $getInvokeParameters $PSBoundParameters
        #endregion Copy Invoke-ADORestAPI parameters
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByID') { # If we're removing by ID
            $uriBase = "$Server".TrimEnd('/'), $Organization, $Project -join '/'
            $uri = $uriBase, "_apis/wit/workitems", "${ID}?" -join '/'

            if ($Server -ne 'https://dev.azure.com/' -and
                -not $PSBoundParameters.ApiVersion) {
                $ApiVersion = '2.0'
            }
            $uri +=
                if ($ApiVersion) {
                    "api-version=$ApiVersion"
                }

            $invokeParams.Uri = $uri
            $invokeParams.Method = 'DELETE'
            if (-not $PSCmdlet.ShouldProcess("Remove Work Item $ID")) { return }
            Invoke-ADORestAPI @invokeParams
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByQuery') {


            $uri = "$Server".TrimEnd('/'), $Organization, $Project, "_apis/wit/wiql?" -join '/'
            $uri += if ($ApiVersion) {
                "api-version=$ApiVersion"
            }

            $invokeParams.Method = "POST"
            $invokeParams.Body = ConvertTo-Json @{query=$Query}
            $invokeParams["Uri"] = $uri

            $queryResult = Invoke-ADORestAPI @invokeParams
            $c, $t, $progId  = 0, $queryResult.workItems.count, [Random]::new().Next()
            $myParams = @{} + $PSBoundParameters
            $myParams.Remove('Query')
            foreach ($wi in $queryResult.workItems) {
                $c++
                Write-Progress "Updating Work Items" " [$c of $t]" -PercentComplete ($c * 100 /$t) -Id $progId
                Remove-ADOWorkItem @myParams -ID $wi.ID
            }

            Write-Progress "Updating Work Items" "Complete" -Completed -Id $progId
        }
    }
}
