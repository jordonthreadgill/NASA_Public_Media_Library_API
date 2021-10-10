# NASA Media Library Image Download Script
# NASA Media API document:  https://images.nasa.gov/docs/images.nasa.gov_api_docs.pdf
# 10/10/2021 - Jordon Threadgill

Function Page-Numbers($pageNumbers){
    $base = $env:USERPROFILE
    $date1 = Get-Date
    $date = $date1.ToString('MM-dd-yyyy')
    $desktop = "$base\Desktop"
    $outpath = "$desktop\NASA Media Library $date"
    New-Item -Path $outpath -ItemType Directory -ErrorAction SilentlyContinue | out-null

    $items = @()
    $linkHistory = @()
    $rest = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]
    $i = 0
    $callNASA = irm -Uri $url -UseBasicParsing -Method get -ContentType "application/json"; start-sleep -m 555
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
    [string]$keywords = $rest.keywords
    $links = ($callNASA | select -ExpandProperty collection).links | ? {$_.prompt -like "*next*"}
    $prompt = $links.prompt
    $rel = $links.rel
    $items1 = $callNASA | select -ExpandProperty collection | select -expand items
    foreach ($it in $items1){
        $json = $it.href
        write-host -f cyan $json
        [string]$jsonLinks = iwr -uri $json | select -expand content; start-sleep -m 555
        if ($error[0] -like "*403 ERROR*"){
            start-sleep -s 61
            [string]$jsonLinks = iwr -uri $json | select -expand content; start-sleep -m 555
        }
        $jsonLinks = $jsonLinks -replace ('\[',"")
        $jsonLinks = $jsonLinks -replace (']',"")

        foreach ($j in $jsonLinks.split(',')){
            if ($j -like "*orig.jpg*"){
                $jj = ($j -replace ('"',"")).trim()
                $items += $jj
            }
        }
    }
    $link = $links.href | select -last 1
    $linklast = $links.href | select -last 1
    $linkfirst =  $links.href | select -First 1
    $linkHistory += $url
    
    while (($linkHistory | ? {$_ -eq $link}) -eq $null){
        $callNASA = irm -Uri $link -UseBasicParsing -Method get -ContentType "application/json"; start-sleep -m 555
        foreach ($thing in $callNASA.collection.items.data){
            $title = $thing.title
            $dateCreated = $thing.date_created
            $descriptionMinor = $thing.description_508
            $descriptionMajor = $thing.description
            $nasaId = $thing.nasa_id
            [string]$keywords = $thing.keywords
            $secondaryCreator = $thing.secondary_creator

            $object1 = [pscustomobject]@{Title = $title; DateCreated = $dateCreated; Description_Minor = $descriptionMinor; NasaId = $nasaId; DescriptionsMajor = $descriptionMajor; Keywords = $keywords; SecondaryCreator = $secondaryCreator}
            $rest += $object1
        }
        $links = ($callNASA | select -ExpandProperty collection).links | ? {$_.prompt -like "*next*"}
        $prompt = $links.prompt
        $rel = $links.rel
        $link = $links.href | select -last 1
        $linklast = $links.href | select -last 1
        $linkfirst =  $links.href | select -First 1
        $linkHistory += $url; write-host $link
        $items1 = $callNASA | select -ExpandProperty collection | select -expand items
        foreach ($it in $items1){
            $json = $it.href
            [string]$jsonLinks = iwr -uri $json -ErrorAction SilentlyContinue | select -expand content; start-sleep -m 555
            if ($error[0] -like "*403 ERROR*"){
                start-sleep -s 61
                [string]$jsonLinks = iwr -uri $json -ErrorAction SilentlyContinue | select -expand content; start-sleep -m 555
            }
            $jsonLinks = $jsonLinks -replace ('\[',"")
            $jsonLinks = $jsonLinks -replace (']',"")

            foreach ($j in $jsonLinks.split(',')){
                if ($j -like "*orig.jpg*"){
                    $jj = ($j -replace ('"',"")).trim()
                    $items += $jj
                }
            }
        }
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
        $1 = $item -replace ("https://images-assets.nasa.gov/image/","")
        $1 = $item -replace ('http://images-assets.nasa.gov/image/',"")
        $ID = $1.split('/')[1] -replace ('~orig.jpg','')
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
            if ($name -like '*:*'){
                $name = $name -replace (":",' -') 
            }
            if ($name -like '*?*'){
                $name = $name -replace ('\?','')
            }
           
            $title1 = $ID + ".jpg"        
            $dc = $thisPic.DateCreated
            $dmi = $thisPic.Description_Minor
            $dma = $thisPic.DescriptionsMajor
            $naid = $thisPic.NasaId
            $kw = $thisPic.Keywords
            $sc =$thisPic.SecondaryCreator
            $location = "$searchPath\$title1"
        }

        $web = iwr -Uri $item -OutFile $location -ErrorAction SilentlyContinue; start-sleep -m 555
        if ($error[0] -like "*403 ERROR*"){
            start-sleep -s 61
            $web = iwr -Uri $item -OutFile $location -ErrorAction SilentlyContinue; start-sleep -m 555
        }
            
        $object = [pscustomobject]@{Location = $location; Title = $name; DateCreated = $dc; Description_Minor = $dmi; NasaId = $naid; Description_Major = $dma; Keywords = $kw; SecondaryCreator = $sc}
        $legend.Add($object)
    }
    $legend | select NasaId, Title, Location, Description_Minor, DateCreated, Keywords, Description_Major, SecondaryCreator | Export-Csv -Path "$searchPath\$search4What Items Data Legend.csv" -NoTypeInformation
}

. ET-PhoneHome

