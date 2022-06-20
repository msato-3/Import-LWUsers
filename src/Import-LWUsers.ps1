## プライベート キー ファイルは Developer コンソールからダウンロードして、フォルダに配置します。
## その他のパラメータは Developer コンソールより値を取得して記載してください

$PrivKeyPath = '.\private_2022012345678.key'
$ClientId = 'gRqxxxxxxxxxxxx'
$ClientSecret = 'Tqexxxxxxxx'
$SvcAccount = 'xxxxx.serviceaccount@yourcompanygroupname'
$domainId = 12345678

$RateLimit = 240

## 入出力ファイル を指定します。
$UsersCSV = '.\ImportUsers.csv'

## 出力ログが不要な場合にはコメントアウトしてください。
$requestLog = '.\Request.log'       # リクエスト送信内容のログ
$responseLog = '.\Response.log'      # 成功したレスポンスのログ
$usersLog = '.\CreatedUsers.csv'    # 作成されたユーザーの email と userId
$errorLog = '.\Error.log'         # エラーとなったレスポンスのログ

###########################################

$sleep = [int] (0.9 * (60 * 1000) / $RateLimit )

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
        Start-Sleep  -Milliseconds $sleep
    }

    $body = $LWUser | convertto-json -depth 10
    $requestBody = [System.Text.Encoding]::UTF8.GetBytes($body)

    if (![String]::IsNullOrEmpty($requestLog)) {
        $logmsg = (Get-Date  -Format G) + "`r`n処理番号 $i  : " + $LWUser.email + "`r`n$body`r`n----------`r`n"
        Add-Content $requestLog $logmsg
    }

    $response = Invoke-WebRequest -Method POST -Uri $APIEndPoint -Headers $global:Header -Body $requestBody -SkipHttpErrorCheck

    if ($response.StatusCode -ge 400) {
        ## ユーザー作成失敗
        Write-host  "HttpStatsuCode : " $response.StatusCode "  : 処理番号 $i  : "  $LWUser.email   -ForegroundColor Red
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
            $logmsg = (Get-Date  -Format G) + "`r`n処理番号 $i  : " + $LWUser.email + "`r`n" + $Response.Content + "`r`n----------`r`n"
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
        privateEmail     = ([String]::IsNullOrEmpty( $CSVUser.privateEmail.Trim() ) ? $null : $CSVUser.privateEmail.Trim() )

        userName         = @{
            lastName          = ([String]::IsNullOrEmpty( $CSVUser.lastName.Trim() ) ? $null : $CSVUser.lastName.Trim() )
            firstName         = ([String]::IsNullOrEmpty( $CSVUser.firstName.Trim() ) ? $null : $CSVUser.firstName.Trim() )
            phoneticLastName  = ([String]::IsNullOrEmpty( $CSVUser.phoneticLastName.Trim( ) ) ? $null : $CSVUser.phoneticLastName.Trim() ) 
            phoneticFirstName = ([String]::IsNullOrEmpty( $CSVUser.phoneticFirstName.Trim() ) ? $null : $CSVUser.phoneticFirstName.Trim() )
        }

        employmentTypeId = ([String]::IsNullOrEmpty( $CSVUser.employmentTypeId.Trim() ) ? $null : $CSVUser.employmentTypeId.Trim() )
        nickName         = ([String]::IsNullOrEmpty( $CSVUser.nickName.Trim() ) ? $null : $CSVUser.nickName.Trim() )
        telephone        = ([String]::IsNullOrEmpty( $CSVUser.telephone.Trim() ) ? $null : $CSVUser.telephone.Trim() )
        cellPhone        = ([String]::IsNullOrEmpty( $CSVUser.cellPhone.Trim() ) ? $null : $CSVUser.cellPhone.Trim() )
        locale           = ([String]::IsNullOrEmpty( $CSVUser.locale.Trim() ) ? $null : $CSVUser.locale.Trim() )
        task             = ([String]::IsNullOrEmpty( $CSVUser.task.Trim() ) ? $null : $CSVUser.task.Trim() )
        location         = ([String]::IsNullOrEmpty( $CSVUser.location.Trim() ) ? $null : $CSVUser.location.Trim() )
        hiredDate        = ([String]::IsNullOrEmpty( $CSVUser.hiredDate.Trim() ) ? $null : $CSVUser.hiredDate.Trim() )
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
        levelId  = ([String]::IsNullOrEmpty($CSVUser.levelId.Trim()) ? $null : $CSVUser.levelId.Trim())
    }
    if (!([String]::IsNullOrEmpty($CSVUser.orgUnitIds))) {
        $org.orgUnits = @()
        foreach ($orgUnitId in $CSVUser.orgUnitIds.split(";").Trim()) {
            $org.orgUnits += @(@{
                    orgUnitId  = $orgUnitId
                    positionId = ([String]::IsNullOrEmpty($CSVUser.positionId.Trim()) ? $null : $CSVUser.positionId.Trim())
                })
        }
    }
    $LWuser.organizations = @($org)

    New-LWUser $LWUser
    $i++
    $LWUser = $NULL
    $org = $NULL
}
$global:Header = $null
Write-Host "完了！" 

