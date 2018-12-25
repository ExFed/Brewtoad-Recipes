param([string]$UserId)

if ([string]::IsNullOrEmpty($userId)) {
    Write-Warning "Requires Brewtoad User Identifier. Found in URL of profile page, e.g.: https://www.brewtoad.com/users/38089"
    exit 1
}

$headers = @{
    'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0'
    'Accept'          = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    'Accept-Language' = 'en-US,en;q=0.5'
    'Accept-Encoding' = 'gzip, deflate, br'
    'DNT'             = '1'
}
$baseUrl = "https://www.brewtoad.com"

filter Find-RecipeNames {
    ([regex]"a class='recipe-link' href='/recipes/([^']+)").Matches($_) |
        ForEach-Object { "$($_.Groups[1].Value)" }
}

filter Get-UserRecipesSummary([Parameter(ValueFromPipeline)][string]$userId) {
    Write-Progress -Activity 'Scraping' -Status 'Downloading recipe list'
    return Invoke-RestMethod "$baseUrl/users/$userId/recipes" -Headers $headers
}

class Recipe {
    [string]$Name
    [xml]$BeerXml
}

filter Get-Recipe([Parameter(ValueFromPipeline)][string]$name) {
    Write-Progress -Activity 'Scraping' -Status "Downloading recipe: $name"
    $beerXml = Invoke-RestMethod "$baseUrl/recipes/$name.xml" -Headers $headers
    return [Recipe]@{
        Name    = $name
        BeerXml = $beerXml
    }
}

filter Get-RecipeNames([Parameter(ValueFromPipeline)][string]$userId) {
    return $userId | Get-UserRecipesSummary | Find-RecipeNames
}

class UserRecipes {
    [string]$UserId
    [Recipe[]]$Recipes
}

function Get-UserRecipes([Parameter(ValueFromPipeline)][string]$UserId) {
    process {
        $recipes = $UserId | Get-RecipeNames | Get-Recipe
        Write-Progress -Activity 'Scraping' -Completed
        return [UserRecipes]@{
            UserId  = $UserId
            Recipes = $recipes
        }
    }
}

function Write-UserRecipes([Parameter(ValueFromPipeline)][UserRecipes]$UserRecipes) {
    process {
        if (!(Test-Path -Path ".\$($UserRecipes.UserId)" -PathType Container)) {
            New-Item -Path . -Name $UserRecipes.UserId -ItemType Directory
        }
        $UserRecipes.Recipes | ForEach-Object { $_.BeerXml.OuterXml | Out-File -FilePath ".\$($UserRecipes.UserId)\$($_.Name).xml" }
    }
}

Get-UserRecipes -UserId $UserId | Write-UserRecipes
