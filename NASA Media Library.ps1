# NASA Media Library Image Download Script
# NASA Media API document:  https://images.nasa.gov/docs/images.nasa.gov_api_docs.pdf
# 7/29/2020 - Jordon Threadgill

$date1 = Get-Date
$date = $date1.ToString('MM-dd-yyyy')
$desktop = "$base\Desktop"
$outpath = "$desktop\NASA Media Library $date"
New-Item -Path $outpath -ItemType Directory -ErrorAction SilentlyContinue

Function Page-Numbers($pageNumbers){
    $items = @()
    $rest = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]
    $i = 0
    $callNASA = irm -Uri $url -UseBasicParsing -Method get -ContentType "application/json"
    foreach ($thing in $callNASA.collection.items.data){
        $title = $thing.title
        $dateCreated = $thing.date_created
        $descriptionMinor = $thing.description_508
        $descriptionMajor = $thing.description
        $nasaId = $thing.nasa_id
        $keywords = @()
        foreach ($k in $thing.keywords){
            [string]$keywords += $k + ','
        }
        [string]$keywords = $keywords -replace “.$”
        $secondaryCreator = $thing.secondary_creator

        $object1 = [pscustomobject]@{Title = $title; DateCreated = $dateCreated; Description_Minor = $descriptionMinor; NasaId = $nasaId; DescriptionsMajor = $descriptionMajor; Keywords = $keywords; SecondaryCreator = $secondaryCreator}
        $rest.Add($object1)
    }
    $title = $rest.title
    $title2 = $title + '.jpg'
    [string]$keywords = $rest.keywords
    $links = ($callNASA | select -ExpandProperty collection).links
    $prompt = $links.prompt
    $rel = $links.rel
    [string]$link = $links.href
    [int]$pageNumber = $link.split('=')[1] -replace ("&q","")
    $items += ($callNASA | select -ExpandProperty collection | select -expand items | select -expand links).href

    if ($i -lt $pageNumber){
        $url = $link
        $callNASA = irm -Uri $url -UseBasicParsing -Method get -ContentType "application/json"
        foreach ($thing in $callNASA.collection.items.data){
            $title = $thing.title
            $dateCreated = $thing.date_created
            $descriptionMinor = $thing.description_508
            $descriptionMajor = $thing.description
            $nasaId = $thing.nasa_id
            [string]$keywords = $thing.keywords
            $secondaryCreator = $thing.secondary_creator

            $object1 = [pscustomobject]@{Title = $title; DateCreated = $dateCreated; Description_Minor = $descriptionMinor; NasaId = $nasaId; DescriptionsMajor = $descriptionMajor; Keywords = $keywords; SecondaryCreator = $secondaryCreator}
            $rest.Add($object1)
        }
        $rest = $callNASA.collection.items.data
        $links = ($callNASA | select -ExpandProperty collection).links
        $prompt = $links.prompt
        $rel = $links.rel
        [string]$link = $links.href; Write-Host $link
        $pageNumber = $link.split('=')[1] -replace ("&q","")
        $items += ($callNASA | select -ExpandProperty collection | select -expand items | select -expand links).href
        $i++
    }
}

Function ET-PhoneHome($ETphoneHome){
    cls
    $mainUrl = "https://images-api.nasa.gov"

    # /search
    # /asset/{nasa_id}
    # /metadata/{nasa_id}
    # /captions/{nasa_id}
    # /album/{album_name}

    $search4What = Read-Host "What are we searching for?" 
    [string]$string = $search4What -replace (" ",'%20') 
    [string]$q = '?q=' + $string
    [string]$img = '&media_type=image' 
    $url = $mainUrl + '/search' + $q + $img
    $searchPath = "$outpath\$search4What"

    New-Item -Path $searchPath -ItemType Directory -ErrorAction Continue

    . Page-Numbers
    $items = $items | sort -Unique
    $legend = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]
    foreach ($item in $items){
        Write-Host $item
        $1 = $item -replace ('https://images-assets.nasa.gov/image/',"")
        $ID = $1.split('/')[1] -replace ('~thumb.jpg','')
        $thisPic = $rest | ? {$_.nasaid -like "*$ID*"}
        if ($thisPic -eq $null){
            $name = $ID
            $title1 = $name + ".jpg"
            $dc = $null
            $dmi = $null
            $dma = $null
            $naid = $ID
            $kw = $null
            $sc =$null
            $location = "$searchPath\$title1"
        } else {
            $name = $thisPic.Title
            $name = $name -replace (':',"-") # $name = $name -replace ('',"")
            $name = $name -replace ('?',"_")
            $name = $name -replace ('/',"_")
            $name = $name -replace ('\',"_")
            $title1 = $name + ".jpg"
            $dc = $thisPic.DateCreated
            $dmi = $thisPic.Description_Minor
            $dma = $thisPic.DescriptionsMajor
            $naid = $thisPic.NasaId
            $kw = $thisPic.Keywords
            $sc =$thisPic.SecondaryCreator
            $location = "$searchPath\$title1"
        }

        $web = iwr -Uri $item -OutFile $location -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 444 
            
        $object = [pscustomobject]@{Location = $location; Title = $name; DateCreated = $dc; Description_Minor = $dmi; NasaId = $naid; Description_Major = $dma; Keywords = $kw; SecondaryCreator = $sc}
        $legend.Add($object)
    }
    $legend | select NasaId, Title, Location, Description_Minor, DateCreated, Keywords, Description_Major, SecondaryCreator | Export-Csv -Path "$searchPath\$search4What Items Data Legend.csv" -NoTypeInformation
}
. ET-PhoneHome

