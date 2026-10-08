enum WebPage {
    // Página que se abre desde la otra compu. Chequea cada 2 segundos si hay novedades,
    // pero nunca cambia la vista sola: muestra un aviso y se actualiza con un click.
    static let html = #"""
    <!doctype html>
    <html lang="es">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Monti Mac2Win</title>
    <style>
      :root { --bg:#f5f5f7; --card:#fff; --text:#1d1d1f; --muted:#6e6e73; --border:#e5e5ea; --accent:#0a84ff; }
      @media (prefers-color-scheme: dark) {
        :root { --bg:#000; --card:#1c1c1e; --text:#f5f5f7; --muted:#98989d; --border:#2c2c2e; }
      }
      * { box-sizing: border-box; }
      body { margin:0; font:15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; background:var(--bg); color:var(--text); }
      main { max-width:720px; margin:0 auto; padding:40px 20px; }
      header { display:flex; align-items:center; gap:10px; margin-bottom:24px; }
      h1 { font-size:22px; margin:0; }
      .dot { width:9px; height:9px; border-radius:50%; background:#30d158; transition:background .2s; }
      .count { color:var(--muted); font-size:13px; margin-left:auto; }
      .item { background:var(--card); border:1px solid var(--border); border-radius:14px; padding:14px 16px;
              margin-bottom:10px; display:flex; gap:14px; align-items:center; animation:in .25s ease-out; }
      @keyframes in { from { opacity:0; transform:translateY(-4px); } }
      .icon { font-size:22px; }
      .body { flex:1; min-width:0; }
      .name { font-weight:600; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
      .meta { color:var(--muted); font-size:13px; }
      pre { margin:0; white-space:pre-wrap; word-break:break-word; font:14px/1.5 ui-monospace, Consolas, monospace;
            max-height:260px; overflow:auto; }
      .btn { border:0; background:var(--accent); color:#fff; padding:8px 16px; border-radius:999px; font:inherit;
             font-size:13px; font-weight:600; cursor:pointer; text-decoration:none; white-space:nowrap; }
      .btn:hover { filter:brightness(1.1); }
      .empty { text-align:center; color:var(--muted); padding:80px 0; }
      .ghost { border:1px solid var(--border); background:var(--card); color:var(--text); width:34px; height:34px;
               border-radius:50%; font-size:16px; cursor:pointer; }
      .ghost:hover { border-color:var(--accent); }
      .banner { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:16px;
                padding:10px 12px 10px 16px; border-radius:14px; background:var(--accent); color:#fff; font-weight:600;
                animation:in .25s ease-out; }
      .banner[hidden] { display:none; }
      .banner .btn { background:#fff; color:var(--accent); }
    </style>
    </head>
    <body>
    <main>
      <header><span class="dot" id="status"></span><h1>Monti Mac2Win</h1><span class="count" id="count"></span>
        <button class="ghost" id="refresh-button" onclick="refresh()" title="Actualizar">↻</button></header>
      <div class="banner" id="banner" hidden><span>Hay novedades en la Mac</span>
        <button class="btn" id="banner-refresh-button" onclick="refresh()">Actualizar</button></div>
      <div id="list"></div>
    </main>
    <script>
      let shown = null;   // lo que está en pantalla
      let latest = null;  // lo último que respondió la Mac
      const fmt = b => { const u = ["B","KB","MB","GB"]; let i = 0; while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; } return (i ? b.toFixed(1) : b) + " " + u[i]; };
      const esc = s => s.replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));

      const fileRow = it => `<div class="item"><div class="icon">📄</div>
        <div class="body"><div class="name">${esc(it.name)}</div><div class="meta">${fmt(it.size)}</div></div>
        <a class="btn" id="download-${it.id}" href="/file/${it.id}" download>Descargar</a></div>`;
      const textRow = it => `<div class="item"><div class="icon">📝</div>
        <div class="body"><pre id="t-${it.id}">${esc(it.text)}</pre></div>
        <button class="btn" id="copy-${it.id}" onclick="copyText('${it.id}', this)">Copiar</button></div>`;

      // Solo consulta: si hay algo distinto a lo que se ve, muestra el aviso.
      async function check() {
        const status = document.getElementById("status");
        try {
          const res = await fetch("/api/items", { cache: "no-store" });
          latest = await res.text();
          status.style.background = "#30d158";
          document.getElementById("banner").hidden = latest === shown;
        } catch (e) {
          status.style.background = "#ff453a";
        }
      }

      async function refresh() {
        await check();
        if (latest === null) return;
        shown = latest;
        document.getElementById("banner").hidden = true;
        const items = JSON.parse(shown);
        document.getElementById("count").textContent = items.length ? items.length + (items.length === 1 ? " ítem" : " ítems") : "";
        document.getElementById("list").innerHTML = items.length
          ? items.map(it => it.kind === "file" ? fileRow(it) : textRow(it)).join("")
          : `<div class="empty">Todavía no hay nada.<br>Arrastrá archivos o escribí un texto en la Mac.</div>`;
      }

      // navigator.clipboard no funciona en http (no seguro), por eso el textarea.
      function copyText(id, btn) {
        const ta = document.createElement("textarea");
        ta.value = document.getElementById("t-" + id).textContent;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
        btn.textContent = "¡Copiado!";
        setTimeout(() => btn.textContent = "Copiar", 1500);
      }

      refresh();
      setInterval(check, 2000);
    </script>
    </body>
    </html>
    """#
}
