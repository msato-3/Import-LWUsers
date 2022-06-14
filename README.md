# Import-LWUsers


2022/04/01 に、LINE WORKS API 2.0 がリリースされました。  
今回は、LINE WORKS API 2.0 を利用して、CSV ファイルに記載したユーザー情報をもとに、LINE WORKS にユーザーを作成する PowerShell スクリプトを書いてみました。  

最低限のエラー処理しか実装していませんので、利用に際しては、必要に応じて追加で実装してください。

PowerShell 7.2 環境で動作を確認しています。

## 1. LINE WORKS の準備

### 1.1. アプリの作成
まずは、LINE WORKS API 2.0 の利用に必要となるアプリの作成を行います。
1. [Developer Console](https://developers.worksmobile.com/jp/?lang=ja) にアクセスし、右上の [Developer Console] をクリックします。
3. はじめてのアクセスの場合には、[LINE WORKS APIサービス利用規約] への同意を求められますので、確認のチェックボックスをチェックして [利用する] をクリックします。
4. [Console] - [API 2.0] へアクセスし、[アプリの新規追加] をクリックします。
5. 適当なアプリ名を入力し、[同意して利用する] をクリックします。
6. [OAuth Scope] - [管理] をクリックし、`user` にチェックを入れて [保存] します。
7. [アプリの説明] にも説明を記入し、最後に [保存] をクリックします。
8. [Service Account] - [発行] をクリックし、サービス アカウント発行の確認ダイアログ ボックスで [OK] をクリックします。
9. [Private Key] - [発行/再発行] をクリックして、Private Key ファイルをダウンロードします。ファイルは後ほど使用しますので、***安全な場所に***保存してください。
10. `Client Id` 、 `Client Secret` 、 `Service Account` をコピーして控えます。また、ページ左側に出ている `Domain ID` も控えます。これらの情報も後ほど使用します。
<img src="https://user-images.githubusercontent.com/105628953/169497265-127c7475-7725-43b9-b0fe-734ecb731b00.png" width="640">


### 1.2. External Key の指定
作成するユーザーに組織、利用権限タイプ、職級、役割を割り当てない場合には、この作業は必要ありません。利用権限タイプ、職級、組織名、役割を割り当てる場合には、以下を実施します。  
ブラウザでポップアップ ブロックが有効にされている場合には、無効化してから実施します。
> external Key は、LINE WORKS の各種のリソースに対して管理者が指定することができる一意の値です。LINE WORKS のリソースには、リソースの作成時にシステムで自動採番される resourceId という一意の値もありますが、いまのところ GUI から確認する術がないため、今回は、external Key を割り当てることにしました。  
> サンプルの csv では exernalKey を利用して指定していますが、resourceId で指定しても動作すると思います。

1. [Developer Console](https://developers.worksmobile.com/jp/?lang=ja) にアクセスし、右上の [Developer Console] をクリックします。
2. [組織連携] をクリックします。
3. [組織 External Key Mapping] で [External key がない場合] を選択して、[一覧のダウンロード] をクリックします。
4. ダウンロードしたファイルをエディタで開いて、`External Key` を指定し、保存します。
5. [アップロード] をクリックして、保存したファイルを選択します。
6. 内容を確認し、[保存] をクリックします。4. で値を入力しなかった場合には、この画面で値を入力することができます。
7. 利用権限タイプ、職級、役割についても、同様のステップで External Key を割り当てます。
<img src="https://user-images.githubusercontent.com/105628953/169497489-d0d25bdd-f650-47a2-96e8-07ba77e20fda.png" width= "480">
<img src="https://user-images.githubusercontent.com/105628953/169497669-4ff3377c-e871-4700-8434-e1d35feee721.png" width = "360">

## ２. PowerShell の準備

### 2.0. PowerShell のインストール
後ほど、powershell-jwt という外部モジュールをインストールしますが、このモジュールは、PowerShell 6.2 以降で動作します。  
PowerShell のアイコンが青い場合、Windows PowerShell 5.2 以下のため、対応していません。  
PowerShell のアイコンが黒い場合には PowerShell 6.0 以降なので、PowerShell を起動し、`$PSVersionTable` でバージョンを確認します。`PSVersion` が PowerShell のバージョンを表します。
```
PS C:\> $PSVersionTable

Name                           Value
----                           -----
PSVersion                      7.2.4
PSEdition                      Core
GitCommitId                    7.2.4
OS                             Microsoft Windows 10.0.22000
Platform                       Win32NT
PSCompatibleVersions           {1.0, 2.0, 3.0, 4.0…}
PSRemotingProtocolVersion      2.3
SerializationVersion           1.1.0.1
WSManStackVersion              3.0
```
対応する PowerShell がインストールされていない場合には、[Windows への PowerShell のインストール](https://docs.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-windows)を参考にインストールしてください。  
青い PowerShell と黒い PowerShell は同じマシンに共存することができますのでご注意ください。以降の作業は黒い PowerShell で実行します。
> Mac でも動作すると思います。Mac への PowerShell のインストールについては [macOS への PowerShell のインストール](https://docs.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-macos) を参照してください。  
> 他のプラットフォームでも動作するかもしれませんが、確認はしていません。

### 2.1. スクリプトのダウンロード
適当な場所にフォルダを作成します。[Import-LWUsers.ps1]、［ImportUsers.csv］ をダウンロードして、フォルダに保存します。
[1.1. アプリの作成] でダウンロードした Private Key ファイルも、同じフォルダに保存します。

### 2.2. スクリプトの変更
ダウンロードしたスクリプト[Import-LWUsers.ps1] をエディタで開いて、使用する環境に合わせて編集します。  
編集箇所は以下です。

#### LINE WORKS 環境情報. 
`$PrivKeyPath` には Private Key ファイルのファイル名を、`$ClientId`、`$ClientSecret`、`$SvcAccount`、`$domainId` には、Developer Console で取得した`Client Id`、`Client Secret`、`Service Account`、`Domain ID` を指定します。
```
$PrivKeyPath = '.\private_2022012345678.key'
$ClientId = 'gRqxxxxxxxxxxxx'
$ClientSecret = 'Tqexxxxxxxx'
$SvcAccount = 'xxxxx.serviceaccount@yourcompanygroupname'
$domainId = 12345678
```

RateLimit は、同じ API を 1 分間に呼び出すことができる制限値です。  
今回のスクリプトを単独で利用する場合には RateLimit に達することはないと思いますが、他にも LINE WORKS API 2.0 を利用するアプリケーションを利用している場合には、安全のために設定を引き下げることを検討してください。
```
$RateLimit = 240
```

#### 入出力ファイル. 
入力ファイルは、後ほど準備して同じフォルダに置きます。  
ファイル名は以下で変更できます。
```
$UsersCSV = '.\ImportUsers.csv'
```

今回のスクリプトでは、リクエスト送信内容ログ、成功したレスポンス、作成されたユーザーの email と userId のペア、エラーとなったレスポンスを、それぞれログとしてファイルに記録します。  
不要なログがある場合には、それぞれコメントアウト (行頭に `#` を入力) してください。
```
$requestLog = '.\Request.log'       # リクエスト送信内容のログ
$responseLog = '.\Response.log'      # 成功したレスポンスのログ
$usersLog = '.\CreatedUsers.csv'    # 作成されたユーザーの email と userId
$errorLog = '.\Error.log'         # エラーとなったレスポンスのログ
```

### 2.3. 必要モジュールのインストール
今回の PowerShell Scripto で必要となる [powershell-jwt](https://github.com/Nucleware/powershell-jwt)と、その関連モジュールをインストールします。  
1. PowerShell コンソールを、[管理者として実行] します。
2. 以下の Cmdlet を実行します。

`Install-Module powershell-jwt`

<img src="https://user-images.githubusercontent.com/105628953/169497841-8a1a77d3-81a8-4dc4-a893-cd5635be49d6.png" width="640">


### 2.4. ユーザー情報の準備
ダウンロードしたユーザー情報ファイルのサンプル ［ImportUsers.csv］ をもとに、作成するユーザーの情報を準備します。  
列名は、`orgUnitIds` を除き、LINE WORKS API 2.0 で利用するフィールド名に合わせてあります。  
Admin Console でのユーザーの一括追加で利用するファイルと、列の並び順はそろえてありますが、以下の点にご注意ください。  

1. `パスワード`を指定した場合には、パスワードを [管理者が作成]、指定しなかった場合には、パスワードを [ユーザーが作成] になります。  
2. `利用権限タイプ`、`職級`、`組織名`、`役職`は、[1.2. External Key の指定] で指定した External Key を使用して、`externalKey:externalKeyValue`の形式で指定します。
```
externalKey:shop_shibuya
```
2. `言語`は、`Japanese` ではなく `ja_JP` と指定します。
3. `携帯番号/国番号`と`携帯番号/番号`は、`携帯番号` にまとめました。
4. `入社日`は、`yyyyMMdd` 形式ではなく、`yyyy-MM-dd` 形式で指定します。

Admin Console のサンプルと、今回のスクリプトの入力ファイルの、列名の対応とサンプル値は以下のとおりです。
|Admin Console のサンプル | InputUsers.csv|サンプル値|
|-|-|-|
|姓|lastName|検証|
|名|firstName|太郎|
|ID|email|taro@yourcompany.com
|パスワード|password|PasswordString!|
|姓(フリガナ)|phoneticLastName|ケンショウ|
|名(フリガナ)|phoneticFirstName|タロウ|
|個人メール|privateEmail|taro@private.com|
|サブメール|aliasEmails|alias1@yourcompany.com;alias2@yourcompany.com|
|ニックネーム|nickName|検証くん|
|利用権限タイプ|employmentTypeId|externalKey:emptype_fulltime|
|職級|levelId|externalKey:level_general|
|組織名|orgUnitIds|externalKey:shop_shibuya;externalKey:shop_shinagawa|
|役職|positionId|externalKey:position_staff|
|電話番号|telephone|03-1234-5678|
|携帯番号/国番号|N/A|N/A|
|携帯番号/番号|cellPhone|090-1234-5678|
|言語|locale|ja_JP|
|担当業務|task|接客担当|
|勤務先|location|にこにこ商会渋谷支店|
|SNS|protocol|LINE|
|SNS_ID|messengerId|LineId|
|入社日|hiredDate|2022-02-02|

> `email` は必須です  
> `lastName` または `firstName` のどちらか一方は必須です  
> `password` または `privateEmail` のどちらか一方は必須です  
> `aliasEmails` と `orgUnitIds` には複数の値を指定できます。`;` で区切って入力します  
> `orgUnitIds` に複数の値を指定した場合、各組織に対し、同じ `positionId` が割り当てられます

## 3. スクリプトの実行
環境に合わせて編集した `Import-LWUsers.ps1`、ユーザー情報を記載した `ImportUsers.csv`、Deverloper Console からダウンロードした Prvate Key ファイルを同じフォルダに保存したこと確認します。  
PowerShell コンソールを開いたら、ファイルを保存したフォルダに移動し、`Import-LWUsers.ps1` を実行します。  
例として、ファイルを `C:¥ImportScript` に保存している場合は、以下になります。
```
cd C:¥ImportScript
.¥Import-LWUsers.ps1
```
