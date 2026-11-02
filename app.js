(() => {
  "use strict";
  const $ = (s, el = document) => el.querySelector(s);
  const $$ = (s, el = document) => [...el.querySelectorAll(s)];
  const config = window.VOID_SUPABASE || {};
  const configured = Boolean(config.url && config.anonKey &&
    !config.url.includes("TU-PROYECTO") && !config.anonKey.includes("TU-CLAVE"));
  const client = configured && window.supabase
    ? window.supabase.createClient(config.url, config.anonKey)
    : null;
  let currentUser = null;
  let currentFile = null;
  let previewUrl = null;

  // Navegación
  const panels = $$(".panel");
  const navItems = $$(".nav-item");
  function showPanel(id) {
    panels.forEach(p => p.classList.toggle("active", p.id === `panel-${id}`));
    navItems.forEach(n => n.classList.toggle("active", n.dataset.panel === id));
    window.scrollTo({ top: 0, behavior: "smooth" });
    if (id === "upload") loadFeed();
    if (id === "scripts") loadScripts();
  }
  navItems.forEach(btn => btn.addEventListener("click", () => showPanel(btn.dataset.panel)));

  // Temas
  const themeSelect = $("#theme-select");
  const savedTheme = localStorage.getItem("void-theme") || "void";
  document.documentElement.setAttribute("data-theme", savedTheme === "void" ? "" : savedTheme);
  if (themeSelect) themeSelect.value = savedTheme;
  themeSelect?.addEventListener("change", () => {
    localStorage.setItem("void-theme", themeSelect.value);
    document.documentElement.setAttribute("data-theme", themeSelect.value === "void" ? "" : themeSelect.value);
  });

  function notice(message) { window.alert(message); }
  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, c => ({
      "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"
    }[c]));
  }
  function formatDate(value) {
    return new Intl.DateTimeFormat("es", { dateStyle:"medium", timeStyle:"short" }).format(new Date(value));
  }

  // Ventana modal reutilizable
  function openModal(title, body, footer = "") {
    $("#void-modal")?.remove();
    const modal = document.createElement("div");
    modal.id = "void-modal";
    modal.className = "void-modal";
    modal.innerHTML = `<div class="void-modal-backdrop" data-close></div>
      <section class="void-modal-card" role="dialog" aria-modal="true" aria-labelledby="void-modal-title">
        <button class="void-modal-close" type="button" aria-label="Cerrar" data-close>×</button>
        <h2 id="void-modal-title">${escapeHtml(title)}</h2>
        <div class="void-modal-body">${body}</div>${footer}
      </section>`;
    document.body.append(modal);
    modal.querySelectorAll("[data-close]").forEach(b => b.addEventListener("click", () => modal.remove()));
    return modal;
  }

  // Cuenta: registro e inicio de sesión Supabase Auth
  function accountModal() {
    if (!client) {
      openModal("Conectar VOID Hub", '<p>La autenticación necesita las credenciales de tu proyecto Supabase.</p><p>Configura <strong>supabase-config.js</strong> y ejecuta el SQL incluido en <strong>supabase-setup.sql</strong>.</p>');
      return;
    }
    const modal = openModal("Tu cuenta", `
      <div class="auth-tabs"><button type="button" class="btn-sm" data-mode="login">Iniciar sesión</button><button type="button" class="btn-sm" data-mode="signup">Crear cuenta</button></div>
      <form id="auth-form" class="auth-form">
        <label>Correo electrónico<input type="email" id="auth-email" autocomplete="email" required placeholder="tu@correo.com"></label>
        <label>Contraseña<input type="password" id="auth-password" minlength="6" autocomplete="current-password" required placeholder="Mínimo 6 caracteres"></label>
        <label id="auth-name-wrap" hidden>Nombre público<input type="text" id="auth-name" maxlength="32" placeholder="Cómo te verá la comunidad"></label>
        <button class="btn-primary" id="auth-submit" type="submit">Iniciar sesión</button>
        <p class="note" id="auth-feedback" aria-live="polite"></p>
      </form>`);
    let mode = "login";
    const form = $("#auth-form", modal);
    const nameWrap = $("#auth-name-wrap", modal);
    const submit = $("#auth-submit", modal);
    modal.querySelectorAll("[data-mode]").forEach(b => b.addEventListener("click", () => {
      mode = b.dataset.mode;
      nameWrap.hidden = mode !== "signup";
      submit.textContent = mode === "signup" ? "Crear cuenta" : "Iniciar sesión";
      $("#auth-password", modal).autocomplete = mode === "signup" ? "new-password" : "current-password";
      $("#auth-feedback", modal).textContent = "";
    }));
    form.addEventListener("submit", async e => {
      e.preventDefault();
      submit.disabled = true;
      const email = $("#auth-email", modal).value.trim();
      const password = $("#auth-password", modal).value;
      const name = $("#auth-name", modal).value.trim();
      let result;
      try {
        result = mode === "signup"
          ? await client.auth.signUp({ email, password, options:{ emailRedirectTo: window.location.origin + "/", data:{ display_name:name || email.split("@")[0] } } })
          : await client.auth.signInWithPassword({ email, password });
        if (result.error) throw result.error;
        $("#auth-feedback", modal).textContent = mode === "signup"
          ? "Cuenta creada. Revisa tu correo si la confirmación está activada."
          : "Sesión iniciada correctamente.";
        if (result.data.session) { currentUser = result.data.user; updateAccountUI(); loadScripts(); setTimeout(() => modal.remove(), 700); }
      } catch (err) {
        $("#auth-feedback", modal).textContent = err.message || "No se pudo completar la operación.";
      } finally { submit.disabled = false; }
    });
  }
  function updateAccountUI() {
    const button = $("#btn-account");
    if (button) button.textContent = currentUser ? (currentUser.user_metadata?.display_name || "Mi cuenta") : "Crear cuenta";
    const logout = $("#btn-logout");
    if (logout) logout.textContent = currentUser ? "Cerrar sesión" : "Sesión cerrada";
    const note = $(".support-box .note");
    if (note) note.textContent = currentUser ? "Sesión activa. El soporte puede configurarse con un canal oficial." : "Inicia sesión para publicar contenido en la comunidad.";
  }
  $("#btn-account")?.addEventListener("click", () => currentUser ? openModal("Sesión activa", `<p>Conectado como <strong>${escapeHtml(currentUser.email)}</strong>.</p><p>Puedes cerrar sesión desde Ajustes.</p>`) : accountModal());
  $("#btn-logout")?.addEventListener("click", async () => {
    if (!client || !currentUser) return notice("No hay una sesión activa.");
    const { error } = await client.auth.signOut();
    if (error) return notice(error.message);
    currentUser = null; updateAccountUI(); notice("Sesión cerrada.");
  });

  // Biblioteca pública de scripts: abrir, copiar y borrar los propios.
  const scriptList = $("#script-list");
  const scriptForm = $("#script-upload-form");
  function renderScripts(items) {
    const count = $("#stat-scripts");
    if (count) count.textContent = String(items.length);
    if (!items.length) { scriptList.innerHTML = '<div class="empty-feed">Todavía no hay scripts. Publica el primero desde Subir.</div>'; return; }
    scriptList.innerHTML = items.map(s => `<article class="script-card">
      <div class="script-icon">⌘</div><div class="script-info"><h3>${escapeHtml(s.title)}</h3><p>${escapeHtml(s.description || "Script de la comunidad")}</p><small>${escapeHtml(s.author_name || "Usuario VOID")}</small></div>
      <button class="btn-sm" type="button" data-open-script="${s.id}">Abrir</button>
      ${currentUser?.id === s.author_id ? `<button class="btn-sm danger-btn" type="button" data-delete-script="${s.id}">Eliminar</button>` : ""}
    </article>`).join("");
    scriptList.querySelectorAll("[data-open-script]").forEach(b => b.addEventListener("click", () => {
      const s = items.find(x => x.id === b.dataset.openScript);
      if (!s) return;
      const modal = openModal(s.title, `<p>${escapeHtml(s.description || "")}</p><pre class="script-code-view"><code>${escapeHtml(s.code)}</code></pre><p class="note">Publicado por ${escapeHtml(s.author_name || "Usuario VOID")}</p>`);
      const copy = document.createElement("button"); copy.className = "btn-primary"; copy.textContent = "Copiar código";
      copy.addEventListener("click", async () => {
        try { await navigator.clipboard.writeText(s.code); copy.textContent = "¡Código copiado!"; }
        catch { const area=document.createElement("textarea"); area.value=s.code; modal.append(area); area.select(); document.execCommand("copy"); area.remove(); copy.textContent="¡Código copiado!"; }
      });
      $(".void-modal-body", modal).append(copy);
    }));
    scriptList.querySelectorAll("[data-delete-script]").forEach(b => b.addEventListener("click", async () => {
      if (!currentUser || !confirm("¿Eliminar este script? Esta acción no se puede deshacer.")) return;
      const { error } = await client.from("scripts").delete().eq("id", b.dataset.deleteScript).eq("author_id", currentUser.id);
      if (error) return notice("No se pudo eliminar: " + error.message);
      await loadScripts();
    }));
  }
  async function loadScripts() {
    if (!scriptList) return;
    if (!client) { scriptList.innerHTML='<div class="empty-feed">Conecta Supabase para activar la biblioteca.</div>'; return; }
    scriptList.innerHTML='<div class="empty-feed">Cargando scripts…</div>';
    const { data, error } = await client.from("scripts").select("id,author_id,author_name,title,description,code,created_at").order("created_at",{ascending:false}).limit(100);
    if (error) { scriptList.innerHTML='<div class="empty-feed">No se pudieron cargar los scripts.</div>'; console.error(error); return; }
    renderScripts(data || []);
  }
  scriptForm?.addEventListener("submit", async e => {
    e.preventDefault();
    if (!client) return notice("Primero configura Supabase.");
    if (!currentUser) { accountModal(); return notice("Inicia sesión para publicar un script."); }
    const title=$("#script-title").value.trim(), description=$("#script-description").value.trim(), code=$("#script-code").value.trim();
    if (!title || !code) return notice("Escribe el nombre y el código del script.");
    const button=$("#btn-script-upload"); button.disabled=true; button.textContent="Publicando…";
    try {
      const { error } = await client.from("scripts").insert({author_id:currentUser.id,author_name:currentUser.user_metadata?.display_name || currentUser.email.split("@")[0],title,description,code});
      if (error) throw error;
      scriptForm.reset(); await loadScripts(); notice("Script publicado en la sección Scripts.");
    } catch(err) { notice(err.message || "No se pudo publicar el script."); }
    finally { button.disabled=false; button.textContent="Publicar"; }
  });

  // Subida y feed público mediante Supabase Storage + Postgres
  const form = $("#upload-form");
  const fileInput = $("#up-file");
  const fileZone = $("#file-zone");
  const preview = $("#preview");
  const feed = $("#feed");
  function resetPreview() {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    previewUrl = null; currentFile = null;
    if (preview) { preview.hidden = true; preview.replaceChildren(); }
  }
  function handleFile(file) {
    if (!file) return;
    if (!file.type.startsWith("image/") && !file.type.startsWith("video/")) return notice("Solo se permiten fotos o videos.");
    if (file.size > 50 * 1024 * 1024) return notice("El archivo supera el límite de 50 MB.");
    resetPreview(); currentFile = file; previewUrl = URL.createObjectURL(file);
    const media = document.createElement(file.type.startsWith("video/") ? "video" : "img");
    media.src = previewUrl;
    if (media.tagName === "VIDEO") { media.controls = true; media.playsInline = true; }
    else media.alt = "Vista previa";
    preview.replaceChildren(media); preview.hidden = false;
  }
  fileInput?.addEventListener("change", () => handleFile(fileInput.files?.[0]));
  ["dragenter","dragover"].forEach(ev => fileZone?.addEventListener(ev, e => { e.preventDefault(); fileZone.classList.add("drag"); }));
  ["dragleave","drop"].forEach(ev => fileZone?.addEventListener(ev, e => { e.preventDefault(); fileZone.classList.remove("drag"); }));
  fileZone?.addEventListener("drop", e => handleFile(e.dataTransfer.files?.[0]));

  function renderPosts(posts) {
    const postCount = $("#stat-members");
    if (postCount) postCount.textContent = String(posts.length);
    if (!posts.length) { feed.innerHTML = '<div class="empty-feed">Todavía no hay publicaciones.<br>¡Comparte la primera!</div>'; return; }
    feed.innerHTML = posts.map(p => {
      const media = p.media_type === "video"
        ? `<video src="${escapeHtml(p.media_url)}" controls playsinline preload="metadata"></video>`
        : `<img src="${escapeHtml(p.media_url)}" alt="${escapeHtml(p.title)}" loading="lazy">`;
      const own = currentUser?.id === p.author_id;
      return `<article class="post"><div class="post-media">${media}</div><div class="post-body">
        <h4>${escapeHtml(p.title)}</h4>${p.comment ? `<p>${escapeHtml(p.comment)}</p>` : ""}
        <div class="post-meta">${escapeHtml(p.author_name || "Usuario VOID")} · ${escapeHtml(formatDate(p.created_at))}</div>${own ? `<button class="btn-sm danger-btn" type="button" data-delete-post="${p.id}">Eliminar publicación</button>` : ""}
      </div></article>`;
    }).join("");
    feed.querySelectorAll("[data-delete-post]").forEach(b => b.addEventListener("click", async () => {
      if (!currentUser || !confirm("¿Eliminar tu publicación y su archivo?")) return;
      const post=posts.find(p=>p.id===b.dataset.deletePost);
      const {error}=await client.from("posts").delete().eq("id",post.id).eq("author_id",currentUser.id);
      if(error) return notice("No se pudo eliminar: "+error.message);
      if(post.media_path) { const removed=await client.storage.from("void-media").remove([post.media_path]); if(removed.error) console.warn("No se pudo borrar el archivo",removed.error); }
      await loadFeed();
    }));
  }
  async function loadFeed() {
    if (!feed) return;
    if (!client) { feed.innerHTML = '<div class="empty-feed">Conecta Supabase para activar el feed público.</div>'; return; }
    feed.innerHTML = '<div class="empty-feed">Cargando publicaciones…</div>';
    const { data, error } = await client.from("posts").select("id,author_id,title,comment,media_url,media_path,media_type,author_name,created_at").order("created_at", { ascending:false }).limit(50);
    if (error) { feed.innerHTML = '<div class="empty-feed">No se pudo cargar el feed. Revisa la configuración de Supabase.</div>'; console.error(error); return; }
    renderPosts(data || []);
  }
  form?.addEventListener("submit", async e => {
    e.preventDefault();
    if (!client) return notice("Primero configura Supabase para publicar.");
    if (!currentUser) { accountModal(); return notice("Inicia sesión para publicar."); }
    const title = $("#up-title").value.trim();
    const comment = $("#up-comment").value.trim();
    if (!title || !currentFile) return notice("Escribe un título y selecciona una foto o video.");
    const submit = $("#btn-upload");
    submit.disabled = true; submit.textContent = "Publicando…";
    try {
      const ext = (currentFile.name.split(".").pop() || (currentFile.type.startsWith("video/") ? "mp4" : "jpg")).toLowerCase().replace(/[^a-z0-9]/g,"");
      const path = `${currentUser.id}/${crypto.randomUUID()}.${ext}`;
      const upload = await client.storage.from("void-media").upload(path, currentFile, { cacheControl:"3600", upsert:false, contentType:currentFile.type });
      if (upload.error) throw upload.error;
      const { data: publicData } = client.storage.from("void-media").getPublicUrl(path);
      const { error } = await client.from("posts").insert({
        author_id:currentUser.id, author_name:currentUser.user_metadata?.display_name || currentUser.email.split("@")[0],
        title, comment, media_url:publicData.publicUrl, media_path:path,
        media_type:currentFile.type.startsWith("video/") ? "video" : "image"
      });
      if (error) {
        await client.storage.from("void-media").remove([path]);
        throw error;
      }
      form.reset(); resetPreview(); await loadFeed(); notice("¡Publicación compartida con toda la comunidad!");
    } catch (err) { notice(err.message || "No se pudo publicar. Inténtalo de nuevo."); }
    finally { submit.disabled = false; submit.textContent = "Publicar"; }
  });

  // Soporte: no simular envíos sin un canal real conectado
  $("#btn-send-support")?.addEventListener("click", () => {
    const message = $("#support-msg").value.trim();
    if (!message) return notice("Escribe un mensaje primero.");
    if (!currentUser) return accountModal();
    notice("Tu sesión está activa. Para recibir mensajes, configura un canal de soporte oficial.");
  });

  // Idioma: se conserva el selector sin fingir una traducción inexistente
  $("#lang-select")?.addEventListener("change", e => {
    if (e.target.value === "en") notice("La traducción al inglés todavía no está disponible.");
  });

  async function init() {
    if (!client) {
      feed.innerHTML = '<div class="empty-feed">El feed público estará disponible cuando conectes Supabase.</div>';
      updateAccountUI(); await loadScripts(); return;
    }
    const { data } = await client.auth.getSession();
    currentUser = data.session?.user || null;
    client.auth.onAuthStateChange((_event, session) => { currentUser = session?.user || null; updateAccountUI(); loadScripts(); });
    updateAccountUI(); await Promise.all([loadFeed(), loadScripts()]);
  }
  init();
})();