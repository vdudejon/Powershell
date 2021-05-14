## v 1.0 May 14 2021
## https://github.com/vdudejon/Powershell/blob/master/Get-DinoPass.psm1
## Using the api from https://dinopass.com, generates a complex but human readable password

function Get-DinoPass{
    $pass1 = (Invoke-WebRequest -Uri http://www.dinopass.com/password/simple).content
    $pass1 = (Get-Culture).TextInfo.ToTitleCase($pass1.ToLower())
    Start-Sleep -Milliseconds 200
    $pass2 = (Invoke-WebRequest -Uri http://www.dinopass.com/password/simple).content
    $pass2 = (Get-Culture).TextInfo.ToTitleCase($pass2.ToLower())
    $pass = "$pass1=$pass2"
    return $pass
}
