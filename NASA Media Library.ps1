# NASA Media Library API Images Download Script
# NASA Media API document:  https://images.nasa.gov/docs/images.nasa.gov_api_docs.pdf
# 10/10/2021 - Jordon Threadgill

Function Search-NASA($searchNASA){
    $base = $env:USERPROFILE
    $date1 = Get-Date
    $date = $date1.ToString('MM-dd-yyyy')
    $desktop = "$base\Desktop"
    $outpath = "$desktop\NASA Media Library $date"
    New-Item -Path $outpath -ItemType Directory -ErrorAction SilentlyContinue | out-null

    #FIRST PAGE QUERY
    $items = @()
    $linkHistory = @()
    $next = $null
    $rest = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]
    $ii = 1
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

    #QUERY ITEMS FROM PAGE 1
    $ii = 0
    $items1 = $callNASA | select -ExpandProperty collection | select -expand items
    foreach ($it in $items1){
        $json = $it.href
        write-host -f cyan "Page 1 - $json"
        [string]$jsonLinks = iwr -uri $json | select -expand content; start-sleep -m 555
        if ($error[0] -like "*403*"){
            start-sleep -s 61
            [string]$jsonLinks = iwr -uri $json | select -expand content; start-sleep -m 555
        }
        if ($error[0] -like "*Maximum number of search results have been displayed*"){
            $linkHistory += $url
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

    #CHECK FOR NEXT PAGE
    $links = ($callNASA | select -ExpandProperty collection).links | ? {$_.prompt -like "*next*"}
    if ($links){
        $next = $true
    }
    if (!($links)){
        $next = $false
    }
    $prompt = $links.prompt
    $rel = $links.rel
    $link = $links.href | select -last 1
    $linkHistory += $url
    
    #IF NEXT PAGE FOUND, QUERY THE ITEMS
    while ($next -eq $true){
        $ii++; write-host -f green "Page: $ii - $link"
        
        #CALL NEXT PAGE OF ITEMS
        $callNASA = irm -Uri $link -UseBasicParsing -Method get -ContentType "application/json"; start-sleep -m 555
        if ($callNasa){
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

            #SORT THE ADDITIONAL ITEMS FOUND
            $items1 = $callNASA | select -ExpandProperty collection | select -expand items
            foreach ($it in $items1){
                $json = $it.href
                write-host -f cyan "Page: $ii - $json"
                [string]$jsonLinks = iwr -uri $json -ErrorAction SilentlyContinue | select -expand content; start-sleep -m 555
                if ($error[0] -like "*403*"){
                    start-sleep -s 61
                    [string]$jsonLinks = iwr -uri $json -ErrorAction SilentlyContinue | select -expand content
                }
                if ($error[0] -like "*Maximum number of search results have been displayed*"){
                    $linkHistory += $url
                }
                $jsonLinks = $jsonLinks -replace ('\[',"")
                $jsonLinks = $jsonLinks -replace (']',"")

                foreach ($j in $jsonLinks.split(',')){
                    if ($j -like "*orig.jpg*"){
                        $jj = ($j -replace ('"',"")).trim()
                        $items += $jj
                    }
                }
            }; write-host -f yellow "Items Found:" $items.count
            $links = ($callNASA | select -ExpandProperty collection).links | ? {$_.prompt -like "*next*"}
            if ($links){
                $next = $true
                $prompt = $links.prompt
                $rel = $links.rel
                $link = $links.href | select -last 1
            }
            if (!($links)){
                $next = $false
            }
            $linkHistory += $link
        }
        if ($error[0] -like "*403*"){
            start-sleep -s 61
            $callNASA = irm -Uri $link -UseBasicParsing -Method get -ContentType "application/json"
        }
        if ($error[0] -like "*Maximum number of search results have been displayed*"){
            $linkHistory += $link
        }
    }
    $linkHistory.href | export-csv -notypeinformation -force -path "$searchpath\$search4what Links History.csv"
}

Function ET-PhoneHome($ETphoneHome){
    cls
    #SEARCH REFERENCES
    # /search
    # /asset/{nasa_id}
    # /metadata/{nasa_id}
    # /captions/{nasa_id}
    # /album/{album_name}

    #SEARCH QUESTION ASK + SOME BASIC INFO
    $mainUrl = "https://images-api.nasa.gov"
    $search4What = Read-Host "What are we searching for?" 
    [string]$string = $search4What -replace (" ",'%20') 
    [string]$q = '?q=' + $string
    [string]$img = '&media_type=image' 
    $url = $mainUrl + '/search' + $q + $img
    $searchPath = "$outpath\$search4What"
    New-Item -Path $searchPath -ItemType Directory -ErrorAction silentlyContinue | out-null

    #SEND THE QUERY TO ANOTHER FUNCTION TO INDEX THE QUERY RESULTS
    . Search-NASA

    #DOWNLOAD THE SEARCH RESULTS AS FILES
    $items = $items | sort -Unique
    $legend = New-Object -TypeName System.Collections.Generic.List[PSCustomObject]
    $i = 0
    foreach ($item in $items){
        $i++; write-host -f darkyellow "$i of" $items.count
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
        if ($error[0] -like "*403*"){
            start-sleep -s 61
            $web = iwr -Uri $item -OutFile $location -ErrorAction Continue
        }
            
        $object = [pscustomobject]@{Location = $location; Title = $name; DateCreated = $dc; Description_Minor = $dmi; NasaId = $naid; Description_Major = $dma; Keywords = $kw; SecondaryCreator = $sc}
        $legend.Add($object)
    }
    
    #EXPORT ITEM INFORMATION LEGEND
    #EXPORT LINK HISTORY IN CASE ANY SEARCH PAGES NEED TO BE REQUERIED
    $legend | select NasaId, Title, Location, Description_Minor, DateCreated, Keywords, Description_Major, SecondaryCreator | Export-Csv -Path "$searchPath\$search4What Items Data Legend.csv" -NoTypeInformation
}

#LETS GO!!!!
. ET-PhoneHome
