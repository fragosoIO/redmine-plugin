--!nonstrict
-- Bar widget: open-issue count. Click opens the issue panel.

local snapshot = noctalia.state.get("issues")

local function render()
  barWidget.setGlyph("ticket")
  if snapshot == nil then
    barWidget.setText("…")
    barWidget.setTooltip(noctalia.tr("loading"))
    return
  end
  if snapshot.error ~= nil then
    barWidget.setText("!")
    barWidget.setTooltip(noctalia.tr(snapshot.error, snapshot.errorArgs))
    return
  end
  barWidget.setText(tostring(snapshot.total))
  barWidget.setTooltip(noctalia.trp("issues", snapshot.total))
end

noctalia.state.watch("issues", function(value)
  snapshot = value
  render()
end)

function update()
  noctalia.setUpdateInterval(5000)
  render()
end

function onClick()
  noctalia.togglePanel("fragoso/redmine:issues")
end
