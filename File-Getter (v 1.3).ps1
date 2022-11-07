<#    Daniel's File getter (TM)
        Version 1.3 -> Fixed wrong-folder and async-cancel bugs
        Version 1.2 -> Added progress bar
        Version 1.1 -> Fresh colors, remider to write file extension.
        Version 1.0 -> Based on TS-Getter v 1.7
#>

$host.UI.RawUI.ForegroundColor = "Black"
$host.UI.RawUI.BackgroundColor = "DarkCyan"
Clear-Host
$w = (Get-Host).UI.RawUI.MaxWindowSize.Width / 2 - 1
try {
    Write-Host "" $($($(". " * $w),"`n",$(" ." * $w),"`n") * 3)
    $w = (Get-Host).UI.RawUI.MaxWindowSize.Width
    Write-Host $("*" * $w)
    Write-Host "+$(" " * $(($w-40)/2-1))Daniel's Incredibly Simple File-Getter!$(" " * $(($w-40)/2))+" -ForegroundColor Yellow
    Write-Host $("*" * $w)
} catch [ArgumentOutOfRangeException]{
    Write-Host "" $($($(". " * 30),"`n",$(" ." * 30),"`n") * 3)
    Write-Host $("*" * 61)
    Write-Host "+          Daniel's Incredibly Simple File-Getter!          +"
    Write-Host $("*" * 61)
}

<# Loop-di-loop (In case the download fails.) #>
$first = $true
:run while ($true) {
    $host.UI.RawUI.WindowTitle = “Daniel's Incredibly Simple File-Getter!”
    <# The base-URL to which our filename enumartion is added. #>
    :url while ($true) {
        $url = Read-Host "`n  The file-URL please:`nDS $(Get-Location)>"

        Write-Host -NoNewline "`n   Is "; Write-Host -NoNewline -ForegroundColor White $url; Write-Host " correct (Y/n) ?"
        if ($(Read-Host "DS $(Get-Location)>") -eq "n") {
            continue url
        }
        break url
    }

    if ($first) {
        <# Output filename #>
        Write-Host "`n  Name of the output file " -NoNewline; Write-Host -ForegroundColor White "(Default = video.mp4)"
        Write-Host "  Don't forget the file extension!"
        $filename = Read-Host "DS $(Get-Location)>"
        if ($filename.Length -eq 0) {
            $filename = "video.mp4"
        }
    }
    $first = $false

    <# Get the file! #>
    try {
        $host.UI.RawUI.WindowTitle = “--> $filename | D's ISFG!”
        Write-Host -BackgroundColor Green "`n  Downloading $filename...`n  Press 'q' to cancel"
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFileAsync($url,"$(Get-Location)\$filename")
        $prev_time = Get-Date
        $prev_size = 0
        break run
    }
    <# Couldn't get the file!#>
    catch [System.Net.WebException]{
        Write-Host -BackgroundColor Red "  An exception was caught: $($_.Exception.Message)`n  Query for '$url' failed!"
        Write-Host "  Let's try that again, ok?"
    }
}

<# Loop the progress bar #>
while ($webClient.IsBusy) {
    [Threading.Thread]::Sleep(1000)

    <# Get the new time & file size #>
    $curr_time = Get-Date;
    $curr_size = (Get-Item ".\\$filename").length

    <# Calculate Speed - Note: IO means this will be imprecise #>
    $speed = "{0:0.00}" -f ((($curr_size - $prev_size) / 131072) / (($curr_time - $prev_time).TotalSeconds));

    <# Progress indicator!#>
    $status_message = "Downloaded $("{0:0.00}" -f ($curr_size/1048576)) MB so far    Speed: $speed MBit/s"
    Write-Progress -Activity "Downloading: $filename" -Status $status_message

    <# Reset variables for next time #>
    $prev_size = $curr_size
    $prev_time = $curr_time

    <# Check i fuser intends to cancel... #>
    :key while ($Host.UI.RawUI.KeyAvailable) {
        $c = $Host.UI.RawUI.ReadKey().Character
        if ($c -eq "q") {
            $webClient.CancelAsync()
            $Host.UI.RawUI.FlushInputBuffer()
            # $host.UI.RawUI.CursorPosition.Y = 0;
            Write-Host -BackgroundColor Yellow "   Cancelling..."
            break key;
        }
    }
}

<# We're Done! And we failed! #>
if ($curr_size -le 1000) {
    Write-Host -BackgroundColor Red "`n  Only $curr_size bytes were Downloaded!`n  I'll delete '$filename'";
    if ($curr_size -ne 0) {
        Write-Host "The file contents are:"
        Get-Item -Path ".\\$filename"
    }
    Remove-Item ".\\$filename"
}
elseif (!(Test-Path variable:c)){
<# Success! #>
    Write-Host -BackgroundColor Green "  Finished the download";
} 
Write-Host -NoNewline "  Have a nice day :)`nDS $(Get-Location)>:"

<# Call me, beep me if you wanna reach me #>
foreach ($d in @(@(1568,150,60),@(1568,150,90),@(1864,90,30),@(1568,150,0))) {
    [console]::beep($d[0],$d[1])
    [Threading.Thread]::Sleep($d[2])
}

$timeout = 600
while (!$Host.UI.RawUI.KeyAvailable -and ($timeout -- -gt 0)) {
    [Threading.Thread]::Sleep(100)
}
exit
