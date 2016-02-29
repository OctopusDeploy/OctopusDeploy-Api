$octopusUrl = "http://localhost";
$apiKey = "API-FVRFJTCHOGUWDE914KLTJQZXY4"
$packageFilePath = "C:\Temp\Acme.Web.4.0.0.nupkg";
$replaceExisting = $true;

$packageUrl = $octopusUrl + "/api/packages/raw?replace=" + $replaceExisting;

Write-Host Uploading $packageFilePath to $packageUrl;


$webRequest = [System.Net.HttpWebRequest]::Create($packageUrl);
$webRequest.Accept = "application/json";
$webRequest.ContentType = "application/json";
$webRequest.Method = "POST";
$webRequest.Headers["X-Octopus-ApiKey"] = $apiKey;


$packageFileStream = new-object IO.FileStream $packageFilePath,'Open','Read','Read'

    $boundary = "----------------------------" + [System.DateTime]::Now.Ticks.ToString("x");
    $boundarybytes = [System.Text.Encoding]::ASCII.GetBytes("`r`n--" + $boundary + "`r`n")
    $webRequest.ContentType = "multipart/form-data; boundary=" + $boundary;
    $webRequest.GetRequestStream().Write($boundarybytes, 0, $boundarybytes.Length);

    $header = "Content-Disposition: form-data; filename="""+ [System.IO.Path]::GetFileName($packageFilePath) +"""`r`nContent-Type: application/octet-stream`r`n`r`n";
    $headerbytes = [System.Text.Encoding]::ASCII.GetBytes($header);
    $webRequest.GetRequestStream().Write($headerbytes, 0, $headerbytes.Length);
    $packageFileStream.CopyTo($webRequest.GetRequestStream());
    $webRequest.GetRequestStream().Write($boundarybytes, 0, $boundarybytes.Length);
    $webRequest.GetRequestStream().Flush();
    $webRequest.GetRequestStream().Close();

    $packageFileStream.Close();
    $packageFileStream.Dispose();


$webResponse = $webRequest.GetResponse();
Write-Host $webResponse.StatusCode $webResponse.StatusDescription;  
$webResponse.Dispose();
