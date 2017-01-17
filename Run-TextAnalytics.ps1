<#
    
    .SYNOPSIS
    Run phrase and sentiment analytics on supplied text.
    
    .DESCRIPTION
    Script recieves a text string input and run it through Microsoft translator, converting the text to English.
    The translated text is the fed to MSFT Text analytics API to run a sentiment and key phrase analisys.

    The concept is to try and determinate if the author of the text is happy or not, and what the text is about.
    IE: Run any open support tickets through to try and prioritize each ticket. or use the key phrases to automatickly route the ticket to the correct department

    .EXAMPLE
    Run-TextAnalytics.ps1 -ID 1234 -Text "My computer crashes all the time and it is your fault. I think it's the processor"

    Name                           Value                                                                                                                                                          
    ----                           -----                                                                                                                                                          
    Translation                    My computer crashes all the time and it is your fault. I think it's the processor                                                                              
    Sentiment Score                3,57 %                                                                                                                                                         
    Key phrases                    time, computer crashes, fault, processor

    .EXAMPLE
    Run-TextAnalytics.ps1 -ID 1234 -Text "Yes, that worked. Do you want to marry me?"

    Name                           Value                                                                                                                                                          
    ----                           -----                                                                                                                                                          
    Translation                    Yes, that worked. Do you want to marry me?                                                                                                                     
    Sentiment Score                91,88 %                                                                                                                                                        
    Key phrases             

    
    .NOTES
    Created by Martin Ehrnst
    www.adatum.no

    Please add your Translation and text analytics account keys
    
    
    .CHANGELOG
    12.01.17: v0.5 Beta (Initial release)
    This version has zero error handling and must be considered POC

    .TODO
    Add error handeling
    Add support for multiple jobs with one output


#>


param (
    [Parameter(Mandatory=$True,Position=1,valueFromPipeLine=$true)]
    [string]$text,
    [Parameter(Mandatory=$True,Position=2,valueFromPipeLine=$true)]
    [INT]$ID
    )

Write-Host -ForegroundColor Cyan "This script have no error handling. Please consider it as a proof of concept"

$TextToTranslate = $text

#Replacing characters that are unsupported
$TextToTranslate = $TextToTranslate -replace "[«»""#]","'"

#region Configuration
$TransaccountKey = "****"
$AnalAccountKey = "****"
[string]$ToLanguage = "en"
#endregion

#region CreateToken
$tokenServiceURL = "https://api.cognitive.microsoft.com/sts/v1.0/issueToken"
$query = "?Subscription-Key=$TransaccountKey"
$TokenUri = $tokenServiceUrl+$query
$token = Invoke-RestMethod -Uri $TokenUri -Method Post

$auth = "Bearer "+$token
#endregion


#region RunTranslation
$translationURL = "http://api.microsofttranslator.com/v2/Http.svc/Translate"
$uri = $translationUrl


$RunTrans = Invoke-RestMethod -Method Get -Headers  @{'Authorization' = $Auth} -Uri ('http://api.microsofttranslator.com/v2/Http.svc/Translate?text={0}&to={1}' -f `
                        ($TextToTranslate, $ToLanguage | %{ [Web.HttpUtility]::UrlEncode($_) } ))

$translatedText = $runTrans.string.'#text'#The translated text
#replace characters that are unsupported
$translatedText = $translatedText -replace "[æå]","a"
$translatedText = $translatedText -replace "[ø]","o"
$translatedText = $translatedText -replace "[£$]",""

#endregion

#region RunTextAnalytics

$TextAnalyticsHeader = @{
    'Ocp-Apim-Subscription-Key' = $AnalAccountKey
    'Content-Type' = 'application/json'
    }

$TextAnalyticsBody = [ordered]@{
    "documents" = 
	@(
        @{
        "language" = "en"; 
        "id" = $id; 
        "text" = $translatedText }
    )
} | ConvertTo-Json


$RunSentiment = Invoke-RestMethod -Method post -Headers $TextAnalyticsHeader -uri 'https://westus.api.cognitive.microsoft.com/text/analytics/v2.0/sentiment' -Body $TextAnalyticsBody
$sentimentScore = $RunSentiment.documents.score
$sentimentScore = $sentimentScore.ToString("P") #setting percentage insted of value

$runPhrases = Invoke-RestMethod -Method post -Headers $TextAnalyticsHeader -uri 'https://westus.api.cognitive.microsoft.com/text/analytics/v2.0/keyPhrases' -Body $TextAnalyticsBody
$keyPhrases = $runPhrases.documents.keyPhrases -join ', ' #seperate each phrase with a comma

$TextAnalysis = @{
    'Sentiment Score' = $sentimentScore
    'Key phrases' = $keyPhrases
    'Translation' = $translatedText
} 

Write-Output "We have finished your text analysis. Here's the result"
$TextAnalysis #Print the result

#endregion
