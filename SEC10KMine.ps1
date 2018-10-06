#
#   MINE 10K SEC FILINGS
#   CREATE MODELS
#
#  if the SEC website changes, the link number (see foreach loop for $10Klinkarray) may change
#  a 10K filing consolidated financial statement usually includes three years - the current and two preceding years. Might be able to pull three years with one call (what if amended?)   
#  Operating Expenses are different for each company - no way to catalog every category or label - will need to parse individually using regex  
#

$CompanyName = Read-Host "Enter the company name to search"
$CompanyName = $CompanyName.Replace(" ","+")
$Years = Read-Host "How many years of filings to return?"
$RootURL = "https://www.sec.gov"


#Option 2
#Search URL with Company Name inserted
$SECSearchURL = "https://www.sec.gov/cgi-bin/browse-edgar?company=$CompanyName&owner=exclude&action=getcompany"

#New web request to search URL
$r = Invoke-WebRequest $SECSearchURL -SessionVariable a

#Select first object that mentions CIK
$CIKmention = $r.Links | Where-Object {$_.href -like "*CIK*"} | Select-Object -First 1
#Covert the object to a string
$CIKstring = $CIKmention.href.ToString() 
#Extract the CIK - matching ten digit number regex - into a matching object
$CIKstring -match "[0-9]{10}"
#Store the CIK match in the CIK variable
$CIK = $matches[0]
#Search for the last $Years years of 10-K filing for the company CIK
$s = Invoke-WebRequest "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=$CIK&type=10-K&dateb=&owner=exclude&count=$Years" -SessionVariable b
#Isolate the 10-K document objects
$Documents = $s.Links | Where-Object {$_.InnerText -like "*Documents"}
#Isolate the 10-K document links themselves
$DocumentsLinks = $Documents.href
#Create an array to store the full URLs for each 10K
$10Klinkarray = @()
#Create the full 10K link for each of the yearly filings
foreach ($Link in $DocumentsLinks)
    {
        $10KURL = $RootURL + $Link
        $10Klinkarray += $10KURL
    }

foreach ($Link in $10Klinkarray)
    {
        $t = Invoke-WebRequest $Link -SessionVariable c
#Grab the actual link to the 10K       
        $10KLink = $t.Links.href[9] 
        $10KLink = $RootURL + $10KLink  
        $u = Invoke-WebRequest $10KLink -SessionVariable d
    }



# KEY METRICS!!!
# Revenue or Net Revenues - NR
# COGS or Cost of Net Revenues - CNR
# Gross Profit - GP (equal to NR - CNR)
# Various entries under Operating Expenses...
#
# Bad Debt - BD
# Operating Expenses - OX (Total of all various entries and debt)
# Operating Income - OI (equal to GP - OX)
# Interest Income - II
# Pretax Income - PI (equal to OI + II)
# Taxes - TX
# Net Income - NI (equal to PI - TX)
# Earnings Per Share - EPS (equal to NI / Shares)
# Gross Margin - GM (equal to GP / NR) 
# Revenue Growth Year over Year - RG (equal to NR1 / NR0 - 1  where # is current (first) and prior year)
# Operating Margin - OM (equal to OI / NR)
# 
# OVERALL METRICS
# Price
# Shares
# Market Cap
# Cash
# Debt
# Enterprise Value - EV (Debt - Investments and Cash)




