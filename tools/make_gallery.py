import base64, os
charts = ["ZOOM_A_5m.png","ZOOM_B_5m.png","M15_trades.png","H1_trades.png","D1_bias.png"]
caps = {
 "ZOOM_A_5m.png":"5-MIN ZOOM (clearest) - orange band = a price ZONE hit repeatedly; blue^=BUY, magenta v=SELL, red x=LOSS. See the SAME zone re-entered again and again -> repeated SL.",
 "ZOOM_B_5m.png":"5-MIN ZOOM (2nd cluster) - same story: re-entering a zone that already lost.",
 "M15_trades.png":"15-MIN full Apr20-Sep2 - green bg = bull bias (close>EMA50), red bg = bear bias. Red boxes = the 49 REPEAT entries (of 152). Those repeats = -$209 (whole loss).",
 "H1_trades.png":"1-HOUR context - buys(blue) vs sells(magenta), bias shading.",
 "D1_bias.png":"1-DAY bias - gold fell 4800->3950 then bounced; long fades fought the down-bias.",
}
parts=['<html><head><meta charset="utf-8"><title>Gold chop diagnosis</title>',
 '<style>body{background:#111;color:#eee;font-family:Segoe UI,Arial;margin:20px}',
 'h2{color:#4da3ff;margin-top:26px}img{width:100%;max-width:1600px;border:1px solid #444;margin:6px 0}',
 'p{color:#ccc;font-size:15px}.k{background:#222;padding:12px;border-left:4px solid #e8a33d}</style></head><body>',
 '<h1>GOLD chop diagnosis - Apr 20 to Sep 2, 2026</h1>',
 '<div class="k"><b>Key finding:</b> 152 fade trades, net -$160. The 49 REPEAT entries (same zone within ~$9 & 36h) lost -$209 by themselves - i.e. the NON-repeat trades were +$49. The loss IS the repeated re-entry at the same losing zone. Buys -$156 vs sells -$4.</div>']
for c in charts:
    p=os.path.join("charts",c)
    if not os.path.exists(p): continue
    b=base64.b64encode(open(p,"rb").read()).decode()
    parts.append("<h2>%s</h2>"%caps.get(c,c))
    parts.append('<img src="data:image/png;base64,%s"/>'%b)
parts.append("</body></html>")
open(os.path.join("charts","gallery.html"),"w",encoding="utf-8").write("\n".join(parts))
print("wrote charts/gallery.html", os.path.getsize(os.path.join("charts","gallery.html")), "bytes")
