name: init-project
args:
  slug:
    description: "Project slug"
  discord_token:
    description: "Discord bot token"
  ch_product:
    description: "Discord channel ID for #product"
    default: "1486613586229854278"
  ch_design:
    description: "Discord channel ID for #design"
    default: "1486613609839726736"
  ch_dev:
    description: "Discord channel ID for #dev"
    default: "1486613643851202743"
  ch_qa:
    description: "Discord channel ID for #qa"
    default: "1486613658984517683"
  ch_release:
    description: "Discord channel ID for #release"
    default: "1486613723241123900"
steps:
  - id: create_threads
    run: |
      TOKEN="${discord_token}"
      API="https://discord.com/api/v10"
      SLUG="${slug}"

      create_thread() {
        local channel_id=$1 name=$2
        local resp=$(curl -sf -X POST "$API/channels/$channel_id/threads" \
          -H "Authorization: Bot $TOKEN" \
          -H "Content-Type: application/json" \
          -d "{\"name\":\"$name\",\"type\":11,\"auto_archive_duration\":10080}")
        echo "$resp" | jq -r '.id // empty'
      }

      P=$(create_thread "${ch_product}" "$SLUG")
      D=$(create_thread "${ch_design}" "$SLUG")
      V=$(create_thread "${ch_dev}" "$SLUG")
      Q=$(create_thread "${ch_qa}" "$SLUG")
      R=$(create_thread "${ch_release}" "$SLUG")

      jq -n \
        --arg slug "$SLUG" \
        --arg product "$P" \
        --arg design "$D" \
        --arg dev "$V" \
        --arg qa "$Q" \
        --arg release "$R" \
        '{slug:$slug, threads:{product:$product, design:$design, dev:$dev, qa:$qa, release:$release}}'
