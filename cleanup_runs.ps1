$ids = gh run list --status failure --limit 50 --json databaseId -q '.[] | .databaseId'
foreach ($id in $ids) {
    if ($id) {
        Write-Host "Deleting run $id"
        gh run delete $id
    }
}
