#from https://github.com/datasets/s-and-p-500-companies/blob/master/data/constituents.csv
$Tickers = Import-CSV C:\Temp\constituents.csv -Header Symbol 

function ConvertFrom-HtmlTableRow {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $htmlTableRow
        ,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        $headers
        ,
        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [switch]$isHeader

    )
    process {
        $cols = $htmlTableRow | select -expandproperty td
        if($isHeader.IsPresent) {
            0..($cols.Count - 1) | %{$x=$cols[$_] | out-string; if(($x) -and ($x.Trim() -gt [string]::Empty)) {$x} else {("Column_{0:0000}" -f $_)}} #clean the headers to ensure each col has a name        
        } else {
            $colCount = ($cols | Measure-Object).Count - 1
            $result = new-object -TypeName PSObject
            0..$colCount | %{
                $colName = if($headers[$_]){$headers[$_]}else{("Column_{0:00000} -f $_")} #in case there are more columns than headers 
                $colValue = $cols[$_]
                $result | Add-Member NoteProperty $colName $colValue
            } 
            write-output $result
        }
    }
}

function ConvertFrom-HtmlTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $htmlTable
    )
    process {
        #only basic <table><tr><td>...</td></tr></table> structure supported
        #$htmlTable.childNodes | ?{ $_.tagName -eq 'tr' } | ConvertFrom-HtmlTableRow

        #remove tags except td or tr
        [xml]$cleanedHtml = ("<!DOCTYPE doctypeName [<!ENTITY nbsp '&#160;'>]><root>{0}</root>" -f ($htmlTable | select -ExpandProperty innerHTML | %{(($_ | out-string) -replace '(</?t[rdh])[^>]*(/?>)|(?:<[^>]*>)','$1$2') -replace '(</?)(?:th)([^>]*/?>)','$1td$2'})) 
        [string[]]$headers = $cleanedHtml.root.tr | select -first 1 | ConvertFrom-HtmlTableRow -isHeader
        if ($headers.Count -gt 0) {
            $cleanedHtml.root.tr | select -skip 1 | ConvertFrom-HtmlTableRow -Headers $headers | select $headers
        }
    }
}


foreach($Ticker in $Tickers)
{
    #Get Historical Pricing
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $HistoricalBaseURL = "https://www.investopedia.com/markets/api/partial/historical/?Symbol=$Ticker&Type=%20Historical+Prices&Timeframe=Daily&StartDate=Jan+01%2C+2009&EndDate=Feb+08%2C+2019"
    
    [System.Uri]$url = $HistoricalBaseURL
    $rqst = Invoke-WebRequest $url 
    $rqst.ParsedHtml.getElementsByTagName('table') | ConvertFrom-HtmlTable | Export-CSV C:\Temp\$Ticker.csv
    #Store historical pricing in CSV for each ticker
    $NoHeaders = Import-CSV -Header Date,Open,High,Low,AdjClose,Volume C:\Temp\$Ticker.csv 
    $NoHeaders | Export-CSV -NoTypeInformation C:\Temp\$Ticker.csv

    #Get historical earnings dates
    $BaseEarningsURL = "https://ycharts.com/companies/$Ticker/eps"
    [System.Uri]$url = $BaseEarningsURL
    $rqst = Invoke-WebRequest $url
	$EarningsDates = ($rqst.ParsedHtml.getElementsByTagName('td') | Where-Object { $_.ClassName -eq 'col1' }).innertext
	$EarningsDates = $EarningsDates | Select-Object -First 50
	
	#Find Friday of earnings date weeks
	$FridaysOfEarnings = @()
	$AllEarningsDates = @()
	foreach ($EarningsDate in $EarningsDates)
	{
		$AllEarningsDates += $EarningsDate
		[datetime]$EarningsDate = $EarningsDate 
		
		if ($EarningsDate.DayofWeek -Like "*Friday*")
		{
			$EarningsDate = $EarningsDate.ToString('MMMM dd, yyyy')
			$FridaysOfEarnings += $EarningsDate
		}
		elseif ($EarningsDate.DayOfWeek -notlike "*Friday*")
		{
			do
			{
				$EarningsDate = $EarningsDate.AddDays(1)
			}
			until ($EarningsDate.DayOfWeek -like "*Friday*")
			
			$EarningsDate = $EarningsDate.ToString('MMMM dd, yyyy')
			$FridaysOfEarnings += $EarningsDate
		}	
	}
	
	$PriceHistory = Import-CSV C:\Temp\$Ticker.csv -Header Date, Open, High, Low, AdjClose, Volume
	
	$EarningsFridayClosePrices = @()
	$EarningsDayClosePrices = @()
	
	foreach ($Friday in $FridaysOfEarnings)
	{		
		foreach ($Line in $PriceHistory)
		{
			$CloseDate = $Line.Date
			[datetime]$CloseDate = $CloseDate
			
			if ($CloseDate -eq $Friday)
			{
				$EarningsFridayClosePrice = $Line.AdjClose
				$EarningsFridayClosePrices += $EarningsFridayClosePrice
			}
			
			
#			foreach ($Date in $AllEarningsDates)
#			{
#				if ($CloseDate -eq $Date)
#				{
#					$EarningsDayClosePrice = $Line.AdjClose
#					$EarningsDayClosePrices += $EarningsDayClosePrice
#				}
#			}
		}
	}	
}



}

clear-host
