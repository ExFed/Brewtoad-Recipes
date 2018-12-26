param([string]$UserId)

if ([string]::IsNullOrEmpty($UserId)) {
    Write-Warning "Requires Brewtoad User Identifier. Found in URL of profile page, e.g.: https://www.brewtoad.com/users/38089"
    exit 1
}

$Headers = @{
    'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0'
    'Accept'          = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    'Accept-Language' = 'en-US,en;q=0.5'
    'Accept-Encoding' = 'gzip, deflate, br'
    'DNT'             = '1'
}
$BaseUrl = "https://www.brewtoad.com"

filter Find-RecipeNames {
    ([regex]"a class='recipe-link' href='/recipes/([^']+)").Matches($_) |
        ForEach-Object { "$($_.Groups[1].Value)" }
}

filter Get-RecipesSummary([Parameter(ValueFromPipeline)][string]$UserId) {
    Write-Progress -Activity 'Scraping' -Status 'Downloading recipe list'
    return Invoke-RestMethod "$BaseUrl/users/$UserId/recipes" -Headers $Headers
}

class Recipe {
    [string]$Name
    [xml]$BeerXml
}

filter Get-Recipe([Parameter(ValueFromPipeline)][string]$Name) {
    Write-Progress -Activity 'Scraping' -Status "Downloading recipe: $Name"
    $BeerXml = Invoke-RestMethod "$BaseUrl/recipes/$Name.xml" -Headers $Headers
    return [Recipe]@{
        Name    = $Name
        BeerXml = $BeerXml
    }
}

filter Get-RecipeNames([Parameter(ValueFromPipeline)][string]$UserId) {
    return $UserId | Get-RecipesSummary | Find-RecipeNames
}

function Write-Recipe([Parameter(ValueFromPipeline)][Recipe]$Recipe, [string]$TargetDir) {
    begin {
        if (!(Test-Path -Path $TargetDir -PathType Container)) {
            New-Item -Path $TargetDir -ItemType Directory
        }
    }
    process {
        $Recipe.BeerXml.OuterXml | Out-File -FilePath ".\$TargetDir\$($Recipe.Name).xml"
    }
}

$UserId | Get-RecipeNames | Get-Recipe | Write-Recipe -TargetDir $UserId
