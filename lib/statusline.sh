#!/bin/bash
# Claude Code status line — sessiya (5 soat) + haftalik (7 kun) + model limitlari (Fable/Opus...),
# O'NG tomonga tekislangan.
# Misol:  5h ██░░░░░░░░░░ 15% · 3h 56min │ 7d █████░░░░░░░ 42% · 1d 18h │ Fable ███░░░░░░░░░ 29%
#
# MANBALAR (ikkitasi, biri ikkinchisini to'ldiradi):
#   1) Claude Code'ning o'zi bergan JSON (.rate_limits.*) — doim yangi, tarmoq kerak emas.
#      DIQQAT: CC `seven_day` ni FAQAT server top-level `seven_day` ni bergandagina yuboradi.
#      Server uni `null` qilsa (yoki hisob endi model bo'yicha haftalikka o'tgan bo'lsa),
#      CC'da 7d umuman bo'lmaydi — shuning uchun ikkinchi manba kerak.
#   2) /api/oauth/usage → ~/.claude/usage-cache.json — bu yerda `limits[]` massivi bor:
#      session / weekly (umumiy) / weekly_scoped (model bo'yicha).
#      Kesh FONDA yangilanadi, statusline kutib turmaydi.
# 5h va 7d uchun CC JSON ustuvor; unda yo'q bo'lsa — keshdagi `limits[]` dan olinadi.

input=$(cat)

read -r pct5 epoch5 pct7 epoch7 < <(printf '%s' "$input" | jq -r '
  [ (.rate_limits.five_hour.used_percentage // "null"),
    (.rate_limits.five_hour.resets_at      // "null"),
    (.rate_limits.seven_day.used_percentage // "null"),
    (.rate_limits.seven_day.resets_at       // "null") ] | join(" ")' 2>/dev/null)
[ -z "$pct5" ] && pct5="null"; [ -z "$epoch5" ] && epoch5="null"
[ -z "$pct7" ] && pct7="null"; [ -z "$epoch7" ] && epoch7="null"

# Terminal kengligi
cols="${COLUMNS:-}"
[ -z "$cols" ] && cols=$(tput cols 2>/dev/null)
[ -z "$cols" ] && cols=80

WIDTH=12  # bitta progress bar kengligi (belgi)

CACHE="$HOME/.claude/usage-cache.json"
CACHE_TTL=120       # sekund: shuncha vaqtdan keyin fonda yangilanadi
CACHE_MAX_AGE=3600  # sekund: bundan eski kesh umuman ko'rsatilmaydi

now=$(date +%s)

file_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

# --- Fon rejimida keshni yangilash (statusline bloklanmaydi) -----------------
refresh_usage_cache() {
  local lock="$CACHE.lock" lockm
  # osilib qolgan eski qulfni tozalash
  if [ -d "$lock" ]; then
    lockm=$(file_mtime "$lock")
    [ -n "$lockm" ] && [ $(( now - lockm )) -gt 60 ] && rmdir "$lock" 2>/dev/null
  fi
  mkdir "$lock" 2>/dev/null || return 0
  (
    trap 'rmdir "$lock" 2>/dev/null' EXIT
    local token tmp
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
            | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [ -z "$token" ] && [ -r "$HOME/.claude/.credentials.json" ]; then
      token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
    fi
    [ -z "$token" ] && exit 0
    tmp="${CACHE}.tmp.$$"
    curl -s --max-time 8 "${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/api/oauth/usage" \
      -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "Content-Type: application/json" > "$tmp" 2>/dev/null
    if jq -e 'type == "object" and has("limits")' "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "$CACHE"
    else
      rm -f "$tmp"
    fi
  ) >/dev/null 2>&1 &
}

# --- Keshdan limitlarni o'qish ----------------------------------------------
# Har qator: "<tur> <nom> <foiz> <epoch>", tur = session | weekly | model
cache_rows=""
cache_m=$(file_mtime "$CACHE")
# Obuna limitlari umuman yo'q bo'lsa (API key / Bedrock sessiyasi) — keshga ham qaramaymiz
if [ "$pct5" != "null" ] || [ "$pct7" != "null" ]; then
if [ -n "$cache_m" ] && [ $(( now - cache_m )) -le "$CACHE_MAX_AGE" ]; then
  cache_rows=$(jq -r '
    def epoch:
      (. // "")
      | if . == "" then "null"
        else (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z"))
             | (try (fromdateiso8601 | tostring) catch "null")
        end;
    def row($kind; $name; $pct; $reset):
      [$kind, $name, (($pct // 0) | tostring), ($reset | epoch)] | join(" ");

    ( (.limits // [])
      | map(select(.percent != null))
      | .[]
      | . as $l
      | (($l.scope.model.display_name // "") | gsub(" "; "_")) as $model
      | if ($l.kind == "session" or $l.group == "session")
          then row("session"; "5h"; $l.percent; $l.resets_at)
        elif $model != ""
          then row("model"; $model; $l.percent; $l.resets_at)
        elif ($l.group == "weekly" or (($l.kind // "") | startswith("weekly")))
          then row("weekly"; "7d"; $l.percent; $l.resets_at)
        else empty
        end
    ),
    # Eski (legacy) top-level maydonlar — `limits[]` da bo`lmasa, zaxira sifatida
    ( if (.seven_day // null) != null and (.seven_day.utilization // null) != null
        then row("weekly"; "7d"; .seven_day.utilization; .seven_day.resets_at) else empty end ),
    ( if (.five_hour // null) != null and (.five_hour.utilization // null) != null
        then row("session"; "5h"; .five_hour.utilization; .five_hour.resets_at) else empty end )
  ' "$CACHE" 2>/dev/null)
fi
fi

# Keshdagi qatorlarni turlarga ajratamiz (birinchi uchragani ustuvor)
c_pct_session=""; c_ep_session=""
c_pct_weekly="";  c_ep_weekly=""
scoped_raw=""
while read -r c_kind c_name c_pct c_ep; do
  [ -z "$c_kind" ] && continue
  case "$c_kind" in
    session) [ -z "$c_pct_session" ] && { c_pct_session=$c_pct; c_ep_session=$c_ep; } ;;
    weekly)  [ -z "$c_pct_weekly"  ] && { c_pct_weekly=$c_pct;  c_ep_weekly=$c_ep;  } ;;
    model)   scoped_raw="${scoped_raw}${c_name} ${c_pct} ${c_ep}"$'\n' ;;
  esac
done <<< "$cache_rows"

# CC JSON'da yo'q bo'lganini keshdan to'ldiramiz (7d aynan shu yerda tiklanadi)
if [ "$pct5" = "null" ] && [ -n "$c_pct_session" ]; then pct5=$c_pct_session; epoch5=$c_ep_session; fi
if [ "$pct7" = "null" ] && [ -n "$c_pct_weekly"  ]; then pct7=$c_pct_weekly;  epoch7=$c_ep_weekly;  fi

# Kesh eskirgan bo'lsa — fonda yangilaymiz
if [ "$pct5" != "null" ] || [ "$pct7" != "null" ]; then
  if [ -z "$cache_m" ] || [ $(( now - cache_m )) -ge "$CACHE_TTL" ]; then
    refresh_usage_cache
  fi
fi

make_bar() {  # $1 = pct (butun son) -> global BAR
  local pctint=$1 filled empty i
  filled=$(( (pctint * WIDTH + 50) / 100 ))
  [ "$filled" -gt "$WIDTH" ] && filled=$WIDTH
  [ "$filled" -lt 0 ] && filled=0
  empty=$(( WIDTH - filled ))
  BAR=""
  i=0; while [ "$i" -lt "$filled" ]; do BAR="${BAR}█"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$empty" ];  do BAR="${BAR}░"; i=$((i+1)); done
}

fmt_reset() {  # $1 = epoch -> global RESET ("2d 4h" / "3h 56min" / "42min" / "now" / "")
  local epoch=$1 rem d h m
  RESET=""
  [ -z "$epoch" ] || [ "$epoch" = "null" ] && return
  rem=$(( ${epoch%.*} - now ))
  if [ "$rem" -le 0 ]; then RESET="now"; return; fi
  d=$(( rem / 86400 )); h=$(( (rem % 86400) / 3600 )); m=$(( (rem % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then RESET="${d}d ${h}h"
  elif [ "$h" -gt 0 ]; then RESET="${h}h ${m}min"
  else                      RESET="${m}min"
  fi
}

segment() {  # $1=label $2=pct $3=epoch -> SEG (matn) va SEGCOLS (ko'rinadigan kenglik)
  local label=$1 pct=$2 epoch=$3 pctint rest
  SEG=""; SEGCOLS=0
  [ -z "$pct" ] || [ "$pct" = "null" ] && return
  pctint=${pct%.*}; [ -z "$pctint" ] && pctint=0
  make_bar "$pctint"
  fmt_reset "$epoch"
  rest=" ${pctint}%"
  [ -n "$RESET" ] && rest="${rest} · ${RESET}"
  SEG="${label} ${BAR}${rest}"
  SEGCOLS=$(( ${#label} + 1 + WIDTH + ${#rest} ))
}

segs=(); segcols=()
add_seg() { [ -n "$SEG" ] && { segs+=("$SEG"); segcols+=("$SEGCOLS"); }; }

build_segments() {  # $1 = bar kengligi -> global segs / segcols
  WIDTH=$1
  segs=(); segcols=()
  segment "5h" "$pct5" "$epoch5"; add_seg
  segment "7d" "$pct7" "$epoch7"; add_seg
  # Model bo'yicha barlar (Fable va h.k.). Reset vaqti 7d bilan bir xil bo'lsa — takrorlamaymiz.
  while read -r m_name m_pct m_epoch; do
    [ -z "$m_name" ] && continue
    if [ -n "$epoch7" ] && [ "$epoch7" != "null" ] && [ "$m_epoch" != "null" ]; then
      diff=$(( ${m_epoch%.*} - ${epoch7%.*} ))
      [ "$diff" -lt 0 ] && diff=$(( -diff ))
      [ "$diff" -lt 300 ] && m_epoch="null"
    fi
    segment "${m_name//_/ }" "$m_pct" "$m_epoch"; add_seg
  done <<< "$scoped_raw"
}

join_segments() {  # $1 = nechta segment -> global line / total
  local n=$1 i=0
  line=""; total=0
  while [ "$i" -lt "$n" ]; do
    if [ -z "$line" ]; then
      line="${segs[$i]}"; total=${segcols[$i]}
    else
      line="${line} │ ${segs[$i]}"; total=$(( total + 3 + segcols[i] ))
    fi
    i=$(( i + 1 ))
  done
}

# Sig'dirish: avval barcha barlarni saqlab, kerak bo'lsa barlarni toraytiramiz;
# bu ham yetmasa — o'ngdagi barlardan (avval model bari) voz kechamiz.
build_segments 12
maxn=${#segs[@]}
line="—"; total=1; fitted=0
for (( n = maxn; n >= 1; n-- )); do
  for w in 12 10 8 6; do
    build_segments "$w"
    join_segments "$n"
    if [ $(( total + 1 )) -le "$cols" ]; then fitted=1; break 2; fi
  done
done
[ "$fitted" -eq 0 ] && { line="—"; total=1; }

pad=$(( cols - total - 1 ))   # 1 belgi o'ng chetdan zaxira
[ "$pad" -lt 0 ] && pad=0
printf '%*s%s' "$pad" '' "$line"
