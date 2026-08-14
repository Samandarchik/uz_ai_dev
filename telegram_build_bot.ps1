# =====================================================================
#  telegram_build_bot.ps1  (ko'p loyihali)
#  Bu mashinada doim ishlab turadigan Telegram bot (long polling).
#  Botga "build" deb yozsangiz -> loyihalar ro'yxati (tugmalar) chiqadi.
#  Tugmani bossangiz: git pull + build_windows.bat ishga tushadi va
#  progress (qabul qilindi -> build -> zip -> github -> tayyor) bitta
#  xabar ichida yangilanib boradi. Public IP KERAK EMAS.
#
#  VERSIYA TEKSHIRUVI: build'dan oldin bot git pull qiladi va
#  pubspec.yaml dagi versiyani oxirgi muvaffaqiyatli build versiyasi bilan
#  solishtiradi (.telegram_bot_state.json). Bir xil bo'lsa build BEKOR
#  qilinadi va eski release havolasi qaytariladi ("Baribir build qilish"
#  tugmasi bilan majburlash mumkin). Yangi build chiqsa - GitHub Releases
#  havolasi xabarga qo'shiladi.
#
#  Sozlash: yonidagi  .telegram_bot.config.txt :
#     1-qator: bot token
#     2-qator: ruxsat berilgan chat ID
#  Loyihalarni pastdagi $Projects ro'yxatiga qo'shing/olib tashlang.
# =====================================================================

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$Dir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$Desktop = Join-Path $env:USERPROFILE 'Desktop'

# --- Loyihalar: nom -> papka (build_windows.bat shu papkada bo'lishi kerak) ---
$Projects = [ordered]@{
    'uz_ai_dev'          = (Join-Path $Desktop 'uz_ai_dev')
    'workly_app'         = (Join-Path $Desktop 'workly_app')
    'qilinadigan_ishlar' = (Join-Path $Desktop 'qilinadigan_ishlar')
    'pos_flutter'        = 'C:\pos_flutter'
}

# --- Config (token + chat id) ---
$CfgPath = Join-Path $Dir '.telegram_bot.config.txt'
if (-not (Test-Path $CfgPath)) {
    Write-Host "[XATO] Config topilmadi: $CfgPath" -ForegroundColor Red
    Read-Host "Chiqish uchun Enter"; exit 1
}
$cfg      = Get-Content $CfgPath -Encoding UTF8
$Token    = ($cfg | Select-Object -First 1).Trim()
$AllowedRaw = ''
if ($cfg.Count -ge 2) { $AllowedRaw = ($cfg[1]).Trim() }
$Allowed  = @($AllowedRaw -split '[,; ]+' | Where-Object { $_ -ne '' })
if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "[XATO] Token bo'sh." -ForegroundColor Red; Read-Host "Enter"; exit 1
}

$Api = "https://api.telegram.org/bot$Token"
$env:UZ_BOT = '1'   # build_windows.bat "pause" qilmasligi uchun

# --- Telegram yordamchilari ---
function Send-Msg([string]$ChatId, [string]$Text, $Markup=$null) {
    $b = @{ chat_id = $ChatId; text = $Text; disable_web_page_preview = 'true' }
    if ($Markup) { $b.reply_markup = $Markup }
    try { return Invoke-RestMethod -Uri "$Api/sendMessage" -Method Post -TimeoutSec 30 -Body $b }
    catch { Write-Host "[ogoh] send: $($_.Exception.Message)" -ForegroundColor DarkYellow; return $null }
}
function Edit-Msg([string]$ChatId, [string]$MsgId, [string]$Text) {
    try { Invoke-RestMethod -Uri "$Api/editMessageText" -Method Post -TimeoutSec 30 -Body @{
        chat_id = $ChatId; message_id = $MsgId; text = $Text; disable_web_page_preview = 'true' } | Out-Null
    } catch { }
}
function Answer-Cb([string]$CbId) {
    try { Invoke-RestMethod -Uri "$Api/answerCallbackQuery" -Method Post -TimeoutSec 15 -Body @{ callback_query_id = $CbId } | Out-Null } catch { }
}

# =====================================================================
#  Versiya holati: oxirgi muvaffaqiyatli build (loyiha -> versiya + link)
#  Fayl:  .telegram_bot_state.json  (git ga tushmaydi)
# =====================================================================
$StatePath = Join-Path $Dir '.telegram_bot_state.json'

function Get-State {
    $h = @{}
    if (Test-Path $StatePath) {
        try {
            $o = Get-Content $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $o.PSObject.Properties) {
                $h[$p.Name] = @{
                    version = [string]$p.Value.version
                    url     = [string]$p.Value.url
                    at      = [string]$p.Value.at
                }
            }
        } catch { }
    }
    return $h
}

function Get-LastBuild([string]$Name) {
    $s = Get-State
    if ($s.ContainsKey($Name)) { return $s[$Name] }
    return @{ version = ''; url = ''; at = '' }
}

function Set-LastBuild([string]$Name, [string]$Version, [string]$Url) {
    $s = Get-State
    $s[$Name] = @{
        version = $Version
        url     = $Url
        at      = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    }
    try { ($s | ConvertTo-Json -Depth 5) | Set-Content $StatePath -Encoding UTF8 }
    catch { Write-Host "[ogoh] state saqlanmadi: $($_.Exception.Message)" -ForegroundColor DarkYellow }
}

# pubspec.yaml -> "0.5.7+57" (build raqami bilan). pubspec yo'q bo'lsa -> git commit.
function Get-ProjectVersion([string]$Path) {
    $pub = Join-Path $Path 'pubspec.yaml'
    if (Test-Path $pub) {
        try {
            foreach ($line in (Get-Content $pub -Encoding UTF8)) {
                if ($line -match '^\s*version:\s*(\S+)') { return $Matches[1].Trim() }
            }
        } catch { }
    }
    try {
        $sha = (& git -C $Path rev-parse --short HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $sha) { return "git:$(([string]$sha).Trim())" }
    } catch { }
    return ''
}

# Build'dan oldin kodni yangilash. Qaytaradi: $true = pull o'tdi.
function Invoke-GitPull([string]$Path) {
    try {
        $out = (& git -C $Path pull 2>&1) -join "`n"
        Write-Host "    git pull: $out" -ForegroundColor DarkGray
        return ($LASTEXITCODE -eq 0)
    } catch {
        Write-Host "[ogoh] git pull: $($_.Exception.Message)" -ForegroundColor DarkYellow
        return $false
    }
}

# Build logidan GitHub release havolasini ajratib olish
function Get-ReleaseUrl([string]$LogText) {
    if (-not $LogText) { return '' }
    $m = [regex]::Match($LogText, 'https://github\.com/[^\s''"]+/releases/tag/[^\s''"]+')
    if ($m.Success) { return $m.Value.TrimEnd('.', ',') }
    return ''
}

# --- Loyihalar menyusi (inline tugmalar) ---
function Show-Menu([string]$ChatId) {
    $btns = @()
    foreach ($k in $Projects.Keys) {
        $btns += , (@(@{ text = $k; callback_data = "b:$k" }))
    }
    # SH5 qoldiqlarini qo'lda yangilash (rk7_bridge sh5-remains) — test rejimi,
    # daemon yo'q: faqat tugma bosilganda yangilanadi.
    $btns += , (@(@{ text = "Ostatka yangilash (SH5)"; callback_data = "sh5:refresh" }))
    $markup = (@{ inline_keyboard = $btns } | ConvertTo-Json -Depth 6 -Compress)
    Send-Msg $ChatId "Qaysi loyihani build qilamiz? Tugmani bosing:" $markup | Out-Null
}

# --- SH5 qoldiqlarini yangilash (rk7_bridge sh5-remains) ---
# SH5 (StoreHouse) dan qoldiqlarni o'qib Mone'ga push qiladi — ilovadagi
# «Ostatka (SH5)» ekrani yangi raqamlarni ko'radi. Bridge config'i o'z
# papkasidan o'qiladi, shuning uchun Push-Location shart.
$Sh5BridgeDir = 'C:\112233\rk7_bridge'

function Invoke-Sh5Refresh([string]$ChatId) {
    $r = Send-Msg $ChatId "Ostatka yangilanmoqda (SH5 -> Mone)..."
    $mid = $null
    if ($r -and $r.result) { $mid = [string]$r.result.message_id }

    $exe = Join-Path $Sh5BridgeDir 'rk7bridge.exe'
    if (-not (Test-Path $exe)) {
        $txt = "XATO: rk7bridge.exe topilmadi:`n$exe"
        if ($mid) { Edit-Msg $ChatId $mid $txt } else { Send-Msg $ChatId $txt | Out-Null }
        return
    }

    $out = ''
    try {
        Push-Location $Sh5BridgeDir
        $out = ((& .\rk7bridge.exe sh5-remains 2>&1) | ForEach-Object { "$_" }) -join "`n"
        $code = $LASTEXITCODE
    } finally { Pop-Location }

    # Oxirgi qatorlar yetarli (masalan "omborlar=40 tovar satrlari=3269").
    $tail = (($out -split "`n") | Select-Object -Last 4) -join "`n"
    if ($code -eq 0) {
        $txt = "Ostatka yangilandi (SH5 -> Mone).`n$tail`nIlovada «Ostatka (SH5)» ni oching."
    } else {
        $txt = "Ostatka yangilash XATO (kod $code):`n$tail"
    }
    if ($mid) { Edit-Msg $ChatId $mid $txt } else { Send-Msg $ChatId $txt | Out-Null }
    Write-Host ">>> ostatka yangilash: kod=$code" -ForegroundColor Cyan
}

# --- Bitta loyihani build qilish + progress ---
$Stages = @(
    @{ re = '\[0/4\] git pull';  msg = 'git pull - oxirgi kod olinmoqda...' },
    @{ re = '\[1/4\]';           msg = 'Loyiha nusxalanmoqda...' },
    @{ re = '\[2/4\]';           msg = 'flutter pub get...' },
    @{ re = '\[3/4\]';           msg = 'BUILD qilinmoqda (biroz kuting)...' },
    @{ re = '\[4/4\]';           msg = 'Zip yaratilmoqda...' },
    @{ re = '\[5/5\]';           msg = "GitHub Releases'ga yuborilmoqda..." }
)

function Invoke-Build([string]$ChatId, [string]$Name, [bool]$Force = $false) {
    $path = $Projects[$Name]
    $bat  = Join-Path $path 'build_windows.bat'
    if (-not (Test-Path $bat)) {
        Send-Msg $ChatId "XATO: $Name - build_windows.bat topilmadi:`n$bat" | Out-Null
        return
    }

    $r = Send-Msg $ChatId "[$Name]`nQabul qilindi. git pull - versiya tekshirilmoqda..."
    $mid = $null
    if ($r -and $r.result) { $mid = [string]$r.result.message_id }

    # --- Avval kodni yangilaymiz, keyin versiyani solishtiramiz ---
    $pullOk = Invoke-GitPull $path
    $ver    = Get-ProjectVersion $path
    $prev   = Get-LastBuild $Name

    if (-not $Force -and $ver -and $prev.version -and $prev.version -eq $ver) {
        $txt = "[$Name]`nBUILD BEKOR QILINDI - versiya bir xil: $ver"
        if ($prev.at)  { $txt += "`nOxirgi build: $($prev.at)" }
        if ($prev.url) { $txt += "`nRelease: $($prev.url)" }
        else           { $txt += "`n(oxirgi release havolasi saqlanmagan)" }
        if (-not $pullOk) { $txt += "`nESLATMA: git pull xato berdi - kod yangilanmagan bo'lishi mumkin." }
        if ($mid) { Edit-Msg $ChatId $mid $txt } else { Send-Msg $ChatId $txt | Out-Null }

        $markup = (@{ inline_keyboard = @(, (@(@{ text = "Baribir build qilish"; callback_data = "f:$Name" }))) } | ConvertTo-Json -Depth 6 -Compress)
        Send-Msg $ChatId "Yangi o'zgarish yo'q. Baribir build qilaymi?" $markup | Out-Null
        Write-Host ">>> [$Name] versiya bir xil ($ver) - build bekor qilindi." -ForegroundColor Yellow
        return
    }

    $hdr = "[$Name] v$ver"
    if ($Force -and $prev.version -eq $ver) { $hdr += " (majburiy)" }
    if ($mid) { Edit-Msg $ChatId $mid "$hdr`nIshga tushirilmoqda..." }

    $log = Join-Path $env:TEMP ("uzbot_" + $Name + ".log")
    if (Test-Path $log) { Remove-Item $log -Force }

    Write-Host ">>> [$Name] build boshlandi..." -ForegroundColor Cyan
    $proc = Start-Process -FilePath $env:ComSpec `
                          -ArgumentList '/c', "`"`"$bat`" > `"$log`" 2>&1`"" `
                          -WorkingDirectory $path -WindowStyle Hidden -PassThru

    $lastIdx = -1
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds 2
        $c = $null
        try { $c = Get-Content $log -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
        if ($c) {
            $idx = -1
            for ($i = 0; $i -lt $Stages.Count; $i++) { if ($c -match $Stages[$i].re) { $idx = $i } }
            if ($idx -gt $lastIdx) {
                $lastIdx = $idx
                if ($mid) { Edit-Msg $ChatId $mid "$hdr`n$($Stages[$idx].msg)" }
                Write-Host "    [$Name] $($Stages[$idx].msg)"
            }
        }
    }

    $tail = ''
    $full = ''
    if (Test-Path $log) {
        try { $tail = (Get-Content $log -Tail 20 -Encoding UTF8) -join "`n" } catch { }
        if ($tail.Length -gt 3000) { $tail = $tail.Substring($tail.Length - 3000) }
        try { $full = Get-Content $log -Raw -Encoding UTF8 } catch { }
    }
    $relUrl = Get-ReleaseUrl $full

    if ($proc.ExitCode -eq 0) {
        $done = "$hdr`nTAYYOR!"
        if ($relUrl) {
            $done += "`nRelease: $relUrl"
        } else {
            # Release chiqmadi -> versiyani "chiqarilgan" deb yozmaymiz, keyingi
            # bosishda qayta urinib ko'rsin (versiya tekshiruvi to'smasin).
            $done += "`nOGOH: GitHub Releases'ga chiqmadi (havola topilmadi) - loglarga qarang."
        }
        if ($mid) { Edit-Msg $ChatId $mid $done } else { Send-Msg $ChatId $done | Out-Null }
        if ($ver -and $relUrl) { Set-LastBuild $Name $ver $relUrl }
        if (-not $relUrl -and $tail) { Send-Msg $ChatId "Loglar:`n$tail" | Out-Null }
    } else {
        $fail = "$hdr`nBUILD XATO (kod $($proc.ExitCode))."
        if ($mid) { Edit-Msg $ChatId $mid $fail } else { Send-Msg $ChatId $fail | Out-Null }
        if ($tail) { Send-Msg $ChatId "Loglar:`n$tail" | Out-Null }
    }
    Write-Host ">>> [$Name] tugadi, kod=$($proc.ExitCode)" -ForegroundColor Cyan
}

# --- Ishga tushirish ---
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  uz_ai_dev  Telegram build bot (ko'p loyihali) ishga tushdi" -ForegroundColor Green
Write-Host "  Loyihalar: $($Projects.Keys -join ', ')" -ForegroundColor Green
if ($Allowed.Count -gt 0) {
    Write-Host "  Ruxsat: $($Allowed -join ', ')" -ForegroundColor Green
} else {
    Write-Host "  DIQQAT: chat ID sozlanmagan - botga yozing, ID sini aytadi." -ForegroundColor Yellow
}
Write-Host "============================================================" -ForegroundColor Green

# Backlog (bot o'chik turgandagi) xabarlarni tashlab yuboramiz
$offset = 0
try {
    $init = Invoke-RestMethod -Uri "$Api/getUpdates?timeout=0&offset=-1" -TimeoutSec 20
    if ($init.ok -and $init.result.Count -gt 0) { $offset = [int]$init.result[-1].update_id + 1 }
} catch { }

while ($true) {
    try {
        $r = Invoke-RestMethod -Uri "$Api/getUpdates?timeout=30&offset=$offset" -TimeoutSec 45
        if (-not $r.ok) { Start-Sleep 2; continue }

        foreach ($u in $r.result) {
            $offset = [int]$u.update_id + 1

            # --- Tugma bosildi (callback) ---
            if ($u.callback_query) {
                $cb     = $u.callback_query
                $chatId = [string]$cb.message.chat.id
                $fromId = [string]$cb.from.id
                Answer-Cb $cb.id
                if ($Allowed.Count -gt 0 -and $Allowed -notcontains $fromId) {
                    Send-Msg $chatId "Ruxsat yo'q. Sizning ID: $fromId" | Out-Null; continue
                }
                $data = [string]$cb.data
                if ($data -eq 'sh5:refresh') {
                    Invoke-Sh5Refresh $chatId
                    continue
                }
                if ($data -like 'b:*' -or $data -like 'f:*') {
                    $force = $data.StartsWith('f:')   # "Baribir build qilish" - versiya tekshiruvisiz
                    $name  = $data.Substring(2)
                    if ($Projects.Contains($name)) { Invoke-Build $chatId $name $force }
                    else { Send-Msg $chatId "Noma'lum loyiha: $name" | Out-Null }
                }
                continue
            }

            # --- Oddiy xabar ---
            $msg = $u.message
            if ($null -eq $msg) { continue }
            $chatId = [string]$msg.chat.id
            $fromId = [string]$msg.from.id
            $text   = ''
            if ($msg.text) { $text = $msg.text.Trim() }
            Write-Host ("[{0}] {1}" -f $chatId, $text)

            if ($Allowed.Count -eq 0) {
                Send-Msg $chatId "Sizning chat ID: $chatId`nUni serverda .telegram_bot.config.txt 2-qatoriga qo'ying va botni qayta ishga tushiring." | Out-Null
                continue
            }
            if ($Allowed -notcontains $fromId) {
                Send-Msg $chatId "Ruxsat yo'q. Sizning ID: $fromId" | Out-Null; continue
            }

            $cmd = ($text -replace '@\w+$', '').ToLower()
            switch -Regex ($cmd) {
                '^/?(build|menu|start|loyiha)$' { Show-Menu $chatId }
                '^/?(ostatka|astatka)$'         { Invoke-Sh5Refresh $chatId }
                '^/?(status|ping)$'             { Send-Msg $chatId "Bot tirik. Loyihalar: $($Projects.Keys -join ', '). 'build' — menyu, 'ostatka' — SH5 qoldiqni yangilash." | Out-Null }
                '^/?(versiya|version)$'         {
                    $st    = Get-State
                    $lines = @("Oxirgi build qilingan versiyalar:")
                    foreach ($k in $Projects.Keys) {
                        if ($st.ContainsKey($k) -and $st[$k].version) {
                            $lines += "$k : v$($st[$k].version)  ($($st[$k].at))"
                            if ($st[$k].url) { $lines += "   $($st[$k].url)" }
                        } else {
                            $lines += "$k : hali build qilinmagan"
                        }
                    }
                    Send-Msg $chatId ($lines -join "`n") | Out-Null
                }
                default                         { Send-Msg $chatId "'build' - loyihalar ro'yxati. 'versiya' - oxirgi build versiyalari. 'ostatka' - SH5 qoldiqni yangilash." | Out-Null }
            }
        }
    }
    catch {
        Write-Host "[ogoh] loop: $($_.Exception.Message)" -ForegroundColor DarkYellow
        Start-Sleep 3
    }
}
