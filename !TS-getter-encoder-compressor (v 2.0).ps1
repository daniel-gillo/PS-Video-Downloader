<#  Daniel's M3U8 TS Getter and MP4 Encoder with an added x265 Compressor (TM)
    Version 1.F -> Added CSV batch input! (beta) & ffmpeg file-list bugfix
    Version 1.E -> Merged increment and m3u8 code, added error codes, legal filenames
    Version 1.D -> Reformatted code, got m3u8 code working, bug fixes
    Version 1.C -> Finally added M3U8 parsing! (beta) Branched off from v 1.B
    Version 1.B -> Beta of 2 incrementers in url (fuck that)
    Version 1.A -> Various minor fixes and improvements (folders, UI)
    Version 1.9 -> Added subfolder for .ts files, UI improvements, fixed unicode bug
    Version 1.8 -> Added ringtone, removed dashes from output file
    Version 1.7 -> Added custom & default directory. Now checks if ffmpeg is installed.
    Version 1.6 -> Added removal of tiny filler files (lazy implementation)
    Version 1.5 -> Switched to .Net webclient & improved progress indicator
    Version 1.4 -> Added custom zero padding, complete settings, debug mode
    Version 1.3 -> Added inputs for URL and settings, auto mode
    Version 1.2 -> Added progress indicator and better queries.
    Version 1.1 -> Added wget exception handling and some colors
    Version 1.0 -> Requires manual adjusting of variables and scrapping through M3U8 files
#>

$VERSION = "1.F"
$global:old_title = “Daniel's Incredible TS Getter-Encoder & Compressor!”
$global:old_fg = "DarkCyan"
$global:old_bg = "Black"

<# Tries to find ffmpeg.exe If it can't prints an error and exits.
  Checks a custom command provided, this folder and $PATH.
  If it fails, provides instructions on where to download ffmpeg.exe.
#>
function Import-ffmpeg () {
  ##### CHANGE THIS VARIABLE TO WHERE ffmpeg.exe IS AT ######
  ##### Use $(Get-Location) for a path relative to me! ######
  $FFMPEG = "$(Get-Location)\ffmpeg.exe"
  ###########################################################

  <# Check for FFmpeg and display error message if missing #>
  if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {$FFMPEG = 'ffmpeg'}
  elseif(Get-Command .\ffmpeg.exe -ErrorAction SilentlyContinue) {
    $FFMPEG = "$(Get-Location)\ffmpeg.exe"
  }
  elseif(Get-Command $FFMPEG -ErrorAction SilentlyContinue) {}
  else {
    Write-Host -ForegroundColor Red "`nI can't find ffmpeg!" ` 
      "Without it I cannot combine the .ts files!`n"
    Write-Host "You can download ffmpeg.exe for Windows from here:"
    Write-Host -ForegroundColor Yellow "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    Write-Host "`nExtract .\bin\ffmpeg.exe from the zip and place it in either:`n`ta) Your system's" `
    '$PATH environment scope' "`n`tb) The same folder as I am in.`n`nYou can also" 'set my $FFMPEG' `
    "location variable, on line 31, to where ffmpeg.exe is.`n`nI don't require any files except" `
    "ffmpeg.exe. If you wish to, you can read the documentation of this ffmpeg build at" `
    "`nhttps://www.gyan.dev/ffmpeg/builds/`n`nAlternatively you can delete lines 29 thru 54 of this" `
    "script to remove this warning and then run me in debug mode.`n"
    Write-Host -ForegroundColor Green "Good luck & Good bye :)"
    Read-Host ">"
    exit 2  # System Error Code (0x2) = ERROR_FILE_NOT_FOUND
  }
  return $FFMPEG
}


<# Swaps out title and colors with the previous one.
  The previous title, and colors are stored in global variables (sigh)
  $old_title, old_fg, old_bg
#>
function Switch-UI-Theme (){
    # Switch Window Title
    $temp = $host.UI.RawUI.WindowTitle
    $host.UI.RawUI.WindowTitle = $old_title
    $global:old_title = $temp

    # Switch Text Color
    $temp = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = "DarkCyan"
    $global:old_fg = $temp

    # Switch Text Background Color
    $temp = $host.UI.RawUI.BackgroundColor
    $host.UI.RawUI.BackgroundColor = "Black"
    $global:old_bg = $temp
}


<# Prints a pretty header announcing the script!
  Note: $w is the character window width. 
    It's Null if you run the script in PowerShell ISE.
#>
function Write-Header () {
  Clear-Host
  $w = [math]::Max(([int](Get-Host).UI.RawUI.MaxWindowSize.Width) - 2, 61)
  Write-Host "" $($($(". " * ($w/2)),"`n",$(" ." * ($w/2)),"`n") * 3)
  Write-Host $("*" * $w)
  Write-Host "+$(" " * $(($w-53)/2))Daniel's Incredible TS Getter-Encoder & Compressor!" `
        "$(" " * $(($w-53)/2))+"
  Write-Host "+$(" " * $(($w-13)/2))Version $VERSION!$(" " * $(($w-13)/2))+"
  Write-Host $("*" * $w)
}


<# Ask for File Name!
  Blank input = video
#>
function Initialize-FileName ($filename) {
  if (!$filename) {
    Write-Host -NoNewline "  Name of the output file "
    Write-Host -ForegroundColor Gray "(Default = video)"
    $filename = Read-Host "DS $(Get-Location)>"
  }
  <# This here below replaces all illegal characters with "-"
    Thanks to: Daniel Streefkerk @ https:// wp.me/p6DOzg-aP #>
  [System.IO.Path]::GetInvalidFileNameChars() | foreach {
    $filename = $filename.replace($_,'-')
  }
  if ($filename.Length -eq 0) {
    $filename = "video"
  }
  return $filename
}


<# Ask for if we're combining the base url with the M3U8 links in the file!
  ONLY FOR M3U8 MODE
  Blank input = True
#>
function Initialize-Relative-M3U8 () {
  Write-Host "  Are the links in the m3u8 file relative to it? (Y/n)"
  $relative_m3u8 = Read-Host "DS $(Get-Location)>"
  if ($relative_m3u8 -eq 'n' -or $relative_m3u8 -eq 'N') {
    $relative_m3u8 = $false
  }
  else {
    $relative_m3u8 = $true
  }
  return $relative_m3u8
}


<# Number padding, ask the user and return the value
  ONLY FOR INCREMENT MODE
  If problems arise we'll default to 0.
#>
function Initialize-NumberPadding () {
    Write-Host "  How much shall we zero-pad the numbers? " -NoNewline
    Write-Host -ForegroundColor Gray "(Default = 0)"
    $pad = Read-Host "DS $(Get-Location)>"
    try {
      if ($pad.lenth -eq 0) {
        $pad = 0
      }
      else {
        $pad = [int]$pad
      }
    }
    catch [System.InvalidCastException]{
      Write-Warning "The input '$pad' couldn't be converted to an integer." `
        "`n  Will default to 0."
      $pad = 0
    }
    return $pad
}


<# Ask for auto mode!
  ONLY FOR INCREMENT MODE
  Blank input = True
#>
function Initialize-Auto () {
    $auto = Read-Host "  Run in full-auto mode? (Y/n)`nDS $(Get-Location)>"
    if ($auto -eq 'n' -or $auto -eq 'N') {
      $auto = $false
    }
    else {
      $auto = $true
    }
    return $auto
}


<# Move Current Directory
  Ask user where they would like to go.
  Then check if the folder they specified was relative to ./, ~, or /
  If none is entered correctly, default to ~/Downloads
#>
function Move-CurrentDir () {
  Write-Host "  Change the download directory?" ` 
    "  Will check path relative to script, to home, and absolute path."
  Write-Host -ForegroundColor Gray "  (Empty input = stay in current directory." ` 
    "`tError Defaults to = $(Resolve-Path ~\Downloads)"
  $path = Read-Host "DS $(Get-Location)>"
  $works = $false
  <# Check if we're meant to go to home or origin #>
  if ($path.Length -eq 1){
    foreach ($d in (".","~","\","/")) {
      if ($path -eq $d){
          $works = $true
            Write-Host -ForegroundColor Gray "  Set location to $(Resolve-Path $d)"
            Set-Location $d
            break
        }
      }
    }
  else {
    <# Iterate though current, home, and system root directory #>
    foreach ($d in (".\","~\","\")) {
      Set-Location $d$path 2>&1 > $null # Is this "2>&1 > $null" too aggressive?
      # $? tells us if the previous command was successful
      if ($?) {
        $works = $true
        Write-Host -ForegroundColor Gray "  Set location to $(Get-Location)"
        break
      }
      else {
        Write-Host -ForegroundColor Gray "  Could not find $(Resolve-Path $d)\$path"
      }
    }
  }
  if ($works -eq $false) {
    Write-Warning "Will default to $(Resolve-Path ~\Downloads)"
    Set-Location ~\Downloads
  }
}

<# Ask for Compression Mode!
  Blank input = False
#>
function Initialize-Compress () {
  $compress = $false
  Write-Host "  After the download, do you wish to compress your video to HEVC x265? (y/N)"
  $query = Read-Host "  This may take quite a while...`nDS $(Get-Location)>"
  if ($query -eq 'y' -or $query -eq 'Y') {
    $compress = $true
  }
  return $compress
}


<# Ask for Debug Mode!
  Blank input = False
#>
function Initialize-Debug () {
  $debug = $false
  $query = Read-Host "  Run in debug mode? (y/N)`n  No files are deleted`nDS $(Get-Location)>"
  if ($query -eq 'y' -or $query -eq 'Y') {
    $debug = $true
  }
  return $debug
}


<# Gets all the TS files in the M3U8 file.
  Generates each of the links for each file.
  Will handle errors, up to point befor askign for user help.
  Prints a status message that updates with every file downloaded.
  Also prints an estimated time (based on the number of files)
  Parameters:
    $failure = The number of concurrent failures allowed
    $url_base = url to folder of .m3u8 file
    $m3u8 = the contents of the .m3u8 file
    $relative_m3u8 = boolean, if the links in the m3u8 need to be combined.
    $m3u8_length = the total amount of links in the .m3u8 file
#>
function Get-TS-M3U8 ($failure, $url_base, $m3u8, $relative_m3u8, $m3u8_length) {
  if (!$failure -or !$url_base -or !$m3u8 -or !$m3u8_length) {
    Write-Host -ForegroundColor Red "Get-TS-M3U8 (0xA0)"
    exit 160  # System Error Code (0xA0) = ERROR_BAD_ARGUMENTS
  }
  $bytes_got = 0  # Cumulative bytes of all files downloaded
  $i = 0  # Number of files downloaded
  $webClient = New-Object System.Net.WebClient  # Instantiate .Net Web-Client
  $webClient.Headers.Add("user-agent", "Mozilla/5.0 (Windows NT 10.0; " + 
        "Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " + 
        "Chrome/100.0.4896.75 Safari/537.36")
  $timeout = @(0, 10, 5, 2)  # Seconds to wait in error given No. errors left
  $start_time = Get-Date
  <# Loop-di-loop #>
  :wget foreach($url_back in $m3u8) {
    <# Check if the line in the m3u8 file is a comment. They start with "#". #>
    if (!($url_back) -or $url_back.Substring(0,1) -eq "#"){
      continue
    }
    <# Increment file counter $i & padded string version $s #>
    $i = $i + 1
    $s = "{0:$("0"*8)}" -f $i
    <# Make the link! #>
    if ($relative_m3u8){
      <# $url_base doesn't end with "/", so we need to insert it if necessary. #>
      if ($url_back.Substring(0,1) -ne "/"){
         $url_back = "/"+$url_back
      }
      $link = "$url_base$url_back"
    }
    else {
      if ($url_back[0] -eq "/") {
        $link = ($url_base -split "/", 4)[0..2] -join "/"
        $link = $link + $url_back
      }
      else{
        $link = $url_back
      }
    }
    <# Get the file! #>
    :single while($true){
      try {
        if ($debug) {Write-Host -ForegroundColor Yellow $link}
        # The most important line of code in the entire script!
        $webClient.Downloadfile($link,"$(Get-Location)\$($host.InstanceId)\$($host.InstanceId)-$s.ts")
        # The try block only checks for a WebException, if we made it this far we're good.
        # Check and reset $failure, in case we had a problem downloading the last file.
        if ($failure -ne 3){
          Write-Host -ForegroundColor Green "  Got the file! Resuming download..."
          $failure = 3
        }
        $bytes_this = $([int64]$webClient.ResponseHeaders["Content-Length"])
        $bytes_got = $bytes_got + $bytes_this
        break single
      }
      <# Couldn't get the file!#>
      catch [System.Net.WebException]{
        <# Fancy printing #>
        if ($failure -eq 3) {
          $shortlink = Compress-String $link
          Write-Warning "An exception was caught: $($_.Exception.Message)`n  Query for '$shortlink' failed."
          $failure = $failure - 1
          [Threading.Thread]::Sleep($timeout[$failure] * 1000)
        }
        elseif ($failure -gt 0) {
          Write-Warning "Will try again in $($timeout[$failure]) seconds.`n`t$failure attempts remaining..."
          [Threading.Thread]::Sleep($timeout[$failure] * 1000)
          $failure = $failure - 1
        }
        else {
          <# Download stalled! Notify user with beep. Notes: G6, F6 #>
          [console]::beep(1568,175); [Threading.Thread]::Sleep(50); [console]::beep(1397,150)
          Write-Host -NoNewline "  I can't reach "
          Write-Host -ForegroundColor Yellow $shortlink
          Write-Host "Your available options are to:`n  (0): Try downloading this file " `
            "again (default)`n  (1): Skip this file & continue with the next one`n  (2): " `
            "Stop the download & merge the files we have`n  (3): Exit without deleting anything"
          $query = Read-Host "DS $(Get-Location)>"
          switch ($query) {
            0 {}
            1 { break single }
            2 { break wget }
            3 { exit 1 }  # System Error Code (0x1) = ERROR_INVALID_FUNCTION
            "*" {}
          }
        }
      }
    }
    <# Progress indicator!#>
    $avg_speed = "{0:0.00}" -f (($bytes_got / 131072) / (($(Get-Date) - $start_time).TotalSeconds))
    $est_time = [timespan]::fromseconds(($(Get-Date) - $start_time).TotalSeconds * `
        [math]::Max(0, $m3u8_length - $i) / $i)
    $est_time = "$([math]::Floor($est_time.TotalMinutes)):$(("{0:00}" -f `
        ($est_time.Seconds - ($est_time.Seconds % 5))))"
    $status_message = "Getting: $filename-$i.ts    Downloaded: $('{0:0.00}' -f `
        ($bytes_got/1048576))MB    Avg. Speed: $avg_speed MBit/s    ~Time Left: $est_time"
    Write-Progress -Activity "Downloading TS files." -Id 1 -Status $status_message `
        -PercentComplete ([math]::Min((100*$i)/$m3u8_length, 100))
  }
  return $status_message
}


<# Gets all the TS files by enumerating through them until it can't find any.
  Will handle errors, up to point befor askign for user help.
  Prints a status message that updates with every file downloaded.
  Parameters:
    $failure = The number of concurrent failures allowed
    $url_base = url up to the incrementer
    $url_base = url after the incrementer
    $pad = how many digits the incrementer should be padded by
#>
function Get-TS-Increment ($failure, $url_base, $url_back, $pad, $debug) {
  if (!$failure -or !$url_base -or !$url_back) {
    Write-Host -ForegroundColor Red "Get-TS-Increment (0xA0)"
    exit 160  # System Error Code (0xA0) = ERROR_BAD_ARGUMENTS
  }
  $bytes_got = 0  # Cumulative bytes of all files downloaded
  $start = 0  # The first number of the incrementer
  $i = $start - 1  # The incrementer!
  $mrc = $start  # "Most recently completed" file number
  $webClient = New-Object System.Net.WebClient  # Instantiate .Net Web-Client
  $start_time = Get-Date

  <# Loop-di-loop #>
  :wget while ($failure -gt 0) {
    <# Increment file counter $i & padded string version $s #>
    $i = $i + 1
    $s = "{0:$("0"*8)}" -f $i
    <# Make the link! #>
    $link = $url_base + $("{0:$("0"*$pad)}" -f $i) + $url_back
    <# Get the file!
      We're number padding here to 8 make sure that if padding is too low the
      files are mered in order!
    #>
    if ($debug){
      Write-Host -ForegroundColor Yellow "mrc = $mrc, i = $i, start = $start, bytes = $bytes_got"
    }
    try {
      # The most important line of code in the entire script!
      $webClient.Downloadfile($link,"$(Get-Location)\$($host.InstanceId)\$($host.InstanceId)-$s.ts")
      # The try block only checks for a WebException, if we made it this far we're good.
      $bytes_this = $([int64]$webClient.ResponseHeaders["Content-Length"])
      # If there's a filler file under 1KB, delete it & don't record it in $bytes_got.
      if ($bytes_this -lt 1024) {
        Remove-Item "$(Get-Location)\$($host.InstanceId)\$($host.InstanceId)-$s.ts"
      }
      else {
        $bytes_got = $bytes_got + $bytes_this
      }
      <# If a file was skipped return to the skipped file, or record $ith file as $mrc.
         I've forgotten how this should work; its not acting as intended. #>
      if ($i - $mrc -gt 1) {
        $i = $mrc - 1
        $failure = 3
      }
      else {
        $mrc = $i
      }
    }

    <# Couldn't get the file!#>
    catch [System.Net.WebException]{
      <# Fancy printing #>
      $shortlink = Compress-String $link
      Write-Warning "An exception was caught: $($_.Exception.Message)`n  Query for '$shortlink' failed."
      if ($auto) {
        # First attempt, increment if the counting starts a 1 instead of 0 
        if ($bytes_got -eq 0){
          $i = $i + 1
        }
        $failure = $failure - 1
        Write-Host -ForegroundColor Magenta "  Only $failure concurrent failures remaining..."
      }
      else {
        <# Download stalled! Notify user with beep. Notes: G6, F6 #>
        [console]::beep(1568,175); [Threading.Thread]::Sleep(50); [console]::beep(1397,150)
        Write-Host -NoNewline "  I can't reach "
        Write-Host -ForegroundColor Yellow $shortlink;
        Write-Host "Your available options are to:`n  (0): Try downloading this file " `
          "again`n  (1): Skip this file & continue with the next one`n  (2): Stop the " `
          "download & merge the files we have (default)`n  (3): Exit without deleting anything"
        $query = Read-Host "DS $(Get-Location)>"
        switch ($query) {
          0 { $i = $i - 1 }
          1 {}
          2 { break wget }
          3 { exit 1 }  # System Error Code (0x1) = ERROR_INVALID_FUNCTION
          "*" { break wget }
        }
      }
    }
    <# Progress indicator!#>
    $avg_speed = "{0:0.00}" -f (($bytes_got / 131072) / (($(Get-Date) - $start_time).TotalSeconds))
    $status_message = "Getting $filename-$s.ts.    Downloaded $("{0:0.00}" -f ($bytes_got/1048576))" + `
          "MB so far    Average Speed: $avg_speed MBit/s"
    Write-Progress -Activity "Downloading TS files." -Id 1 -Status $status_message
  }
  return $status_message
}


<# Check if we downloaded anything!
  Counts the number of files downloaded.
  If none were downloaded:
    1) Delete the folder and any ancillary files.
    2) Terminate script
  Paramters:
    $filename = The name of the .mp4 file that is to be compressed.
#>
function Checkpoint-Download ($filename) {
  if (!$filename) {
    Write-Host -ForegroundColor Red "Checkpoint-Download (0xA0)"
    exit 160  # System Error Code (0xA0) = ERROR_BAD_ARGUMENTS
  }
  $no_files = (Get-ChildItem -Path ".\$($host.InstanceId)" | Where-Object { `
        $_.Extension -eq ".ts" -and -not $_.Name.StartsWith("$filename") } `
        | Group-Object Extension -NoElement | sort -desc).Count
  if ($no_files -eq 0) {
    Write-Host "No files were downloaded!"
    Remove-Item ".\$($host.InstanceId)" -Recurse
    Write-Host -ForegroundColor Green "Good Bye & Good Luck"
    Read-Host "DS $(Get-Location)>"
    exit 1241  # System Error Code (0x4D9) = ERROR_INCORRECT_ADDRESS
  }
}


<# Combine all the .ts files and export them into a single .mp4 file.
  Firstly it creates a .txt file containing a list of all .ts files, not
  including the combined file.
  Note: The .txt file must be in ASCII for FFMPEG reasons.
  Paramters:
    $FFMPEG = The location where ffmpeg.exe is, to run it.
    $filename = The name of the .mp4 file that is to be compressed.
#>
function Export-Mp4 ($FFMPEG, $filename) {
  if (!$FFMPEG -or !$filename) {
    Write-Host -ForegroundColor Red "Export-Mp4 (0xA0)"
    exit 160  # System Error Code (0xA0) = ERROR_BAD_ARGUMENTS
  }
  # Bugfix with new version of ffmpeg
  # Get-ChildItem -Path ".\$($host.InstanceId)" | Where-Object { $_.Extension -eq ".ts" -and -not `
         # $_.Name.StartsWith("$filename") } | ForEach-Object { "file '\$_'" } `
         # | Out-File -Encoding ASCII ".\$($host.InstanceId)\$filename-ts-list.txt"
   # Get-ChildItem -Path ".\$($host.InstanceId)" | Where-Object { $_.Extension -eq ".ts" -and -not `
         # $_.Name.StartsWith("$filename") } | ForEach-Object { "file './$($host.InstanceId)/$_'" } `
         # | Out-File -Encoding ASCII ".\$($host.InstanceId)\$filename-ts-list.txt"

  Write-Host -ForegroundColor Yellow (($(& $FFMPEG -version).Split("`n",3) | Select -Index 0,1) -join "`n")
  
  & $FFMPEG -y -hide_banner -loglevel warning -allowed_extensions ALL -protocol_whitelist concat,file,http,https,tcp,tls,crypto -i "$(Get-Location)\$($host.InstanceId)\video.m3u8" -acodec copy -vcodec copy "$filename.mp4"
  # & $FFMPEG -y -hide_banner -loglevel warning -allowed_extensions ALL -i "$(Get-Location)\$($host.InstanceId)\video.m3u8" -acodec copy -vcodec copy "$filename.mp4"
  # & $FFMPEG -hide_banner -loglevel warning -f concat -safe 0 -i ".\$($host.InstanceId)\$filename-ts-list.txt" -c copy "$filename.ts"
  # & $FFMPEG -y -hide_banner -loglevel warning -i "$filename.ts" -acodec copy -vcodec copy "$filename.mp4"

  # Check if ffmpeg succeeded
  if ($?) {
    Write-Host -ForegroundColor Green "FFmpeg finished merging all TS files to an MP4."
  } else {
    Write-Host -ForegroundColor Yellow "FFmpeg failed to create an MP4!"
  }
   
  return 0
}


<# Compress the .mp4 file by converting it to HEVC x265.
  This can take a LONG time; as long as the file is or even more!
  Paramters:
    $FFMPEG = The location where ffmpeg.exe is, to run it.
    $filename = The name of the .mp4 file that is to be compressed.
#>
function Compress-Mp4 ($FFMPEG, $filename) {
  if (!$FFMPEG -or !$filename) {
    Write-Host -ForegroundColor Red "Compress-Mp4 (0xA0)"
    exit 160  # System Error Code (0xA0) = ERROR_BAD_ARGUMENTS
  }
  Write-Host -ForegroundColor Green "  Beginning Compression!"
  Write-Host -ForegroundColor Yellow (($(& $FFMPEG -version).Split("`n",3) | Select -Index 0,1) -join "`n")
  & $FFMPEG -y -hide_banner -loglevel warning -i "$filename.mp4" -vcodec libx265 -crf 28 "$filename-small.mp4"

  if ($debug -eq $false) { Remove-Item "$filename.mp4" }
}


<# Measure the size of an M3U8 that's to be downloaded.
  It must be smaller than 1MB.
  IMPORTANT: This function won't catch a System.Net.WebException!
  Paramters:
    $link = The url of the file we're checking
  Returns:
    0 = Success, 1 = Failure
#>
function Measure-LinkSize ($link) {
  $out = 0
  try{
    $link_length = [int](Invoke-WebRequest $link -Method Head).Headers."Content-Length"
  }
  catch [System.Net.WebException]{
    Write-Host -ForegroundColor Yellow "Couldn't measure the link size! $($Error[0])"
    $link_length = 1
  }
  if ($link_length -gt 1048576){
    # The file is too big
    $out = 1
    $msg1 = "The m3u8 link specified leads to a file that's $("{0:0.00}" -f ($link_length / 1048576)) MB large."
    $msg2 = "Its too big to be a valid m3u8 file!`nFor reference: *Charles Dickens' Great Expectations* is exactly 1MB."
    Write-Host -ForegroundColor Red $msg1
    Write-Host -ForegroundColor Magenta $msg2
  }
  return $out
}


<# Shorten a string (usually a link)so it can be printed in one line for error messages.
  Paramters:
    $link = The url to be shortened
#>
function Compress-String ($str) {
  $len = 47  # Length of $short
  if ($str.Length -le $len){
    $short = $str
  }
  else {
    $short = $str.substring(0,25) + "..." + $str.substring($str.Length - $len)
  }
  return $short
}

<# Plays a funky tune when run.
  May add more and a input to pick one or run one at random.
#>
function Play-Ringtones (){
  <# Gotta make a move to a town that's right for me! #>
  foreach ($d in @(@(1047, 82),@(1047, 82),@(932, 82), @(1047, 328),
                   @(784, 328),@(784, 82), @(1047, 82),@(1397, 82),
                   @(1319, 82),@(1047, 0))) {
    [console]::beep($d[0],164)
    [Threading.Thread]::Sleep($d[1])
  }

}


function Single-Vid ($FFMPEG, $CSV, $url, $INCREMENT_MODE, $filename, $pad, $relative_m3u8, $auto, $compress, $debug){
  $failure = 3  # Permitted failed concurrent downloads
  $first = $true
  :url while ($true) {
    if (!$CSV) {
      if (!$first) {
        Write-Host -NoNewline "  Welcome! Please enter the url to an m3u8 file," `
            "or the url`n  you'd like to increment through with a space where the`n" `
            " incrmenter is. "
        $url = $(Read-Host "DS $(Get-Location)>").Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
        $first = $false
      }
      <# We need to guess now if the user wants to download and parse an .M3U8 file,
          or if they want to increment a base url (our two modes of operation).
          Since there's a very high likelihood that the user copy-and-pasted a
          new-line at the end of the string, Powershell will read that as the user
          pressing ENTER. This forces us to make a judgement call here.
          The conditions are: one string with no spaces that contains "m3u8". #>
        if ($url.Length -eq 1 -and $url[0].ToLower() -match "m3u8"){
          # Likely a valid .m3u8 file
          $INCREMENT_MODE = $false
          $url_m3u8 = $url[0]
          $url_base = $url_m3u8.subString(0, $url_m3u8.LastIndexOf("/"))
        }
        elseif ($url.Length -eq 1) {
          # Unknown; We need to ask the user
          $query = Read-Host "  Is this a valid url for an M3U8 file? (y/N)`nDS $(Get-Location)>"
          if ($query -eq 'y' -or $query -eq 'Y') {
            $INCREMENT_MODE = $false
            $url_m3u8 = $url[0]
            $url_base = $url_m3u8.subString(0, $url_m3u8.LastIndexOf("/"))
          }
          else {
            # Wrong url, try again.
            continue url
          }
        }
        else {
          # Likely a valid base url with space for an incrementer
          $INCREMENT_MODE = $true
        }
      }
      else {
        if ($debug) {
          Write-Host -ForegroundColor Green ("#"*30)
          Write-Host "INCREMENT_MODE = $INCREMENT_MODE`nauto = $auto`ncompress = $compress`ndebug = $debug`nrelative_m3u8 = $relative_m3u8`npad = $pad`nfilename = $filename`nurl = $url"
          Write-Host "Type(INCREMENT_MODE) = $($INCREMENT_MODE.GetType())"
        }
        if (!$INCREMENT_MODE) {
          $url_m3u8 = $url
          $url_base = $url_m3u8.subString(0, $url_m3u8.LastIndexOf("/"))
        }
      }
      <# We have our mode set, and are now going to parse the url as either:
        a link to a .M3U8 file, or a split link with an incrementing value. #>
      if ($INCREMENT_MODE){
        $url_base = $url[0]
        $url_back = $url[1]
        $url = $url_base + "42" + $url_back
        break url
      }
      # M3U8 Mode!
      else {
        <# Download the m3u8 file #>
        try {
          # Check to see if file too big to be an M3U8 file. For now its 1MB
          if (Measure-LinkSize $url_m3u8) { continue url }
          $m3u8 = [System.Text.Encoding]::ASCII.GetString($(Invoke-WebRequest -URI $url_m3u8 -Method Get).Content).Split("`n")
          <# if ((Get-Item $m3u8_file).length -le 100) {
            Write-Host -ForegroundColor Red -NoNewline "The m3u8 contailed less than" ` 
              " 100 bytes! Please enter it again."
            continue
          } #>
        }
        catch [System.Net.WebException]{
          Write-Host -ForegroundColor Red "The m3u8 link specified doesn't lead to file I can download! Please enter it again."
          Write-Host -ForegroundColor Red -NoNewline "URL = ' $url_m3u8'"
          Write-Host ?$, $Error[0]
          [Threading.Thread]::Sleep(500)
          $failure = $failure - 1
          if ($failure -eq 0) {
            break url
          }
          continue url
        }
        <# Display head ($i lines) of the M3U8 File #>
        $m3u8_length = 0
        $m3u8_file = ""
        foreach($line in $m3u8){
          if ($line.Length -and $line.Substring(0,1) -ne "#"){
            $m3u8_length = $m3u8_length + 1
            $m3u8_file = $m3u8_file + ".\$($host.InstanceId)-$("{0:$("0"*8)}" -f ($m3u8_length)).ts`n"
          }
          else{
            $m3u8_file = $m3u8_file + $line + "`n"
          }
        }
        $i = 8  # Number of lines to display
        Write-Host "  Here's the first $i out of $($m3u8.Length) lines of the .m3u8 file containing $m3u8_length links."
        foreach($line in 1..$i){
          Write-Host -NoNewline "$line  ".PadLeft(6)
          Write-Host -ForegroundColor Gray $(Compress-String $m3u8[$line - 1])
          if ($line -eq $m3u8_length){
            Write-Host -ForegroundColor Yellow "      End of File`n"
            break
          }
        }
        if (!$CSV) {
            Write-Host -NoNewline "   Is "
            Write-Host -NoNewline -ForegroundColor Gray $url[0]
            Write-Host " correct (Y/n) ?"
            if ($(Read-Host "DS $(Get-Location)>") -eq "n") {
              continue url
            }
         }
         $url = $url_m3u8
         break url

      }
    }
    if (!$CSV) {
      <# Ask user for input! #>
      $filename = Initialize-FileName
      Move-CurrentDir  # Change working directory directory
      if ($INCREMENT_MODE){
        $pad = Initialize-NumberPadding
        $auto = Initialize-Auto
      }
      else {
        $relative_m3u8 = Initialize-Relative-M3U8
      }
      $compress = Initialize-Compress
      $debug = Initialize-Debug
    }
    <# Print what the user wants us to get to make sure
      Finish editing this #>
    Write-Host -ForegroundColor Gray "You selected:`n  Url = $url`n" `
        " Filename . . . . = $filename"
    if ($INCREMENT_MODE){
      Write-Host -ForegroundColor Gray "" `
        " Mode . . . . . . = Increment Mode`n" `
        " Number Padding . = $pad`n" `
        " Auto-Mode  . . . = $auto"
    }
    else {
      Write-Host -ForegroundColor Gray "" `
        " Mode . . . . . . = M3U8 Mode`n" `
        " Relative M3U8  . = $relative_m3u8"
    }
    Write-Host -ForegroundColor Gray "" `
        " HEVC Compression = $compress`n" `
        " Debug-Mode . . . = $debug`n" `
        " TS files in  . . = '$(Get-Location)\$($host.InstanceId)'"

    <# Prepare for download, do the menial shit before #>
    $host.UI.RawUI.WindowTitle = “==> $filename | Dan's IMTG-E&C!”
    Write-Progress -Activity "Starting the download!.." -Id 1
    New-Item -Path ".\$($host.InstanceId)" -ItemType Directory 2>&1 > $null

    <# Download the .TS files!
      I hope we picked the right mode!
    #>
    if ($INCREMENT_MODE) {
      $status_message = Get-TS-Increment $failure $url_base $url_back $pad $debug
    }
    else{
      $status_message = Get-TS-M3U8 $failure $url_base $m3u8 $relative_m3u8 $m3u8_length
    }

    Checkpoint-Download $filename  # Check if we downloaded anything


    <# We finished all the downloads!
    Write final status bar #>
    foreach($line in ("", " Finished downloading TS files!", "    $status_message", "")){
      Write-Host -BackgroundColor DarkCyan -ForegroundColor Yellow $line.PadRight((Get-Host).UI.RawUI.MaxWindowSize.Width, " ")
    }

    # Write the m3u8 file!
    #Out-File -FilePath "$(Get-Location)\$($host.InstanceId)\video.m3u8" -InputObject $m3u8_file -Encoding utf8 -Force
    $file_encoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines("$(Get-Location)\$($host.InstanceId)\video.m3u8", $m3u8_file, $file_encoding)

    $out = Export-Mp4 $FFMPEG $filename  # Convert all .ts files to a single mp4
    if ($CSV -or ($debug -eq $false -and $out -eq 0)) {
      Remove-Item ".\$($host.InstanceId)" -Recurse
      if ($INCREMENT_MODE -eq $true) {
        Remove-Item "$filename.ts"
      }
    }
    if ($compress) {
      Compress-Mp4 $FFMPEG $filename  # If requested, HEVC compress the exported mp4
    }
    return $out

}



<# THE MAIN FUNCTION!!!
  This is an actual Cmdlet function and has all the additional paramters and
  values that come with it.

#>
function Get-TS
{
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    <# $arg_url_front = the entire .m3u8 url or the first half for an url that
      contains a incrmenter #>
    [Parameter(Mandatory=$false,
      ValueFromPipelineByPropertyName=$true,
      Position=0)]
    $arg_url_front,

    <# $arg_url_back = the second half of the incrementing url. The part after
      the incrmenter. If not provided script assumes a .m3u8 link. #>
    [String]
    $arg_url_back
  )

  Begin {
    Switch-UI-Theme
    Write-Header
  }

  Process {
    $CSV = $false
    $out = 0
    $CSV_FILE = ".\videos.csv"
    $FFMPEG = Import-ffmpeg  # Find ffmpeg.exe

    Write-Host -NoNewline "  Welcome! Please enter the url to an m3u8 file," `
        "or the url`n  you'd like to increment through with a space where the`n" `
        " incrmenter is. "
    $url = $(Read-Host "DS $(Get-Location)>").Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)

      <# CSV functionality
        Check if the user wants to read a CSV file #>
      if ($url.Length -eq 1 -and $url[0].ToLower() -match "csv") {
        $CSV = $true
        Import-CSV $CSV_FILE | Foreach-Object {
          $INCREMENT_MODE = [System.Convert]::ToBoolean($_.increment_mode)
          if ($INCREMENT_MODE) {
            # INCREMENT
            $pad = [int]$_.pad
          }
          else {
            # M3U8
            $relative_m3u8 = [System.Convert]::ToBoolean($_.relative_m3u8)
          }
          # BOTH
          $auto =     [System.Convert]::ToBoolean($_.auto)
          $compress = [System.Convert]::ToBoolean($_.compress)
          $debug =    [System.Convert]::ToBoolean($_.debug)
          $filename = Initialize-FileName $_.title
          $url = $_.url


          <# Make the Single-Video function call. So send all info there! #>
          $temp = Single-Vid $FFMPEG $CSV $url $INCREMENT_MODE $filename $pad $relative_m3u8 $auto $compress $debug
          $out = $out + $temp + 1
        }
      }
      else {
        $out = Single-Vid $FFMPEG $CSV $url
      }
      return $out
  }
  End {
    Write-Host -ForegroundColor Green "Have a nice day! <3"
    Play-Ringtones  # Play a jingle announcing the end of the script
    Switch-UI-Theme  # Switch theme back to previous default
  }
}

Get-TS
exit 0  # System Error Code (0x0) = ERROR_SUCCESS