## プライベート キー ファイルは Developer コンソールからダウンロードして、フォルダに配置します。
## その他のパラメータは Developer コンソールより値を取得して記載してください

$PrivKeyPath = '.\private_2022012345678.key'
$ClientId = 'gRqxxxxxxxxxxxx'
$ClientSecret = 'Tqexxxxxxxx'
$SvcAccount = 'xxxxx.serviceaccount@yourcompanygroupname'
$domainId = 12345678


## 入出力ファイル を指定します。
$UsersCSV = '.\ImportUsers.csv'

## 出力ログが不要な場合にはコメントアウトしてください。
$requestLog = '.\Request.log'       # リクエスト送信内容のログ
$responseLog = '.\Response.log'      # 成功したレスポンスのログ
$usersLog = '.\CreatedUsers.csv'    # 作成されたユーザーの email と userId
$errorLog = '.\Error.log'         # エラーとなったレスポンスのログ

###########################################


$global:Header = $null
$APIEndPoint = 'https://www.worksapis.com/v1.0/users'


function  Initialize-Header() {
    Import-Module powershell-jwt

    $rsaPrivateKey = Get-Content $PrivKeyPath -AsByteStream

    $iat = [int](Get-Date -UFormat %s)
    $exp = $iat + 3600

    $payload = @{
        sub = $SvcAccount
        iat = $iat
    }
    
    $jwt = New-JWT -Algorithm 'RS256' -SecretKey $rsaPrivateKey -PayloadClaims $payload -ExpiryTimestamp $exp -Issuer $ClientId
    
    $requestHeader = @{
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    $requestBody = @{
        assertion     = $jwt
        grant_type    = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = 'user'
    }

    $url = 'https://auth.worksmobile.com/oauth2/v2.0/token'
    $response = Invoke-RestMethod -Uri $url -Method POST -Headers $requestHeader -Body $requestBody

    $global:Header = @{
        Authorization  = "Bearer " + $response.access_token
        'Content-Type' = 'application/json'
        Accept         = 'application/json'
    }
}

function New-LWUser($LWUser) {
    if ([String]::IsNullOrEmpty($global:Header)) {
        Initialize-Header
    }
    else {
        Start-Sleep 1
    }

    $body = $LWUser | convertto-json -depth 10
    $requestBody = [System.Text.Encoding]::UTF8.GetBytes($body)

    if (![String]::IsNullOrEmpty($requestLog)) {
        $logmsg = (Get-Date  -Format G) + "`r`n処理番号 $i  : " + $CSVUser.email + "`r`n$body`r`n----------`r`n"
        Add-Content $requestLog $logmsg
    }

    $response = Invoke-WebRequest -Method POST -Uri $APIEndPoint -Headers $global:Header -Body $requestBody -SkipHttpErrorCheck

    if ($response.StatusCode -ge 400) {
        ## ユーザー作成失敗
        Write-host  "HttpStatsuCode : " $response.StatusCode "  : 処理番号 $i  : "  $CSVUser.email   -ForegroundColor Red
        if (![String]::IsNullOrEmpty($errorLog)) {
            $logmsg = (Get-Date  -Format G) + "  :  " + $Response.StatusCode + "  :  処理番号: $i  : " + $CSVUser.email + "  :  " + $Response.Content
            Add-Content $errorLog $logmsg
        }
    }
    else {
        ## ユーザー作成成功
        
        if (![String]::IsNullOrEmpty($usersLog)) {
            $user = $response.Content | ConvertFrom-Json
            $logmsg = "$i," + $user.email + "," + $User.userId
            Add-Content $usersLog $logmsg
        }

        if (![String]::IsNullOrEmpty($responseLog)) {
            $logmsg = (Get-Date  -Format G) + "`r`n処理番号 $i  : " + $CSVUser.email + "`r`n" + $Response.Content + "`r`n----------`r`n"
            Add-Content $responseLog $logmsg
        }
    }
}

$CSVUsers = Import-Csv -path $UsersCSV  -Delimiter "," -Encoding UTF8
Write-Host "読み込まれたユーザー数: " $CSVUsers.count
$i = 1
foreach ($CSVUser in $CSVUsers) {
    Write-Host ”$i 人目処理開始 : "$CSVUser.email

    $LWUser = @{
        domainId         = $domainId
        email            = $CSVUser.email.Trim()
        privateEmail     = $CSVUser.privateEmail.Trim()

        userName         = @{
            lastName          = $CSVUser.lastName.Trim()
            firstName         = $CSVUser.firstName.Trim()
            phoneticLastName  = $CSVUser.phoneticLastName.Trim()
            phoneticFirstName = $CSVUser.phoneticFirstName.Trim()
        }

        employmentTypeId = $CSVUser.employmentTypeId.Trim()
        nickName         = $CSVUser.nickName.Trim()
        telephone        = $CSVUser.telephone.Trim()
        cellPhone        = $CSVUser.cellPhone.Trim()
        locale           = $CSVUser.locale.Trim()
        task             = $CSVUser.task.Trim()
        location         = $CSVUser.location.Trim()
        hiredDate        = $CSVUser.hiredDate.Trim()
    }

    if (!([String]::IsNullOrEmpty($CSVUser.protocol))) {
        $Protocol = $CSVUser.protocol.Trim().ToUpper()
        if ($Protocol -in @('LINE', 'FACEBOOK', 'TWITTER')) {
            $LWUser.messenger = @{
                protocol    = $Protocol
                messengerId = $CSVUser.messengerId.Trim()
            }
        }
        else {
            $LWUser.messenger = @{
                protocol       = 'CUSTOM'
                customProtocol = $CSVUser.protocol.Trim()
                messengerId    = $CSVUser.messengerId.Trim()
            }
        }
    }

    if (!([String]::IsNullOrEmpty($CSVUser.aliasEmails))) {
        $LWUser.aliasEmails = $CSVUser.aliasEmails.split(';').Trim()
    }

    if (([String]::IsNullOrEmpty($CSVUser.password))) {
        $LWUser.passwordConfig = @{
            passwordCreationType = 'MEMBER'
        }
    }
    else {
        $LWUser.passwordConfig = @{
            passwordCreationType = 'ADMIN'
            password             = $CSVUser.password.Trim()
        }
    }

    $org = @{
        domainId = $domainId
        primary  = $true
        levelId  = $CSVUser.levelId.Trim()
    }
    if (!([String]::IsNullOrEmpty($CSVUser.orgUnitIds))) {
        $org.orgUnits = @()
        foreach ($orgUnitId in $CSVUser.orgUnitIds.split(";").trim()) {
            $org.orgUnits += @(@{
                    orgUnitId  = $orgUnitId
                    positionId = $CSVUser.positionId.Trim()
                })
        }
    }
    $LWuser.organizations = @($org)

    New-LWUser $LWUser
    $i++
}
$global:Header = $null
Write-Host "完了！" 
