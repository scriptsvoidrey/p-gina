--[[
╔══════════════════════════════════════════════════════════════════════╗
                           nub protegido
╚══════════════════════════════════════════════════════════════════════╝

nub protegido es una libreria de interfaces para Roblox creada con una filosofia
clara: priorizar la compatibilidad, el rendimiento y la simplicidad antes
que los efectos visuales.

ORDEN DE PRIORIDAD:  Compatibilidad > Rendimiento > Simplicidad > Diseño
Toda mejora o nueva caracteristica debe respetar este orden.

NOTA PARA DESARROLLADORES E IA: si se agregan optimizaciones o funciones
nuevas, no romper la API publica, no reducir la compatibilidad, no
sacrificar rendimiento por efectos visuales, y mantener el codigo limpio
y consistente con el resto de la libreria.

REGISTRO DE CAMBIOS: cualquier fix, reparacion, o bug encontrado en esta
libreria se documenta en README_es.md / README_en.md (seccion "Novedades"
de la version correspondiente), NUNCA como un comentario "antes esto
fallaba" o "FIX:" pegado en el punto exacto del codigo donde se reparo.
El codigo debe describir lo que HACE hoy, no su historial de bugs.

    Carga (un solo archivo):
        local Nub = loadstring(readfile("Nub.lua"))()

    -- ── USO BASICO ───────────────────────────────────────────
    local Ventana = Nub:CrearVentana({
        Titulo        = "Mi Script",
        Subtitulo     = "by YO",
        TamanoX       = 560,
        TamanoY       = 340,
        TeclaToggle   = Enum.KeyCode.RightControl,
        Buscador      = true,   -- opcional, true por defecto
        AutoGuardar   = true,   -- opcional, true por defecto (persistencia nativa)
        NombreConfig  = "misettings",
    })
    local Tab     = Ventana:CrearTab("Principal", "🏠")
    local Seccion = Tab:CrearSeccion("General")

    -- ── CONTROLES ────────────────────────────────────────────
    -- Todos devuelven { Set(valor), Get() } salvo Boton y Parrafo.
    -- El campo Flag es el ID unico para SaveManager y Nub.Flags.
    -- El campo Callback(valor) se llama cada vez que el usuario cambia
    -- el control; el parametro es el valor nuevo.

    Seccion:Boton   ({ Texto="Hola",        Callback=function() print("hi") end })
    Seccion:Toggle  ({ Texto="Modo X", Flag="modoX", Defecto=false, Callback=function(v) print(v) end })
    Seccion:Slider  ({ Texto="Vel",    Flag="vel",  Min=0, Max=100, Incremento=1, Sufijo="%", Defecto=50, Callback=function(v) print(v) end })
    Seccion:Input   ({ Texto="Nombre", Flag="nombre", Defecto="", Placeholder="...", Callback=function(v) print(v) end })
    Seccion:Dropdown({ Texto="Arma",   Flag="arma", Opciones={"Espada","Hacha"}, Defecto="Espada", Callback=function(v) print(v) end })
    Seccion:ColorPicker({ Texto="Color", Flag="col", Defecto=Color3.fromRGB(255,0,0), Callback=function(c) print(c) end })
    Seccion:Keybind ({ Texto="Activar", Flag="kb", Defecto=Enum.KeyCode.F, Callback=function(k) print(k) end })
    Seccion:Casilla ({ Texto="Marcar", Flag="casilla1", Defecto=false, Callback=function(v) print(v) end })
    Seccion:Parrafo ({ Titulo="Nota", Contenido="Descripcion larga aqui.", RichText=false })

    -- ── API PUBLICA (para developers externos) ────────────────
    Nub.Flags["vel"]               -- valor actual de cualquier control
    Nub:ObtenerFlag("vel")         -- shortcut con nil-safe
    Nub:ObtenerElemento("vel")     -- {Set, Get} del control
    Nub:Notificar({ Titulo="OK", Texto="listo", Duracion=4 })
    Nub.ThemeManager:AplicarTema("Morado")
    Nub.SaveManager:Guardar("config")
    Nub.SaveManager:Cargar("config")
    Nub:RegistrarConexion(conexion) -- auto-limpieza (ver mas abajo)
    Nub:RegistrarHilo(hilo)
    Nub:RegistrarDibujo(objetoDrawing)
    Nub.Capacidades.Drawing   -- true/false, para saber si el ejecutor soporta Drawing.new()
    Nub.Capacidades.Archivos  -- true/false, soporte de writefile/readfile

    Ventana:GuardarConfiguracion()
    Ventana:CargarConfiguracion()
    Ventana:Buscar("texto")
    Ventana:AgregarSelectorTemas()
    Ventana:Destruir()    -- cierra y limpia la GUI completamente

    -- ── ESTRUCTURA INTERNA ────────────────────────────────────
    1) Utils    -> funciones base (Frame, Texto, Tween, Corner...)
    2) Themes   -> paletas de color (Negro/Blanco/Verde/Morado/Rojo)
    3) Nub   -> nucleo: Ventana, Tab, Seccion, controles,
                   EventManager, AnimationManager, SaveManager,
                   ThemeManager, sistema de auto-limpieza global
]]

-- ===================================================================
--  SECCION 1: UTILS
-- ===================================================================
-- ══════════════════════════════════════════════════════════════
--  POLYFILL DE task.* (compatibilidad con ejecutores limitados)
-- ══════════════════════════════════════════════════════════════
-- Casi toda la libreria depende de task.spawn/task.delay/task.wait/
-- task.defer/task.cancel. En la gran mayoria de los ejecutores esto
-- ya viene nativo, pero por si alguno mas viejo o con sandboxing raro
-- no lo tiene, se rellena aca con las funciones globales clasicas
-- (delay, wait, spawn, coroutine) para que la libreria no se caiga
-- en la primera linea que use task.*. Si 'task' ya existe (caso
-- normal), no se toca nada de lo que el ejecutor ya provee.
if type(task) ~= "table" then
    task = {}
end
if type(task.wait) ~= "function" then
    task.wait = function(t)
        if type(wait) == "function" then return wait(t) end
        return t or 0
    end
end
if type(task.spawn) ~= "function" then
    task.spawn = function(f, ...)
        if type(spawn) == "function" then
            return spawn(function(...) f(...) end, ...)
        end
        local co = coroutine.create(f)
        local ok, err = coroutine.resume(co, ...)
        if not ok then warn("[Nub] Polyfill task.spawn error:", err) end
        return co
    end
end
if type(task.delay) ~= "function" then
    task.delay = function(t, f, ...)
        local args = {...}
        if type(delay) == "function" then
            delay(t, function() f(table.unpack(args)) end)
        else
            coroutine.wrap(function()
                if type(wait) == "function" then wait(t) end
                f(table.unpack(args))
            end)()
        end
    end
end
if type(task.defer) ~= "function" then
    task.defer = task.spawn
end
if type(task.cancel) ~= "function" then
    task.cancel = function(hilo)
        if type(hilo) == "thread" then
            pcall(function()
                if coroutine.status(hilo) ~= "dead" and coroutine.close then
                    coroutine.close(hilo)
                end
            end)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  CLONADO DEFENSIVO DE TABLAS (evita aliasing entre Flags y el
--  estado interno de controles que usan tablas, ej. Dropdown Multi)
-- ══════════════════════════════════════════════════════════════
-- Lua trabaja tablas por referencia. Sin esto, 'Nub.Flags.MiDropdown'
-- (en un Dropdown Multi) apuntaba a la MISMA tabla que el control usa
-- internamente para pintar sus opciones -- si un script externo hacia
-- 'Nub.Flags.MiDropdown["Espada"] = true' a mano, corrompia el
-- estado visual del control sin pasar por su logica (los botones no
-- se repintaban, Get() podia devolver algo desincronizado del dibujo).
-- 'table.clone' es nativo de Luau, pero por si algun ejecutor viejo no
-- lo expone, hay fallback manual (mismo espiritu que el polyfill de
-- task.* de arriba).
local function clonarTabla(t)
    if type(t) ~= "table" then return {} end
    if type(table.clone) == "function" then return table.clone(t) end
    local copia = {}
    for clave, valor in pairs(t) do copia[clave] = valor end
    return copia
end

local function copiarDefecto(v)
    if type(v) == "table" then return clonarTabla(v) end
    return v
end

local function nuevaTablaElementos()
    return setmetatable({}, {
        __newindex = function(t, flag, elem)
            rawset(t, flag, elem)
            if type(elem) == "table" and type(elem.Get) == "function" then
                local ok, valor = pcall(elem.Get)
                if ok and valor ~= nil then elem._defecto = copiarDefecto(valor) end
            end
        end,
    })
end

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")

local Nub = {}
Nub.Elementos = nuevaTablaElementos()
Nub.Version   = "2.12.5"

-- ══════════════════════════════════════════════════════════════
--  OPCIONES GLOBALES
-- ══════════════════════════════════════════════════════════════
-- Un punto unico para que un script prenda o apague comportamientos
-- globales sin pasar la misma config a cada control. Todas tienen un
-- valor por defecto que conserva el comportamiento de siempre.
Nub.Opciones = {
    -- Estilo por defecto del ColorPicker cuando no se pasa 'Estilo':
    -- "RGB" (3 sliders + hex + muestras, como siempre) o "2D" (cuadrado
    -- saturacion/valor + barra de matiz).
    ColorPickerEstiloPredeterminado = "RGB",

    -- Recordar la posicion de la ventana entre ejecuciones. Se puede
    -- sobreescribir por ventana con CrearVentana({ GuardarPosicion = ... }).
    GuardarPosicionVentana = true,

    -- Mostrar el modal "Eliminar interfaz?" al presionar la X.
    -- En false la X destruye la ventana directo.
    ConfirmarCierre = true,

    -- Tamano inicial de la interfaz y del texto, en % (los mismos valores que
    -- muestran los sliders de la Preinstalada). Es lo que se aplica al abrir la
    -- ventana cuando no hay ajustes guardados. Interfaz: 70 a 130. Texto: 80 a 150.
    EscalaInterfazPredeterminada = 125,
    EscalaTextoPredeterminada = 150,

    -- Borde que llevan las ventanas que no pasan 'Borde' propio (mismo formato
    -- que CrearVentana({ Borde = ... })). nil = el borde de siempre:
    --   Nub.Opciones.BordeVentanaPredeterminado = "tema"
    BordeVentanaPredeterminado = nil,

    -- En true, TM:AplicarTema ajusta la transparencia de los bordes del tema
    -- segun la luminancia del fondo: mas opacos en temas claros, mas sutiles
    -- en oscuros. No cambia color ni grosor. Se aplica en el proximo cambio de tema.
    BordeAdaptativo = false,

    -- En true, algunos controles (Dropdown, ColorPicker) animan su elemento
    -- visible junto con el hover de la fila.
    MicroInteracciones = false,

    -- En true, un click con el mouse sobre una barra (Slider, RangeSlider)
    -- coloca la manija en ese punto y empieza a arrastrar de inmediato.
    -- En false hay que mover el cursor unos pixeles antes de que responda.
    -- El toque (touch) siempre espera el gesto para no pelear con el scroll.
    ClickDirectoEnBarras = true,
}

-- Modo debug: en false (comportamiento de siempre) los errores internos
-- se tragan con pcall y solo quedan en Nub:ObtenerErrores(). En true,
-- ademas se hace warn() inmediato apenas ocurren -- pensado para cuando
-- el propio developer de Nub (o de un script que la usa) esta
-- probando cosas y no quiere tener que llamar ObtenerErrores() a mano
-- despues de cada prueba. No cambia nada del comportamiento hacia el
-- usuario final del script (los pcall siguen protegiendo igual).
Nub.DebugMode = false
Nub.MostrarErroresEnUI = true

-- ══════════════════════════════════════════════════════════════
--  AUTOGUARDADO NATIVO E INTELIGENTE
-- ══════════════════════════════════════════════════════════════
-- Cualquier cambio de flag (mover un slider, activar un toggle,
-- marcar una casilla, etc.) marca "hay cambios sin guardar". Un loop
-- de fondo revisa esa marca cada 10 segundos: si hubo al menos un
-- cambio desde la ultima revision, guarda una vez (silencioso) y
-- limpia la marca; si no hubo nada, no toca el disco. Esto reemplaza
-- al debounce reactivo anterior (que escribia ~0.4s despues de cada
-- cambio): un slider arrastrado 200 veces en 3 segundos ya no puede
-- disparar una escritura por si solo, sin importar que tan rapido se
-- mueva -- como mucho se guarda una vez cada 10s mientras haya
-- actividad. La ventana de riesgo de perder el ultimo cambio (si el
-- juego crashea o el script se re-ejecuta) sube de ~0.4s a ~10s; el
-- boton manual de "Guardar" (ver mas abajo) sigue disponible para
-- quien quiera forzar un guardado inmediato sin esperar el ciclo.
local ventanaActivaGuardado = nil
local hayCambiosSinGuardar  = false
local loopAutoguardadoActivo = false

-- Guard interno (no expuesto en la API publica, para que ningun
-- script externo pueda dejarlo trabado en 'true' por error): mientras
-- SM:Cargar/CargarSilencioso/CargarUI estan restaurando flags desde
-- un archivo, cada 'Nub.Flags[flag] = valor' pasa por el mismo
-- proxy que usa el usuario al tocar un control -- sin este guard,
-- restaurar 30 flags guardados marcaba "hay cambios sin guardar" 30
-- veces, y el loop de autoguardado de 10s terminaba reescribiendo
-- el mismo archivo que se acababa de leer, sin que el usuario
-- hubiera tocado nada.
local _cargandoDesdeArchivo = false

local function marcarCambioPendiente()
    if _cargandoDesdeArchivo then return end
    hayCambiosSinGuardar = true
end

-- Arranca el loop de autoguardado UNA sola vez por ventana activa
-- (CrearVentana lo llama). Se detiene solo cuando la ventana se
-- destruye, via el mismo mecanismo de limpieza que usa el resto de
-- hilos de fondo de la libreria (RegistrarHilo).
local function iniciarLoopAutoguardado()
    if loopAutoguardadoActivo then return end
    loopAutoguardadoActivo = true
    Nub:RegistrarHilo(task.spawn(function()
        while loopAutoguardadoActivo do
            task.wait(10)
            if hayCambiosSinGuardar and ventanaActivaGuardado and ventanaActivaGuardado.NombreConfig and Nub.SaveManager then
                hayCambiosSinGuardar = false
                pcall(function()
                    Nub.SaveManager:GuardarSilencioso(ventanaActivaGuardado.NombreConfig)
                end)
            end
        end
    end))
end

-- Nub.Flags es una tabla "proxy": leerla se comporta como una
-- tabla normal, pero CUALQUIER escritura (incluida la actualizacion
-- de un flag que ya existia, no solo su creacion) dispara el
-- guardado automatico. Esto cubre todos los controles sin tener que
-- tocar cada uno por separado.
-- Ventanas que tienen un selector de temas en la barra lateral, para que
-- TM:AplicarTema pueda sincronizarlas sin importar desde donde se aplico
-- el tema (el propio selector, el Dropdown de la pestaña Preinstalada,
-- o una llamada manual del developer).
local _ventanasConSelectorTemas = setmetatable({}, {__mode = "k"})

local _flagsReales = {}

-- Flags que NUNCA deben terminar en el .json de configuracion, aunque
-- vivan dentro de _flagsReales para poder leerse con ObtenerFlag().
-- Hoy solo lo usa Label (ver mas abajo) -- un Label es un valor de
-- SOLO LECTURA/visualizacion (FPS, memoria, vida del objetivo,
-- distancia, combo...), no un ajuste que el usuario configura, asi
-- que no tiene sentido guardarlo ni restaurarlo entre ejecuciones.
local _flagsNoPersistir = {}

-- Flags que pertenecen a la pestaña "Preinstalada" (tema, buscador,
-- nombre para guardar perfil, etc.) -- ajustes DE LA INTERFAZ, no del
-- script/juego. Se guardan en un archivo propio (ver
-- SM:GuardarUI/CargarUI mas abajo) para que el sistema de PERFILES
-- (SM:Guardar/Cargar/Listar/Eliminar) nunca los incluya ni los
-- sobreescriba. Un flag se marca asi:
--     _flagsUI[flag] = true
local _flagsUI = {}

-- ══════════════════════════════════════════════════════════════
--  REGISTRO GLOBAL DE KEYBINDS (deteccion de conflictos)
-- ══════════════════════════════════════════════════════════════
-- Cada Seccion:Keybind se anota aca al crearse. Esto NO se usa para
-- disparar nada -- cada Keybind sigue escuchando su propio InputBegan
-- de forma independiente -- es solo para poder avisarle al usuario si
-- dos Keybinds terminan compartiendo la misma combinacion de tecla.
-- A proposito NO se cambia ni se desactiva automaticamente ninguno de
-- los dos: ambos quedan asignados y ambos Callbacks se van a seguir
-- disparando; el aviso es para que el usuario decida cual reasignar.
local _keybindsRegistrados = {}

-- Descompone un valor de Keybind (Enum.KeyCode suelto en modo simple,
-- o tabla {KeyCode=,Ctrl=,Shift=,Alt=} en modo ConModificadores) en
-- sus 4 partes, siempre con los modificadores normalizados a boolean.
local function _descomponerTecla(v)
    if typeof(v) == "table" then
        return v.KeyCode, v.Ctrl or false, v.Shift or false, v.Alt or false
    end
    return v, false, false, false
end

local function _formatoTecla(keyCode, ctrl, shift, alt)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then return "Ninguna" end
    local partes = {}
    if ctrl then table.insert(partes, "Ctrl") end
    if shift then table.insert(partes, "Shift") end
    if alt then table.insert(partes, "Alt") end
    table.insert(partes, keyCode.Name)
    return table.concat(partes, "+")
end

-- Dos Keybinds "conflictan" si presionar lo mismo dispara a los dos:
-- misma KeyCode Y mismos modificadores (tratar "sin modificador" como
-- false parejo, sin importar si el Keybind usa ConModificadores o no,
-- para que un Keybind simple en "F" SI conflictue con un
-- ConModificadores asignado como "F" sin ningun modificador).
local function _teclasEnConflicto(a, b)
    local kA, cA, sA, aA = _descomponerTecla(a)
    local kB, cB, sB, aB = _descomponerTecla(b)
    if not kA or not kB then return false end
    if kA == Enum.KeyCode.Unknown or kB == Enum.KeyCode.Unknown then return false end
    return kA == kB and cA == cB and sA == sB and aA == aB
end

-- Revisa el registro global y avisa (SIN modificar nada) si
-- 'nuevoValor', recien elegido para 'entryPropio', choca con la tecla
-- ya asignada de otro Keybind existente. Se llama unicamente en los
-- puntos donde el usuario efectivamente ACABA de capturar/elegir una
-- tecla nueva -- nunca para Sets programaticos ni para el "disparo" de
-- accion directa en modo tactil (ahi no se esta reasignando nada).
local function _revisarConflictoKeybind(entryPropio, nuevoValor)
    local conflictos = {}
    for _, entrada in ipairs(_keybindsRegistrados) do
        if entrada ~= entryPropio then
            local okValor, valorAjeno = pcall(entrada.GetValor)
            if okValor and _teclasEnConflicto(nuevoValor, valorAjeno) then
                table.insert(conflictos, entrada.texto or "Keybind")
            end
        end
    end
    if #conflictos > 0 then
        local k, c, s, a = _descomponerTecla(nuevoValor)
        pcall(function()
            Nub:Notificar({
                Titulo   = "⚠️ Tecla en uso",
                Texto    = "'" .. _formatoTecla(k, c, s, a) .. "' ya esta asignada a: " .. table.concat(conflictos, ", "),
                Duracion = 4,
            })
        end)
    end
end

-- Se llama UNA VEZ después de cargar un perfil guardado (perfil de
-- script o ajustes de UI). Recorre todos los Keybinds registrados
-- en la ventana activa y agrupa aquellos que comparten la misma
-- combinación de tecla, disparando UNA sola notificación por grupo
-- conflictivo (en vez de una por Keybind involucrado, que sería
-- ruidoso y repetitivo).
--
-- Diferencia con '_revisarConflictoKeybind': esa función reporta el
-- conflicto de UN Keybind a la vez, en el momento en que el usuario
-- acaba de reasignar una tecla. Esta es para el caso "cargué un
-- archivo que ya tenía conflictos guardados de una sesión anterior":
-- reporta todos los grupos de una sola pasada, sin que ningún
-- Keybind tenga que estar "siendo reasignado" en ese momento.
local function _revisarConflictosAlCargar()
    if #_keybindsRegistrados < 2 then return end

    -- Agrupa por firma única de tecla (KeyCode + modificadores).
    -- La clave es string para poder usar la tabla como diccionario
    -- sin depender del hash interno de EnumItems.
    local porFirma = {}
    for _, entrada in ipairs(_keybindsRegistrados) do
        local ok, valor = pcall(entrada.GetValor)
        if ok then
            local k, c, s, a = _descomponerTecla(valor)
            if k and k ~= Enum.KeyCode.Unknown then
                local firma = k.Name
                    .. "|" .. tostring(c)
                    .. "|" .. tostring(s)
                    .. "|" .. tostring(a)
                porFirma[firma] = porFirma[firma] or {
                    k = k, c = c, s = s, a = a, textos = {},
                }
                table.insert(porFirma[firma].textos, entrada.texto or "Keybind")
            end
        end
    end

    for _, grupo in pairs(porFirma) do
        if #grupo.textos >= 2 then
            pcall(function()
                Nub:Notificar({
                    Titulo   = "⚠️ Teclas en conflicto",
                    Texto    = "'" .. _formatoTecla(grupo.k, grupo.c, grupo.s, grupo.a)
                               .. "' está asignada a: " .. table.concat(grupo.textos, ", "),
                    Duracion = 8,
                })
            end)
        end
    end
end

Nub.Flags = setmetatable({}, {
    __index = _flagsReales,
    __newindex = function(_, clave, valor)
        -- Si el valor es EXACTAMENTE el mismo que ya estaba guardado
        -- (mismo numero, string, bool, Color3 o EnumItem), no tiene
        -- sentido programar una escritura a disco -- esto evitaba que
        -- por ejemplo un Slider que dispara Set() en bucle con el
        -- mismo numero (restaurado por SaveManager, o un script
        -- externo llamando :Set() repetidamente) generara escrituras
        -- y hilos de guardado de forma innecesaria.
        --
        -- Excepcion: tablas (ej. la seleccion de un Dropdown Multi).
        -- Se comparan siempre como "cambiaron" sin mirar el contenido:
        -- desde el fix de clonarTabla (ver mas arriba), cada escritura
        -- de una tabla llega aca como una copia NUEVA (referencia
        -- distinta a la anterior), asi que un == siempre daria "distinto"
        -- de cualquier forma -- este 'if' solo evita el costo de andar
        -- comparando tablas campo por campo para llegar a esa misma
        -- conclusion.
        if type(valor) ~= "table" and _flagsReales[clave] == valor then
            return
        end
        _flagsReales[clave] = valor
        marcarCambioPendiente()
        if Nub.Eventos then
            Nub.Eventos.FlagCambiada:Fire(clave, valor)
        end
    end,
})

local Utils = {}

-- ══════════════════════════════════════════════════════════════
--  ESCALA DE TEXTO (independiente del UIScale general)
-- ══════════════════════════════════════════════════════════════
-- El UIScale general escala TODO (tamaños, espaciados, iconos),
-- lo cual a veces se ve raro si solo se quiere texto mas grande/chico.
-- Este sistema guarda el tamaño BASE de cada texto creado con
-- Utils.Texto y permite reescalarlo por categoria (pestañas o texto
-- general) sin tocar el resto del layout.
local registroEscalaTexto = {}

-- ── Limpieza de registros al destruirse una instancia ───────────
-- Nub:Registrar y registrarEscalaTexto guardan cada instancia en un
-- array global. Las que se destruyen en plena ejecucion (tarjetas de
-- notificacion, chips que se redibujan, dialogos...) quedaban ahi para
-- siempre, referenciadas y sin liberar. Ahora cada entrada se marca como
-- muerta en O(1) al destruirse la instancia, y el array se compacta de
-- una sola pasada cuando hay suficientes muertas -- sin table.find por
-- cada destruccion (que seria O(n^2) al destruir una ventana entera).
local function compactarRegistro(registro)
    local j = 0
    for i = 1, #registro do
        local entrada = registro[i]
        if not entrada.muerta then
            j = j + 1
            registro[j] = entrada
        end
    end
    for i = #registro, j + 1, -1 do registro[i] = nil end
end

-- Las conexiones de una instancia destruida quedan desconectadas pero su
-- entrada sigue en _G.Nub_InstanciaActiva.Conexiones: se podan igual.
local function podarConexionesMuertas()
    local activa = _G.Nub_InstanciaActiva
    if not activa then return end
    local lista = activa.Conexiones
    local j = 0
    for i = 1, #lista do
        local conexion = lista[i]
        if conexion.Connected ~= false then
            j = j + 1
            lista[j] = conexion
        end
    end
    for i = #lista, j + 1, -1 do lista[i] = nil end
end
local muertosEscalaTexto = 0
local escalasTexto = { tabs = 1, general = 1, titulo = 1 }

-- Calcula el tamaño de fuente que le corresponde a una entrada del
-- registro: 'base * factor de escala', con el piso de siempre (9px en
-- touch sin teclado, 6px en el resto). Si la entrada es 'truncable'
-- (viene de un Utils.Texto con Truncar = true -- texto de una sola
-- linea en un ancho fijo, el tipo que antes se cortaba con "..."),
-- ademas se reduce PUNTUALMENTE por debajo de ese tamaño "ideal" hasta
-- que el texto entra en el ancho real disponible. Nunca baja del piso
-- -- un texto verdaderamente imposible de hacer entrar (una oracion
-- larga en un espacio muy chico) termina truncado igual, como ultimo
-- recurso, no roto ni ilegible del todo.
-- Si 'inst' o algun ancestro GuiObject tiene Visible = false, no hay
-- layout posible: AbsoluteSize va a ser 0 hasta que se vuelva visible.
-- Reintentar en ese caso es un loop infinito (task.defer que nunca
-- converge) -- cuando el ancestro se muestre, AbsoluteSize cambia
-- solo y el listener ya conectado en registrarEscalaTexto dispara el
-- recalculo, sin necesidad de seguir reintentando a ciegas.
local function hayAncestroOculto(inst)
    local actual = inst
    while actual do
        if actual:IsA("GuiObject") and not actual.Visible then return true end
        actual = actual.Parent
    end
    return false
end

local function calcularYAplicarTamano(entrada)
    local inst = entrada.instancia
    if not (inst and inst.Parent) then return end
    local factor = escalasTexto[entrada.categoria] or 1
    local piso = (Nub.Capacidades and not Nub.Capacidades.Teclado) and 9 or 6
    local objetivo = math.max(piso, math.floor(entrada.base * factor + 0.5))

    if not entrada.truncable then
        pcall(function() inst.TextSize = objetivo end)
        return
    end

    local anchoDisponible = inst.AbsoluteSize.X
    if anchoDisponible <= 0 then
        -- Caso A: ancestro oculto (seccion colapsada, tab inactivo).
        -- No reintentar: cuando se muestre, AbsoluteSize cambia solo y
        -- el listener ya conectado recalcula (ver hayAncestroOculto).
        if hayAncestroOculto(inst) then return end
        -- Caso B: layout todavia no calculado (primer frame tras
        -- crearse). Reintentar el proximo frame, con techo de
        -- seguridad por si el caso A no lo agarra (ej. orden de
        -- Parent/Visible atipico) para nunca repetir indefinido.
        entrada.reintentos = (entrada.reintentos or 0) + 1
        if entrada.reintentos > 10 then return end
        task.defer(calcularYAplicarTamano, entrada)
        return
    end
    entrada.reintentos = 0

    local altoDisponible = inst.AbsoluteSize.Y > 0 and inst.AbsoluteSize.Y or 100
    local tamano = objetivo
    while tamano > piso do
        local okMedida, ancho = pcall(function()
            return TextService:GetTextSize(inst.Text, tamano, inst.Font, Vector2.new(10000, altoDisponible)).X
        end)
        if not okMedida or ancho <= anchoDisponible then break end
        tamano = tamano - 1
    end
    pcall(function() inst.TextSize = tamano end)
end

-- 'truncable' (nuevo, opcional): true cuando la instancia viene de un
-- Utils.Texto con Truncar = true. Activa el ajuste automatico de
-- ancho descripto arriba, ademas del factor de escala manual normal.
local function registrarEscalaTexto(instancia, tamanoBase, categoria, truncable)
    categoria = categoria or "general"
    local entrada = {
        instancia = instancia, base = tamanoBase, categoria = categoria,
        truncable = truncable or false,
        reintentos = 0,
    }
    table.insert(registroEscalaTexto, entrada)
    instancia.Destroying:Connect(function()
        entrada.muerta = true
        muertosEscalaTexto = muertosEscalaTexto + 1
        if muertosEscalaTexto >= 64 and muertosEscalaTexto * 4 >= #registroEscalaTexto then
            muertosEscalaTexto = 0
            compactarRegistro(registroEscalaTexto)
            podarConexionesMuertas()
        end
    end)

    if truncable then
        -- Reajustar cada vez que el ancho REAL disponible cambia (la
        -- ventana se redimensiona, el usuario mueve el slider de
        -- ancho/escala, cambia de orientacion, etc.) -- asi el ajuste
        -- se recalcula solo, sin depender de que algun otro sistema
        -- avise explicitamente que el layout cambio.
        local esperando, repetir = false, false
        local function alCambiarTamano()
            if esperando then repetir = true return end
            esperando = true
            calcularYAplicarTamano(entrada)
            task.delay(0.03, function()
                esperando = false
                if repetir then
                    repetir = false
                    calcularYAplicarTamano(entrada)
                end
            end)
        end
        Nub:RegistrarConexion(
            instancia:GetPropertyChangedSignal("AbsoluteSize"):Connect(alCambiarTamano)
        )
        -- Y tambien si el TEXTO cambia despues (ej. Label:Set() con un
        -- valor mas largo o mas corto que el original).
        Nub:RegistrarConexion(
            instancia:GetPropertyChangedSignal("Text"):Connect(function()
                calcularYAplicarTamano(entrada)
            end)
        )
        -- Primer ajuste en modo defer: AbsoluteSize todavia no es el
        -- real en el mismo frame en que se crea la instancia.
        task.defer(calcularYAplicarTamano, entrada)
    elseif escalasTexto[categoria] ~= 1 then
        calcularYAplicarTamano(entrada)
    end
end

local function aplicarEscalaTexto(categoria, factor)
    escalasTexto[categoria] = factor
    for _, entrada in ipairs(registroEscalaTexto) do
        if entrada.categoria == categoria then
            calcularYAplicarTamano(entrada)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  CONTADOR DE INSTANCIAS (para el indicador de "Salud")
-- ══════════════════════════════════════════════════════════════
-- Lleva la cuenta de instancias de UI vivas sin recorrer el arbol de
-- la GUI: sube al crear (Utils.Frame/Texto/BotonBase, los 3 puntos
-- que concentran la inmensa mayoria de nodos de UI reales que crea
-- el core) y baja solo, via .Destroying de cada instancia.
local _contadorInstanciasUI = 0

local function contarInstanciaCreada(inst)
    _contadorInstanciasUI = _contadorInstanciasUI + 1
    inst.Destroying:Connect(function()
        _contadorInstanciasUI = _contadorInstanciasUI - 1
    end)
    return inst
end

-- ── Esquinas y bordes ───────────────────────────────────────────
function Utils.Corner(padre, radio)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radio or 6)
    c.Parent = padre
    return c
end

function Utils.Stroke(padre, color, grosor, transparencia)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(7, 27, 1)
    s.Thickness = grosor or 1
    s.Transparency = transparencia or 0
    s.Parent = padre
    return s
end

-- ── Hover ────────────────────────────────────────────────────────
-- Da feedback visual al pasar el cursor: aclara ligeramente el
-- BackgroundColor3 de 'objetoColor' durante 0.15s, y lo devuelve a su
-- color original al salir. 'objetoEventos' es quien escucha
-- MouseEnter/MouseLeave (puede ser el mismo objetoColor, o un boton
-- transparente que esta ENCIMA de la fila que sí tiene color, como
-- pasa en Dropdown/ColorPicker).
--
-- El color "original" se relee en cada MouseEnter (no se guarda una
-- sola vez) para que funcione bien incluso si el usuario cambia de
-- tema mientras el cursor no esta encima del control.
-- 'obtenerColorBase' (opcional): funcion que devuelve cual DEBERIA
-- ser el color de fondo "en reposo" en este instante. Sin ella, al
-- salir el cursor/dedo se vuelve al color que habia AL ENTRAR
-- ('colorOriginal', capturado una sola vez) -- para casi todos los
-- controles esta bien, porque su color de reposo no cambia mientras
-- el cursor esta encima. Pero en controles cuyo color de fondo
-- representa un ESTADO que puede cambiar durante el hover mismo (ej.
-- el boton de una opcion de RadioGroup, que pasa de 'Entrada' a
-- 'Accent' apenas se lo toca), restaurar el valor viejo capturado en
-- MouseEnter pisa el color de estado nuevo: en touch, MouseEnter (boton
-- todavia no seleccionado, guarda 'Entrada') y MouseLeave (casi
-- inmediato al soltar el dedo, YA seleccionado) pueden ocurrir
-- alrededor del mismo click que cambia el estado, y sin este parametro
-- el MouseLeave revierte visualmente la seleccion recien hecha aunque
-- el flag interno SI haya cambiado -- bug real reportado en RadioGroup
-- en mobile (el foco/luz de la opcion elegida no se actualizaba).
-- Con 'obtenerColorBase', tanto Enter como Leave preguntan cual es el
-- color correcto EN ESE INSTANTE en vez de confiar en un snapshot.
function Utils.Hover(objetoEventos, objetoColor, intensidad, duracion, obtenerColorBase, alCambiarHover)
    if not objetoEventos or not objetoColor then return end
    objetoColor = objetoColor or objetoEventos
    -- Nub.Motion.HoverIntensidad (0.20) y Nub.Motion.Hover (0.12,
    -- duracion) son los defaults reales -- se leen aca en vez de
    -- hardcodear los numeros, para que cambiarlos en un solo lugar
    -- (Nub.Motion) alcance para todos los Hover de la libreria que
    -- no pasen sus propios valores explicitos.
    intensidad = intensidad or Nub.Motion.HoverIntensidad
    duracion = duracion or Nub.Motion.Hover

    -- 'enHover' + resetear 'colorOriginal' a nil en cada Leave: en
    -- touch, MouseEnter puede disparar VARIAS veces seguidas sin un
    -- MouseLeave real entre medio (mantener el dedo presionado, o
    -- tocar rapido varias veces) -- comportamiento distinto al mouse
    -- en PC, donde Enter y Leave alternan limpio. Sin este guard, cada
    -- MouseEnter releia 'objetoColor.BackgroundColor3' (que ya estaba
    -- aclarado por el hover anterior) y volvia a aclarar ENCIMA de eso,
    -- acumulando hasta blanco puro y sin poder restaurar el color
    -- original real (bug reportado: "el control queda quemado en
    -- blanco" en mobile). Con el guard, un MouseEnter mientras ya
    -- estamos en hover simplemente no hace nada -- el color solo se
    -- captura una vez, al entrar de verdad.
    local enHover = false
    local colorOriginal = nil
    local colorReposo = nil
    local reposoVigenteHasta = 0

    Nub:RegistrarConexion(objetoEventos.MouseEnter:Connect(function()
        if enHover then return end
        enHover = true
        pcall(function()
            local base = obtenerColorBase and obtenerColorBase()
            if not base then
                if colorReposo and os.clock() < reposoVigenteHasta then
                    base = colorReposo
                else
                    base = objetoColor.BackgroundColor3
                end
            end
            colorReposo = base
            colorOriginal = base
            Utils.Tween(objetoColor, {
                BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), intensidad)
            }, duracion, Nub.Motion.EaseSuave, Enum.EasingDirection.Out)
        end)
        if alCambiarHover then pcall(alCambiarHover, true) end
    end))
    Nub:RegistrarConexion(objetoEventos.MouseLeave:Connect(function()
        if not enHover then return end
        enHover = false
        pcall(function()
            local destino = obtenerColorBase and obtenerColorBase() or colorOriginal or colorReposo
            if not destino then return end
            colorReposo = destino
            reposoVigenteHasta = os.clock() + duracion + 0.08
            Utils.Tween(objetoColor, {BackgroundColor3 = destino}, duracion, Nub.Motion.EaseSuave, Enum.EasingDirection.Out)
        end)
        colorOriginal = nil
        if alCambiarHover then pcall(alCambiarHover, false) end
    end))
end

-- ── Feedback visual de click (micro-interacción) ─────────────────
-- Aplica un "press" visual al objeto que el usuario VE (no al hitbox
-- invisible): el objeto se achica a 97% durante 0.06s y vuelve a 100%
-- con un rebote Back Out en 0.14s. Es lo que hace que los controles se
-- sientan "táctiles" en vez de solo cambiar color al tocarlos.
--
-- Usa un UIScale dedicado (no anima Size directamente) por dos motivos:
--   1. Animar Size pelearia con AnchorPoint y con los tweens de layout
--      que ya usan varios controles (Dropdown, ColorPicker).
--   2. Un UIScale aditivo no interfiere con el UIScale de compensacion
--      de tamaño que ya usan btnCerrar/btnMin -- Roblox los multiplica
--      SIEMPRE QUE sean instancias distintas: si el objeto YA tiene un
--      UIScale hijo de OTRO sistema (ej. crearCompensadorTamano), NO se
--      crea uno segundo -- se reutiliza ese mismo, para evitar dos
--      UIScale simultaneos en el mismo objeto (comportamiento no
--      garantizado en Roblox: puede que solo se aplique uno de los
--      dos). Hoy (btnCerrar/btnMin no pasan por Utils.ClickConfiable)
--      este caso no se da, pero el chequeo es defensivo por si algun
--      control futuro combina ambos sistemas.
--
-- El UIScale se crea lazy en el primer click y queda vivo en el objeto.
-- El tween de vuelta es idempotente: si el usuario hace doble click, el
-- segundo Tween cancela el anterior (Utils.Tween lo maneja) y arranca
-- otra vez desde 0.97 -- sin acumulacion de deriva.
function Utils.ClickFeedback(objetoVisual)
    if not objetoVisual or not objetoVisual.Parent then return end
    local escala = objetoVisual:FindFirstChild("__Nub_ClickScale")
    if not escala then
        -- Reusa un UIScale ajeno si existe, salvo el de entrada de la
        -- pastilla (__Nub_EntradaScale): ese lo maneja su propia animacion.
        for _, hijo in ipairs(objetoVisual:GetChildren()) do
            if hijo:IsA("UIScale") and hijo.Name ~= "__Nub_EntradaScale" then
                escala = hijo
                break
            end
        end
    end
    if not escala then
        escala = Instance.new("UIScale")
        escala.Name = "__Nub_ClickScale"
        escala.Scale = 1
        escala.Parent = objetoVisual
    end
    escala.Scale = 0.97
    Utils.Tween(escala, {Scale = 1}, Nub.Motion.Press, Nub.Motion.EasePop, Enum.EasingDirection.Out)
end

-- ── Click confiable dentro de scroll ─────────────────────────────
-- Sustituto de 'objeto.MouseButton1Click:Connect(callback)' pensado
-- para controles que viven dentro de un ScrollingFrame (todas las
-- paginas de tabs lo son): con MouseButton1Click puro, Roblox a veces
-- "come" el primer tap pensando que puede ser el inicio de un scroll,
-- y el usuario tiene que tocar dos veces para que registre. Esto usa
-- Down+Up propios: se guarda la posicion del Down, y el Up solo
-- dispara el callback si el dedo/cursor no se movio mas del umbral
-- (misma logica que ya usa el tooltip para distinguir "tap" de "estoy
-- scrolleando"). Se registra con RegistrarConexion, igual que
-- cualquier otra conexion de la libreria.
-- 'objetoVisual' (opcional): el elemento que el usuario VE, para aplicar
-- el feedback de click (Utils.ClickFeedback). Si no se pasa, se asume
-- que 'objeto' es el visual. Se necesita explícito en los call-sites
-- que escuchan sobre un hitbox ampliado invisible (ver Utils.HitboxAmpliado):
-- en esos casos 'objeto' es el hitbox y 'objetoVisual' es el control real
-- que esta debajo -- sin este parámetro, el UIScale del feedback se
-- aplicaría sobre el hitbox invisible y el usuario no vería nada.
function Utils.ClickConfiable(objeto, callback, objetoVisual)
    -- Umbral mas permisivo en touch (18px) que en mouse (10px): un tap
    -- en celular se desvia facil 15-20px entre el Down y el Up sin que
    -- el usuario lo perciba como scroll, y con el umbral fijo de 10px
    -- ese movimiento normal se descartaba como "fue un scroll" -- un
    -- factor real detras de RadioGroup y otros controles sintiendose
    -- poco responsivos en mobile. 18px sigue siendo chico como para
    -- confundir un scroll real con un tap, pero no es una garantia
    -- absoluta (riesgo bajo, no nulo).
    local UMBRAL_MOVIMIENTO_CLICK = Nub.Capacidades.EsTactil and 18 or 10
    local posDown = nil
    Nub:RegistrarConexion(objeto.MouseButton1Down:Connect(function(x, y)
        posDown = Vector2.new(x, y)
        Utils.ClickFeedback(objetoVisual or objeto)
    end))
    Nub:RegistrarConexion(objeto.MouseButton1Up:Connect(function(x, y)
        if not posDown then return end
        local movio = (Vector2.new(x, y) - posDown).Magnitude > UMBRAL_MOVIMIENTO_CLICK
        posDown = nil
        if movio then return end -- fue un scroll, no un click
        callback()
    end))
end

-- ── Hitbox ampliado (area de toque mas grande que el visual) ─────
-- Crea un TextButton HIJO de 'boton' (no hermano), invisible,
-- extendido 'padding' px mas alla de cada borde de 'boton' -- asi es
-- el que efectivamente recibe el click/tap, mientras 'boton' se deja
-- sin tocar (mismo tamaño, mismo aspecto visual, cero cambio para
-- quien mira la interfaz).
--
-- Tiene que ser HIJO, no hermano: la mayoria de estos botones viven
-- dentro de un UIListLayout/UIGridLayout (opciones de RadioGroup,
-- lista de Dropdown, barra de tabs) que organiza TODOS sus hijos
-- directos como celdas del layout. Un hermano extra ahi adentro
-- seria tratado como una celda mas -- rompiendo el espaciado visual
-- de toda la fila/lista. Como hijo de 'boton', es un NIETO del
-- contenedor con layout: invisible para ese layout, que solo mira
-- sus hijos directos. Roblox no recorta hijos mas grandes que su
-- padre salvo que el padre tenga ClipsDescendants = true (ninguno de
-- los botones de la libreria lo activa), asi que el hitbox puede
-- extenderse simetricamente mas alla de 'boton' sin problema.
--
-- Tiene que ser un TextButton (no un Frame simple, aunque sea
-- invisible): Utils.ClickConfiable y Utils.Hover dependen de señales
-- que SOLO existen en botones (MouseButton1Down/Up, MouseEnter/Leave)
-- -- un Frame comun no las tiene. Mismo motivo por el que el hitbox
-- del Slider (precedente mas viejo, ver crearBarraArrastrable) usa
-- InputBegan en vez de estas señales: ese caso escucha un Frame a
-- proposito porque necesita arrastre continuo, no un click puntual,
-- y no vive dentro de ningun UIListLayout.
--
-- Devuelve 'boton' sin tocar si padding <= 0 o si no hay 'boton'.
--
-- Uso tipico:
--   local hitbox = Utils.HitboxAmpliado(boton, 5)
--   Utils.ClickConfiable(hitbox, callback)     -- el click escucha en 'hitbox'
--   Utils.Hover(hitbox, boton, ...)            -- el hover tambien escucha en 'hitbox', pero PINTA 'boton'
function Utils.HitboxAmpliado(boton, padding)
    padding = padding or 0
    if padding <= 0 or not boton then return boton end

    local hitbox = Utils.BotonBase({
        Padre = boton,
        Size = UDim2.new(1, padding * 2, 1, padding * 2),
        Posicion = UDim2.new(0, -padding, 0, -padding),
        Transparencia = 1, Radio = false,
    })
    hitbox.ZIndex = boton.ZIndex + 1
    return hitbox
end

-- ── Gradiente de acento ──────────────────────────────────────────
-- (definicion movida mas abajo, justo despues de donde se declara
-- la variable local 'Theme' -- ver mas adelante en el archivo)

-- ── Nub Motion ────────────────────────────────────────────────
-- Duraciones de animacion con nombre, para que todos los Tweens de
-- la libreria (y los que arme el desarrollador que la usa) sigan la
-- misma personalidad de movimiento en vez de numeros sueltos.
Nub.Motion = {
    -- DURACIONES. Todo tween de la libreria sale de aca (no hay numeros sueltos).
    Directo  = 0,    -- feedback directo: el control responde al dedo/cursor. Sin tween.
    Press    = 0.14, -- pop de vuelta tras un click (Utils.ClickFeedback)
    Hover    = 0.12, -- cambios de color/borde al pasar el cursor, casillas, flashes de estado
    HoverIntensidad = 0.20, -- cuanto se aclara un control en hover (0-1); default de Utils.Hover
    FlashIn  = 0.08, -- que tan rapido "pega" el destello de validacion (Utils.FlashFeedback)
    FlashOut = 0.35, -- que tan rapido se apaga de vuelta al color normal
    Expand   = 0.18, -- abrir/cerrar Dropdown, ColorPicker, seccion, flecha, tooltip, pop de tags/chips
    Modal    = 0.25, -- entrada de modales, notificaciones, apertura/restauracion de ventana, splash
    Page     = 0.22, -- cambio de pestaña / slide de contenido / contador de valor
    Spin     = 0.6,  -- una vuelta de spinner de carga

    -- CURVAS. Entrar = Quart Out (nitido). Salir = Quad In (acelera hacia afuera).
    -- Pop = Back Out (rebote sutil). Suave = Sine (cambios continuos).
    EaseEntrar = Enum.EasingStyle.Quart, -- usar con EasingDirection.Out
    EaseSalir  = Enum.EasingStyle.Quad,  -- usar con EasingDirection.In
    EasePop    = Enum.EasingStyle.Back,  -- pops y rebotes
    EaseSuave  = Enum.EasingStyle.Sine,  -- hovers, cambios continuos
    EaseLineal = Enum.EasingStyle.Linear, -- spinners, progreso circular
}

-- Colores fijos para Utils.FlashFeedback, declarados ACA (bien arriba
-- del archivo, junto al resto de constantes de motion/timing) y no
-- reusando COLORES_TIPO_NOTIF (que vive mas abajo, cerca del sistema
-- de notificaciones) a proposito: varios de los lugares que llaman a
-- FlashFeedback (crearBarraArrastrable, Slider, Input, ColorPicker)
-- estan definidos ANTES que COLORES_TIPO_NOTIF en el archivo, y
-- referenciar un 'local' declarado mas abajo desde código mas arriba
-- lo resuelve como variable GLOBAL (nil) en Lua -- el mismo tipo de
-- bug que ya paso una vez con VERSION_FORMATO_GUARDADO. Declarar
-- constantes propias aca, antes de todo lo que las usa, evita el
-- problema de raiz en vez de tener que acordarse del orden cada vez.
local COLOR_FLASH_EXITO = Color3.fromRGB(46, 204, 113)
local COLOR_FLASH_ERROR = Color3.fromRGB(231, 76, 60)

-- ── Destello de validacion (feedback semantico) ──────────────────
-- Breve flash de color sobre el fondo de un TextBox: verde si el
-- valor que se acaba de escribir fue aceptado, rojo si no. Pensado
-- para el patron "el usuario escribe algo, presiona Enter, y el
-- control revierte en silencio si no era valido" -- sin este destello
-- no hay ninguna señal de que el Enter se registro, ni de si el valor
-- se acepto o se rechazo (bug de UX real: Slider, Input con
-- Tipo=number/pattern, y el campo Hex de ColorPicker lo sufrian).
--
-- 'colorNormal' es el color de reposo real al que volver despues del
-- destello (normalmente Theme.Entrada) -- se pasa explicito en vez de
-- leerse de 'instancia.BackgroundColor3' en el momento del llamado,
-- para no capturar un color a mitad de otra animacion en curso (mismo
-- motivo por el que Utils.Hover tiene su propio 'colorOriginal').
function Utils.FlashFeedback(instancia, exito, colorNormal)
    if not instancia or not instancia.Parent then return end
    local colorFlash = exito and COLOR_FLASH_EXITO or COLOR_FLASH_ERROR
    pcall(function()
        Utils.Tween(instancia, {BackgroundColor3 = colorFlash}, Nub.Motion.FlashIn)
        task.delay(Nub.Motion.FlashIn, function()
            pcall(function()
                Utils.Tween(instancia, {BackgroundColor3 = colorNormal}, Nub.Motion.FlashOut)
            end)
        end)
    end)
end

-- ── Tween corto ─────────────────────────────────────────────────
-- Utils.Tween(objeto, {Propiedad=valor,...}, tiempo, estilo, direccion)
--
-- Registro del ultimo Tween activo POR OBJETO+PROPIEDADES (tabla
-- debil por clave externa: si el objeto se destruye, se libera solo
-- con el GC). Antes, si dos Tweens se disparaban sobre el mismo
-- objeto casi al mismo tiempo Y LA MISMA PROPIEDAD (ej. Hover que
-- entra y sale rapido, o un click rapido en un Boton), ambos
-- quedaban corriendo en paralelo peleando por esa propiedad --
-- resultado: parpadeos o el objeto "vibrando" entre dos valores.
-- Si ya hay un Tween corriendo sobre EXACTAMENTE el mismo conjunto
-- de propiedades en ese objeto, se cancela antes de arrancar el
-- nuevo (Cancel() lo deja en su posicion actual, punto de partida
-- logico para la animacion siguiente). La clave de cache incluye
-- tanto el objeto como los nombres de las propiedades animadas, asi
-- que animar 'Size' y animar 'BackgroundColor3' del mismo objeto
-- (por ejemplo, Utils.Hover sobre el color y hacerExpandible sobre
-- el tamaño del mismo Frame) no se cancelan entre si -- solo se
-- cancela cuando de verdad es la MISMA propiedad.
local tweensActivos = setmetatable({}, {__mode = "k"})

local function clavePropiedades(props)
    local nombres = {}
    for nombre in pairs(props) do table.insert(nombres, nombre) end
    table.sort(nombres)
    return table.concat(nombres, ",")
end

function Utils.Tween(obj, props, tiempo, estilo, direccion)
    if not obj or not obj.Parent then return nil end
    local clave = clavePropiedades(props)
    local porObjeto = tweensActivos[obj]
    local anterior = porObjeto and porObjeto[clave]
    if anterior then
        pcall(function() anterior:Cancel() end)
    end
    -- Duracion 0 (Nub.Motion.Directo): feedback directo, se aplica sin
    -- tween. Se usa para lo que responde al dedo mientras se arrastra.
    if tiempo == 0 then
        pcall(function()
            for propiedad, valor in pairs(props) do obj[propiedad] = valor end
        end)
        return nil
    end
    local info = TweenInfo.new(tiempo or Nub.Motion.Expand, estilo or Enum.EasingStyle.Quad, direccion or Enum.EasingDirection.Out)
    local ok, t = pcall(function()
        local tw = TweenService:Create(obj, info, props)
        tw:Play()
        return tw
    end)
    if ok then
        tweensActivos[obj] = tweensActivos[obj] or {}
        tweensActivos[obj][clave] = t
    end
    return ok and t or nil
end

-- ── Numero animado ──────────────────────────────────────────────
-- Anima un numero de 'desde' a 'hasta' durante 'duracion' segundos
-- y llama 'callback(valor)' en cada actualizacion. Usado por Slider,
-- Progreso y Label para mostrar transiciones suaves en vez de saltos
-- instantaneos de "50" a "80" en el texto.
--
-- Implementado con un NumberValue + TweenService (no un loop manual)
-- porque asi el tween sigue la misma fisica que el resto de la
-- libreria y no consume un hilo por contador. El NumberValue es
-- "virtual" -- no se parentea a nada, se destruye al completar el
-- tween, no deja residuos en la GUI.
--
-- Cancelacion: si se llama dos veces seguidas sobre el mismo
-- 'callback' (ej. usuario arrastrando un slider rapido), el tween
-- anterior del NumberValue se cancela antes de crear el siguiente.
-- El cache 'numeroTweensActivos' usa el callback como clave
-- (referencia unica por control). Clave debil no es necesaria aca
-- porque el NumberValue se destruye solo al completar.
local numeroTweensActivos = setmetatable({}, {__mode = "k"})

function Utils.TweenNumero(desde, hasta, duracion, callback, estilo, direccion, clave)
    if type(callback) ~= "function" then return end
    if desde == hasta then
        callback(hasta)
        return
    end

    local llave = clave or callback
    local anterior = numeroTweensActivos[llave]
    if anterior then
        pcall(function() anterior.tween:Cancel() end)
        pcall(function() anterior.valor:Destroy() end)
    end

    local valor = Instance.new("NumberValue")
    valor.Value = desde
    local conexion = valor:GetPropertyChangedSignal("Value"):Connect(function()
        pcall(callback, valor.Value)
    end)

    local info = TweenInfo.new(
        duracion or 0.22,
        estilo or Nub.Motion.EaseEntrar,
        direccion or Enum.EasingDirection.Out
    )
    local ok, tw = pcall(function()
        return TweenService:Create(valor, info, {Value = hasta})
    end)
    if not ok then
        -- Si el TweenService falla por algun motivo, al menos llamamos
        -- el callback con el valor final para no dejar la UI en un
        -- estado intermedio inconsistente.
        conexion:Disconnect()
        valor:Destroy()
        callback(hasta)
        return
    end

    local registro = {tween = tw, valor = valor}
    numeroTweensActivos[llave] = registro
    tw:Play()
    tw.Completed:Connect(function()
        conexion:Disconnect()
        valor:Destroy()
        if numeroTweensActivos[llave] == registro then numeroTweensActivos[llave] = nil end
    end)
end

-- ── Frame genérico ──────────────────────────────────────────────
-- Utils.Frame({Padre=, Size=, Posicion=, Color=, Transparencia=, Radio=,
--               Borde=true, ColorBorde=, GrosorBorde=, Orden=, Recortar=, Alto=})
function Utils.Frame(cfg)
    cfg = cfg or {}
    local f = Instance.new("Frame")
    contarInstanciaCreada(f)
    f.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 26)
    f.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then f.AnchorPoint = cfg.Ancla end
    f.BackgroundColor3 = cfg.Color or Color3.fromRGB(28, 39, 21)
    f.BackgroundTransparency = cfg.Transparencia or 0
    f.BorderSizePixel = 0
    f.ClipsDescendants = cfg.Recortar or false
    f.LayoutOrder = cfg.Orden or 0
    if cfg.Visible ~= nil then f.Visible = cfg.Visible end
    f.Parent = cfg.Padre
    if cfg.Radio ~= false then Utils.Corner(f, cfg.Radio) end
    if cfg.Borde then
        local strokeBorde = Utils.Stroke(f, cfg.ColorBorde, cfg.GrosorBorde, cfg.TransparenciaBorde)
        -- ClaveTemaBorde (opcional): antes esta funcion creaba el
        -- stroke pero nunca devolvia su referencia, asi que era
        -- imposible registrarlo desde afuera para que actualice color
        -- al cambiar de tema (por eso el borde de 'main', por ejemplo,
        -- se quedaba pegado al color del tema inicial). Pasando esta
        -- clave, el registro queda hecho automaticamente aca mismo.
        if cfg.ClaveTemaBorde then
            Nub:Registrar(strokeBorde, "Color", cfg.ClaveTemaBorde)
        end
    end
    return f
end

-- Fila estándar de 1 renglón (la usan Boton, Toggle, Slider, Input, Dropdown, ColorPicker)
function Utils.Fila(padre, alto, orden, color)
    return Utils.Frame({Padre = padre, Size = UDim2.new(1, 0, 0, alto), Orden = orden, Color = color, Radio = 8})
end

-- ── Texto ───────────────────────────────────────────────────────
-- Utils.Texto({Padre=, Texto=, Size=, Posicion=, Color=, Tamano=, Fuente=,
--               Alineacion=, Truncar=, Ajustar=, Orden=, TextoTransparencia=})
function Utils.Texto(cfg)
    cfg = cfg or {}
    local l = Instance.new("TextLabel")
    contarInstanciaCreada(l)
    l.BackgroundTransparency = 1
    l.Size = cfg.Size or UDim2.new(1, -8, 1, 0)
    l.Position = cfg.Posicion or UDim2.new(0, 8, 0, 0)
    l.Font = cfg.Fuente or Enum.Font.Gotham
    local tamanoBase = cfg.Tamano or 12
    l.TextSize = tamanoBase
    l.TextColor3 = cfg.Color or Color3.fromRGB(255, 255, 255)
    l.TextXAlignment = cfg.Alineacion or Enum.TextXAlignment.Left
    l.TextTruncate = cfg.Truncar and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    l.TextWrapped = cfg.Ajustar or false
    l.TextTransparency = cfg.TextoTransparencia or 0
    l.RichText = cfg.RichText or false
    l.Text = cfg.Texto or ""
    l.LayoutOrder = cfg.Orden or 0
    l.Parent = cfg.Padre
    if cfg.ColorTema then
        Nub:Registrar(l, "TextColor3", cfg.ColorTema)
    elseif not cfg.Color then
        Nub:Registrar(l, "TextColor3", "Text")
    end
    -- Registrar para el sistema de escala de texto (tabs/general).
    -- 'cfg.Truncar' activa el ajuste automatico de ancho (ver
    -- calcularYAplicarTamano) ademas del factor de escala manual --
    -- asi un texto largo en un espacio fijo se achica lo necesario
    -- para entrar completo, en vez de cortarse con "...".
    registrarEscalaTexto(l, tamanoBase, cfg.Categoria, cfg.Truncar)
    return l
end

-- ── Layout dinámico ─────────────────────────────────────────────
function Utils.Diferir(fn)
    local pendiente = false
    return function()
        if pendiente then return end
        pendiente = true
        task.delay(0.03, function()
            pendiente = false
            fn()
        end)
    end
end

function Utils.FactorEscalaUI(inst)
    local f = 1
    local actual = inst
    while actual do
        local ok, sc = pcall(function() return actual:FindFirstChildOfClass("UIScale") end)
        if ok and sc then f = f * sc.Scale end
        actual = actual.Parent
    end
    return (f > 0) and f or 1
end

function Utils.HacerFilaDinamica(fila, lbl, altoMin, padY)
    padY = padY or 7
    lbl.TextWrapped   = true
    lbl.TextTruncate  = Enum.TextTruncate.None
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.AnchorPoint   = Vector2.new(0, 0.5)
    lbl.Position = UDim2.new(lbl.Position.X.Scale, lbl.Position.X.Offset, 0.5, 0)
    lbl.Size     = UDim2.new(lbl.Size.X.Scale, lbl.Size.X.Offset, 0, 0)
    local function recalcular()
        if not (fila.Parent and lbl.Parent) then return end
        local h = lbl.AbsoluteSize.Y
        if h <= 0 then return end
        local alto = math.max(altoMin, math.ceil(h / Utils.FactorEscalaUI(lbl)) + padY * 2)
        if fila.Size.Y.Offset ~= alto then
            fila.Size = UDim2.new(fila.Size.X.Scale, fila.Size.X.Offset, 0, alto)
        end
    end
    Nub:RegistrarConexion(lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(recalcular)))
    task.defer(recalcular)
end

-- ── Botón base (sin texto propio, se le agrega Utils.Texto encima si hace falta) ──
function Utils.BotonBase(cfg)
    cfg = cfg or {}
    local b = Instance.new("TextButton")
    contarInstanciaCreada(b)
    b.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 26)
    b.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then b.AnchorPoint = cfg.Ancla end
    b.BackgroundTransparency = cfg.Transparencia == nil and 1 or cfg.Transparencia
    b.BackgroundColor3 = cfg.Color or Color3.fromRGB(28, 39, 21)
    b.AutoButtonColor = false
    b.Text = ""
    b.BorderSizePixel = 0
    b.LayoutOrder = cfg.Orden or 0
    b.Parent = cfg.Padre
    if cfg.Radio then Utils.Corner(b, cfg.Radio) end
    return b
end

-- ── Arrastrar un frame ──────────────────────────────────────────
-- No crea una nueva conexión global a InputChanged por
-- cada ventana. Ahora usa EventManager (una sola conexión global),
-- igual que hacen Slider y ColorPicker, evitando el memory leak
-- cuando el usuario crea la ventana más de una vez.
function Utils.Arrastrable(disparador, objetivo, eventMgr)
    local arrastrando = false
    local inicioArrastre, inicioObjetivo

    disparador.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            arrastrando     = true
            inicioArrastre  = Vector2.new(input.Position.X, input.Position.Y)
            inicioObjetivo  = objetivo.Position

            local conexionInputChanged
            conexionInputChanged = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    arrastrando = false
                    if eventMgr then eventMgr:DetenerArrastre() end
                    if conexionInputChanged then
                        conexionInputChanged:Disconnect()
                        conexionInputChanged = nil
                    end
                end
            end)
            Nub:RegistrarConexion(conexionInputChanged)

            if eventMgr then
                eventMgr:Arrastrar(function(inp)
                    if not arrastrando then return end
                    local delta = Vector2.new(inp.Position.X, inp.Position.Y) - inicioArrastre
                    objetivo.Position = UDim2.new(
                        inicioObjetivo.X.Scale,  inicioObjetivo.X.Offset + delta.X,
                        inicioObjetivo.Y.Scale,  inicioObjetivo.Y.Offset + delta.Y
                    )
                end)
            end
        end
    end)
end


-- ===================================================================
--  SECCION 2: THEMES
-- ===================================================================
local Themes = {}

Themes.Predeterminado = "Negro"

Themes.Lista = {

    -- Tema neutro oscuro (predeterminado) — el estilo de siempre de Nub
    Negro = {
        Background      = Color3.fromRGB(45, 48, 53),
        BackgroundDark  = Color3.fromRGB(32, 34, 38),
        BackgroundLight = Color3.fromRGB(55, 58, 64),
        Accent          = Color3.fromRGB(90, 140, 210),
        AccentLight     = Color3.fromRGB(130, 175, 230),
        Highlight       = Color3.fromRGB(180, 200, 230),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(12, 13, 15),
        Panel           = Color3.fromRGB(18, 19, 22),
        PanelClaro      = Color3.fromRGB(26, 28, 32),
        Fila            = Color3.fromRGB(32, 34, 38),
        Entrada         = Color3.fromRGB(15, 16, 19),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },

    -- Tema claro — fondo blanco con texto oscuro para que resalte
    Blanco = {
        Background      = Color3.fromRGB(218, 218, 224),
        BackgroundDark  = Color3.fromRGB(198, 198, 205),
        BackgroundLight = Color3.fromRGB(240, 240, 245),
        Accent          = Color3.fromRGB(60, 120, 210),
        AccentLight     = Color3.fromRGB(100, 155, 230),
        Highlight       = Color3.fromRGB(40, 70, 130),
        Text            = Color3.fromRGB(25, 25, 30),
        TextDark        = Color3.fromRGB(20, 20, 20),
        Border          = Color3.fromRGB(195, 195, 200),
        Panel           = Color3.fromRGB(252, 252, 254),
        PanelClaro      = Color3.fromRGB(240, 240, 244),
        Fila            = Color3.fromRGB(232, 232, 237),
        Entrada         = Color3.fromRGB(220, 220, 226),
        Apagado         = Color3.fromRGB(180, 180, 180),
    },

    Verde = {
        Background      = Color3.fromRGB(58, 122, 68),
        BackgroundDark  = Color3.fromRGB(42, 92, 50),
        BackgroundLight = Color3.fromRGB(72, 145, 82),
        Accent          = Color3.fromRGB(90, 190, 120),
        AccentLight     = Color3.fromRGB(130, 215, 155),
        Highlight       = Color3.fromRGB(170, 230, 185),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(15, 30, 18),
        Panel           = Color3.fromRGB(24, 40, 27),
        PanelClaro      = Color3.fromRGB(32, 52, 36),
        Fila            = Color3.fromRGB(28, 46, 31),
        Entrada         = Color3.fromRGB(20, 34, 22),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },

    Morado = {
        Background      = Color3.fromRGB(78, 55, 120),
        BackgroundDark  = Color3.fromRGB(58, 40, 92),
        BackgroundLight = Color3.fromRGB(98, 72, 145),
        Accent          = Color3.fromRGB(140, 105, 210),
        AccentLight     = Color3.fromRGB(175, 145, 230),
        Highlight       = Color3.fromRGB(205, 185, 240),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(18, 12, 28),
        Panel           = Color3.fromRGB(26, 20, 36),
        PanelClaro      = Color3.fromRGB(34, 27, 46),
        Fila            = Color3.fromRGB(30, 24, 42),
        Entrada         = Color3.fromRGB(22, 17, 32),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },

    Rojo = {
        Background      = Color3.fromRGB(214, 70, 60),
        BackgroundDark  = Color3.fromRGB(164, 45, 40),
        BackgroundLight = Color3.fromRGB(230, 110, 100),
        Accent          = Color3.fromRGB(163, 45, 60),
        AccentLight     = Color3.fromRGB(204, 94, 100),
        Highlight       = Color3.fromRGB(234, 160, 160),
        Text            = Color3.fromRGB(255, 255, 255),
        TextDark        = Color3.fromRGB(25, 20, 20),
        Border          = Color3.fromRGB(35, 8, 8),
        Panel           = Color3.fromRGB(34, 20, 20),
        PanelClaro      = Color3.fromRGB(44, 27, 27),
        Fila            = Color3.fromRGB(38, 24, 24),
        Entrada         = Color3.fromRGB(28, 17, 17),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },
}



-- ===================================================================
--  SECCION 3: ALANUI (nucleo)
-- ===================================================================
-- (Nub ya fue declarado al inicio del archivo, junto con Utils,
-- para que Utils.Texto pudiera usar Nub:Registrar)

-- ── Servicios ──────────────────────────────────────────────────
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════
--  LOG INTERNO DE ERRORES
-- ══════════════════════════════════════════════════════════════
-- Historial acotado (ultimos 50 errores) consultable con
-- Nub:ObtenerErrores(), con el contexto completo, el mensaje
-- completo (sin truncar) y el momento en que ocurrio.
local MAX_LOGS_ERRORES = 50
Nub._Logs = {}

function Nub:_RegistrarError(contexto, mensaje)
    table.insert(self._Logs, {
        Momento  = os.time(),
        Contexto = tostring(contexto or "?"),
        Mensaje  = tostring(mensaje or ""),
    })
    if #self._Logs > MAX_LOGS_ERRORES then
        table.remove(self._Logs, 1)
    end
    -- SIEMPRE se imprime en la consola de Roblox (antes quedaba solo
    -- en el historial interno, invisible salvo que se llamara
    -- ObtenerErrores() a mano). Esto cubre tambien los errores de
    -- SaveManager (guardado/carga fallidos), que antes fallaban en
    -- silencio total.
    warn("[Nub] Error en '" .. tostring(contexto or "?") .. "': " .. tostring(mensaje or ""))
end

-- API publica: devuelve el historial de errores capturados
-- internamente (el mas reciente al final). Util para debugging sin
-- depender de haber visto la consola en el momento exacto del fallo.
function Nub:ObtenerErrores()
    local copia = {}
    for i, entrada in ipairs(self._Logs) do copia[i] = clonarTabla(entrada) end
    return copia
end

-- ── MODO DEBUG (Nub.DebugMode) ───────────────────────────────
-- _RegistrarError (arriba) y ejecutarConFallback (mas abajo) YA
-- avisan siempre con warn(), aunque DebugMode este en false -- eso
-- no cambia con esto.
--
-- Lo que SI hay en la libreria son pcall() puntuales que a proposito
-- tragan el error sin avisar nada: son casos donde fallar es
-- ESPERABLE y normal (ej. sincronizar el color de un elemento de tema
-- que ya fue destruido, o escribir un archivo de tema opcional) y
-- avisar de cada uno por defecto seria ruido para el usuario final.
-- 'intentarSilencioso' envuelve esos casos puntuales: con DebugMode
-- en false se comporta exactamente igual que antes (silencio total);
-- en true, ademas hace warn() para que el developer pueda ver esos
-- fallos "esperables" mientras esta probando su script.
local function intentarSilencioso(descripcion, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and Nub.DebugMode then
        warn("[Nub] (DebugMode) '" .. descripcion .. "' fallo silenciosamente: " .. tostring(err))
    end
    return ok, err
end

-- ══════════════════════════════════════════════════════════════
--  EVENTOS GLOBALES (Nub.Eventos)
-- ══════════════════════════════════════════════════════════════
-- Señales minimas propias (no BindableEvent de Roblox, para no
-- depender de Instance.new aca y poder dispararse desde cualquier
-- parte de la libreria sin preocuparse por el padre de la GUI).
-- Permiten a un script externo reaccionar a cambios sin tener que
-- envolver manualmente cada control:
--   Nub.Eventos.FlagCambiada:Connect(function(flag, valor) ... end)
-- Cobertura actual: FlagCambiada (cualquier escritura en Nub.Flags),
-- TabCambiada (al seleccionar una pestaña) y TemaCambiado (al aplicar
-- un tema). ControlRegistrado queda declarada para consistencia con lo
-- que pide la propuesta, pero por ahora no se dispara desde ningun
-- control todavia -- hacerlo bien requeriria tocar los ~10 puntos
-- donde se crea un control, y se prefirio no arriesgar eso en esta
-- pasada. Si la necesitas activa, avisale a quien mantenga esto.
local function crearSenal()
    local conectados = {}
    local senal = {}
    function senal:Connect(callback)
        if type(callback) ~= "function" then
            return {Disconnect = function() end}
        end
        local entrada = {activo = true, callback = callback}
        table.insert(conectados, entrada)
        return {
            Disconnect = function() entrada.activo = false end,
        }
    end
    function senal:Fire(...)
        -- Se copia la lista antes de iterar por si algun callback
        -- conecta o desconecta algo del mismo evento mientras corre.
        -- table.move copia el rango completo de un solo saque, sin el
        -- overhead de una llamada a funcion por cada entrada.
        local instantanea = table.move(conectados, 1, #conectados, 1, {})
        for _, entrada in ipairs(instantanea) do
            if entrada.activo then
                local ok, err = pcall(entrada.callback, ...)
                if not ok then Nub:_RegistrarError("Eventos", err) end
            end
        end
    end
    return senal
end

Nub.Eventos = {
    FlagCambiada      = crearSenal(),
    TabCambiada       = crearSenal(),
    TemaCambiado      = crearSenal(),
    ControlRegistrado = crearSenal(),
    TipoCambiado      = crearSenal(), -- se dispara al reclasificar el entorno (ForzarTipo, rotacion de pantalla)
    HistorialCambiado = crearSenal(),
}

-- ── Manejo de errores con notificacion visual ──────────────────
-- Envuelve en pcall todos los callbacks.
-- Si el callback falla, muestra una notificacion roja en vez de
-- solo warn() invisible para el usuario final, y ademas queda
-- registrado en Nub._Logs (ver arriba) para revisar despues.
local function ejecutarConFallback(callback, contexto, ...)
    if not callback then return end
    local args = {...}
    local ok, err = pcall(function() return callback(table.unpack(args)) end)
    if not ok then
        Nub:_RegistrarError(contexto, err)
        local mensajeCompleto = tostring(err)
        local mensajeMostrado = mensajeCompleto:sub(1, 120)
        if #mensajeCompleto > 120 then
            mensajeMostrado = mensajeMostrado .. "… (ver Nub:ObtenerErrores())"
        end
        -- Intenta notificar; si la GUI todavia no existe, solo warn
        if Nub.MostrarErroresEnUI ~= false then
            pcall(function()
                Nub:Notificar({
                    Titulo = "⚠️ Error en " .. (contexto or "control"),
                    Texto  = mensajeMostrado,
                    Duracion = 6,
                })
            end)
        end
        warn("[Nub] Callback error (" .. (contexto or "?") .. "):", err)
    end
    return ok
end

-- ── Validador de uso (advertencias para el DEVELOPER) ───────────
-- Distinto a ejecutarConFallback/_RegistrarError (que atrapan errores
-- QUE YA OCURRIERON dentro del Callback en tiempo de ejecucion): esto
-- revisa la CONFIGURACION del control ANTES de crearlo, para avisar
-- de descuidos comunes en la consola de Roblox (F9). Nunca usa
-- error() -- solo warn() + auto-correccion silenciosa, para no
-- romper el script del developer jamas.
--
-- OJO: a proposito NO se advierte por un Callback ausente (nil) --
-- en Nub eso es un patron valido e intencional (developer que solo
-- quiere guardar el flag y leerlo despues con Nub:Try/ObtenerFlag).
-- Solo se advierte cuando Callback SI se paso pero con el tipo
-- incorrecto (typo real, ej. Callback = miVariable).
local function advertirDev(tipo, nombre, mensaje)
    warn(("[Nub] %s \"%s\": %s"):format(tipo, tostring(nombre or "?"), mensaje))
end

-- 'Desactivar': cuando este control se prende, apaga los otros
-- controles que liste (Toggle o Casilla). Compartido entre Toggle y
-- Casilla para no duplicar la logica.
local function aplicarDesactivarSiCorresponde(cfg, v)
    if v == true and cfg.Desactivar then
        for _, otraFlag in ipairs(cfg.Desactivar) do
            local controlObjetivo = Nub.Elementos[otraFlag]
            if controlObjetivo and controlObjetivo.Get() == true then
                controlObjetivo.Set(false, true)
            end
        end
    end
end

local function validarCallback(tipo, cfg)
    if cfg.Callback ~= nil and type(cfg.Callback) ~= "function" then
        advertirDev(tipo, cfg.Texto, "'Callback' se paso pero no es una función (es " .. typeof(cfg.Callback) .. "). Se ignoró para no romper el script.")
        cfg.Callback = nil
    end
end

-- ══════════════════════════════════════════════════════════════
--  NORMALIZACION DE Set(v) vs :Set(v)
-- ══════════════════════════════════════════════════════════════
-- El objeto publico que devuelve cada control (Tab:CrearSeccion(...):
-- Slider({...})) expone un Set(v) de UN solo parametro, pensado para
-- llamarse con punto: control.Set(50). Si el desarrollador lo llama
-- con dos puntos por error -- control:Set(50), un error de sintaxis
-- muy comun en Lua -- eso desazucara a control.Set(control, 50): el
-- propio objeto del control se cuela como primer argumento y el 50
-- real queda como segundo, silenciosamente descartado por cualquier
-- Set de un solo parametro. El valor real (la propia tabla del
-- control) termina en operaciones que esperaban un numero/string/etc,
-- y el resultado es un crash dificil de entender (ej. "invalid
-- argument #1 to 'clamp'").
--
-- Esta funcion normaliza ambas formas de llamada. Se distingue por
-- CANTIDAD de argumentos, no por tipo -- distinguir por
-- 'type(a) == "table"' parece natural pero da falsos positivos en los
-- controles donde el valor real TAMBIEN es una tabla (Dropdown con
-- Multi = true recibe una lista de opciones; Keybind con
-- ConModificadores = true recibe {KeyCode=, Ctrl=, Shift=, Alt=}): en
-- esos casos, un Set(tablaLegitima) via punto se confundiria con un
-- Set(self, nil) via dos puntos, y el valor real se perderia. Contar
-- argumentos evita el problema por completo: control:Set(v) SIEMPRE
-- pasa 2 argumentos (self, v); control.Set(v) SIEMPRE pasa 1.
local function normalizarArgSet(...)
    if select('#', ...) >= 2 then
        return (select(2, ...))
    end
    return (select(1, ...))
end


-- Util para developers externos que no saben si el flag existe.
-- Ejemplo: local vel = Nub:Try("velocidad", 0)
function Nub:Try(flag, fallback)
    local elem = self.Elementos[flag]
    if not elem then return fallback end
    local ok, val = pcall(elem.Get)
    if not ok or val == nil then return fallback end
    return val
end

-- ── Detectar ejecutor (usado por pestana Sistema) ───────────────
local function detectarEjecutor()
    -- getexecutorname() es la forma mas confiable (Synapse, Fluxus, etc.)
    if type(getexecutorname) == "function" then
        local ok, nombre = pcall(getexecutorname)
        if ok and nombre and nombre ~= "" then return nombre end
    end
    -- Fallbacks por globales conocidas
    local lista = {
        {function() return syn ~= nil end,          "Synapse X"},
        {function() return krnl ~= nil end,         "Krnl"},
        {function() return fluxus ~= nil end,       "Fluxus"},
        {function() return sirhurt ~= nil end,      "SirHurt"},
        {function() return PROTOSMASHER_LOADED ~= nil end, "ProtoSmasher"},
        {function() return is_sirhurt_closure ~= nil end,  "SirHurt (alt)"},
        {function() return identifyexecutor ~= nil end,    "Desconocido (identifyexecutor)"},
    }
    for _, entrada in ipairs(lista) do
        local ok2, esEse = pcall(entrada[1])
        if ok2 and esEse then return entrada[2] end
    end
    return "Desconocido"
end

-- ── Compatibilidad multi-ejecutor ──────────────────────────────
local function obtenerPadreGui()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function protegerGui(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui)
        elseif protectgui then protectgui(gui) end
    end)
end

local function fsDisponible()
    return type(writefile) == "function" and type(readfile) == "function"
end

-- HttpService:JSONEncode no sabe serializar un Color3 (no es un tipo
-- JSON valido) — lo convierte silenciosamente en 'null' en vez de dar
-- un error, asi que un ColorPicker guardado se perdia sin ningun aviso.
-- Se empaqueta a una tabla plana {R,G,B} antes de guardar, y se
-- reconstruye a Color3 al cargar.
local function esColor3(v)
    return typeof and typeof(v) == "Color3"
end

local function esEnum(v)
    return typeof and typeof(v) == "EnumItem"
end

-- 'soloUI' = true restringe el resultado UNICAMENTE a los flags
-- marcados con MarcarComoUI (usado por SM:GuardarUI). El guardado de
-- PERFILES normal no necesita excluir nada aca: como cada uno vive en
-- una carpeta separada (ver SM.CarpetaUI mas abajo), un flag de UI
-- simplemente nunca se toca desde ese lado.

-- VERSION_FORMATO_GUARDADO tiene que estar declarada ACA, antes de
-- empaquetarFlagsParaGuardar, y no mas abajo junto a
-- migrarDatosGuardados/prepararDatosCargados (donde estaba antes).
-- Motivo: en Lua un 'local' solo es upvalue para el codigo que aparece
-- DESPUES de su declaracion en el archivo, sin importar el orden de
-- ejecucion en runtime. Si esta constante se declara mas abajo,
-- 'empaquetarFlagsParaGuardar' (definida arriba) la resuelve como
-- variable GLOBAL (nil) en vez de como upvalue -- { __version = nil }
-- no agrega la clave al JSON, y el versionado queda inerte sin que se
-- note (bug real detectado en revision de v2.11.1+versionado).
-- La logica de version SI puede quedarse mas abajo (migrarDatosGuardados,
-- prepararDatosCargados): corren despues, en tiempo de carga, y para
-- entonces esta constante ya es upvalue valida para ellas tambien.
local VERSION_FORMATO_GUARDADO = 2

local function empaquetarFlagsParaGuardar(flags, soloUI)
    local resultado = { __version = VERSION_FORMATO_GUARDADO }
    for clave, valor in pairs(flags) do
        local omitir = _flagsNoPersistir[clave]
            or (soloUI and not _flagsUI[clave])
            or (not soloUI and _flagsUI[clave])
        if omitir then
            -- Se omite a proposito: ver comentario junto a
            -- '_flagsNoPersistir'/'_flagsUI' donde se declaran.
        elseif esColor3(valor) then
            resultado[clave] = {
                __color3 = true,
                R = math.floor(valor.R * 255 + 0.5),
                G = math.floor(valor.G * 255 + 0.5),
                B = math.floor(valor.B * 255 + 0.5),
            }
        elseif esEnum(valor) then
            -- Enum.KeyCode.F, etc. HttpService:JSONEncode no sabe
            -- serializar un EnumItem -- se guarda su nombre y se
            -- reconstruye con Enum.KeyCode[nombre] al cargar.
            resultado[clave] = {
                __enum = true,
                EnumType = tostring(valor.EnumType),
                Name = valor.Name,
            }
        elseif type(valor) == "table" and esEnum(valor.KeyCode) then
            -- Keybind con ConModificadores = true: {KeyCode=, Ctrl=,
            -- Shift=, Alt=}. Mismo problema que el Enum suelto -- el
            -- KeyCode interno tambien necesita empaquetarse.
            resultado[clave] = {
                __keybindMods = true,
                KeyCode = valor.KeyCode.Name,
                Ctrl = valor.Ctrl or false,
                Shift = valor.Shift or false,
                Alt = valor.Alt or false,
            }
        else
            resultado[clave] = valor
        end
    end
    return resultado
end

local function desempaquetarValorCargado(valor)
    if type(valor) == "table" and valor.__color3 then
        return Color3.fromRGB(valor.R or 0, valor.G or 0, valor.B or 0)
    end
    if type(valor) == "table" and valor.__enum then
        -- Enum[tipo][nombre] con un nombre que no existe NO tira
        -- error -- devuelve nil silenciosamente. Sin este chequeo
        -- extra, un .json con un KeyCode obsoleto/invalido dejaba
        -- pasar 'nil' en vez de caer al fallback de abajo.
        local ok, enumItem = pcall(function() return Enum[valor.EnumType][valor.Name] end)
        if ok and enumItem then return enumItem end
        return Enum.KeyCode.Unknown
    end
    if type(valor) == "table" and valor.__keybindMods then
        local ok, keyCode = pcall(function() return Enum.KeyCode[valor.KeyCode] end)
        return {
            KeyCode = ok and keyCode or Enum.KeyCode.Unknown,
            Ctrl = valor.Ctrl or false,
            Shift = valor.Shift or false,
            Alt = valor.Alt or false,
        }
    end
    return valor
end

-- ══════════════════════════════════════════════════════════════
--  VERSIONADO DEL FORMATO DE GUARDADO
-- ══════════════════════════════════════════════════════════════
-- El .json guardado lleva un campo __version para poder migrar
-- archivos de esquemas viejos si el formato cambia en el futuro.
-- No confundir con Nub.Version (la version de la libreria en si):
-- esto es la version del ESQUEMA del archivo, no del codigo.
--
-- Cuando subirlo:
--   * Cambio ESTRUCTURAL del documento (metadata a nivel archivo,
--     cambio del layout de los flags, agrupacion por categoria, etc).
--   * NO hace falta subirlo por agregar un campo opcional a un valor
--     puntual -- eso ya es retrocompatible por el empaquetado por tipo
--     (__color3/__enum/__keybindMods), que le permite al lado de la
--     lectura hacer 'valor.NuevoCampo or default'.
--
-- Al LEER:
--   * Sin __version (archivos pre-versioning): se asume 1.
--   * Con __version == actual: se lee directo, sin migrar.
--   * Con __version < actual: se corre la cadena de migraciones.
--   * Con __version > actual: se avisa por notificacion y se intenta
--     leer igual (mejor lectura parcial que rechazo total -- el usuario
--     puede haber downgradeado el script).
--
-- IMPORTANTE: el nombre '__version' queda RESERVADO a nivel archivo.
-- Un flag de usuario llamado '__version' (improbable, pero posible)
-- seria sobreescrito por el metadata al guardar. Si algun dia hace
-- falta, migrar a un layout con metadata anidada.
--
-- (La constante VERSION_FORMATO_GUARDADO esta declarada mas arriba,
-- justo antes de empaquetarFlagsParaGuardar -- ver el comentario ahi
-- para el motivo exacto del porque tiene que estar ANTES de esa
-- funcion y no aca, donde estuvo por error en una version anterior.)

-- Migra 'datos' desde 'versionOrigen' hasta VERSION_FORMATO_GUARDADO.
-- Cada bloque 'if versionOrigen < N then' es una migracion incremental:
-- al agregar una version nueva, se agrega un bloque aca y nada mas --
-- los archivos viejos van pasando por todos los bloques en orden.
local function migrarDatosGuardados(datos, versionOrigen)
    -- v1 -> v2: el cambio es solo agregar __version al archivo (que ya
    -- se agrega al guardar). Ningun flag cambia de forma ni de nombre,
    -- asi que la migracion es un no-op. Cuando en el futuro haya
    -- cambios reales, se agrega aca un bloque que transforme 'datos':
    --     if versionOrigen < 3 then datos = transformarV2aV3(datos) end
    return datos
end

-- Extrae la version de un documento recien decodificado, la saca del
-- documento para que el bucle de restauracion no la confunda con un
-- flag, y corre las migraciones que hagan falta.
local function prepararDatosCargados(datos)
    if type(datos) ~= "table" then return {} end

    local versionOrigen = tonumber(datos.__version) or 1
    datos.__version = nil

    if versionOrigen > VERSION_FORMATO_GUARDADO then
        pcall(function()
            Nub:Notificar({
                Titulo   = "⚠️ Config mas nueva",
                Texto    = "El archivo guardado es de un formato mas reciente (v"
                           .. versionOrigen .. "). Se intentara leer igual.",
                Duracion = 6,
            })
        end)
    end

    return migrarDatosGuardados(datos, versionOrigen)
end

-- ══════════════════════════════════════════════════════════════
--  CAPACIDADES DEL EJECUTOR (test una sola vez al cargar)
-- ══════════════════════════════════════════════════════════════
-- No todos los ejecutores soportan lo mismo (archivos, Drawing,
-- proteccion de GUI, gethui...). En vez de que cada feature falle en
-- silencio con un pcall suelto, se detecta todo UNA vez al cargar la
-- libreria y se expone en Nub.Capacidades para que:
--   1) la propia libreria avise UNA sola vez si falta algo (no en
--      cada intento), en vez de warnings repetidos, y
--   2) el developer externo pueda consultarlo antes de usar una
--      caracteristica opcional (ej. Drawing para un ESP).
-- ══════════════════════════════════════════════════════════════
--  CAPACIDADES DEL EJECUTOR Y DEL ENTORNO
-- ══════════════════════════════════════════════════════════════
-- Dos grupos bien diferenciados:
--   * HECHOS CRUDOS  -> lo que el entorno realmente reporta
--     (read-only, nunca se sobreescriben desde el script).
--   * DERIVADOS      -> clasificacion calculada a partir de los
--     hechos. Esto es lo unico que ForzarTipo() puede tocar --
--     asi nunca se miente sobre lo que el entorno PUEDE hacer,
--     solo sobre como se CLASIFICA.
local TIPOS_ENTORNO_VALIDOS = {
    PC = true, Movil = true, Tablet = true,
    Consola = true, Studio = true, Desconocido = true,
}

Nub.Capacidades = {
    -- ── Hechos crudos (mediciones reales) ──
    Archivos   = fsDisponible(),
    Drawing    = type(Drawing) == "table" and type(Drawing.new) == "function",
    ProtectGUI = (type(syn) == "table" and type(syn.protect_gui) == "function")
                 or type(protectgui) == "function",
    GetHUI     = type(gethui) == "function",
    -- Dispositivos tactiles sin teclado fisico/bluetooth no pueden
    -- capturar una tecla para un Keybind (nunca va a llegar el evento
    -- de teclado que se espera). Se detecta una sola vez para que
    -- Seccion:Keybind pueda ofrecer un comportamiento util en vez de
    -- quedarse esperando para siempre un input que nunca va a pasar.
    Teclado    = UserInputService.KeyboardEnabled,
    -- Si hay un gamepad conectado (ej. control Bluetooth en movil), un
    -- Keybind sin teclado puede capturar un boton del control en vez
    -- de forzar directamente el modo "botón de acción" — mas fiel a lo
    -- que el desarrollador pidio (una TECLA/boton que dispare algo).
    Gamepad    = UserInputService.GamepadEnabled,

    -- Nuevos hechos crudos del entorno
    EsStudio     = RunService:IsStudio(),
    TieneTouch   = UserInputService.TouchEnabled,
    TieneMouse   = UserInputService.MouseEnabled,
    -- GetPlatform() es un METODO de UserInputService, no una propiedad
    -- suelta -- Enum.Platform no existe como tabla indexable directa.
    -- Ademas GetPlatform() esta marcado por Roblox con capability
    -- RobloxScript: un LocalScript corriendo en Studio (o un ejecutor
    -- con sandbox restrictivo) NO puede llamarlo, y sin pcall esa
    -- excepcion corta la construccion de TODA esta tabla -- lo cual
    -- corta la carga completa del modulo. Mismo patron defensivo que
    -- ya se usa para Drawing/gethui/writefile mas arriba.
    --
    -- Fallback a nil, manejado downstream (NO a un Enum.Platform.Unknown
    -- inventado -- ese miembro no existe en Enum.Platform y tirar un
    -- indexado invalido rompe exactamente el caso que este pcall trata
    -- de blindar). El codigo que lee Capacidades.Plataforma ya maneja
    -- nil sin problema: NombrePlataforma() tiene 'if not p then return
    -- "Desconocida" end', y RecalcularDerivadosEntorno/descripcionEntorno
    -- usan 'C.Plataforma and ...', asi que nil cae limpio por esos
    -- guards existentes sin necesitar un EnumItem placeholder.
    Plataforma   = (function()
        local ok, p = pcall(function() return UserInputService:GetPlatform() end)
        if ok and p then return p end
        return nil
    end)(),
    -- ViewportSize necesita guard: CurrentCamera puede ser nil en el
    -- instante exacto en que se carga el modulo (antes de que el
    -- personaje/camara esten listos). Sin esto, leer .ViewportSize
    -- directo rompe TODA la carga de la libreria. El listener de
    -- mas abajo lo actualiza apenas la camara este disponible.
    ViewportSize = (function()
        local c = Workspace.CurrentCamera
        return c and c.ViewportSize or Vector2.new(0, 0)
    end)(),

    -- ── Derivados (recalculables por ForzarTipo) ──
    Tipo         = "Desconocido",
    EsTactil     = false,
    EsEscritorio = false,
    EsTouchOnly  = false,
}

-- Nombre legible de la plataforma, para mostrar en la UI sin tener
-- que hacer tostring(Enum.Platform.XboxOne) en cada lugar.
function Nub.Capacidades:NombrePlataforma()
    local p = self.Plataforma
    if not p then return "Desconocida" end
    -- tostring() sobre un EnumItem devuelve "Enum.Platform.Windows";
    -- .Name devuelve "Windows" -- mas limpio para UI.
    return p.Name or tostring(p)
end

-- Recalcula Tipo y los booleanos derivados a partir de los hechos
-- crudos + el posible override en _G.Nub_TipoForzado. Se llama:
--   1) una vez al cargar el modulo,
--   2) cada vez que ForzarTipo/LiberarForzado cambian el override,
--   3) cada vez que el ViewportSize cambia (para re-clasificar
--      tablet vs movil si el usuario rota la pantalla).
function Nub:RecalcularDerivadosEntorno()
    local C = self.Capacidades

    -- Orden de prioridad:
    --   1. Override manual (manda sobre todo).
    --   2. Studio (es un caso muy especifico, va antes que PC).
    --   3. Consola (Xbox/PS se reportan como plataformas propias).
    --   4. PC con mouse Y teclado (incluso si TAMBIEN tiene touch,
    --      como una notebook con pantalla tactil -- sigue siendo PC).
    --   5. Solo touch -> Tablet o Movil segun ancho de viewport.
    --   6. Fallback: teclado sin mouse ni touch -> PC raro, pero PC.
    -- Comparar por .Name en vez de indexar Enum.Platform.X directo:
    -- algunos miembros de este Enum (como XboxOne) no son validos en
    -- todas las versiones/ramas del motor de Roblox -- indexarlos
    -- directo (Enum.Platform.XboxOne) tira error "no es un member
    -- valido" y rompe la carga completa de la libreria. Comparando
    -- por nombre contra una lista, un nombre que no exista mas
    -- simplemente no matchea nunca, sin romper nada.
    local PLATAFORMAS_CONSOLA = {
        XboxOne = true, XboxSeriesX = true, XboxSeriesS = true,
        PS4 = true, PS5 = true, UWP = true,
    }
    local nombrePlataforma = C.Plataforma and C.Plataforma.Name

    local tipo
    if _G.Nub_TipoForzado and TIPOS_ENTORNO_VALIDOS[_G.Nub_TipoForzado] then
        tipo = _G.Nub_TipoForzado
    elseif C.EsStudio then
        tipo = "Studio"
    elseif nombrePlataforma and PLATAFORMAS_CONSOLA[nombrePlataforma] then
        tipo = "Consola"
    elseif C.TieneMouse and C.Teclado then
        tipo = "PC"
    elseif C.TieneTouch then
        -- Heuristica tablet vs movil: las tablets reales reportan
        -- viewport de 600px+ de ancho en Roblox; los telefonos, menos.
        -- No es exacto (un celular moderno en alta densidad puede
        -- acercarse a 600), por eso existe ForzarTipo() como override.
        --
        -- El ancho solo no alcanza: un celular en landscape (ej.
        -- 714x360) supera los 600px de ancho sin ser una tablet -- la
        -- experiencia real ahi es de telefono apretado, no de tablet.
        -- Si el ALTO es bajo (<500px), es ese caso -- landscape de
        -- celular -- sin importar cuanto ancho tenga. No se usa la
        -- relacion de aspecto como criterio porque es mas fragil: hay
        -- tablets 4:3 y celulares 16:9 en horizontal con proporciones
        -- parecidas entre si.
        if C.ViewportSize.Y < 500 or C.ViewportSize.X < 600 then
            tipo = "Movil"
        else
            tipo = "Tablet"
        end
    elseif C.Teclado then
        tipo = "PC"
    else
        tipo = "Desconocido"
    end

    C.Tipo         = tipo
    C.EsTactil     = (tipo == "Movil" or tipo == "Tablet")
    C.EsEscritorio = (tipo == "PC" or tipo == "Consola")
    C.EsTouchOnly  = C.TieneTouch and not C.TieneMouse and not C.Teclado

    if self.Eventos and self.Eventos.TipoCambiado then
        self.Eventos.TipoCambiado:Fire(tipo)
    end
    return tipo
end

-- Primera clasificacion al cargar el modulo.
Nub:RecalcularDerivadosEntorno()

-- Listener en vivo de ViewportSize. Reusa el patron de persistencia
-- entre re-ejecuciones de EventManager (_G.<nombre>) -- necesario
-- porque esta conexion se crea a nivel de MODULO, antes de que
-- exista _G.Nub_InstanciaActiva (que solo aparece al llamar
-- CrearVentana). Sin esto, cada re-ejecucion sumaba una conexion
-- nueva que nunca se desconectaba.
if type(_G.Nub_ConexionesCapacidades) == "table" then
    for _, c in ipairs(_G.Nub_ConexionesCapacidades) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.Nub_ConexionesCapacidades = {}

local function engancharViewportCapacidades(camara)
    if not camara then return end
    local conexion = camara:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        Nub.Capacidades.ViewportSize = camara.ViewportSize
        Nub:RecalcularDerivadosEntorno()
    end)
    table.insert(_G.Nub_ConexionesCapacidades, conexion)
end

engancharViewportCapacidades(Workspace.CurrentCamera)
-- Si CurrentCamera es nil al cargar, se engancha apenas aparezca.
table.insert(_G.Nub_ConexionesCapacidades,
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local c = Workspace.CurrentCamera
        if not c then return end
        Nub.Capacidades.ViewportSize = c.ViewportSize
        Nub:RecalcularDerivadosEntorno()
        engancharViewportCapacidades(c)
    end)
)

-- ══════════════════════════════════════════════════════════════
--  FEATURES VERIFICABLES
-- ══════════════════════════════════════════════════════════════
-- Descriptores de "que puede hacer Nub en este entorno".
-- La mayoria REFERENCIA una clave de Nub.Capacidades -- no
-- re-testean nada por su cuenta. Asi hay una sola fuente de verdad:
-- si mañana cambia como se calcula ProtectGUI, se cambia en
-- Capacidades y Features lo refleja solo.
--
-- Solo las features que NO son capacidades de entorno (globals del
-- ejecutor como setclipboard, loadstring) llevan 'test' inline.
Nub.Features = {
    { nombre = "GUI",          claveCapacidad = nil,          test = function() return true end,                          nivel = "requerido"  },
    { nombre = "Archivos",     claveCapacidad = "Archivos",   nivel = "recomendado", mensaje = "No se podrán guardar configuraciones." },
    { nombre = "Drawing",      claveCapacidad = "Drawing",    nivel = "recomendado", mensaje = "Los ESP visuales no funcionarán." },
    { nombre = "ProtectGUI",   claveCapacidad = "ProtectGUI", nivel = "recomendado", mensaje = "La GUI puede ser detectada por anti-cheats." },
    { nombre = "GetHUI",       claveCapacidad = "GetHUI",     nivel = "recomendado", mensaje = "La GUI puede quedar detrás del CoreGui." },
    { nombre = "Teclado",      claveCapacidad = "Teclado",    nivel = "opcional",    mensaje = "Los Keybind se activarán en modo táctil." },
    { nombre = "Gamepad",      claveCapacidad = "Gamepad",    nivel = "opcional",    mensaje = "No se podrá usar control para atajos." },
    { nombre = "Loadstring",   test = function() return type(loadstring)   == "function" end, nivel = "opcional", mensaje = "No se podrán cargar scripts externos." },
    { nombre = "SetClipboard", test = function() return type(setclipboard) == "function" end, nivel = "opcional", mensaje = "No se podrá copiar texto al portapapeles." },
}

local _indiceFeatures = {}
for _, f in ipairs(Nub.Features) do _indiceFeatures[f.nombre] = f end

-- Verificacion unificada. Devuelve una tabla (no solo un bool) para
-- que el caller pueda mostrar el motivo sin tener que buscar la
-- feature de nuevo.
function Nub:VerificarSoporte(nombre)
    local f = _indiceFeatures[nombre]
    if not f then
        return { ok = false, nivel = "desconocido", nombre = nombre,
                 mensaje = "Función no reconocida por Nub." }
    end
    local ok = false
    if f.claveCapacidad then
        ok = self.Capacidades[f.claveCapacidad] == true
    elseif f.test then
        local okTest, r = pcall(f.test)
        ok = okTest and r == true
    end
    return {
        ok      = ok,
        nivel   = f.nivel,
        nombre  = f.nombre,
        mensaje = ok and nil or f.mensaje,
    }
end

-- Override manual. Persiste entre re-ejecuciones via _G (mismo patron
-- que _G.Nub_InstanciaActiva). Pensado para el caso borde de
-- tablets mal clasificadas o PCs en ventana muy chica.
function Nub:ForzarTipo(tipo)
    if tipo and not TIPOS_ENTORNO_VALIDOS[tipo] then
        return false, "Tipo inválido. Válidos: PC, Movil, Tablet, Consola, Studio, Desconocido."
    end
    _G.Nub_TipoForzado = tipo
    self:RecalcularDerivadosEntorno()
    return true
end

function Nub:LiberarForzado()
    return self:ForzarTipo(nil)
end

-- Diagnostico completo -- pensado para que un usuario lo pegue en un
-- reporte de bug, no para uso cotidiano.
function Nub:DiagnosticoCompleto()
    local C = self.Capacidades
    local soportadas, total, advertencias = 0, 0, {}
    for _, f in ipairs(self.Features) do
        total = total + 1
        local r = self:VerificarSoporte(f.nombre)
        if r.ok then
            soportadas = soportadas + 1
        elseif f.nivel ~= "requerido" then
            table.insert(advertencias, {
                nombre  = f.nombre,
                nivel   = f.nivel,
                mensaje = r.mensaje,
            })
        end
    end
    return {
        Tipo            = C.Tipo,
        Plataforma      = C:NombrePlataforma(),
        EsStudio        = C.EsStudio,
        Ejecutor        = detectarEjecutor(),
        Viewport        = C.ViewportSize,
        Forzado         = _G.Nub_TipoForzado,
        FeaturesOk      = soportadas,
        FeaturesTotal   = total,
        Advertencias    = advertencias,
        Capacidades     = C,
    }
end

-- Notifica UNA sola vez (no cada vez que se llama la funcion) cuando
-- falta una capacidad. Usado internamente por SaveManager, etc.
local _avisosCapacidad = {}
local function avisarCapacidadFaltante(clave, titulo, texto)
    if _avisosCapacidad[clave] then return end
    _avisosCapacidad[clave] = true
    pcall(function()
        Nub:Notificar({ Titulo = titulo, Texto = texto, Duracion = 8 })
    end)
end

-- ══════════════════════════════════════════════════════════════
--  SISTEMA DE AUTO-LIMPIEZA (evita duplicados al re-ejecutar)
-- ══════════════════════════════════════════════════════════════
-- Cada vez que el usuario le da de nuevo a "Execute" en su ejecutor
-- sin cerrar el juego, Lua crea una instancia NUEVA y separada de esta
-- libreria: las tablas locales de la ejecucion anterior se pierden,
-- pero las conexiones a servicios persistentes de Roblox (RunService,
-- UserInputService, la camara), los hilos (task.spawn) y los objetos
-- Drawing/GUI que creo la ejecucion anterior siguen vivos y corriendo
-- en segundo plano — se van duplicando en cada ejecucion y eso es lo
-- que causa la caida de FPS con el tiempo.
--
-- Para evitarlo, se guarda un registro en _G (que SI persiste entre
-- ejecuciones dentro de la misma sesion del ejecutor, a diferencia de
-- las variables locales del script) y se limpia automaticamente cada
-- vez que se crea una ventana nueva con Nub:CrearVentana.
local function limpiarInstanciaPrevia()
    local previa = _G.Nub_InstanciaActiva
    if type(previa) ~= "table" then return end

    -- 1) Desconectar conexiones (RenderStepped, Heartbeat, InputBegan,
    --    cambios de propiedad, clics, etc.)
    for _, conexion in ipairs(previa.Conexiones or {}) do
        pcall(function()
            if conexion and conexion.Connected then conexion:Disconnect() end
        end)
    end

    -- 2) Cancelar hilos (task.spawn / task.delay) que sigan corriendo
    for _, hilo in ipairs(previa.Hilos or {}) do
        pcall(function()
            if hilo and coroutine.status(hilo) ~= "dead" then task.cancel(hilo) end
        end)
    end

    -- 3) Eliminar objetos Drawing (cajas, tracers, cualquier Drawing.new)
    for _, objeto in ipairs(previa.Dibujos or {}) do
        pcall(function() if objeto then objeto:Remove() end end)
    end

    -- 4) Destruir instancias sueltas registradas manualmente
    --    (BillboardGuis, Highlights, etc. que no cuelguen de un GUI
    --    que ya se destruya por su cuenta)
    for _, inst in ipairs(previa.Instancias or {}) do
        pcall(function() if inst and inst.Parent then inst:Destroy() end end)
    end

    -- 5) Respaldo: destruir por nombre los GUIs propios de Nub que
    --    hayan quedado de la ejecucion anterior, por si algo no se
    --    registro manualmente
    pcall(function()
        local padre = obtenerPadreGui()
        for _, nombreGui in ipairs({"Nub_ScreenGui", "Nub_TooltipOverlay"}) do
            local viejo = padre:FindFirstChild(nombreGui)
            if viejo then viejo:Destroy() end
        end
    end)
end

local function crearRegistroInstancia(titulo)
    return { Conexiones = {}, Hilos = {}, Dibujos = {}, Instancias = {}, Ventana = nil, Titulo = titulo }
end

-- ── API PUBLICA de auto-limpieza ────────────────────────────────
-- El script que use la libreria (ej. un ESP) puede registrar sus
-- propios recursos aca para beneficiarse de la limpieza automatica
-- la proxima vez que se ejecute el script:
--   Nub:RegistrarConexion(conexion)          -- de un :Connect(...)
--   Nub:RegistrarHilo(hilo)                  -- de un task.spawn(...)
--   Nub:RegistrarDibujo(objetoDrawing)        -- de un Drawing.new(...)
--   Nub:RegistrarInstancia(instancia)         -- cualquier Instance suelto
-- Las cuatro funciones devuelven el mismo valor que reciben, para
-- poder envolver la creacion sin una linea extra, por ejemplo:
--   local conexion = Nub:RegistrarConexion(RunService.RenderStepped:Connect(miFuncion))
--   local hilo = Nub:RegistrarHilo(task.spawn(miLoop))
--   local caja = Nub:RegistrarDibujo(Drawing.new("Square"))
function Nub:RegistrarConexion(conexion)
    if _G.Nub_InstanciaActiva and conexion then
        table.insert(_G.Nub_InstanciaActiva.Conexiones, conexion)
    end
    return conexion
end

-- Desconecta una conexion Y la saca del registro global de
-- _G.Nub_InstanciaActiva.Conexiones en el mismo paso. Pensada para
-- conexiones que se registraron con RegistrarConexion (por si la
-- ventana se destruye antes) pero que ADEMAS se desconectan manualmente
-- en algun momento anterior a eso (ej. un tooltip que se cierra, un
-- dropdown que se cierra al tocar afuera). Sin esto, un Disconnect()
-- manual deja la entrada muerta acumulandose en el registro: no es un
-- leak funcional (la conexion ya esta desconectada, no sigue
-- reaccionando a nada), pero la tabla crece sin necesidad durante
-- sesiones largas con mucho uso de tooltips/dropdowns.
--
--   local c = Nub:RegistrarConexion(UserInputService.InputBegan:Connect(fn))
--   ...
--   Nub:DesconectarYLimpiar(c)   -- en vez de c:Disconnect() a mano
function Nub:DesconectarYLimpiar(conexion)
    if not conexion then return end
    pcall(function() conexion:Disconnect() end)
    if _G.Nub_InstanciaActiva then
        local lista = _G.Nub_InstanciaActiva.Conexiones
        local idx = table.find(lista, conexion)
        if idx then table.remove(lista, idx) end
    end
end

function Nub:RegistrarHilo(hilo)
    if _G.Nub_InstanciaActiva and hilo then
        table.insert(_G.Nub_InstanciaActiva.Hilos, hilo)
    end
    return hilo
end

function Nub:RegistrarDibujo(objetoDrawing)
    if _G.Nub_InstanciaActiva and objetoDrawing then
        table.insert(_G.Nub_InstanciaActiva.Dibujos, objetoDrawing)
    end
    return objetoDrawing
end

function Nub:RegistrarInstancia(instancia)
    if _G.Nub_InstanciaActiva and instancia then
        table.insert(_G.Nub_InstanciaActiva.Instancias, instancia)
    end
    return instancia
end

-- ── Tema activo ────────────────────────────────────────────────
local Theme = {}
for clave, valor in pairs(Themes.Lista[Themes.Predeterminado]) do Theme[clave] = valor end
Nub.Theme = Theme

-- ── Gradiente de acento ──────────────────────────────────────────
-- Degradado sutil (izq -> der) desde Theme.Accent hasta una version
-- ~12% mas clara del mismo color. Nativo (UIGradient), sin costo real
-- de rendimiento. Se registra en el mismo sistema de temas que ya
-- usa el resto de la libreria (Nub:Registrar), pasando una FUNCION
-- como 'claveTema' -- exactamente como ya hacen las pestañas para su
-- BackgroundColor3 dinamico -- asi el gradiente se recalcula solo
-- cada vez que cambia el tema, sin tocar nada mas.
--
-- IMPORTANTE: esta funcion tiene que estar definida DESPUES de
-- "local Theme = {}" de arriba. Si se define antes (mas arriba en
-- el archivo), Lua no puede verla como upvalue -- 'Theme' resolveria
-- a una variable GLOBAL inexistente (nil), y cualquier control que
-- llame a esta funcion tira "attempt to index nil with 'Accent'".
function Utils.GradienteAcento(instancia, intensidad)
    intensidad = intensidad or 0.12
    local function calcularSecuencia()
        local base = Theme.Accent
        local claro = base:Lerp(Color3.new(1, 1, 1), intensidad)
        return ColorSequence.new(base, claro)
    end

    local gradiente = Instance.new("UIGradient")
    gradiente.Color = calcularSecuencia()
    gradiente.Rotation = 0
    gradiente.Parent = instancia

    Nub:Registrar(gradiente, "Color", calcularSecuencia)
    return gradiente
end

-- Registro para ThemeManager
local registroTema = {}
local muertosTema = 0
function Nub:Registrar(instancia, propiedad, claveTema)
    local entrada = {instancia = instancia, propiedad = propiedad, claveTema = claveTema}
    table.insert(registroTema, entrada)
    -- Ver compactarRegistro: se marca muerta al destruirse y se compacta
    -- en lote, para no acumular instancias muertas en sesiones largas.
    if typeof(instancia) == "Instance" then
        instancia.Destroying:Connect(function()
            entrada.muerta = true
            muertosTema = muertosTema + 1
            if muertosTema >= 64 and muertosTema * 4 >= #registroTema then
                muertosTema = 0
                compactarRegistro(registroTema)
            end
        end)
    end
end

-- ── API PUBLICA: acceso rapido a flags y elementos ──────────────
-- Para developers externos que quieran leer/escribir controles por flag.
function Nub:ObtenerFlag(flag)
    return Nub.Flags[flag]
end

-- Marca uno o mas Flags como exclusivos de la pestaña "Preinstalada":
-- el sistema de PERFILES (SM:Guardar/Cargar/Listar/Eliminar) jamas los
-- incluira ni los sobreescribira -- tienen su propio guardado con
-- SM:GuardarUI()/CargarUI(). Se llama despues de crear el control:
--     Seccion:Dropdown({ Flag = "temaSeleccionado", ... })
--     Nub:MarcarComoUI("temaSeleccionado")
-- Acepta un flag suelto o una tabla de flags.
function Nub:MarcarComoUI(flagOTabla)
    if type(flagOTabla) == "table" then
        for _, f in ipairs(flagOTabla) do _flagsUI[f] = true end
    else
        _flagsUI[flagOTabla] = true
    end
end

function Nub:ObtenerElemento(flag)
    return Nub.Elementos[flag]
end

-- Atajo de conveniencia para developers: actualizar un Label (o
-- cualquier control con Set que acepte string/number) sin tener
-- que hacer Nub:ObtenerElemento(flag).Set(v) a mano.
-- Devuelve true si encontró el control, false si no existe.
function Nub:ActualizarLabel(flag, texto)
    local elem = self.Elementos[flag]
    if not elem then return false end
    local ok = pcall(elem.Set, texto)
    return ok
end

-- ══════════════════════════════════════════════════════════════
--  PROFILER (Propuesta 11) — foto instantanea bajo demanda
-- ══════════════════════════════════════════════════════════════
-- Complementa al panel de "Salud" ya existente en la pestaña
-- preinstalada (que corre en vivo mientras esa pestaña esta abierta):
-- esto es un snapshot que se puede pedir en cualquier momento desde
-- el propio script del developer o desde la consola, sin depender de
-- tener esa pestaña visible. Devuelve una tabla Y ademas la imprime
-- en consola en una sola linea, para poder usarse de las dos formas:
--   local datos = Nub:Profiler()
--   print(datos.Conexiones)
function Nub:Profiler()
    local datos = {
        Flags       = 0,
        Elementos   = 0,
        Conexiones  = 0,
        Hilos       = 0,
        Dibujos     = 0,
        Instancias  = 0,
        ObjetosGui  = 0,
        MemoriaMb   = nil,
    }

    -- 'Nub.Flags' es un proxy (setmetatable con __index = _flagsReales,
    -- ver mas arriba) -- pairs() NO dispara __index, solo itera claves
    -- FISICAMENTE presentes en la tabla base, que siempre esta vacia por
    -- diseño. Iterar sobre _flagsReales directamente (la tabla real
    -- donde viven los valores) es lo que hay que contar aca.
    for _ in pairs(_flagsReales) do datos.Flags = datos.Flags + 1 end
    for _ in pairs(Nub.Elementos) do datos.Elementos = datos.Elementos + 1 end

    local instancia = _G.Nub_InstanciaActiva
    if instancia then
        datos.Conexiones = #(instancia.Conexiones or {})
        datos.Hilos      = #(instancia.Hilos or {})
        datos.Dibujos    = #(instancia.Dibujos or {})
        datos.Instancias = #(instancia.Instancias or {})
    end

    local okGui, padreGui = pcall(obtenerPadreGui)
    if okGui and padreGui then
        local sg = padreGui:FindFirstChild("Nub_ScreenGui")
        if sg then
            local okDesc, descendientes = pcall(function() return sg:GetDescendants() end)
            if okDesc then datos.ObjetosGui = #descendientes end
        end
    end

    -- La memoria total del cliente es una aproximacion (no memoria
    -- exclusiva de Nub): no todos los ejecutores exponen Stats, asi
    -- que se protege con pcall y se deja en nil si no esta disponible.
    local okStats, statsService = pcall(function() return game:GetService("Stats") end)
    if okStats and statsService then
        local okMem, mem = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
        if okMem and type(mem) == "number" and mem > 0 then
            datos.MemoriaMb = math.floor(mem + 0.5)
        end
    end

    print(("[Nub] Profiler -> Flags:%d  Elementos:%d  Conexiones:%d  Hilos:%d  Dibujos:%d  Instancias:%d  ObjetosGUI:%d  Memoria:%s")
        :format(datos.Flags, datos.Elementos, datos.Conexiones, datos.Hilos,
                datos.Dibujos, datos.Instancias, datos.ObjetosGui,
                datos.MemoriaMb and ("~" .. datos.MemoriaMb .. "MB") or "N/D"))

    return datos
end

-- ══════════════════════════════════════════════════════════════
--  EVENT MANAGER — centraliza los InputChanged de arrastre.
--  Una sola conexion global; cada control solo registra quien
--  es el activo en ese momento. Usado por Slider, ColorPicker
--  Y ahora tambien por Utils.Arrastrable (ventana draggable).
-- ══════════════════════════════════════════════════════════════
local EventManager = {}
EventManager._activo = nil
EventManager._alFinalizar = nil -- callback opcional que corre UNA VEZ al soltar el arrastre

function EventManager:Arrastrar(callback, alFinalizar)
    self._activo = callback
    self._alFinalizar = alFinalizar
end

function EventManager:DetenerArrastre()
    self._activo = nil
    if self._alFinalizar then
        local cb = self._alFinalizar
        self._alFinalizar = nil
        pcall(cb)
    end
end

-- API PUBLICA: permite a cualquier control preguntar "¿se está
-- arrastrando algo ahora mismo?" antes de reaccionar a un click/tap.
-- Se usa para evitar que, mientras el dedo mueve un slider (o la
-- ventana, o un canal de color), el mismo gesto dispare por accidente
-- OTRO control que haya quedado debajo del dedo (ej. porque el layout
-- se movio al redimensionar la ventana con el slider de Ancho/Alto).
function EventManager:HayArrastreActivo()
    return self._activo ~= nil
end

-- Estas dos conexiones son a nivel de MODULO (se crean una sola vez
-- cuando el archivo se carga), no de ventana -- por eso NO pasan por
-- Nub:RegistrarConexion (ese registro recien existe una vez que se
-- llama CrearVentana, y estas corren antes). Sin proteccion, cada
-- re-ejecucion del script sumaba una conexion mas a InputChanged/
-- InputEnded que jamas se desconectaba -- crecian para siempre,
-- cada una reaccionando a CADA movimiento de mouse/touch de por vida.
-- Se les da su propio slot en _G para poder limpiar las de la
-- ejecucion anterior antes de crear las nuevas.
if type(_G.Nub_ConexionesEventManager) == "table" then
    for _, c in ipairs(_G.Nub_ConexionesEventManager) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.Nub_ConexionesEventManager = {}

local conexionInputChanged = UserInputService.InputChanged:Connect(function(input)
    if EventManager._activo and (
        input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch
    ) then
        pcall(EventManager._activo, input)
    end
end)

local conexionInputEnded = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        EventManager:DetenerArrastre()
    end
end)

table.insert(_G.Nub_ConexionesEventManager, conexionInputChanged)
table.insert(_G.Nub_ConexionesEventManager, conexionInputEnded)

Nub.EventManager = EventManager

-- ══════════════════════════════════════════════════════════════
--  ANIMATION MANAGER
-- ══════════════════════════════════════════════════════════════
local Animaciones = {}

function Animaciones.Fade(obj, transparenciaObjetivo, tiempo)
    return Utils.Tween(obj, {BackgroundTransparency = transparenciaObjetivo}, tiempo)
end

function Animaciones.Slide(obj, posicionObjetivo, tiempo)
    return Utils.Tween(obj, {Position = posicionObjetivo}, tiempo)
end

function Animaciones.Scale(obj, tamanoObjetivo, tiempo)
    return Utils.Tween(obj, {Size = tamanoObjetivo}, tiempo)
end

function Animaciones.Bounce(obj, tamanoNormal, tiempo)
    tiempo = tiempo or Nub.Motion.Modal
    local agrandado = UDim2.new(
        tamanoNormal.X.Scale, tamanoNormal.X.Offset + 4,
        tamanoNormal.Y.Scale, tamanoNormal.Y.Offset + 2
    )
    Utils.Tween(obj, {Size = agrandado}, tiempo / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    task.delay(tiempo / 2, function()
        if obj and obj.Parent then
            Utils.Tween(obj, {Size = tamanoNormal}, tiempo / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
    end)
end

Nub.Animaciones = Animaciones

-- ── Barra deslizante generica (Slider y ColorPicker) ───────────
-- cfg.AltoHitbox (opcional): alto del area de toque INVISIBLE, mas
-- grande que la barra visual. En PC el cursor es preciso y la barra
-- fina (6-10px) alcanza; en mobile con un dedo grueso es facil errar.
-- cfg.OffsetHitboxY (opcional, default 0): desplaza el hitbox hacia
-- abajo respecto del centro de la barra visual -- util cuando hay
-- otro control (ej. el TextBox de valor del Slider) pegado arriba y
-- agrandar el hitbox simetricamente lo invadiria.
local function crearBarraArrastrable(cfg)
    local fondo = Utils.Frame({
        Padre = cfg.Padre, Size = cfg.Size, Posicion = cfg.Posicion,
        Color = Theme.Entrada, Radio = 4,
    })
    Nub:Registrar(fondo, "BackgroundColor3", "Entrada")

    local aroArrastre = Utils.Stroke(fondo, Theme.AccentLight, 2, 1)
    Nub:Registrar(aroArrastre, "Color", "AccentLight")

    local function marcarArrastre(activo)
        Utils.Tween(aroArrastre, {Transparency = activo and 0 or 1}, Nub.Motion.Hover)
    end

    local relleno = Utils.Frame({
        Padre = fondo,
        Size = UDim2.new((cfg.Valor - cfg.Min) / (cfg.Max - cfg.Min), 0, 1, 0),
        Color = Theme.Accent, Radio = 4,
    })
    Nub:Registrar(relleno, "BackgroundColor3", "Accent")
    -- Intensidad mas alta (0.35) que el default de la funcion (0.12,
    -- el que usan el splash de carga y Progreso): en una barra fina de
    -- slider, un gradiente sutil casi no se nota -- este control es
    -- justamente el que se pidio que se vea "con brillo".
    Utils.GradienteAcento(relleno, 0.35)

    -- Manija (thumb) al final del relleno: un circulo que sigue al relleno solo
    -- (es su hijo, asi que no necesita tweens propios) y deja ver DONDE esta el
    -- valor. Su diametro depende de la altura de la barra (+6px). 'Manija = false'
    -- la omite.
    if cfg.Manija ~= false then
        local alturaBarra = (cfg.Size and cfg.Size.Y.Offset > 0) and cfg.Size.Y.Offset or 8
        local diametro = cfg.DiametroManija or (alturaBarra + 6)
        local manija = Utils.Frame({
            Padre = relleno, Size = UDim2.new(0, diametro, 0, diametro),
            Posicion = UDim2.new(1, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Highlight, Radio = 999,
        })
        manija.ZIndex = 3
        Nub:Registrar(manija, "BackgroundColor3", "Highlight")
        local trazoManija = Utils.Stroke(manija, Theme.Accent, 2, 0)
        Nub:Registrar(trazoManija, "Color", "Accent")
    end

    -- OPCIONAL (cfg.Pasos = true): marcas divisorias por cada escalon
    -- de 'Incremento', para sliders de valores discretos (ej. FOV en
    -- pasos de 5). Solo cosmetico -- no cambia el arrastre ni el
    -- redondeo, que ya hace Seccion:Slider. Se limita a un maximo de
    -- 40 marcas para no crear objetos de mas si alguien lo activa con
    -- un rango muy fino (ej. Incremento = 0.1 en un rango de 0-100).
    if cfg.Pasos and cfg.Incremento and cfg.Incremento > 0 then
        local totalPasos = math.floor((cfg.Max - cfg.Min) / cfg.Incremento + 0.5)
        if totalPasos >= 2 and totalPasos <= 40 then
            for i = 1, totalPasos - 1 do
                local rel = i / totalPasos
                local marca = Utils.Frame({
                    Padre = fondo, Size = UDim2.new(0, 2, 1, 0),
                    Posicion = UDim2.new(rel, -1, 0, 0),
                    Color = Theme.Border, Transparencia = 0.35, Radio = false,
                })
                marca.ZIndex = 2
                Nub:Registrar(marca, "BackgroundColor3", "Border")
            end
        end
    end

    -- Feedback directo: el relleno sigue al dedo/cursor SIN tween (cero
    -- latencia). Un cambio programatico (Set, carga de perfil) si se anima.
    local function fijarVisual(valor)
        local rel = math.clamp((valor - cfg.Min) / (cfg.Max - cfg.Min), 0, 1)
        local duracion = EventManager:HayArrastreActivo() and Nub.Motion.Directo or Nub.Motion.Page
        Utils.Tween(relleno, {Size = UDim2.new(rel, 0, 1, 0)}, duracion, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    end

    local function calcularYAplicar(input)
        local rel = math.clamp(
            (input.Position.X - fondo.AbsolutePosition.X) / fondo.AbsoluteSize.X, 0, 1
        )
        local v = cfg.Min + rel * (cfg.Max - cfg.Min)
        Utils.Tween(relleno, {Size = UDim2.new(rel, 0, 1, 0)}, Nub.Motion.Directo)
        cfg.OnCambio(v)
    end

    -- Si se pidio un hitbox ampliado, se crea un frame invisible
    -- HERMANO de 'fondo' (mismo padre), mas alto y centrado en la
    -- misma franja horizontal, que es el que efectivamente escucha
    -- el input -- pero calcularYAplicar() sigue leyendo
    -- fondo.AbsolutePosition/AbsoluteSize (la barra visual real), asi
    -- que el porcentaje de arrastre no se distorsiona por el tamaño
    -- del hitbox. Sin AltoHitbox, el comportamiento es identico al de
    -- siempre: 'fondo' mismo escucha su propio input.
    local objetoInput = fondo
    if cfg.AltoHitbox and cfg.AltoHitbox > 0 then
        local hitbox = Utils.Frame({
            Padre = fondo,
            Size = UDim2.new(1, (cfg.PadHitboxX or 0) * 2, 0, cfg.AltoHitbox),
            Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
            Transparencia = 1, Radio = false,
        })
        hitbox.ZIndex = fondo.ZIndex + 1
        objetoInput = hitbox
    end

    objetoInput.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            if EventManager:HayArrastreActivo() then return end

            -- Disambiguacion de gesto: al tocar, TODAVIA no sabemos si
            -- el usuario quiere arrastrar el slider o scrollear la
            -- pagina (si el slider vive dentro de un ScrollingFrame,
            -- que es el caso normal). Antes, se asumia arrastre desde
            -- el primer contacto -- se movia el thumb YA en el touch
            -- inicial y se desactivaba el scroll del ancestro de una,
            -- asi que cualquier intento de scrollear que pasara sobre
            -- un slider quedaba "atrapado" moviendolo en vez de
            -- scrollear la pagina (bug real reportado en mobile).
            --
            -- Ahora se espera a que el dedo se mueva un minimo
            -- (UMBRAL_GESTO) para recien ahi decidir por la direccion
            -- dominante del movimiento:
            --   |delta.X| > |delta.Y|  -> arrastre de verdad: recien
            --     aca se desactiva el scroll del ancestro y se mueve
            --     el thumb, nunca antes.
            --   |delta.Y| > |delta.X|  -> es un scroll: se libera el
            --     gesto sin tocar el slider ni el scroll (que nunca se
            --     llego a desactivar), y el ScrollingFrame nativo sigue
            --     scrolleando normal, sin ningun salto ni demora.
            -- Un toque corto que nunca supera el umbral (tap sin
            -- arrastre) tampoco mueve el slider -- cambio de
            -- comportamiento intencional respecto a la version
            -- anterior (que si movia el thumb al punto tocado con un
            -- tap simple): ese "tap para posicionar" era justamente lo
            -- que causaba el bug, asi que se elimina.
            local UMBRAL_GESTO = 10 -- px
            local inicio = Vector2.new(input.Position.X, input.Position.Y)
            local decidido = false
            local esArrastre = false

            local scrollAncestro = fondo:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollEstabaActivo = scrollAncestro and scrollAncestro.ScrollingEnabled

            local function candidato(inputMovido)
                if not decidido then
                    local actual = Vector2.new(inputMovido.Position.X, inputMovido.Position.Y)
                    local delta = actual - inicio
                    if delta.Magnitude < UMBRAL_GESTO then
                        return -- todavia no se movio lo suficiente para decidir
                    end
                    decidido = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        esArrastre = true
                        if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                        marcarArrastre(true)
                    else
                        -- Es scroll: se libera el gesto sin tocar nada
                        -- mas -- el scroll nativo nunca se desactivo,
                        -- asi que sigue andando sin interrupcion.
                        EventManager:DetenerArrastre()
                        return
                    end
                end
                if esArrastre then
                    calcularYAplicar(inputMovido)
                end
            end

            if input.UserInputType == Enum.UserInputType.MouseButton1 and Nub.Opciones.ClickDirectoEnBarras ~= false then
                decidido, esArrastre = true, true
                if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                marcarArrastre(true)
                calcularYAplicar(input)
            end

            EventManager:Arrastrar(candidato, function()
                if esArrastre then marcarArrastre(false) end
                if scrollAncestro then scrollAncestro.ScrollingEnabled = scrollEstabaActivo end
            end)
        end
    end)

    return fondo, relleno, fijarVisual
end

-- ══════════════════════════════════════════════════════════════
--  SELECTOR 2D (saturacion/valor + barra de matiz) — usado por
--  ColorPicker con Estilo = "2D".
--  El cuadrado se arma con CAPAS superpuestas sobre un fondo del color
--  de matiz puro: una capa blanca que se desvanece hacia la derecha
--  (saturacion) y una negra que se desvanece hacia arriba (valor). No
--  se pueden poner los dos gradientes en el mismo marco: la
--  transparencia del gradiente afectaria al fondo mismo.
--  Devuelve { sincronizarDeColor3(c), conectarOnCambio(cb) }.
-- ══════════════════════════════════════════════════════════════
local function crearColorPicker2D(cfg)
    local cuadro = Utils.Frame({
        Padre = cfg.Padre, Size = UDim2.new(1, 0, 0, cfg.AltoCuadro or 100),
        Orden = cfg.OrdenCuadro or 1, Color = Color3.fromHSV(0, 1, 1), Radio = 6,
    })

    local capaBlanca = Utils.Frame({
        Padre = cuadro, Size = UDim2.new(1, 0, 1, 0), Color = Color3.new(1, 1, 1), Radio = 6,
    })
    capaBlanca.ZIndex = cuadro.ZIndex + 1
    local gradBlanco = Instance.new("UIGradient")
    gradBlanco.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
    })
    gradBlanco.Rotation = 0 -- izquierda (blanco) -> derecha (transparente)
    gradBlanco.Parent = capaBlanca

    local capaNegra = Utils.Frame({
        Padre = cuadro, Size = UDim2.new(1, 0, 1, 0), Color = Color3.new(0, 0, 0), Radio = 6,
    })
    capaNegra.ZIndex = cuadro.ZIndex + 2
    local gradNegro = Instance.new("UIGradient")
    gradNegro.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0),
    })
    gradNegro.Rotation = 90 -- arriba (transparente) -> abajo (negro)
    gradNegro.Parent = capaNegra

    local indicador = Utils.Frame({
        Padre = cuadro, Size = UDim2.new(0, 12, 0, 12), Ancla = Vector2.new(0.5, 0.5),
        Color = Color3.new(1, 1, 1), Radio = 999,
    })
    indicador.ZIndex = cuadro.ZIndex + 3
    Utils.Stroke(indicador, Color3.new(0, 0, 0), 2, 0)

    local barraHue = Utils.Frame({
        Padre = cfg.Padre, Size = UDim2.new(1, 0, 0, cfg.AltoHue or 14),
        Orden = cfg.OrdenHue or 2, Color = Color3.new(1, 1, 1), Radio = 6,
    })
    local gradHue = Instance.new("UIGradient")
    gradHue.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.500, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1.000, Color3.fromRGB(255, 0, 0)),
    })
    gradHue.Parent = barraHue
    local manijaHue = Utils.Frame({
        Padre = barraHue, Size = UDim2.new(0, 8, 1, 6), Ancla = Vector2.new(0.5, 0.5),
        Posicion = UDim2.new(0, 0, 0.5, 0), Color = Color3.new(1, 1, 1), Radio = 4,
    })
    manijaHue.ZIndex = barraHue.ZIndex + 2
    Utils.Stroke(manijaHue, Color3.new(0, 0, 0), 2, 0)

    -- Estado. El matiz (h) se conserva cuando el color es gris o negro: ahi
    -- toHSV devuelve h = 0 y, sin esto, el matiz saltaria a rojo.
    local h, s, v = 0, 0, 1
    local alCambiar = nil

    local function refrescar()
        cuadro.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        indicador.Position = UDim2.new(s, 0, 1 - v, 0)
        manijaHue.Position = UDim2.new(h, 0, 0.5, 0)
    end

    local function dispararCambio()
        refrescar()
        if alCambiar then alCambiar(Color3.fromHSV(h, s, v)) end
    end

    -- Zonas de input: BotonBase es transparente por defecto y recibe el toque.
    local function conectarArrastre(zona, aplicar)
        zona.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if EventManager:HayArrastreActivo() then return end
            -- Aqui no hay que decidir entre "scroll" y "arrastre" como en un
            -- slider: tocar el cuadrado siempre significa elegir color, asi que
            -- se bloquea el scroll de la pagina mientras dura el gesto.
            local scrollAncestro = zona:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollEstabaActivo = scrollAncestro and scrollAncestro.ScrollingEnabled
            if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
            aplicar(input)
            EventManager:Arrastrar(aplicar, function()
                if scrollAncestro then scrollAncestro.ScrollingEnabled = scrollEstabaActivo end
            end)
        end)
    end

    local zonaCuadro = Utils.BotonBase({ Padre = cuadro, Size = UDim2.new(1, 0, 1, 0) })
    zonaCuadro.ZIndex = cuadro.ZIndex + 4
    conectarArrastre(zonaCuadro, function(inp)
        s = math.clamp((inp.Position.X - cuadro.AbsolutePosition.X) / math.max(cuadro.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((inp.Position.Y - cuadro.AbsolutePosition.Y) / math.max(cuadro.AbsoluteSize.Y, 1), 0, 1)
        dispararCambio()
    end)

    local zonaHue = Utils.BotonBase({ Padre = barraHue, Size = UDim2.new(1, 0, 1, 0) })
    zonaHue.ZIndex = barraHue.ZIndex + 3
    conectarArrastre(zonaHue, function(inp)
        h = math.clamp((inp.Position.X - barraHue.AbsolutePosition.X) / math.max(barraHue.AbsoluteSize.X, 1), 0, 1)
        dispararCambio()
    end)

    return {
        sincronizarDeColor3 = function(c)
            local nh, ns, nv = Color3.toHSV(c)
            if ns > 0.001 and nv > 0.001 then h = nh end
            s, v = ns, nv
            refrescar()
        end,
        conectarOnCambio = function(cb) alCambiar = cb end,
    }
end

-- ══════════════════════════════════════════════════════════════
--  BARRA ARRASTRABLE DE RANGO (doble manija) — usada por RangeSlider.
--  Variante de crearBarraArrastrable con DOS thumbs (Min y Max) sobre
--  un mismo fondo, y un relleno central entre ambos en vez de desde
--  el borde izquierdo. Reusa el mismo patron de disambiguacion de
--  gesto (scroll vs arrastre) que la barra simple -- ver los
--  comentarios de crearBarraArrastrable para el porque de cada parte;
--  aca solo se documenta lo que es DISTINTO por tener dos manijas.
--
--  A diferencia de crearBarraArrastrable, el relleno se mueve directo
--  (sin Tween) durante el arrastre: cambia Position Y Size a la vez
--  en cada evento, y tweenear ambas propiedades por separado con la
--  maquinaria generica de Utils.Tween en cada pixel de arrastre seria
--  mas costoso que el beneficio visual -- el slider simple solo
--  tweenea Size porque Position ahi es siempre 0,0.
-- ══════════════════════════════════════════════════════════════
local function crearBarraArrastrableRango(cfg)
    local fondo = Utils.Frame({
        Padre = cfg.Padre, Size = cfg.Size, Posicion = cfg.Posicion,
        Color = Theme.Entrada, Radio = 4,
    })
    Nub:Registrar(fondo, "BackgroundColor3", "Entrada")

    local function relX(v)
        return math.clamp((v - cfg.Min) / (cfg.Max - cfg.Min), 0, 1)
    end

    -- Relleno ENTRE las dos manijas (no desde el borde izquierdo como
    -- en el slider simple).
    local relleno = Utils.Frame({
        Padre = fondo,
        Posicion = UDim2.new(relX(cfg.ValorMin), 0, 0, 0),
        Size = UDim2.new(relX(cfg.ValorMax) - relX(cfg.ValorMin), 0, 1, 0),
        Color = Theme.Accent, Radio = 4,
    })
    Nub:Registrar(relleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(relleno, 0.35)

    -- Las dos manijas son circulos (Frame + Corner al 100%) mas
    -- grandes que el alto de la barra, ancladas a su propio centro
    -- para que puedan pararse EXACTO sobre el borde del relleno.
    local DIAMETRO_MANIJA = cfg.DiametroManija or 16
    local function crearManija()
        local m = Utils.Frame({
            Padre = fondo,
            Size = UDim2.new(0, DIAMETRO_MANIJA, 0, DIAMETRO_MANIJA),
            Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Highlight, Radio = 999,
        })
        m.ZIndex = 3
        Nub:Registrar(m, "BackgroundColor3", "Highlight")
        local aro = Utils.Stroke(m, Theme.AccentLight, 2, 1)
        Nub:Registrar(aro, "Color", "AccentLight")
        return m, aro
    end
    local manijaMin, aroMin = crearManija()
    local manijaMax, aroMax = crearManija()

    local function posicionarManija(manija, v)
        manija.Position = UDim2.new(relX(v), 0, 0.5, 0)
    end
    posicionarManija(manijaMin, cfg.ValorMin)
    posicionarManija(manijaMax, cfg.ValorMax)

    local function marcarArrastre(aro, activo)
        Utils.Tween(aro, {Transparency = activo and 0 or 1}, Nub.Motion.Hover)
    end

    -- Redibuja ambas manijas y el relleno para un par de valores ya
    -- calculados. Usado por Set() / carga de guardado -- no forma
    -- parte del loop de arrastre (que redibuja directo, ver arriba).
    local function fijarVisual(vMin, vMax)
        posicionarManija(manijaMin, vMin)
        posicionarManija(manijaMax, vMax)
        relleno.Position = UDim2.new(relX(vMin), 0, 0, 0)
        relleno.Size = UDim2.new(relX(vMax) - relX(vMin), 0, 1, 0)
    end

    local function calcularValor(input)
        local rel = math.clamp(
            (input.Position.X - fondo.AbsolutePosition.X) / fondo.AbsoluteSize.X, 0, 1
        )
        return cfg.Min + rel * (cfg.Max - cfg.Min)
    end

    local objetoInputRango = fondo
    if cfg.AltoHitbox and cfg.AltoHitbox > 0 then
        objetoInputRango = Utils.Frame({
            Padre = fondo,
            Size = UDim2.new(1, (cfg.PadHitboxX or 0) * 2, 0, cfg.AltoHitbox),
            Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
            Transparencia = 1, Radio = false,
        })
        objetoInputRango.ZIndex = fondo.ZIndex + 1
    end

    objetoInputRango.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            if EventManager:HayArrastreActivo() then return end

            local UMBRAL_GESTO = 10
            local inicio = Vector2.new(input.Position.X, input.Position.Y)
            local decidido = false
            local esArrastre = false
            -- Que manija se mueve con este gesto: se decide UNA vez,
            -- al confirmarse que es arrastre (no antes) -- por
            -- cercania al punto donde arranco el toque. Empate (ej.
            -- rango colapsado a un solo punto, mismo valor en ambas):
            -- gana la manija que todavia tiene margen para moverse
            -- hacia el lado del toque, para que el gesto nunca quede
            -- "trabado" sin efecto visible.
            local moviendoMin = nil

            local scrollAncestro = fondo:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollEstabaActivo = scrollAncestro and scrollAncestro.ScrollingEnabled

            local function elegirManija(inputInicial)
                local vToque = calcularValor(inputInicial)
                local vMin, vMax = cfg.ObtenerMin(), cfg.ObtenerMax()
                local distMin, distMax = math.abs(vToque - vMin), math.abs(vToque - vMax)
                if distMin < distMax then
                    moviendoMin = true
                elseif distMax < distMin then
                    moviendoMin = false
                else
                    moviendoMin = vToque <= vMin
                end
            end

            local function candidato(inputMovido)
                if not decidido then
                    local actual = Vector2.new(inputMovido.Position.X, inputMovido.Position.Y)
                    local delta = actual - inicio
                    if delta.Magnitude < UMBRAL_GESTO then return end
                    decidido = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        esArrastre = true
                        elegirManija(input)
                        if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                        marcarArrastre(moviendoMin and aroMin or aroMax, true)
                    else
                        EventManager:DetenerArrastre()
                        return
                    end
                end
                if not esArrastre then return end

                local v = calcularValor(inputMovido)
                local vMin, vMax = cfg.ObtenerMin(), cfg.ObtenerMax()
                if moviendoMin then
                    v = math.min(v, vMax) -- Min nunca cruza a Max
                    posicionarManija(manijaMin, v)
                    cfg.OnCambio(v, vMax)
                else
                    v = math.max(v, vMin) -- Max nunca cruza a Min
                    posicionarManija(manijaMax, v)
                    cfg.OnCambio(vMin, v)
                end
                -- Relleno: siempre recalculado desde el par actual de
                -- valores (no desde 'v' solo), asi que un OnCambio que
                -- redondeara al vuelo (via cfg.ObtenerMin/Max, que
                -- leen el valor YA procesado) queda reflejado sin
                -- desincronizarse del thumb.
                local vMinReal, vMaxReal = cfg.ObtenerMin(), cfg.ObtenerMax()
                relleno.Position = UDim2.new(relX(vMinReal), 0, 0, 0)
                relleno.Size = UDim2.new(relX(vMaxReal) - relX(vMinReal), 0, 1, 0)
            end

            if input.UserInputType == Enum.UserInputType.MouseButton1 and Nub.Opciones.ClickDirectoEnBarras ~= false then
                decidido, esArrastre = true, true
                elegirManija(input)
                if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                marcarArrastre(moviendoMin and aroMin or aroMax, true)
                candidato(input)
            end

            EventManager:Arrastrar(candidato, function()
                if esArrastre then
                    marcarArrastre(moviendoMin and aroMin or aroMax, false)
                end
                if scrollAncestro then scrollAncestro.ScrollingEnabled = scrollEstabaActivo end
            end)
        end
    end)

    return fondo, fijarVisual
end

-- ── Panel expandible generico (Dropdown y ColorPicker) ─────────
-- El panel se cierra al volver a tocar la cabecera (o, en un
-- Dropdown de seleccion unica, al elegir una opcion), y tambien con
-- un TAP en cualquier otra parte de la pantalla mientras esta
-- abierto. "Tap" = el toque empezo FUERA del panel y termino sin
-- moverse mas del umbral de ClickConfiable: si el dedo/cursor se
-- movio, fue un scroll o un arrastre y el panel sigue abierto. Para
-- eso hay dos conexiones (InputBegan + InputEnded), creadas DESPUES de
-- que el click de apertura ya disparo (no se auto-cierra con su propio
-- click). Se registran con Nub:RegistrarConexion para quedar
-- cubiertas por la auto-limpieza al re-ejecutar el script, y se
-- desconectan juntas apenas se cierra (tap afuera o click en la
-- cabecera) para no dejar listeners sueltos con el panel cerrado.
local function hacerExpandible(marco, altoCerrado, obtenerAltoAbierto)
    local abierto = false
    -- Dos conexiones (InputBegan + InputEnded) que viven y mueren juntas.
    local conexionesCierre = {}

    local function estaFuera(input)
        local pos = marco.AbsolutePosition
        local tam = marco.AbsoluteSize
        local x, y = input.Position.X, input.Position.Y
        return x < pos.X or x > pos.X + tam.X or y < pos.Y or y > pos.Y + tam.Y
    end

    local function limpiarConexionesCierre()
        for _, conexion in ipairs(conexionesCierre) do
            Nub:DesconectarYLimpiar(conexion)
        end
        conexionesCierre = {}
    end

    local function alternar()
        abierto = not abierto
        local alto = abierto and obtenerAltoAbierto() or altoCerrado
        Utils.Tween(marco, {Size = UDim2.new(1, 0, 0, alto)}, Nub.Motion.Expand)

        -- DesconectarYLimpiar desconecta la conexion Y saca su entrada
        -- del registro global en un solo paso -- esta funcion la usa
        -- CADA Dropdown/panel expandible de la interfaz cada vez que
        -- se abre y se cierra.
        limpiarConexionesCierre()

        if abierto then
            -- Cierra con un TAP real, no con el inicio de un scroll: al
            -- tocar fuera se guarda donde empezo el toque, y recien al
            -- soltar se decide. Si el dedo/cursor se movio mas del umbral
            -- fue un scroll o un arrastre (no se cierra); si no, fue un
            -- tap (se cierra). Mismo criterio y umbrales que
            -- Utils.ClickConfiable.
            local UMBRAL_MOVIMIENTO = Nub.Capacidades.EsTactil and 18 or 10
            local inicio = nil
            table.insert(conexionesCierre, Nub:RegistrarConexion(
                UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
                       input.UserInputType ~= Enum.UserInputType.Touch then return end
                    if marco.Parent and estaFuera(input) then
                        inicio = {
                            tipo = input.UserInputType,
                            pos = Vector2.new(input.Position.X, input.Position.Y),
                        }
                    else
                        inicio = nil
                    end
                end)
            ))
            table.insert(conexionesCierre, Nub:RegistrarConexion(
                UserInputService.InputEnded:Connect(function(input)
                    if not inicio or input.UserInputType ~= inicio.tipo then return end
                    local movio = (Vector2.new(input.Position.X, input.Position.Y) - inicio.pos).Magnitude > UMBRAL_MOVIMIENTO
                    inicio = nil
                    if movio then return end -- fue un scroll/arrastre, no un tap
                    if marco.Parent and abierto then alternar() end
                end)
            ))
        end

        return abierto
    end
    return alternar
end

-- ══════════════════════════════════════════════════════════════
--  TOOLTIPS
-- ══════════════════════════════════════════════════════════════
local function anchoTexto(texto, tamano)
    return TextService:GetTextSize(
        texto or "", tamano or 11, Enum.Font.Gotham, Vector2.new(1000, 20)
    ).X
end

local overlayGui, panelAyuda, lblAyuda, conexionCierreGlobal

local function obtenerOverlayTooltip()
    if overlayGui and overlayGui.Parent then return overlayGui end

    overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "Nub_TooltipOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 999
    pcall(function() overlayGui.Parent = obtenerPadreGui() end)
    protegerGui(overlayGui)

    panelAyuda = Instance.new("Frame")
    panelAyuda.Name = "PanelAyuda"
    panelAyuda.BackgroundColor3 = Theme.Panel
    panelAyuda.BorderSizePixel = 0
    panelAyuda.Visible = false
    panelAyuda.ZIndex = 1000
    panelAyuda.Size = UDim2.new(0, 224, 0, 0)
    panelAyuda.AutomaticSize = Enum.AutomaticSize.Y
    panelAyuda.Parent = overlayGui
    Nub:Registrar(panelAyuda, "BackgroundColor3", "Panel")
    Utils.Corner(panelAyuda, 6)
    local strokeTooltip = Utils.Stroke(panelAyuda, Theme.Accent, 1, 0.3)
    Nub:Registrar(strokeTooltip, "Color", "Accent")

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight   = UDim.new(0, 12), UDim.new(0, 12)
    pad.PaddingTop,  pad.PaddingBottom  = UDim.new(0, 9), UDim.new(0, 9)
    pad.Parent = panelAyuda

    lblAyuda = Utils.Texto({
        Padre = panelAyuda, Texto = "",
        Size = UDim2.new(1, 0, 0, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Tamano = 11, Ajustar = true,
    })
    lblAyuda.LineHeight = 1.15
    lblAyuda.AutomaticSize = Enum.AutomaticSize.Y
    lblAyuda.ZIndex = 1001
    Nub:Registrar(lblAyuda, "TextColor3", "Text")

    return overlayGui
end

local function cerrarTooltipGlobal()
    if panelAyuda then panelAyuda.Visible = false end
    if conexionCierreGlobal then
        Nub:DesconectarYLimpiar(conexionCierreGlobal)
        conexionCierreGlobal = nil
    end
end

-- Muestra el panel de ayuda anclado a 'elementoRef' (cualquier
-- GuiObject: el boton "?" o directamente la fila entera). Compartida
-- entre el click del "?" y el nuevo "mantener presionado en la fila".
local function mostrarTooltipEn(elementoRef, textoAyuda)
    obtenerOverlayTooltip()

    if panelAyuda.Visible and lblAyuda.Text == textoAyuda then
        cerrarTooltipGlobal()
        return
    end

    -- IMPORTANTE: si ya habia otro tooltip abierto (con OTRO
    -- texto), su conexion de "cerrar al tocar afuera" quedaba
    -- huerfana aca antes de este fix -- se sobreescribia la
    -- variable sin desconectar la anterior. Cada "?" que el
    -- usuario tocaba mientras otro tooltip ya estaba abierto
    -- sumaba una conexion de UserInputService que nunca se
    -- liberaba, y eso es exactamente el tipo de fuga que hace
    -- bajar el FPS de a poco cuanto mas se usa la interfaz.
    cerrarTooltipGlobal()

    lblAyuda.Text = textoAyuda
    panelAyuda.Size = UDim2.new(0, 224, 0, 0)

    -- Posicion en coordenadas absolutas de pantalla, justo debajo
    -- del elemento de referencia (el overlay cubre toda la pantalla)
    local pos = elementoRef.AbsolutePosition
    local tam = elementoRef.AbsoluteSize
    local x = pos.X
    local y = pos.Y + tam.Y + 4
    local anchoPantalla = overlayGui.AbsoluteSize.X
    if anchoPantalla > 0 then
        x = math.min(x, anchoPantalla - 232)
    end
    panelAyuda.Position = UDim2.new(0, math.max(4, x), 0, y)
    panelAyuda.Visible = true

    -- Pop de entrada con UIScale: el panel arranca en 0.9x y sube a
    -- 1.0x con Back Out. Se crea/reutiliza el UIScale del panel (mismo
    -- patron defensivo que Utils.ClickFeedback, por si algun dia se
    -- anade otro sistema que use UIScale en el mismo objeto).
    local escalaTip = panelAyuda:FindFirstChild("__Nub_TooltipScale")
    if not escalaTip then
        escalaTip = Instance.new("UIScale")
        escalaTip.Name = "__Nub_TooltipScale"
        escalaTip.Parent = panelAyuda
    end
    escalaTip.Scale = 0.9
    Utils.Tween(escalaTip, {Scale = 1}, Nub.Motion.Expand, Nub.Motion.EasePop, Enum.EasingDirection.Out)

    -- El SIGUIENTE click/toque, sin importar donde sea, cierra el
    -- tooltip. No se cierra con el mismo toque que lo abrio (esta
    -- conexion se crea DESPUES de que ese InputBegan ya disparo), asi
    -- que solo reacciona a un click/toque genuinamente nuevo. Queda
    -- registrada en RegistrarConexion y se desconecta con
    -- DesconectarYLimpiar (no con :Disconnect() suelto), para quedar
    -- cubierta tambien si la ventana se destruye mientras el tooltip
    -- esta abierto.
    conexionCierreGlobal = Nub:RegistrarConexion(
        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
               input.UserInputType ~= Enum.UserInputType.Touch then return end
            cerrarTooltipGlobal()
        end)
    )
end

local function agregarTooltip(fila, posicion, textoAyuda)
    if not textoAyuda then return end

    local btnInfo = Utils.BotonBase({
        Padre = fila, Size = UDim2.new(0, 20, 0, 20),
        Posicion = posicion, Color = Theme.AccentLight,
        Transparencia = 0, Radio = 10,
    })
    btnInfo.ZIndex = 5
    Nub:Registrar(btnInfo, "BackgroundColor3", "AccentLight")

    local lblSigno = Utils.Texto({
        Padre = btnInfo, Texto = "?",
        Alineacion = Enum.TextXAlignment.Center,
        Fuente = Enum.Font.GothamBold, Tamano = 12,
        Color = Theme.TextDark,
    })
    Nub:Registrar(lblSigno, "TextColor3", "TextDark")

    btnInfo.MouseButton1Click:Connect(function()
        mostrarTooltipEn(btnInfo, textoAyuda)
    end)

    return btnInfo
end

-- Atajo para filas con label de texto.
-- 'lblInstancia' es opcional: si se pasa la instancia real del
-- TextLabel, el "?" se reposiciona solo cada vez que el texto cambia
-- de tamaño (ej. al mover el slider "Tamaño del texto general" en la
-- pestaña Preinstalada). Sin esto, la posicion del "?" quedaba fija
-- calculada una sola vez con el tamaño de letra ORIGINAL, y cuando el
-- usuario agrandaba el texto despues, el label se lo comia por encima.
local function agregarTooltipTexto(fila, textoLabel, textoAyuda, lblInstancia, offsetDerecho)
    if not textoAyuda then return end
    -- REDISEÑO COMPLETO (el enfoque anterior medía el ancho del texto
    -- en píxeles -- via TextService o TextBounds -- y recalculaba la
    -- posición del "?" cada vez que el texto podía haber cambiado de
    -- tamaño: por escala de texto, por escala de interfaz, por texto
    -- truncado que se re-mide, etc. Pese a 3 capas de recálculo
    -- (AbsoluteSize, TextBounds, TextSize) el "?" seguía apareciendo
    -- encima de palabras: siempre existe una ventana de tiempo entre
    -- "el texto cambió" y "el listener recalculó" donde el "?" queda
    -- en la posición vieja mientras el texto ya es otro. Es un
    -- problema estructural del enfoque "medir y reaccionar", no un
    -- caso puntual sin cubrir.
    --
    -- SOLUCION: el "?" ya NO se posiciona según el ancho del TEXTO.
    -- Se posiciona según el 'lbl.Size' que cada control YA declaro al
    -- crear su label -- ese Size es fijo (ej. UDim2.new(1, -50, 1, 0)
    -- en crearCabecera), reservado a proposito para dejarle lugar al
    -- contenido de la derecha (switch, valor, botones). El "?" se
    -- ancla justo AL FINAL de ese espacio ya reservado, sin medir
    -- absolutamente nada del contenido del texto. Como el hueco es
    -- fijo por diseño, es imposible que el "?" invada el switch/valor
    -- de la derecha (ya estaba fuera de ese espacio de antemano), y es
    -- imposible que la escala de texto lo mueva (no depende de eso).
    --
    -- Unico costo: el "?" queda a una distancia FIJA del borde
    -- derecho del label, no "pegado exactamente despues de la ultima
    -- letra". Si el texto es corto, puede quedar con mas aire a la
    -- derecha del texto que antes. Es un compromiso deliberado: un
    -- espacio en blanco ocasional es un problema cosmetico menor
    -- comparado con el "?" tapando palabras de forma cronica.
    if not (lblInstancia and lblInstancia.Size) then
        -- Sin lblInstancia no hay Size fijo de donde anclarse -- cae al
        -- comportamiento minimo (posicion fija generica) en vez de
        -- fallar en silencio.
        agregarTooltip(fila, UDim2.new(0, 160, 0, 8), textoAyuda)
        return
    end

    local TAM_INFO = 20
    local RESERVA  = TAM_INFO + 12
    local sx = lblInstancia.Size.X.Scale
    local ox = offsetDerecho or lblInstancia.Size.X.Offset
    local px = lblInstancia.Position.X.Offset
    lblInstancia.Size = UDim2.new(sx, ox - RESERVA - px,
        lblInstancia.Size.Y.Scale, lblInstancia.Size.Y.Offset)

    local xInfo = ox - TAM_INFO - 6
    local btnInfo = agregarTooltip(fila, UDim2.new(sx, xInfo, 0.5, 0), textoAyuda)
    btnInfo.AnchorPoint = Vector2.new(0, 0.5)

    local function centrarY()
        if not (btnInfo.Parent and lblInstancia.Parent and fila.Parent) then return end
        if lblInstancia.AbsoluteSize.Y <= 0 then return end
        local e = Utils.FactorEscalaUI(fila)
        local cy = (lblInstancia.AbsolutePosition.Y - fila.AbsolutePosition.Y
            + lblInstancia.AbsoluteSize.Y / 2) / e
        btnInfo.Position = UDim2.new(sx, xInfo, 0, math.floor(cy + 0.5))
    end
    Nub:RegistrarConexion(lblInstancia:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        centrarY(); task.defer(centrarY)
    end))
    Nub:RegistrarConexion(fila:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        centrarY(); task.defer(centrarY)
    end))
    task.defer(centrarY)

    -- Mantener presionado en CUALQUIER parte de la fila (no solo en
    -- el "?") tambien muestra el mismo tooltip. Funciona en paralelo
    -- al click del "?" -- no lo reemplaza, y no interfiere con el
    -- click normal de Toggle/Boton/etc: esto solo OBSERVA el input,
    -- nunca lo bloquea ni lo retrasa, asi que un click corto sigue
    -- disparando el Toggle/Boton al instante como siempre.
    --
    -- BUG REAL: antes solo chequeaba "seguis presionando?" -- pero
    -- scrollear la pagina TAMBIEN cuenta como "seguir presionando"
    -- mientras arrastras el dedo. No habia forma de distinguir
    -- "mantener quieto para pedir ayuda" de "estoy scrolleando".
    -- Ahora se guarda la posicion donde empezo el toque, y si se
    -- movio mas de UMBRAL_MOVIMIENTO px antes de que se cumpla el
    -- tiempo de espera, se asume que es un scroll y NO se muestra
    -- el tooltip.
    --
    -- Detalles que lo hacen confiable en touch (antes fallaba al mantener
    -- el dedo en el Label y otras filas):
    --  * Umbral de movimiento igual al de Utils.ClickConfiable (18px en
    --    touch, 10px con mouse): el dedo nunca esta 100% quieto y 10px
    --    en touch es solo ~3mm.
    --  * Se vigila el toque cada 50ms durante la espera, en vez de mirar
    --    una sola vez al final: si el dedo se mueve de verdad se cancela
    --    al instante (scroll), y si no, el tooltip aparece justo a los
    --    0.45s sin depender de que InputEnded haya llegado a esta fila.
    --  * Segundo disparador: el evento TouchLongPress de la propia fila.
    --    Solo ABRE el tooltip (nunca lo cierra), asi que si los dos
    --    disparadores coinciden no se anulan entre si.
    fila.Active = true
    local UMBRAL_MOVIMIENTO = Nub.Capacidades.EsTactil and 18 or 10 -- px
    local TIEMPO_MANTENER = 0.45
    local toqueActual = nil

    local function abrirSiNoEstaAbierto()
        if EventManager:HayArrastreActivo() then return end
        if panelAyuda and panelAyuda.Visible and lblAyuda and lblAyuda.Text == textoAyuda then return end
        pcall(mostrarTooltipEn, fila, textoAyuda)
    end

    fila.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        toqueActual = input
        local posInicial = Vector2.new(input.Position.X, input.Position.Y)
        local inicio = os.clock()
        task.spawn(function()
            while toqueActual == input do
                if not (fila and fila.Parent) then return end
                if input.UserInputState == Enum.UserInputState.End then return end
                if EventManager:HayArrastreActivo() then return end
                local pos = Vector2.new(input.Position.X, input.Position.Y)
                if (pos - posInicial).Magnitude > UMBRAL_MOVIMIENTO then
                    return -- se movio: era un scroll, no un "mantener quieto"
                end
                if os.clock() - inicio >= TIEMPO_MANTENER then
                    toqueActual = nil
                    abrirSiNoEstaAbierto()
                    return
                end
                task.wait(0.05)
            end
        end)
    end)
    fila.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        toqueActual = nil
    end)
    pcall(function()
        fila.TouchLongPress:Connect(function(_, estado)
            if estado == Enum.UserInputState.Begin then abrirSiNoEstaAbierto() end
        end)
    end)

    -- Sin recalculos: la posicion de btnInfo es UDim2.new(1, posXBoton, 0, 8),
    -- fija relativa al ANCHO DE FILA (Scale=1), no al texto. Si la fila
    -- cambia de ancho, Roblox reubica el "?" solo (como cualquier
    -- elemento anclado por Scale); no depende del contenido ni tamaño
    -- del texto, asi que no hace falta escuchar TextBounds/TextSize/
    -- AbsoluteSize del label nunca mas.

    return btnInfo
end

-- ══════════════════════════════════════════════════════════════
--  BUSCADOR GLOBAL
-- ══════════════════════════════════════════════════════════════
local indiceBusqueda = {}

-- ══════════════════════════════════════════════════════════════
--  REGISTRO DE SECCIONES COLAPSABLES
-- ══════════════════════════════════════════════════════════════
-- Cada Tab:CrearSeccion agrega aca una entrada con su marco, su
-- contenedor de controles, la flecha del header (si es colapsable),
-- y metodos para cambiar su estado. El buscador (filtrarBusqueda)
-- recorre esta lista para forzar expansion mientras hay busqueda
-- activa y restaurar el estado previo cuando se limpia.
-- Se vacia en los mismos puntos donde se vacian indiceBusqueda /
-- registroVisibilidad: CrearVentana, Ventana:Destruir, y el handler
-- del boton "Eliminar" del dialogo de confirmacion.
local seccionesRegistradas = {}

-- ══════════════════════════════════════════════════════════════
--  LABELS AUTO-ACTUALIZABLES (registro global)
-- ══════════════════════════════════════════════════════════════
-- Cada Label creado con Cada > 0 y Actualizar(fn) se registra acá.
-- Clave débil (__mode = "k"): si el label se destruye (ventana
-- cerrada o recreada), se libera solo del registro sin que haya
-- que limpiarlo a mano. Un solo loop global (ver más abajo) itera
-- esta tabla y dispara las actualizaciones que correspondan según
-- el timestamp de cada entrada -- NUNCA un hilo por label, que
-- sería un desastre con varios labels a la vez.
local _labelsAutoActualizables = setmetatable({}, {__mode = "k"})

-- Un solo loop para TODOS los labels auto-actualizables. Se conecta
-- una vez a nivel de módulo y nunca se desconecta (no depende de
-- ventana activa); itera la tabla débil -- si no hay labels vivos,
-- el costo por Heartbeat es una iteración vacía, despreciable.
--
-- Cada entrada se salta hasta que pasa su propio 'cada' (guardado
-- como 'proxima' timestamp). Eso da la granularidad exacta que pidió
-- cada Label sin tener que crear un RunService por label.
--
-- pcall por callback: si el 'Actualizar' del developer tira error,
-- se loguea y se sigue con los demás (mismo criterio que el resto
-- de la librería para callbacks del developer).
--
if type(_G.Nub_ConexionesModulo) == "table" then
    for _, c in ipairs(_G.Nub_ConexionesModulo) do
        pcall(function() c:Disconnect() end)
    end
end
_G.Nub_ConexionesModulo = {}

table.insert(_G.Nub_ConexionesModulo, RunService.Heartbeat:Connect(function()
    local ahora = os.clock()
    for entrada, config in pairs(_labelsAutoActualizables) do
        if entrada and entrada.Parent and ahora >= config.proxima then
            config.proxima = ahora + config.cada
            local ok, nuevo = pcall(config.fn)
            if ok and nuevo ~= nil then
                pcall(config.aplicar, nuevo)
            elseif not ok then
                Nub:_RegistrarError("Label auto-update ('" .. tostring(config.flag) .. "')", nuevo)
            end
        end
    end
end))

-- ══════════════════════════════════════════════════════════════
--  VISIBILIDAD CONDICIONAL ENTRE CONTROLES (VisibleSi)
-- ══════════════════════════════════════════════════════════════
-- Permite ocultar/mostrar la FILA de un control segun el valor de
-- OTRO flag, sin que el developer tenga que llamar Set() a mano cada
-- vez que cambia el control del que depende. Ejemplo tipico (el que
-- motiva esto): mostrar "Distancia"/"Prioridad" solo cuando "AutoFarm"
-- esta activo.
--
--   Seccion:Slider({
--       Texto = "Distancia",
--       VisibleSi = function() return Nub.Flags.AutoFarm == true end,
--   })
--
-- Se re-evalua cada vez que CUALQUIER flag cambia (enganchado a
-- Nub.Eventos.FlagCambiada de proposito, no solo la flag puntual de
-- la que depende) -- evaluar unas pocas funciones booleanas en cada
-- cambio de flag es insignificante en costo, y asi se evita tener que
-- declarar de que flag depende cada control por separado.
--
-- Clave debil (__mode = "k"): si la fila se destruye (ventana cerrada
-- o recreada) y nada mas la referencia, Lua puede recolectarla sola sin
-- que haya que limpiar este registro a mano en cada reset de ventana.
local registroVisibilidad = setmetatable({}, {__mode = "k"}) -- [fila] = funcionCondicion

local function cumpleVisibilidadCondicional(fila)
    local condicion = registroVisibilidad[fila]
    if not condicion then return true end
    local ok, resultado = pcall(condicion)
    if not ok then
        Nub:_RegistrarError("VisibleSi", resultado)
        return true -- si la condicion del developer tira error, se prefiere MOSTRAR el control antes que esconderlo sin explicacion
    end
    return resultado and true or false
end

local function registrarVisibilidadCondicional(fila, visibleSi)
    if type(visibleSi) ~= "function" or not fila then return end
    registroVisibilidad[fila] = visibleSi
    fila.Visible = cumpleVisibilidadCondicional(fila)
end

local function reevaluarVisibilidadCondicional()
    for fila, _ in pairs(registroVisibilidad) do
        if fila and fila.Parent then
            fila.Visible = cumpleVisibilidadCondicional(fila)
        end
    end
end

table.insert(_G.Nub_ConexionesModulo, Nub.Eventos.FlagCambiada:Connect(reevaluarVisibilidadCondicional))

local function registrarBuscable(fila, texto, visibleSi)
    table.insert(indiceBusqueda, {fila = fila, texto = (texto or ""):lower()})
    registrarVisibilidadCondicional(fila, visibleSi)
end

-- ══════════════════════════════════════════════════════════════
--  NOTIFICACIONES
-- ══════════════════════════════════════════════════════════════
local contenedorNotif

local function crearContenedorNotif(padreGui)
    if contenedorNotif and contenedorNotif.Parent then return end
    contenedorNotif = Utils.Frame({
        Padre = padreGui, Transparencia = 1,
        Size = UDim2.new(0, 260, 0, 0),
        Posicion = UDim2.new(1, -270, 0, 10),
        Radio = false,
    })
    contenedorNotif.Name = "Nub_Notificaciones"
    contenedorNotif.AutomaticSize = Enum.AutomaticSize.Y
    contenedorNotif.ZIndex = 500
    contenedorNotif.Active = false

    local layout = Instance.new("UIListLayout")
    layout.Padding           = UDim.new(0, 0)
    layout.SortOrder         = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = contenedorNotif
end

-- Tope de notificaciones simultaneas. Si un script dispara muchas
-- notificaciones seguidas (ej. un bucle detectando errores), el resto
-- se guarda en una cola y va apareciendo a medida que las anteriores
-- se cierran, en vez de saturar la pantalla.
local MAX_NOTIF_SIMULTANEAS = 4
local colaNotif   = {}
local notifActivas = 0

-- Colores de acento segun 'Tipo' (Propuesta 12). Sin Tipo, o con
-- Tipo="Info", se mantiene el comportamiento de siempre (acento del
-- tema, reactivo a ThemeManager). Con un Tipo especifico el color
-- queda fijo a ese semantico -- no tendria sentido que un error se
-- vuelva verde solo porque cambiaste de tema mientras estaba en pantalla.
local COLORES_TIPO_NOTIF = {
    Success = Color3.fromRGB(46, 204, 113),
    Warning = Color3.fromRGB(241, 196, 15),
    Error   = Color3.fromRGB(231, 76, 60),
}

local function mostrarTarjetaNotif(config)
    notifActivas = notifActivas + 1

    local colorAcento  = COLORES_TIPO_NOTIF[config.Tipo]
    local esTipoFijo   = colorAcento ~= nil
    colorAcento = colorAcento or Theme.Accent

    local hueco = Utils.Frame({
        Padre = contenedorNotif, Size = UDim2.new(1, 0, 0, 0),
        Transparencia = 1, Radio = false,
    })
    hueco.AutomaticSize = Enum.AutomaticSize.Y
    local rellenoHueco = Instance.new("UIPadding")
    rellenoHueco.PaddingBottom = UDim.new(0, 6)
    rellenoHueco.Parent = hueco

    local tarjeta = Utils.Frame({
        Padre = hueco, Color = Theme.Panel,
        Size = UDim2.new(1, 0, 0, 0), Radio = 8,
        Borde = true, ColorBorde = colorAcento, TransparenciaBorde = 0.3,
        -- Si el Tipo fija un color semantico (Warning/Error/Success),
        -- no se registra contra el tema -- se queda en ese color fijo
        -- mientras la tarjeta este en pantalla.
        ClaveTemaBorde = (not esTipoFijo) and "Accent" or nil,
    })
    tarjeta.AutomaticSize    = Enum.AutomaticSize.Y
    tarjeta.ClipsDescendants = true
    tarjeta.Active           = false -- no bloquea el toque de lo que haya detrás
    Nub:Registrar(tarjeta, "BackgroundColor3", "Panel")

    -- Gradiente diagonal muy sutil: el color de tipo (Success/Warning/
    -- Error) o el acento del tema, tintando el fondo en la esquina
    -- superior-izquierda al 8%, desvaneciendose hacia Panel. Hace que
    -- la notif "pertenezca" visualmente a su tipo sin ser agresivo.
    local gradNotif = Instance.new("UIGradient")
    gradNotif.Rotation = 135
    gradNotif.Color = ColorSequence.new(
        Theme.Panel:Lerp(colorAcento, 0.08),
        Theme.Panel
    )
    gradNotif.Parent = tarjeta
    -- No se registra contra el tema: si el tipo es fijo (Success/
    -- Warning/Error) el color no debe cambiar con el tema, y si no
    -- lo es, se recalculó al crear la tarjeta de todas formas.

    local escalaTarjeta = Instance.new("UIScale")
    escalaTarjeta.Scale = 0.85
    escalaTarjeta.Parent = tarjeta

    -- Franja de acento. Hace de barra de progreso: se va consumiendo durante
    -- la duracion de la notificacion (una barra inferior posicionada a mano
    -- alteraria la altura de la tarjeta, que es AutomaticSize y tiene padding).
    local franjaAcento = Utils.Frame({Padre = tarjeta, Size = UDim2.new(0, 3, 1, 0), Color = colorAcento, Radio = false})

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft,  pad.PaddingRight  = UDim.new(0, 12), UDim.new(0, 10)
    pad.PaddingTop,   pad.PaddingBottom = UDim.new(0, 8),  UDim.new(0, 8)
    pad.Parent = tarjeta

    Utils.Texto({
        Padre = tarjeta, Texto = config.Titulo or "Notificación",
        Size = UDim2.new(1, 0, 0, 16), Posicion = UDim2.new(0, 0, 0, 0),
        Fuente = Enum.Font.GothamBold, Tamano = 12, Color = Theme.Highlight,
    })

    local lblTexto = Utils.Texto({
        Padre = tarjeta, Texto = config.Texto or "",
        Size = UDim2.new(1, 0, 0, 0), Posicion = UDim2.new(0, 0, 0, 16),
        Tamano = 11, Ajustar = true, Color = Theme.Text,
    })
    lblTexto.AutomaticSize = Enum.AutomaticSize.Y

    -- Entrada: deslizamiento + "pop" de escala con rebote suave (Back)
    tarjeta.Position = UDim2.new(1.2, 0, 0, 0)
    Utils.Tween(tarjeta, {Position = UDim2.new(0, 0, 0, 0)}, Nub.Motion.Modal, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    Utils.Tween(escalaTarjeta, {Scale = 1}, Nub.Motion.Modal, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)

    local function cerrarTarjeta()
        if not (tarjeta and tarjeta.Parent) then return end
        -- Salida: deslizamiento + achique rapido, mas seco que la entrada
        local t = Utils.Tween(tarjeta, {Position = UDim2.new(1.2, 0, 0, 0)}, Nub.Motion.Page, Nub.Motion.EaseSalir, Enum.EasingDirection.In)
        Utils.Tween(escalaTarjeta, {Scale = 0.85}, Nub.Motion.Page, Nub.Motion.EaseSalir, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            local altoHueco = hueco.AbsoluteSize.Y
            hueco.AutomaticSize = Enum.AutomaticSize.None
            hueco.Size = UDim2.new(1, 0, 0, altoHueco)
            local colapso = Utils.Tween(hueco, {Size = UDim2.new(1, 0, 0, 0)}, Nub.Motion.Page, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
            local function terminar()
                local okDestruir, errDestruir = pcall(function() hueco:Destroy() end)
                if not okDestruir then Nub:_RegistrarError("Notificaciones (destruir tarjeta)", errDestruir) end

                notifActivas = math.max(0, notifActivas - 1)
                local siguiente = table.remove(colaNotif, 1)
                if siguiente then
                    local okSig, errSig = pcall(mostrarTarjetaNotif, siguiente)
                    if not okSig then Nub:_RegistrarError("Notificaciones (siguiente en cola)", errSig) end
                end
            end
            if colapso then colapso.Completed:Connect(terminar) else terminar() end
        end)
    end

    if config.Persistente then
        -- No se autocierra por tiempo -- se agrega un boton invisible
        -- que cubre toda la tarjeta para poder descartarla con un click
        -- cuando el usuario ya la vio. Se hace SOLO en este caso (y no
        -- para todas las notificaciones) para no cambiar el
        -- comportamiento de "Active = false" de las normales, que a
        -- proposito dejan pasar el click a lo que haya detras.
        local botonCerrar = Instance.new("TextButton")
        botonCerrar.BackgroundTransparency = 1
        botonCerrar.Text     = ""
        botonCerrar.Size     = UDim2.new(1, 0, 1, 0)
        botonCerrar.ZIndex   = tarjeta.ZIndex + 1
        botonCerrar.Parent   = tarjeta
        -- Feedback visible antes de irse: pop de escala + el borde se
        -- enciende, y recien despues sale. Si el click llega mientras la
        -- tarjeta todavia esta entrando, se cierra directo (el pop
        -- pisaria la animacion de entrada).
        local cerrando = false
        local entradaTerminada = false
        task.delay(Nub.Motion.Modal, function() entradaTerminada = true end)
        botonCerrar.MouseButton1Click:Connect(function()
            if cerrando then return end
            cerrando = true
            if entradaTerminada and tarjeta.Parent then
                Utils.ClickFeedback(tarjeta) -- reusa escalaTarjeta (unico UIScale de la tarjeta)
                local borde = tarjeta:FindFirstChildOfClass("UIStroke")
                if borde then Utils.Tween(borde, {Transparency = 0}, Nub.Motion.FlashIn) end
                task.delay(Nub.Motion.Press, cerrarTarjeta)
            else
                cerrarTarjeta()
            end
        end)
    else
        local duracionNotif = config.Duracion or 4
        Utils.Tween(franjaAcento, {Size = UDim2.new(0, 3, 0, 0)}, duracionNotif, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        task.delay(duracionNotif, cerrarTarjeta)
    end
end

-- ── Bloqueo y resaltado de controles ────────────────────────────
function Utils.EnvolverInstancia(inst)
    local proxy = setmetatable({}, {
        __index = function(_, clave)
            local ok, valor = pcall(function() return inst[clave] end)
            if not ok then return nil end
            if type(valor) == "function" then
                return function(_, ...) return valor(inst, ...) end
            end
            return valor
        end,
        __newindex = function(_, clave, valor) inst[clave] = valor end,
    })
    rawset(proxy, "Instancia", inst)
    return proxy
end

function Utils.AnexarBloqueo(elem, fila)
    local overlay, lblMotivo, insignia
    local bloqueado, motivo = false, nil
    local POS_INSIGNIA = UDim2.new(1, -8, 0.5, 0)
    local tokenSacudida = 0
    rawset(elem, "Fila", fila)
    local trazo, tokenResaltado = nil, 0

    local function sinSelf(a, b)
        if a == elem then return b end
        return a
    end

    local function refrescarTexto()
        if lblMotivo then
            lblMotivo.Text = "🔒 " .. (motivo and motivo ~= "" and motivo or "Bloqueado")
        end
    end

    local function asegurarOverlay()
        if overlay and overlay.Parent then return end
        overlay = Instance.new("TextButton")
        overlay.Name = "Nub_Locked"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Theme.BackgroundDark
        overlay.BackgroundTransparency = 0.35
        overlay.BorderSizePixel = 0
        overlay.AutoButtonColor = false
        overlay.Text = ""
        overlay.ZIndex = 100
        overlay.Visible = false
        overlay.Parent = fila
        local esquina = fila:FindFirstChildOfClass("UICorner")
        if esquina then Utils.Corner(overlay, esquina.CornerRadius.Offset) end
        Nub:Registrar(overlay, "BackgroundColor3", "BackgroundDark")
        insignia = Utils.Frame({
            Padre = overlay, Size = UDim2.new(0.55, -8, 0, 26),
            Posicion = POS_INSIGNIA, Ancla = Vector2.new(1, 0.5),
            Color = Theme.Panel, Radio = 6,
        })
        insignia.ZIndex = 101
        Nub:Registrar(insignia, "BackgroundColor3", "Panel")
        lblMotivo = Utils.Texto({
            Padre = insignia, Texto = "",
            Size = UDim2.new(1, -12, 1, 0), Posicion = UDim2.new(0, 6, 0, 0),
            Alineacion = Enum.TextXAlignment.Center, Tamano = 12, Truncar = true,
        })
        lblMotivo.ZIndex = 102

        -- Tocar un control bloqueado: la insignia se sacude y destella en
        -- rojo ("no se puede"). Se sacude la INSIGNIA y no la fila: la fila
        -- vive dentro de un UIListLayout que pisaria su Position en cada
        -- recalculo; la insignia es hija del overlay, que no tiene layout.
        Utils.ClickConfiable(overlay, function()
            if not (insignia and insignia.Parent) then return end
            tokenSacudida = tokenSacudida + 1
            local mio = tokenSacudida
            Utils.FlashFeedback(insignia, false, Theme.Panel)
            task.spawn(function()
                for _, dx in ipairs({-3, 3, -3, 3, 0}) do
                    if tokenSacudida ~= mio or not (insignia and insignia.Parent) then return end
                    Utils.Tween(insignia, {
                        Position = UDim2.new(POS_INSIGNIA.X.Scale, POS_INSIGNIA.X.Offset + dx, POS_INSIGNIA.Y.Scale, POS_INSIGNIA.Y.Offset),
                    }, 0.05, Nub.Motion.EaseSuave, Enum.EasingDirection.InOut)
                    task.wait(0.05)
                end
            end)
        end, insignia)
    end

    -- Entrada animada del bloqueo: el velo se desvanece y la insignia
    -- entra deslizando desde la derecha con rebote. Solo cuando el control
    -- ya esta en pantalla (un Locked = true de nacimiento queda directo).
    local function animarEntradaBloqueo()
        local transparenciaVelo = overlay.BackgroundTransparency
        local transparenciaInsignia = insignia.BackgroundTransparency
        local transparenciaTexto = lblMotivo.TextTransparency
        overlay.BackgroundTransparency = 1
        insignia.BackgroundTransparency = 1
        lblMotivo.TextTransparency = 1
        insignia.Position = UDim2.new(POS_INSIGNIA.X.Scale, POS_INSIGNIA.X.Offset + 24, POS_INSIGNIA.Y.Scale, POS_INSIGNIA.Y.Offset)
        Utils.Tween(overlay, {BackgroundTransparency = transparenciaVelo}, Nub.Motion.Expand, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
        Utils.Tween(insignia, {BackgroundTransparency = transparenciaInsignia, Position = POS_INSIGNIA}, Nub.Motion.Expand, Nub.Motion.EasePop, Enum.EasingDirection.Out)
        Utils.Tween(lblMotivo, {TextTransparency = transparenciaTexto}, Nub.Motion.Expand, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    end

    local function bloquear(nuevoMotivo, animar)
        local yaBloqueado = bloqueado
        motivo = nuevoMotivo
        asegurarOverlay()
        refrescarTexto()
        overlay.Visible = true
        bloqueado = true
        if animar and not yaBloqueado and fila.AbsoluteSize.X > 0 then
            animarEntradaBloqueo()
        end
    end

    rawset(elem, "Lock", function(a, b)
        bloquear(sinSelf(a, b), true)
    end)

    rawset(elem, "Unlock", function()
        local estabaBloqueado = bloqueado
        bloqueado = false
        -- El velo real se oculta YA (IsLocked y overlay.Visible son
        -- inmediatos, igual que siempre). El desvanecimiento lo hace una
        -- copia temporal que no forma parte del control.
        if overlay then overlay.Visible = false end
        if estabaBloqueado and overlay and fila.Parent and fila.AbsoluteSize.X > 0 then
            local fantasma = Instance.new("Frame")
            fantasma.Name = "__Nub_LockFade"
            fantasma.Size = UDim2.new(1, 0, 1, 0)
            fantasma.BackgroundColor3 = overlay.BackgroundColor3
            fantasma.BackgroundTransparency = overlay.BackgroundTransparency
            fantasma.BorderSizePixel = 0
            fantasma.Active = false
            fantasma.ZIndex = overlay.ZIndex
            local esquinaOverlay = overlay:FindFirstChildOfClass("UICorner")
            if esquinaOverlay then Utils.Corner(fantasma, esquinaOverlay.CornerRadius.Offset) end
            fantasma.Parent = fila
            Utils.Tween(fantasma, {BackgroundTransparency = 1}, Nub.Motion.Expand, Nub.Motion.EaseSalir, Enum.EasingDirection.In)
            task.delay(Nub.Motion.Expand + 0.05, function()
                if fantasma.Parent then fantasma:Destroy() end
            end)
        end
    end)

    rawset(elem, "IsLocked", function() return bloqueado end)

    rawset(elem, "SetLockedTitle", function(a, b)
        motivo = sinSelf(a, b)
        refrescarTexto()
    end)

    rawset(elem, "Highlight", function(a, b)
        local opciones = sinSelf(a, b)
        local duracion = 2
        if type(opciones) == "number" then
            duracion = opciones
        elseif type(opciones) == "table" and type(opciones.Duracion) == "number" then
            duracion = opciones.Duracion
        end
        duracion = math.clamp(duracion, 0.5, 10)

        tokenResaltado = tokenResaltado + 1
        local mio = tokenResaltado
        if trazo then trazo:Destroy() end
        trazo = Instance.new("UIStroke")
        trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        trazo.Thickness = 2
        trazo.Color = Theme.AccentLight
        trazo.Transparency = 1
        trazo.Parent = fila

        local pulsos = math.max(1, math.floor(duracion / 0.8))
        local propio = trazo
        local tween = TweenService:Create(propio,
            TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, pulsos - 1, true),
            {Transparency = 0})
        tween:Play()
        task.delay(duracion + 0.2, function()
            if propio.Parent then propio:Destroy() end
            if tokenResaltado == mio then trazo = nil end
        end)
    end)

    -- Bloqueo inicial (Locked = true al crear el control): sin animacion.
    return function(nuevoMotivo) bloquear(nuevoMotivo, false) end
end

function Utils.EnvolverControlBloqueable(Seccion, contenedor, nombre)
    local original = Seccion[nombre]
    if type(original) ~= "function" then return end
    Seccion[nombre] = function(self, cfg)
        local previos = {}
        for _, hijo in ipairs(contenedor:GetChildren()) do previos[hijo] = true end
        local resultado = original(self, cfg)
        local fila
        for _, hijo in ipairs(contenedor:GetChildren()) do
            if not previos[hijo] and hijo:IsA("GuiObject")
                and (not fila or hijo.LayoutOrder > fila.LayoutOrder) then
                fila = hijo
            end
        end
        if not fila then return resultado end
        local elem = resultado
        if typeof(resultado) == "Instance" then elem = Utils.EnvolverInstancia(resultado) end
        if type(elem) ~= "table" then return resultado end
        local bloquearInicial = Utils.AnexarBloqueo(elem, fila)
        if type(cfg) == "table" and cfg.Locked then bloquearInicial(cfg.LockedTitle) end
        return elem
    end
end

function Utils.FundirEntrada(raiz, duracion, incluirRaiz, retraso)
    local objetivos = {}
    local function registrar(inst)
        if inst:IsA("GuiObject") then
            if inst.BackgroundTransparency < 0.99 then
                table.insert(objetivos, {inst, "BackgroundTransparency", inst.BackgroundTransparency})
            end
            if (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) and inst.TextTransparency < 0.99 then
                table.insert(objetivos, {inst, "TextTransparency", inst.TextTransparency})
            end
            if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.ImageTransparency < 0.99 then
                table.insert(objetivos, {inst, "ImageTransparency", inst.ImageTransparency})
            end
        elseif inst:IsA("UIStroke") and inst.Transparency < 0.99 then
            table.insert(objetivos, {inst, "Transparency", inst.Transparency})
        end
    end
    if incluirRaiz then registrar(raiz) end
    for _, d in ipairs(raiz:GetDescendants()) do registrar(d) end
    for _, o in ipairs(objetivos) do o[1][o[2]] = 1 end
    local function iniciar()
        for _, o in ipairs(objetivos) do
            if o[1].Parent then
                Utils.Tween(o[1], {[o[2]] = o[3]}, duracion, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            end
        end
    end
    if retraso and retraso > 0 then task.delay(retraso, iniciar) else iniciar() end
end

-- ══════════════════════════════════════════════════════════════
--  BORDES CON DEGRADADO Y ANIMACION (con los colores de la interfaz)
--  Utils.AplicarBorde(marco, spec) -> { Actualizar(spec), Trazo }
--
--  'spec' admite lo mismo que un tag y ademas colores del TEMA:
--    nil / false / "ninguno"  vuelve al borde de siempre
--    "tema"      degradado Accent -> AccentLight (sigue al tema)
--    "acento"    color liso Accent (sigue al tema)
--    "borde"     el color de borde del tema
--    "rainbow"   arcoiris animado
--    "info" | "success" | "warning" | "danger" | "neutral"   colores del tag
--    Color3      color liso
--    { c1, c2, ... }   degradado de 2 o mas; cada c es un Color3, una clave del
--                      tema ("Accent", "AccentLight", "Highlight"...) o un color
--                      del tag ("success"...). Las claves del tema siguen al tema.
--    { Color = <cualquiera de arriba>, Grosor = 2, Animar = true,
--      Velocidad = 4, Transparencia = 0 }   tabla de configuracion
--  Animar gira el degradado (Velocidad = segundos por vuelta). Con "rainbow" se
--  anima solo, salvo Animar = false. El degradado se cierra sobre si mismo al
--  animarse, para que la vuelta no tenga costura.
--
--  Reusa el UIStroke que el marco ya tenga (no se pueden apilar dos bordes) y
--  le cambia la clave de tema; al quitar el borde se restaura tal cual estaba.
-- ══════════════════════════════════════════════════════════════
local COLORES_SEMANTICOS = {
    info = Color3.fromRGB(70, 130, 210), warning = Color3.fromRGB(215, 160, 50),
    success = Color3.fromRGB(70, 170, 100), danger = Color3.fromRGB(190, 60, 60),
    neutral = Color3.fromRGB(95, 100, 110),
}
local COLORES_ARCOIRIS = {
    Color3.fromRGB(235, 70, 70), Color3.fromRGB(240, 150, 50), Color3.fromRGB(235, 210, 60),
    Color3.fromRGB(80, 200, 110), Color3.fromRGB(70, 150, 235), Color3.fromRGB(160, 90, 220),
}

local function resolverColorBorde(elemento)
    if typeof(elemento) == "Color3" then return elemento end
    if type(elemento) == "string" then
        return Theme[elemento] or COLORES_SEMANTICOS[elemento] or Theme.Accent
    end
    return Theme.Accent
end

function Utils.AplicarBorde(marco, spec)
    local trazo = marco:FindFirstChildOfClass("UIStroke")
    if not trazo then
        trazo = Instance.new("UIStroke")
        trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        trazo.Thickness = 2
        trazo.Transparency = 1
        trazo.Color = Theme.Border
        trazo.Parent = marco
    end
    local grosorOriginal, transparenciaOriginal, colorOriginal = trazo.Thickness, trazo.Transparency, trazo.Color

    local function buscarEntrada()
        for _, e in ipairs(registroTema) do
            if e.instancia == trazo and e.propiedad == "Color" and not e.muerta then return e end
        end
        return nil
    end
    local entradaInicial = buscarEntrada()
    local claveOriginal = entradaInicial and entradaInicial.claveTema or nil

    local function fijarColorTrazo(clave)
        local entrada = buscarEntrada()
        if entrada then entrada.claveTema = clave else Nub:Registrar(trazo, "Color", clave) end
        local valor = (type(clave) == "function") and clave() or Theme[clave]
        if typeof(valor) == "Color3" then trazo.Color = valor end
    end

    local gradiente, tween
    local function limpiar()
        if tween then tween:Cancel(); tween = nil end
        if gradiente then gradiente:Destroy(); gradiente = nil end
    end
    marco.Destroying:Connect(function() if tween then tween:Cancel() end end)

    local manejador = { Trazo = trazo }

    function manejador.Actualizar(nuevo)
        limpiar()

        if nuevo == nil or nuevo == false or nuevo == "ninguno" then
            fijarColorTrazo(claveOriginal or function() return colorOriginal end)
            trazo.Thickness = grosorOriginal
            trazo.Transparency = transparenciaOriginal
            return
        end

        local colorSpec, grosor, animar, velocidad, transparencia = nuevo, 2, nil, 4, 0
        if type(nuevo) == "table" and nuevo[1] == nil then
            colorSpec = nuevo.Color
            grosor = tonumber(nuevo.Grosor) or 2
            animar = nuevo.Animar
            velocidad = tonumber(nuevo.Velocidad) or 4
            transparencia = tonumber(nuevo.Transparencia) or 0
        end
        if colorSpec == nil then colorSpec = "tema" end
        trazo.Thickness = math.clamp(grosor, 1, 8)
        trazo.Transparency = math.clamp(transparencia, 0, 1)

        local elementos = nil
        if colorSpec == "tema" then
            elementos = { "Accent", "AccentLight" }
        elseif colorSpec == "rainbow" then
            elementos = COLORES_ARCOIRIS
            if animar == nil then animar = true end
        elseif type(colorSpec) == "table" and #colorSpec >= 2 then
            elementos = colorSpec
        end

        if elementos then
            local cerrarBucle = (animar == true)
            local function construir()
                local n = #elementos
                local total = n + (cerrarBucle and 1 or 0)
                local puntos = {}
                for i = 1, total do
                    local e = elementos[((i - 1) % n) + 1]
                    table.insert(puntos, ColorSequenceKeypoint.new((i - 1) / (total - 1), resolverColorBorde(e)))
                end
                return ColorSequence.new(puntos)
            end
            gradiente = Instance.new("UIGradient")
            gradiente.Color = construir()
            gradiente.Parent = trazo
            Nub:Registrar(gradiente, "Color", construir)
            -- El color del trazo se MULTIPLICA con el del degradado: va en blanco.
            fijarColorTrazo(function() return Color3.new(1, 1, 1) end)
            if animar == true then
                tween = TweenService:Create(
                    gradiente,
                    TweenInfo.new(math.max(0.5, velocidad), Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
                    {Rotation = 360}
                )
                tween:Play()
            end
            return
        end

        if colorSpec == "acento" then
            fijarColorTrazo("Accent")
        elseif colorSpec == "borde" then
            fijarColorTrazo("Border")
        elseif typeof(colorSpec) == "Color3" then
            local fijo = colorSpec
            fijarColorTrazo(function() return fijo end)
        elseif type(colorSpec) == "string" and (Theme[colorSpec] or COLORES_SEMANTICOS[colorSpec]) then
            fijarColorTrazo(function() return resolverColorBorde(colorSpec) end)
        else
            advertirDev("Borde", nil, "Color '" .. tostring(colorSpec) .. "' no reconocido. Se dejó el borde normal.")
            fijarColorTrazo(claveOriginal or function() return colorOriginal end)
            trazo.Thickness = grosorOriginal
            trazo.Transparency = transparenciaOriginal
        end
    end

    if spec ~= nil then manejador.Actualizar(spec) end
    return manejador
end

-- Anillo de foco para una caja de texto: un borde de acento que aparece al
-- enfocarla y se apaga al salir. Antes escribir en un campo no tenia ningun
-- feedback de "este es el campo activo". Las cajas de texto de Nub no
-- tienen ningun UIStroke propio, asi que no hay choque con otro borde.
function Utils.AnilloFoco(caja)
    local trazo = Instance.new("UIStroke")
    trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    trazo.Thickness = 1.5
    trazo.Color = Theme.Accent
    trazo.Transparency = 1
    trazo.Parent = caja
    Nub:Registrar(trazo, "Color", "Accent")
    Nub:RegistrarConexion(caja.Focused:Connect(function()
        Utils.Tween(trazo, {Transparency = 0.1}, Nub.Motion.Hover)
    end))
    Nub:RegistrarConexion(caja.FocusLost:Connect(function()
        Utils.Tween(trazo, {Transparency = 1}, Nub.Motion.Expand)
    end))
    return trazo
end

-- Animacion de insercion para elementos que viven dentro de un layout
-- (divisores): el marco CRECE desde 0 en el eje indicado empujando
-- suavemente a sus vecinos, mientras sus hijos hacen fade. Solo para
-- elementos NUEVOS (FundirEntrada lee la transparencia actual como
-- objetivo, asi que no debe llamarse a mitad de otra animacion).
function Utils.AnimarInsercion(marco, eje)
    if not (marco and marco.Parent) then return end
    local tamFinal = marco.Size
    local clipOriginal = marco.ClipsDescendants
    marco.ClipsDescendants = true
    if eje == "x" then
        marco.Size = UDim2.new(tamFinal.X.Scale, 0, tamFinal.Y.Scale, tamFinal.Y.Offset)
    else
        marco.Size = UDim2.new(tamFinal.X.Scale, tamFinal.X.Offset, tamFinal.Y.Scale, 0)
    end
    Utils.FundirEntrada(marco, Nub.Motion.Expand, false)
    Utils.Tween(marco, {Size = tamFinal}, Nub.Motion.Expand, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    task.delay(Nub.Motion.Expand + 0.05, function()
        if marco.Parent then
            marco.Size = tamFinal
            marco.ClipsDescendants = clipOriginal
        end
    end)
end

function Utils.EntradaModal(fondo, card)
    local transparenciaFondo = fondo.BackgroundTransparency
    fondo.BackgroundTransparency = 1
    local escala = Instance.new("UIScale")
    escala.Scale = 0.95
    escala.Parent = card
    local RETRASO_ASENTAR = 0.06
    Utils.FundirEntrada(card, Nub.Motion.Modal, true, RETRASO_ASENTAR)
    Utils.Tween(fondo, {BackgroundTransparency = transparenciaFondo}, Nub.Motion.Expand, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    task.delay(RETRASO_ASENTAR, function()
        if escala.Parent then
            Utils.Tween(escala, {Scale = 1}, Nub.Motion.Modal, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
        end
    end)
end

function Utils.IconoImagen(padre, asset, color, tamano, posicion)
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Image = asset
    img.ImageColor3 = color or Color3.new(1, 1, 1)
    img.ScaleType = Enum.ScaleType.Fit
    img.Size = UDim2.new(0, tamano, 0, tamano)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Position = posicion
    img.Parent = padre
    return img
end

function Utils.AnexarDescripcion(fila, padre, orden, texto, anchoZona)
    local panel = Utils.Frame({
        Padre = padre, Size = UDim2.new(1, 0, 0, 0),
        Color = Theme.Fila, Orden = orden, Radio = 8,
    })
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Visible = false
    Nub:Registrar(panel, "BackgroundColor3", "Fila")
    local relleno = Instance.new("UIPadding")
    relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
    relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 28), UDim.new(0, 12)
    relleno.Parent = panel
    local lblDescripcion = Utils.Texto({
        Padre = panel, Texto = tostring(texto),
        Size = UDim2.new(1, 0, 0, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Ajustar = true, Tamano = 11, Color = Theme.TextDark, ColorTema = "TextDark",
    })
    lblDescripcion.AutomaticSize = Enum.AutomaticSize.Y

    local zona = Utils.BotonBase({
        Padre = fila, Size = anchoZona or UDim2.new(1, 0, 1, 0),
        Color = Theme.Fila, Transparencia = 1, Radio = 8,
    })
    local flecha = Instance.new("ImageLabel")
    flecha.BackgroundTransparency = 1
    flecha.Image = "rbxassetid://83472139709682"
    flecha.ScaleType = Enum.ScaleType.Fit
    flecha.Size = UDim2.new(0, 10, 0, 10)
    flecha.AnchorPoint = Vector2.new(0.5, 0.5)
    flecha.Position = UDim2.new(0, 14, 0.5, 0)
    flecha.Rotation = -90
    flecha.Parent = fila
    Nub:Registrar(flecha, "ImageColor3", "Text")

    Utils.ClickConfiable(zona, function()
        panel.Visible = not panel.Visible
        Utils.Tween(flecha, {Rotation = panel.Visible and 0 or -90}, Nub.Motion.Expand)
    end)
    return panel
end

-- ── Historial de cambios (Deshacer / Rehacer) ───────────────────
Nub._historial = { deshacer = {}, rehacer = {}, ultimos = {}, pausa = 0 }
local MAX_HISTORIAL = 50

local function avisarHistorial()
    local h = Nub._historial
    Nub.Eventos.HistorialCambiado:Fire(#h.deshacer, #h.rehacer)
end

table.insert(_G.Nub_ConexionesModulo, Nub.Eventos.FlagCambiada:Connect(function(flag, valor)
    local h = Nub._historial
    local previo = h.ultimos[flag]
    h.ultimos[flag] = copiarDefecto(valor)
    if h.pausa > 0 or _flagsUI[flag] or _flagsNoPersistir[flag] then return end
    local elem = Nub.Elementos[flag]
    if previo == nil and elem then previo = elem._defecto end
    if previo == nil then return end
    if type(valor) ~= "table" and previo == valor then return end

    local ahora = os.clock()
    local ultima = h.deshacer[#h.deshacer]
    if ultima and #ultima.cambios == 1 and ultima.cambios[1].flag == flag and ahora - ultima.t < 0.6 then
        ultima.cambios[1].despues = copiarDefecto(valor)
        ultima.t = ahora
        if type(valor) ~= "table" and ultima.cambios[1].antes == valor then
            table.remove(h.deshacer)
        end
    elseif ultima and ahora - ultima.t < 0.05 then
        table.insert(ultima.cambios, { flag = flag, antes = copiarDefecto(previo), despues = copiarDefecto(valor) })
        ultima.t = ahora
    else
        table.insert(h.deshacer, {
            t = ahora,
            cambios = { { flag = flag, antes = copiarDefecto(previo), despues = copiarDefecto(valor) } },
        })
        if #h.deshacer > MAX_HISTORIAL then table.remove(h.deshacer, 1) end
    end
    h.rehacer = {}
    avisarHistorial()
end))

local function aplicarCambiosHistorial(cambios, usarAntes, enReverso)
    local h = Nub._historial
    h.pausa = h.pausa + 1
    local total = #cambios
    for i = 1, total do
        local c = cambios[enReverso and (total - i + 1) or i]
        local elem = Nub.Elementos[c.flag]
        if elem and type(elem.Set) == "function" then
            local fuente = c.despues
            if usarAntes then fuente = c.antes end
            local valor = copiarDefecto(fuente)
            pcall(elem.Set, valor, true)
            h.ultimos[c.flag] = copiarDefecto(valor)
        end
    end
    h.pausa = h.pausa - 1
end

function Nub:Deshacer()
    local h = self._historial
    local entrada = table.remove(h.deshacer)
    if not entrada then return false end
    aplicarCambiosHistorial(entrada.cambios, true, true)
    table.insert(h.rehacer, entrada)
    avisarHistorial()
    return true, entrada
end

function Nub:Rehacer()
    local h = self._historial
    local entrada = table.remove(h.rehacer)
    if not entrada then return false end
    aplicarCambiosHistorial(entrada.cambios, false, false)
    table.insert(h.deshacer, entrada)
    avisarHistorial()
    return true, entrada
end

function Nub:PuedeDeshacer() return #self._historial.deshacer > 0 end
function Nub:PuedeRehacer() return #self._historial.rehacer > 0 end

function Nub:ObtenerHistorial()
    return { Deshacer = #self._historial.deshacer, Rehacer = #self._historial.rehacer }
end

function Nub:LimpiarHistorial()
    local h = self._historial
    h.deshacer, h.rehacer, h.ultimos = {}, {}, {}
    for flag, elem in pairs(self.Elementos) do
        if type(elem) == "table" and type(elem.Get) == "function" then
            local ok, valor = pcall(elem.Get)
            if ok and valor ~= nil then h.ultimos[flag] = copiarDefecto(valor) end
        end
    end
    avisarHistorial()
end

function Nub:DescribirCambio(entrada)
    if type(entrada) ~= "table" or not entrada.cambios or #entrada.cambios == 0 then return "" end
    local primero = entrada.cambios[1]
    local function texto(v)
        if type(v) == "table" then return "[tabla]" end
        return tostring(v)
    end
    local resumen = tostring(primero.flag) .. ": " .. texto(primero.antes) .. " -> " .. texto(primero.despues)
    if #entrada.cambios > 1 then resumen = resumen .. " (+" .. (#entrada.cambios - 1) .. ")" end
    return resumen
end

function Nub:Confirmar(cfg)
    cfg = cfg or {}
    local gui = self._guiConfirmar
    if not (gui and gui.Parent) then
        self:_RegistrarError("Confirmar", "no hay una ventana activa donde mostrar el modal")
        return nil
    end

    local botones = {}
    if type(cfg.Botones) == "table" and #cfg.Botones > 0 then
        for _, b in ipairs(cfg.Botones) do table.insert(botones, clonarTabla(b)) end
    else
        if cfg.BotonCancelar then
            local b = clonarTabla(cfg.BotonCancelar)
            b.Texto = b.Texto or "Cancelar"
            b.Variante = b.Variante or "neutral"
            table.insert(botones, b)
        end
        local aceptar = clonarTabla(cfg.BotonAceptar or {})
        aceptar.Texto = aceptar.Texto or "Aceptar"
        aceptar.Variante = aceptar.Variante or "primary"
        table.insert(botones, aceptar)
    end

    self._modalesAbiertos = (self._modalesAbiertos or 0) + 1
    local zBase = 500 + (self._modalesAbiertos - 1) * 10
    local tituloError = cfg.Titulo or "Confirmar"

    local fondo = Utils.Frame({
        Padre = gui, Size = UDim2.new(1, 0, 1, 0),
        Color = Color3.new(0, 0, 0), Transparencia = 0.5, Radio = false,
    })
    fondo.ZIndex = zBase
    fondo.Active = true

    local cerrado = false
    fondo.Destroying:Connect(function()
        if cerrado then return end
        cerrado = true
        self._modalesAbiertos = math.max(0, (self._modalesAbiertos or 1) - 1)
        for i = #registroTema, 1, -1 do
            local inst = registroTema[i].instancia
            if inst == fondo or inst:IsDescendantOf(fondo) then table.remove(registroTema, i) end
        end
        for i = #registroEscalaTexto, 1, -1 do
            local inst = registroEscalaTexto[i].instancia
            if inst == fondo or inst:IsDescendantOf(fondo) then table.remove(registroEscalaTexto, i) end
        end
        task.defer(function()
            local activa = _G.Nub_InstanciaActiva
            if not activa then return end
            for i = #activa.Conexiones, 1, -1 do
                if activa.Conexiones[i].Connected == false then table.remove(activa.Conexiones, i) end
            end
        end)
    end)

    -- 'Ancho' (240-480, default 300) y 'ColorBorde' (Color3): un borde de color
    -- propio es mas grueso y no sigue al tema; sin el, el borde es el de siempre.
    local anchoCard = math.clamp(tonumber(cfg.Ancho) or 300, 240, 480)
    local colorBordePropio = typeof(cfg.ColorBorde) == "Color3" and cfg.ColorBorde or nil
    local card = Utils.Frame({
        Padre = fondo, Size = UDim2.new(0, anchoCard, 0, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Radio = 10,
        Borde = true, ColorBorde = colorBordePropio or Theme.Border,
        GrosorBorde = colorBordePropio and 2 or 1,
        ClaveTemaBorde = (not colorBordePropio) and "Border" or nil,
    })
    card.ZIndex = zBase + 1
    -- 'Borde' (mismo formato que Ventana:EstablecerBorde): degradado y/o
    -- animacion en el borde del modal. Tiene prioridad sobre 'ColorBorde'.
    if cfg.Borde ~= nil then Utils.AplicarBorde(card, cfg.Borde) end
    card.AutomaticSize = Enum.AutomaticSize.Y
    Nub:Registrar(card, "BackgroundColor3", "Panel")

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
    pad.Parent = card

    local orden = 0
    if cfg.Icono then
        orden = orden + 1
        local lblIcono = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Icono),
            Size = UDim2.new(1, 0, 0, 28), Orden = orden,
            Alineacion = Enum.TextXAlignment.Center, Tamano = 24,
        })
        lblIcono.ZIndex = zBase + 2
    end

    if cfg.Titulo then
        orden = orden + 1
        local lblTitulo = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Titulo),
            Size = UDim2.new(1, 0, 0, 0), Orden = orden,
            Fuente = Enum.Font.GothamBold, Tamano = 15, Ajustar = true,
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lblTitulo.AutomaticSize = Enum.AutomaticSize.Y
        lblTitulo.ZIndex = zBase + 2
    end

    if cfg.Contenido then
        orden = orden + 1
        local lblCuerpo = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Contenido),
            Size = UDim2.new(1, 0, 0, 0), Orden = orden,
            Ajustar = true, Tamano = 12, TextoTransparencia = 0.15,
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lblCuerpo.AutomaticSize = Enum.AutomaticSize.Y
        lblCuerpo.ZIndex = zBase + 2
    end

    -- Casilla opcional ("No volver a preguntar", "Recordar mi elección"...). Su
    -- estado se le pasa a los Callback de los botones: Callback(marcada).
    local casillaMarcada = type(cfg.Casilla) == "table" and cfg.Casilla.Defecto == true
    if type(cfg.Casilla) == "table" then
        orden = orden + 1
        local filaCasilla = Utils.Frame({
            Padre = card, Size = UDim2.new(1, 0, 0, 26), Orden = orden, Transparencia = 1,
        })
        filaCasilla.ZIndex = zBase + 2
        local caja = Utils.BotonBase({
            Padre = filaCasilla, Size = UDim2.new(0, 18, 0, 18),
            Posicion = UDim2.new(0, 0, 0.5, -9),
            Color = casillaMarcada and Theme.Accent or Theme.Entrada,
            Transparencia = 0, Radio = 4,
        })
        caja.ZIndex = zBase + 3
        local trazoCaja = Utils.Stroke(caja, Theme.Border, 1, 0.3)
        Nub:Registrar(trazoCaja, "Color", "Border")
        -- Mismo dibujo que Seccion:Casilla: dos barritas rotadas en vez del
        -- glifo "✓", que se ve distinto segun la fuente de cada ejecutor.
        local trazoCorto = Utils.Frame({
            Padre = caja, Size = UDim2.new(0, 6, 0, 2),
            Posicion = UDim2.new(0.5, -6, 0.5, 1), Color = Theme.Text,
            Transparencia = casillaMarcada and 0 or 1, Radio = 1,
        })
        trazoCorto.ZIndex = zBase + 4
        trazoCorto.Rotation = 45
        local trazoLargo = Utils.Frame({
            Padre = caja, Size = UDim2.new(0, 10, 0, 2),
            Posicion = UDim2.new(0.5, -2, 0.5, -3), Color = Theme.Text,
            Transparencia = casillaMarcada and 0 or 1, Radio = 1,
        })
        trazoLargo.ZIndex = zBase + 4
        trazoLargo.Rotation = -45
        Nub:Registrar(trazoCorto, "BackgroundColor3", "Text")
        Nub:Registrar(trazoLargo, "BackgroundColor3", "Text")

        local lblCasilla = Utils.Texto({
            Padre = filaCasilla, Texto = tostring(cfg.Casilla.Texto or ""),
            Size = UDim2.new(1, -26, 1, 0), Posicion = UDim2.new(0, 26, 0, 0),
            Tamano = 11, TextoTransparencia = 0.15, Truncar = true,
        })
        lblCasilla.ZIndex = zBase + 3

        -- Toda la fila es clickeable (no solo el cuadradito).
        local zonaClick = Utils.BotonBase({
            Padre = filaCasilla, Size = UDim2.new(1, 0, 1, 0), Transparencia = 1,
        })
        zonaClick.ZIndex = zBase + 5
        zonaClick.MouseButton1Click:Connect(function()
            casillaMarcada = not casillaMarcada
            Utils.Tween(caja, {BackgroundColor3 = casillaMarcada and Theme.Accent or Theme.Entrada}, Nub.Motion.Hover)
            Utils.Tween(trazoCorto, {BackgroundTransparency = casillaMarcada and 0 or 1}, Nub.Motion.Hover)
            Utils.Tween(trazoLargo, {BackgroundTransparency = casillaMarcada and 0 or 1}, Nub.Motion.Hover)
        end)
    end

    local total = #botones
    local vertical = total > 3
    orden = orden + 1
    local filaBotones = Utils.Frame({
        Padre = card, Size = UDim2.new(1, 0, 0, vertical and 0 or 34),
        Transparencia = 1, Orden = orden,
    })
    filaBotones.ZIndex = zBase + 2
    if vertical then filaBotones.AutomaticSize = Enum.AutomaticSize.Y end

    local layoutBotones = Instance.new("UIListLayout")
    layoutBotones.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    layoutBotones.Padding = UDim.new(0, 8)
    layoutBotones.SortOrder = Enum.SortOrder.LayoutOrder
    layoutBotones.Parent = filaBotones

    local blanco = Color3.fromRGB(255, 255, 255)
    local function cerrar()
        if fondo.Parent then fondo:Destroy() end
    end
    local function presionar(i)
        local boton = botones[i]
        if not boton then return end
        cerrar()
        if type(boton.Callback) == "function" then
            ejecutarConFallback(boton.Callback, boton.Texto or tituloError, casillaMarcada)
        end
    end

    for i, boton in ipairs(botones) do
        local variante = boton.Variante or "neutral"
        local anchoBtn = vertical and UDim2.new(1, 0, 0, 34)
            or UDim2.new(1 / total, -math.ceil(8 * (total - 1) / total), 1, 0)
        local color, claveTema, colorTexto, conBorde = Theme.Fila, "Fila", nil, false
        local transparencia = 0
        if variante == "primary" then
            color, claveTema, colorTexto = Theme.Accent, "Accent", blanco
        elseif variante == "danger" then
            color, claveTema, colorTexto = Color3.fromRGB(190, 60, 60), nil, blanco
        elseif variante == "tertiary" then
            color, claveTema, conBorde, transparencia = Theme.Panel, nil, true, 1
        end

        local btn = Utils.BotonBase({
            Padre = filaBotones, Size = anchoBtn,
            Color = color, Transparencia = transparencia, Radio = 6,
        })
        btn.LayoutOrder = i
        btn.ZIndex = zBase + 3
        if claveTema then Nub:Registrar(btn, "BackgroundColor3", claveTema) end
        if conBorde then
            local trazo = Utils.Stroke(btn, Theme.Border, 1, 0)
            Nub:Registrar(trazo, "Color", "Border")
        else
            Utils.Hover(btn, btn)
        end

        local lbl = Utils.Texto({
            Padre = btn, Texto = tostring(boton.Texto or "OK"),
            Alineacion = Enum.TextXAlignment.Center, Tamano = 12,
            Fuente = Enum.Font.GothamMedium, Color = colorTexto, Truncar = true,
        })
        lbl.ZIndex = zBase + 4

        btn.MouseButton1Click:Connect(function() presionar(i) end)
    end

    Utils.EntradaModal(fondo, card)

    return {
        Cerrar = cerrar, Presionar = presionar, Fondo = fondo,
        ObtenerCasilla = function() return casillaMarcada end,
    }
end

-- ══════════════════════════════════════════════════════════════
--  DIALOGO() — modal semantico sobre Confirmar
-- ══════════════════════════════════════════════════════════════
-- Un solo campo ('Tipo') pre-configura icono, color de borde y boton de
-- aceptar. No hay una segunda implementacion de modal: usa Confirmar.
--   Nub:Dialogo({ Tipo = "error", Titulo = "Fallo al guardar",
--                    Contenido = "El archivo estaba bloqueado." })
-- Icono, Botones, BotonAceptar, BotonCancelar, Ancho, ColorBorde y Casilla
-- explicitos sobreescriben el preset.
local PRESETS_DIALOGO = {
    info     = { icono = "ℹ️", aceptar = "Entendido", variante = "primary", borde = nil },
    question = { icono = "❓", aceptar = "Sí",        variante = "primary", borde = nil },
    success  = { icono = "✅", aceptar = "Genial",    variante = "primary", borde = Color3.fromRGB(46, 204, 113) },
    warning  = { icono = "⚠️", aceptar = "Aceptar",   variante = "primary", borde = Color3.fromRGB(241, 196, 15) },
    error    = { icono = "❌", aceptar = "Cerrar",    variante = "danger",  borde = Color3.fromRGB(231, 76, 60) },
}

function Nub:Dialogo(cfg)
    cfg = cfg or {}
    local tipo = cfg.Tipo or "info"
    local preset = PRESETS_DIALOGO[tipo]
    if not preset then
        advertirDev("Dialogo", cfg.Titulo, "Tipo '" .. tostring(tipo) .. "' no reconocido (info, question, success, warning, error). Se usó \"info\".")
        tipo, preset = "info", PRESETS_DIALOGO.info
    end

    local cfgConfirmar = {
        Titulo     = cfg.Titulo or (tipo:sub(1, 1):upper() .. tipo:sub(2)),
        Contenido  = cfg.Contenido,
        Icono      = cfg.Icono or preset.icono,
        Ancho      = cfg.Ancho,
        ColorBorde = cfg.ColorBorde or preset.borde,
        Borde      = cfg.Borde,
        Casilla    = cfg.Casilla,
    }

    if cfg.Botones then
        cfgConfirmar.Botones = cfg.Botones
    else
        -- 'Cancelar' aparece por defecto solo donde tiene sentido (pregunta y
        -- advertencia); en info/exito/error basta con un boton.
        local mostrarCancelar = cfg.MostrarCancelar
        if mostrarCancelar == nil then mostrarCancelar = (tipo == "question" or tipo == "warning") end
        if cfg.BotonCancelar then
            cfgConfirmar.BotonCancelar = cfg.BotonCancelar
        elseif mostrarCancelar then
            cfgConfirmar.BotonCancelar = { Texto = "Cancelar" }
        end
        local aceptar = clonarTabla(cfg.BotonAceptar or {})
        aceptar.Texto = aceptar.Texto or preset.aceptar
        aceptar.Variante = aceptar.Variante or preset.variante
        cfgConfirmar.BotonAceptar = aceptar
    end

    return Nub:Confirmar(cfgConfirmar)
end

function Nub:Notificar(config)
    config = config or {}
    if not contenedorNotif then return end

    if notifActivas >= MAX_NOTIF_SIMULTANEAS then
        -- Prioridad (Propuesta 12): un numero mas alto salta adelante
        -- de lo que ya este esperando con prioridad menor, en vez de
        -- siempre irse al final de la cola. Sin Prioridad se comporta
        -- exactamente igual que antes (FIFO puro, prioridad 0).
        local prioridad = config.Prioridad or 0
        local posicion  = #colaNotif + 1
        for i, enCola in ipairs(colaNotif) do
            if (enCola.Prioridad or 0) < prioridad then
                posicion = i
                break
            end
        end
        table.insert(colaNotif, posicion, config)
        return
    end
    mostrarTarjetaNotif(config)
end

-- ══════════════════════════════════════════════════════════════
--  VENTANA PRINCIPAL
-- ══════════════════════════════════════════════════════════════
-- 🪟 CREAR VENTANA — crea la ventana principal; todo lo demás (Tabs, Secciones, controles) cuelga de acá.
function Nub:CrearVentana(config)
    local ok, resultado = pcall(function()
    config = config or {}
    local titulo    = config.Titulo    or "nub protegido"
    -- El developer que usa Nub puede poner cualquier Subtitulo para
    -- SU propio script (esa es su propia identidad/credito) -- pero
    -- se le agrega "• Nub vX.X" al final SIEMPRE, sin ninguna forma
    -- de sacarlo desde 'config'. Asi el nombre de la libreria queda
    -- fijo sin importar que tanto rebranding haga el developer en su
    -- Titulo -- y la version que se ve es SIEMPRE la real (lee
    -- Nub.Version en vivo), asi que aunque el desarrollador escriba
    -- un numero de version viejo a mano dentro de su propio Subtitulo
    -- (ej. "by Fulano (v2.4)"), al lado siempre aparece la version
    -- real y actualizada de la libreria para que no quede como la
    -- unica fuente de verdad un texto que se puede desactualizar.
    local subtitulo = config.Subtitulo or "nub protegido"
    local anchoX    = config.TamanoX   or 560
    local anchoY    = config.TamanoY   or 340
    local teclaUI   = config.TeclaToggle or Enum.KeyCode.RightControl

    -- Auto-limpieza: si el script se re-ejecuto (ej. el usuario le dio
    -- de nuevo a "Execute" en su ejecutor sin cerrar el juego), esto
    -- desconecta y destruye TODO lo que haya quedado corriendo de la
    -- ejecucion anterior (conexiones, hilos, Drawing, GUIs) antes de
    -- crear la ventana nueva.
    pcall(limpiarInstanciaPrevia)
    _G.Nub_InstanciaActiva = crearRegistroInstancia(titulo)

    local padreGui = obtenerPadreGui()
    local viejo    = padreGui:FindFirstChild("Nub_ScreenGui")
    if viejo then viejo:Destroy() end

    -- Limpiar registros de la ventana anterior
    registroTema          = {}
    indiceBusqueda        = {}
    registroEscalaTexto   = {}
    Nub.Elementos      = nuevaTablaElementos()
    _keybindsRegistrados  = {}
    seccionesRegistradas  = {}
    for k in pairs(_flagsReales) do _flagsReales[k] = nil end
    _flagsNoPersistir     = {}
    _flagsUI              = {}
    hayCambiosSinGuardar  = false
    Nub:LimpiarHistorial()

    -- Tamano inicial de interfaz y texto. ANTES los sliders de la Preinstalada
    -- MOSTRABAN 125% y 150% pero la interfaz arrancaba al 100%: el Slider no
    -- ejecuta su Callback al crearse. Ahora esos valores se aplican de verdad.
    -- 'escalasTexto' es una variable del MODULO (la comparten todas las
    -- ventanas): se reinicia aca para que una ventana nueva nazca como la
    -- primera vez y no herede el tamano de texto que dejo la anterior.
    local function redondearA5(valor, minimo, maximo)
        return math.clamp(math.floor(valor / 5 + 0.5) * 5, minimo, maximo)
    end
    local ESCALA_INTERFAZ_INICIAL = redondearA5(tonumber(Nub.Opciones.EscalaInterfazPredeterminada) or 125, 70, 130)
    local ESCALA_TEXTO_INICIAL    = redondearA5(tonumber(Nub.Opciones.EscalaTextoPredeterminada) or 150, 80, 150)
    escalasTexto.tabs, escalasTexto.general, escalasTexto.titulo = ESCALA_TEXTO_INICIAL / 100, ESCALA_TEXTO_INICIAL / 100, 1
    ventanaActivaGuardado = nil -- evita que una ventana nueva con AutoGuardar=false siga guardando bajo el NombreConfig de la ventana anterior (ya destruida)
    loopAutoguardadoActivo = false -- detiene el loop de la ventana anterior; CrearVentana lo reactiva si la nueva tiene AutoGuardar habilitado
    contenedorNotif  = nil   -- fuerza recrear el contenedor en el nuevo padre
    colaNotif        = {}
    notifActivas     = 0

    local sg = Instance.new("ScreenGui")
    sg.Name           = "Nub_ScreenGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = padreGui
    protegerGui(sg)

    crearContenedorNotif(sg)
    Nub._guiConfirmar = sg
    Nub._modalesAbiertos = 0

    -- La ventana arranca en tamaño 0 (centrada) y se expande con un
    -- efecto de rebote suave hasta su tamaño final. Es un solo Tween
    -- nativo de TweenService: no consume nada una vez terminado (no
    -- hay loops ni hilos detras).
    local main = Utils.Frame({
        Padre = sg,
        Size = UDim2.new(0, 0, 0, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0),
        Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Radio = 14, Recortar = true,
        Borde = true, ColorBorde = Theme.Border, GrosorBorde = 2,
        ClaveTemaBorde = "Border",
    })
    main.Active = true
    Nub:Registrar(main, "BackgroundColor3", "Panel")

    -- Borde de la ventana: CrearVentana({ Borde = ... }) o, si no se pasa,
    -- Nub.Opciones.BordeVentanaPredeterminado. Ver Utils.AplicarBorde para
    -- los formatos. Se cambia luego con Ventana:EstablecerBorde(spec).
    local especBordeInicial = config.Borde
    if especBordeInicial == nil then especBordeInicial = Nub.Opciones.BordeVentanaPredeterminado end
    local manejadorBordeVentana = Utils.AplicarBorde(main, especBordeInicial)

    -- Overlay de sombra: un Frame que cubre TODA la pantalla, detras
    -- de la ventana, con una transparencia muy alta (95%) para que
    -- el efecto sea sutil pero perceptible en cualquier fondo del
    -- juego (incluidos fondos claros). A diferencia de un halo
    -- ajustado al borde de la ventana (que solo se nota en los
    -- pixeles inmediatos al borde), esto le da a la ventana una
    -- sensacion real de "estar flotando por encima" del resto de la
    -- pantalla, sin llegar a oscurecer el juego de forma molesta.
    local sombraPantalla = Utils.Frame({
        Padre = sg,
        Size = UDim2.new(1, 0, 1, 0),
        Posicion = UDim2.new(0, 0, 0, 0),
        Color = Color3.new(0, 0, 0),
        Transparencia = 1, -- arranca invisible; el fade-in de abajo la lleva a 0.95
        Radio = false,
    })
    sombraPantalla.ZIndex = -10
    -- Fade-in de la sombra. Antes la propiedad era 'Transparencia' (no existe en
    -- Roblox): el tween fallaba en silencio y la sombra nunca aparecia.
    Utils.Tween(sombraPantalla, {BackgroundTransparency = 0.95}, Nub.Motion.Modal, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    -- La sombra sigue la visibilidad de 'main' (no su tamaño/posicion,
    -- ya que el overlay cubre toda la pantalla fija): al minimizar la
    -- ventana (main.Visible = false), el overlay se oculta con ella.
    -- Se liga a Visible en vez de ocultarlo a mano en cada punto que
    -- toque main.Visible, para cubrir tambien cualquier punto futuro
    -- sin tener que acordarse.
    Nub:RegistrarConexion(main:GetPropertyChangedSignal("Visible"):Connect(function()
        sombraPantalla.Visible = main.Visible
    end))

    -- Posicion de nacimiento de la ventana: el centro de la pantalla, o
    -- 'PosicionInicial' (UDim2) si el script la pasa. Se guarda aparte para
    -- poder restaurarla cada vez que la ventana se vuelve a abrir con la
    -- tecla de toggle o el boton de minimizar: el usuario puede arrastrarla a
    -- cualquier lugar mientras esta abierta, pero al cerrar y volver a abrir
    -- NO debe quedar "pegada" a donde la solto la ultima vez.
    local POSICION_CENTRO = typeof(config.PosicionInicial) == "UDim2" and config.PosicionInicial
        or UDim2.new(0.5, 0, 0.5, 0)
    local POSICION_ORIGINAL_VENTANA = POSICION_CENTRO

    -- ── Recordar la posicion ENTRE EJECUCIONES ──────────────────────
    -- GuardarPosicion (default true; global: Nub.Opciones.GuardarPosicionVentana).
    -- Decisiones de diseno:
    --   * Archivo PROPIO por script (Nub/Config/_ui/posicion_<NombreConfig>.json),
    --     no el de ajustes de UI: ese es global para todos los scripts y solo se
    --     escribe con el boton "Guardar" de la Preinstalada.
    --   * Se LEE aqui mismo, de forma sincrona, antes de la animacion de apertura
    --     (no depende del task.defer de CargarUI), asi la ventana no salta.
    --   * Se guarda el OFFSET respecto al centro como fraccion del viewport:
    --     Utils.Arrastrable mueve la ventana cambiando el Offset (el Scale queda
    --     fijo en 0.5) y asi la posicion sobrevive a un cambio de resolucion.
    --   * Si no hay soporte de archivos, simplemente no se recuerda nada.
    local guardarPosActual = (config.GuardarPosicion ~= false)
        and (Nub.Opciones.GuardarPosicionVentana ~= false)

    local function viewportActual()
        local c = workspace.CurrentCamera
        local vp = c and c.ViewportSize or Nub.Capacidades.ViewportSize
        if not vp or vp.X <= 0 or vp.Y <= 0 then return Vector2.new(800, 360) end
        return vp
    end

    local function rutaArchivoPosicion()
        local nombre = tostring(config.NombreConfig or "autosave")
        nombre = nombre:gsub('[/\\:*?"<>|%c]', "_")
        return "Nub/Config/_ui/posicion_" .. nombre .. ".json"
    end

    local function leerPosicionGuardada()
        if not (guardarPosActual and fsDisponible() and type(isfile) == "function") then return nil end
        local ruta = rutaArchivoPosicion()
        if not isfile(ruta) then return nil end
        local okLeer, texto = pcall(readfile, ruta)
        if not okLeer then return nil end
        local okJson, datos = pcall(function() return HttpService:JSONDecode(texto) end)
        if not (okJson and type(datos) == "table"
            and type(datos.ox) == "number" and type(datos.oy) == "number") then
            return nil
        end
        return { ox = math.clamp(datos.ox, -1, 1), oy = math.clamp(datos.oy, -1, 1) }
    end

    local function escribirPosicionAhora()
        if not (guardarPosActual and fsDisponible()) then return false end
        if not (main and main.Parent) then return false end
        local vp = viewportActual()
        local p = main.Position
        local datos = {
            ox = (p.X.Offset - POSICION_CENTRO.X.Offset) / vp.X,
            oy = (p.Y.Offset - POSICION_CENTRO.Y.Offset) / vp.Y,
        }
        if type(isfolder) == "function" and type(makefolder) == "function" then
            for _, carpeta in ipairs({ "Nub", "Nub/Config", "Nub/Config/_ui" }) do
                if not isfolder(carpeta) then pcall(makefolder, carpeta) end
            end
        end
        return (pcall(function()
            writefile(rutaArchivoPosicion(), HttpService:JSONEncode(datos))
        end))
    end

    local posGuardada = leerPosicionGuardada()
    if posGuardada then
        local vp = viewportActual()
        POSICION_ORIGINAL_VENTANA = UDim2.new(
            POSICION_CENTRO.X.Scale, POSICION_CENTRO.X.Offset + math.floor(posGuardada.ox * vp.X + 0.5),
            POSICION_CENTRO.Y.Scale, POSICION_CENTRO.Y.Offset + math.floor(posGuardada.oy * vp.Y + 0.5)
        )
    end

    -- Apertura de la ventana: mismo tiempo en todos los dispositivos
    -- (Motion.Modal). El rebote Back/Out se siente "vivo" sin volverse
    -- lento en celulares.
    local duracionApertura = Nub.Motion.Modal
    local tweenApertura = Utils.Tween(main, {
        Size     = UDim2.new(0, anchoX, 0, anchoY),
        Position = POSICION_ORIGINAL_VENTANA,
    }, duracionApertura, Nub.Motion.EasePop, Enum.EasingDirection.Out)
    sg.Destroying:Connect(function()
        if tweenApertura then pcall(function() tweenApertura:Cancel() end) end
        -- El overlay del tooltip (overlayGui) es un ScreenGui APARTE de
        -- 'sg', cacheado a nivel de modulo -- sobrevive a sg:Destroy()
        -- por si solo. Si habia un tooltip abierto justo cuando se
        -- cierra la ventana, su conexion a InputBegan quedaba viva
        -- para siempre, apuntando a un panel que ya no tiene sentido.
        pcall(cerrarTooltipGlobal)
    end)

    -- ══════════════════════════════════════════════════════════════
    --  PANTALLA DE CARGA (splash) AL INICIAR
    -- ══════════════════════════════════════════════════════════════
    -- Se muestra por encima de todo mientras se termina de construir
    -- la interfaz: nombre de la libreria (Nub), abajo el credito
    -- del SCRIPT (el 'Subtitulo' que ya pasa el developer, ej. "by
    -- TuNombre" — no es un texto propio de la libreria), y una barra
    -- de progreso.
    --
    -- La duracion NO es un numero fijo inventado: 'task.spawn' arranca
    -- esta espera ANTES de que CrearVentana termine de retornar, y la
    -- primera espera a RunService.Heartbeat hace que este hilo se
    -- pause aqui hasta el proximo frame. Como las llamadas del
    -- developer a CrearTab/CrearSeccion/controles son sincronas (sin
    -- yields) y ocurren INMEDIATAMENTE despues de recibir la Ventana
    -- que retorna esta funcion, para cuando este hilo se reanuda en el
    -- siguiente frame, TODOS los controles (los propios de la libreria
    -- y los del developer) ya fueron creados y registrados en
    -- 'indiceBusqueda'. Con ese numero real se calcula cuanto debe
    -- durar la barra — una interfaz con pocos controles carga rapido,
    -- una con muchos tarda un poco mas.
    -- false mientras el splash tapa la ventana: durante el armado inicial no
    -- se anima nada (quedaria oculto debajo y seria trabajo tirado).
    local ventanaRevelada = false
    Nub._ventanaRevelada = false

    -- Guardado de la posicion: cualquier cambio de Position DESPUES de que la
    -- ventana ya es visible (arrastre, recentrado por los sliders de tamano,
    -- ResetearPosicion...) programa una escritura con debounce de 0.8s, para no
    -- tocar el disco en cada pixel del arrastre.
    local guardadoPosPendiente = false
    local function programarGuardadoPos()
        if guardadoPosPendiente then return end
        guardadoPosPendiente = true
        task.delay(0.8, function()
            guardadoPosPendiente = false
            if main and main.Parent then escribirPosicionAhora() end
        end)
    end
    Nub:RegistrarConexion(main:GetPropertyChangedSignal("Position"):Connect(function()
        if ventanaRevelada and guardarPosActual then programarGuardadoPos() end
    end))

    -- Si la ventana quedo (parcial o totalmente) fuera de la pantalla -- por
    -- una posicion guardada en otra resolucion, por ejemplo --, la trae de
    -- vuelta usando su tamano REAL. Devuelve la posicion nueva, o nil si no
    -- hizo falta moverla.
    local function mantenerEnPantalla()
        if not (main and main.Parent) then return nil end
        local vp = viewportActual()
        local pos, tam = main.AbsolutePosition, main.AbsoluteSize
        if tam.X <= 0 or tam.Y <= 0 then return nil end
        local dx, dy = 0, 0
        if tam.X >= vp.X or pos.X < 0 then dx = -pos.X
        elseif pos.X + tam.X > vp.X then dx = vp.X - (pos.X + tam.X) end
        if tam.Y >= vp.Y or pos.Y < 0 then dy = -pos.Y
        elseif pos.Y + tam.Y > vp.Y then dy = vp.Y - (pos.Y + tam.Y) end
        if math.abs(dx) < 1 and math.abs(dy) < 1 then return nil end
        local p = main.Position
        local destino = UDim2.new(p.X.Scale, p.X.Offset + math.floor(dx + 0.5), p.Y.Scale, p.Y.Offset + math.floor(dy + 0.5))
        Utils.Tween(main, {Position = destino}, Nub.Motion.Page, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
        return destino
    end
    if posGuardada then
        task.delay(duracionApertura + 0.5, function()
            local corregido = mantenerEnPantalla()
            if corregido then POSICION_ORIGINAL_VENTANA = corregido end
        end)
    end
    local splash = Utils.Frame({
        Padre = sg, Color = Theme.Panel, Radio = 10,
        Size = UDim2.new(2, 0, 2, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0),
        Ancla = Vector2.new(0.5, 0.5),
    })
    splash.ZIndex = 2000
    splash.Active = true
    Nub:Registrar(splash, "BackgroundColor3", "Panel")

    -- Logo del creador (rbxassetid propio). Es puramente decorativo:
    -- si el asset alguna vez no carga (moderacion, id invalido, etc.),
    -- un ImageLabel simplemente no muestra nada ahi — no tira error, no
    -- rompe el splash. El texto "Nub" de abajo sigue funcionando
    -- como respaldo de identidad en cualquier caso.
    local logoImagen = Instance.new("ImageLabel")
    logoImagen.BackgroundTransparency = 1
    logoImagen.Image = "rbxassetid://123994745552712"
    logoImagen.ScaleType = Enum.ScaleType.Fit
    logoImagen.Size = UDim2.new(0, 64, 0, 64)
    logoImagen.Position = UDim2.new(0.5, -32, 0.5, -100)
    logoImagen.Parent = splash

    Utils.Texto({
        Padre = splash, Texto = "Nub",
        Size = UDim2.new(1, 0, 0, 28), Posicion = UDim2.new(0, 0, 0.5, -28),
        Alineacion = Enum.TextXAlignment.Center,
        Fuente = Enum.Font.GothamBold, Tamano = 22, Color = Theme.AccentLight,
    })
    local lblCreditoSplash = Utils.Texto({
        Padre = splash, Texto = subtitulo,
        Size = UDim2.new(1, 0, 0, 16), Posicion = UDim2.new(0, 0, 0.5, 2),
        Alineacion = Enum.TextXAlignment.Center,
        Tamano = 12, Color = Theme.TextDark, TextoTransparencia = 0.3,
    })
    Nub:Registrar(lblCreditoSplash, "TextColor3", "TextDark")

    local barraSplashFondo = Utils.Frame({
        Padre = splash, Color = Theme.Entrada, Radio = 4,
        Size = UDim2.new(0, 180, 0, 6), Posicion = UDim2.new(0.5, -90, 0.5, 34),
    })
    Nub:Registrar(barraSplashFondo, "BackgroundColor3", "Entrada")
    local barraSplashRelleno = Utils.Frame({
        Padre = barraSplashFondo, Color = Theme.Accent, Radio = 4,
        Size = UDim2.new(0, 0, 1, 0),
    })
    Nub:Registrar(barraSplashRelleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(barraSplashRelleno)
    Utils.FundirEntrada(splash, Nub.Motion.Modal, true) -- incluye el panel: antes aparecia opaco de golpe y solo sus hijos hacian fade

    Nub:RegistrarHilo(task.spawn(function()
        local ok, err = pcall(function()
            local RunService = game:GetService("RunService")
            for _ = 1, 3 do
                if not (splash and splash.Parent) then return end
                RunService.Heartbeat:Wait()
            end
            if not (splash and splash.Parent) then return end

            local totalControles = #indiceBusqueda
            -- Barra de carga cosmetica: el trabajo real ya termino; la barra
            -- solo acompaña. Tope corto para no retrasar la primera impresion.
            local duracion = math.clamp(0.35 + totalControles * 0.008, 0.35, 1.0)

            Utils.Tween(barraSplashRelleno, {Size = UDim2.new(1, 0, 1, 0)}, duracion, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.wait(duracion)
            if not (splash and splash.Parent) then return end

            -- Se desliza hacia arriba y desaparece, revelando la
            -- ventana ya lista (y ya animada) debajo.
            ventanaRevelada = true
            Nub._ventanaRevelada = true
            local tSplash = Utils.Tween(splash, {Position = UDim2.new(0.5, 0, -1.5, 0)}, Nub.Motion.Modal, Nub.Motion.EaseSalir, Enum.EasingDirection.In)
            tSplash.Completed:Connect(function()
                pcall(function() if splash and splash.Parent then splash:Destroy() end end)
            end)
        end)
        if not ok then
            ventanaRevelada = true
            Nub._ventanaRevelada = true
            Nub:_RegistrarError("Splash inicial", err)
            pcall(function() if splash and splash.Parent then splash:Destroy() end end)
        end
    end))

    -- ==========================================
    -- ESCALA AUTOMATICA POR RESOLUCION (Responsive, estilo Rayfield)
    -- ==========================================
    -- En vez de una razon fija sobre una resolucion de referencia
    -- (1920x1080), se calcula cuanto hay que escalar la ventana para
    -- que quepa dentro de un porcentaje COMODO de la pantalla real del
    -- usuario. En celulares (pantalla angosta) se permite ocupar casi
    -- todo el ancho; en PC/tablets se mantiene mas compacta. Esto
    -- garantiza que la ventana SIEMPRE entre en pantalla, sea cual sea
    -- el dispositivo, en vez de un piso de escala fijo que en telefonos
    -- muy angostos podia hacer que la ventana se saliera de los bordes.
    -- Se combina con un slider manual en la pestaña Preinstalada
    -- (70%-130%) para que el usuario ajuste el tamaño a su gusto por
    -- encima de esta base automatica.
    local escalaUI = Instance.new("UIScale")
    escalaUI.Scale = 1
    escalaUI.Parent = main

    local escalaManual = ESCALA_INTERFAZ_INICIAL / 100 -- 1 = 100%; el slider "Tamaño de la interfaz" lo mueve entre 0.7 y 1.3

    -- NEW: ancho y alto de la ventana ajustables de forma INDEPENDIENTE
    -- (a diferencia de escalaManual, que agranda/achica todo de forma
    -- uniforme). anchoXBase/anchoYBase son el tamaño de referencia
    -- (el que puso el developer en config); factorAncho/factorAlto los
    -- mueven los sliders de la pestaña Preinstalada por separado.
    local anchoXBase, anchoYBase = anchoX, anchoY
    local factorAncho, factorAlto = 1, 1

    local function actualizarTamanoVentana()
        local nuevoAncho = anchoXBase * factorAncho
        local nuevoAlto  = anchoYBase * factorAlto
        -- Arrastrando un slider: sin tween (feedback directo). Cambio
        -- programatico (carga de perfil, codigo del dev): animado.
        local duracion = EventManager:HayArrastreActivo() and Nub.Motion.Directo or Nub.Motion.Page
        Utils.Tween(main, {
            Size     = UDim2.new(0, nuevoAncho, 0, nuevoAlto),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }, duracion, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    end

    local function recalcularEscala()
        local camara = Workspace.CurrentCamera
        if not camara then return end
        local tam = camara.ViewportSize
        if tam.X <= 0 or tam.Y <= 0 then return end

        local esMovil = tam.X < 700 or tam.Y < 500
        local pctAncho = esMovil and 0.94 or 0.75
        local pctAlto  = esMovil and 0.82 or 0.75

        local anchoActual = anchoXBase * factorAncho
        local altoActual  = anchoYBase * factorAlto

        local escalaPorAncho = (tam.X * pctAncho) / anchoActual
        local escalaPorAlto  = (tam.Y * pctAlto)  / altoActual
        local escalaAuto = math.min(escalaPorAncho, escalaPorAlto, 1.15)
        escalaAuto = math.max(escalaAuto, 0.45) -- piso solo para legibilidad, no para el ajuste

        local limiteEscala = math.min((tam.X * 0.98) / anchoActual, (tam.Y * 0.88) / altoActual)
        local escalaFinal = math.max(0.3, math.min(escalaAuto * escalaManual, limiteEscala))
        local duracion = EventManager:HayArrastreActivo() and Nub.Motion.Directo or Nub.Motion.Page
        Utils.Tween(escalaUI, {Scale = escalaFinal}, duracion, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    end

    recalcularEscala()

    -- Se re-engancha sola cada vez que Workspace.CurrentCamera cambia
    -- (personaje nuevo, camara cinematica custom, etc.), en vez de
    -- quedar atada para siempre a la que estaba activa al abrir.
    local conexionViewport = nil
    local function engancharCamara()
        if conexionViewport then
            Nub:DesconectarYLimpiar(conexionViewport)
            conexionViewport = nil
        end
        local camaraActual = Workspace.CurrentCamera
        if camaraActual then
            conexionViewport = Nub:RegistrarConexion(
                camaraActual:GetPropertyChangedSignal("ViewportSize"):Connect(recalcularEscala)
            )
        end
    end
    engancharCamara()
    Nub:RegistrarConexion(
        Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            engancharCamara()
            recalcularEscala()
        end)
    )

    -- ==========================================
    -- MINIMIZAR ESTILO RAYFIELD
    -- ==========================================
    -- Al minimizar, la ventana se oculta por completo (no se encoge) y
    -- aparece un pequeño texto flotante arriba de la pantalla; con un
    -- clic vuelve a abrirse la interfaz completa.
    -- El ancho de la pildora se calcula segun el texto real
    -- ("🔧 " + titulo, con un piso y un techo para que no quede
    -- gigante ni diminuta), con un margen extra fijo ademas del
    -- padding general: TextService:GetTextSize mide segun la fuente
    -- PEDIDA (Gotham, sin glifo real para 🔧), no segun la fuente de
    -- reemplazo que Roblox usa al renderizar el emoji -- esa fuente
    -- de reemplazo suele dibujarlo mas ancho de lo calculado.
    local textoPill = "🔧 " .. titulo
    local anchoPill = math.clamp(anchoTexto(textoPill, 12) + 28 + 14, 120, 280)

    local pillRestaurar = Utils.BotonBase({
        Padre = sg,
        Size = UDim2.new(0, anchoPill, 0, 30),
        Posicion = UDim2.new(0.5, 0, 0, 29), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Transparencia = 0, Radio = 15,
    })
    pillRestaurar.Visible = false
    pillRestaurar.ZIndex  = 50
    pillRestaurar.Active  = true
    Nub:Registrar(pillRestaurar, "BackgroundColor3", "Panel")
    local strokePill = Utils.Stroke(pillRestaurar, Theme.Accent, 1, 0.3)
    Nub:Registrar(strokePill, "Color", "Accent")

    Utils.Texto({
        Padre = pillRestaurar, Texto = textoPill,
        Size = UDim2.new(1, -12, 1, 0),
        Posicion = UDim2.new(0, 6, 0, 0),
        Alineacion = Enum.TextXAlignment.Center,
        Truncar = true,
        Fuente = Enum.Font.GothamBold, Tamano = 12,
    })

    local ventanaAbierta = true
    local animandoVentana = false
    local idOperacionVentana = 0

    -- REESCRITO A FONDO: las versiones anteriores dependian de que el
    -- evento 'Completed' de cada Tween se disparara para avanzar la
    -- cadena (abrir pill -> abrir main -> listo). El problema de raiz
    -- es que 'Completed' SOLO se dispara si el Tween llega solo a su
    -- estado final -- si se cancela por CUALQUIER motivo (otro Tween
    -- sobre el mismo objeto, una reejecucion del script, un error de
    -- timing del ejecutor, etc.) 'Completed' no se dispara NUNCA, y
    -- toda la cadena se quedaba a mitad de camino: 'main' con
    -- Size=(0,0,0,0) pero Visible=true (osea invisible igual, porque
    -- no tiene tamaño), o el pill sin volver a mostrarse.
    --
    -- Ahora no se depende de 'Completed' en absoluto: se dispara el
    -- Tween (para que se vea la animacion cuando todo va bien) y en
    -- paralelo se espera el tiempo YA CONOCIDO de esa animacion con
    -- task.wait(), y al final se FUERZA el valor final a mano. Si el
    -- Tween se cancelo por lo que sea, el valor ya quedo bien puesto
    -- de todos modos -- la ventana SIEMPRE termina en el estado
    -- correcto, se vea o no la animacion de por medio.
    local function alternarVentana(abrir)
        if animandoVentana or abrir == ventanaAbierta then return end
        animandoVentana = true
        ventanaAbierta = abrir

        -- Evita que una operacion "vieja" (por ejemplo si el usuario
        -- alcanza a tocar dos veces rapido) pise el estado de una mas
        -- nueva que ya esta en curso.
        local idOperacion = idOperacionVentana + 1
        idOperacionVentana = idOperacion
        local function esOperacionVigente() return idOperacionVentana == idOperacion end

        if abrir then
            local tamanoObjetivo = UDim2.new(0, anchoXBase * factorAncho, 0, anchoYBase * factorAlto)
            Utils.Tween(pillRestaurar, {Size = UDim2.new(0, 0, 0, 0)}, Nub.Motion.Expand, Nub.Motion.EaseSalir, Enum.EasingDirection.In)

            main.Visible = true
            main.Size = UDim2.new(0, 0, 0, 0)
            -- Vuelve siempre a la posicion original, sin importar a
            -- donde la haya arrastrado el usuario antes de cerrarla.
            main.Position = POSICION_ORIGINAL_VENTANA
            Utils.Tween(main, {Size = tamanoObjetivo}, Nub.Motion.Modal, Nub.Motion.EasePop, Enum.EasingDirection.Out)

            task.spawn(function()
                task.wait(Nub.Motion.Expand) -- lo que dura el tween del pill
                if esOperacionVigente() then
                    pcall(function()
                        pillRestaurar.Visible = false
                        pillRestaurar.Size = UDim2.new(0, anchoPill, 0, 30)
                    end)
                end
                task.wait(math.max(0, Nub.Motion.Modal - Nub.Motion.Expand)) -- resto hasta cubrir el tween de main
                if esOperacionVigente() then
                    -- Se fuerza el tamaño final EXACTO, se haya visto
                    -- la animacion completa o no.
                    pcall(function() main.Size = tamanoObjetivo end)
                    animandoVentana = false
                end
            end)
        else
            Utils.Tween(main, {Size = UDim2.new(0, 0, 0, 0)}, Nub.Motion.Expand, Nub.Motion.EaseSalir, Enum.EasingDirection.In)

            task.spawn(function()
                task.wait(Nub.Motion.Expand + 0.04)
                if not esOperacionVigente() then return end
                pcall(function()
                    main.Visible = false
                    main.Size = UDim2.new(0, 0, 0, 0) -- fuerza el tamaño final por si el tween no llegó
                    pillRestaurar.Size = UDim2.new(0, 0, 0, 0)
                    pillRestaurar.Visible = true
                end)
                Utils.Tween(pillRestaurar, {Size = UDim2.new(0, anchoPill, 0, 30)}, Nub.Motion.Modal, Nub.Motion.EasePop, Enum.EasingDirection.Out)
                task.wait(Nub.Motion.Modal + 0.01)
                if esOperacionVigente() then
                    pcall(function() pillRestaurar.Size = UDim2.new(0, anchoPill, 0, 30) end)
                    animandoVentana = false
                end
            end)
        end
    end

    pillRestaurar.MouseButton1Click:Connect(function() alternarVentana(true) end)

    -- Barra superior
    local barraTitulo = Utils.Frame({
        Padre = main, Size = UDim2.new(1, 0, 0, 34),
        Color = Theme.Background, Radio = 10,
    })
    barraTitulo.Active = true
    Nub:Registrar(barraTitulo, "BackgroundColor3", "Background")

    local tapa = Utils.Frame({
        Padre = barraTitulo,
        Size = UDim2.new(1, 0, 0, 10),
        Posicion = UDim2.new(0, 0, 1, -10),
        Color = Theme.Background, Radio = false,
    })
    Nub:Registrar(tapa, "BackgroundColor3", "Background")

    -- Gradiente horizontal muy sutil en el header (Background →
    -- +8% hacia blanco). Da una sensacion de "profundidad" sin
    -- alterar el color percibido del tema. Horizontal (no vertical)
    -- a proposito: el 'tapa' inferior del header (10px que cubren
    -- los bordes redondeados) tapa la parte de abajo, y con un
    -- gradiente vertical se veria un corte visible ahi.
    local function secuenciaHeader()
        local base = Theme.Background
        return ColorSequence.new(base, base:Lerp(Color3.new(1, 1, 1), 0.08))
    end
    local gradHeader = Instance.new("UIGradient")
    gradHeader.Rotation = 0
    gradHeader.Color = secuenciaHeader()
    gradHeader.Parent = barraTitulo
    Nub:Registrar(gradHeader, "Color", secuenciaHeader)

    -- Mismo gradiente en la 'tapa' inferior (por debajo). Se aplica
    -- el mismo, con la misma Rotation=0, para que el degradado se
    -- vea continuo entre header y tapa -- sin el, la parte inferior
    -- (10px) quedaria en color plano y se notaria la discontinuidad.
    local gradTapa = Instance.new("UIGradient")
    gradTapa.Rotation = 0
    gradTapa.Color = secuenciaHeader()
    gradTapa.Parent = tapa
    Nub:Registrar(gradTapa, "Color", secuenciaHeader)

    local lineaAcento = Utils.Frame({
        Padre = main, Size = UDim2.new(1, -24, 0, 2),
        Posicion = UDim2.new(0, 12, 0, 33), Color = Theme.Accent, Radio = false,
    })
    lineaAcento.ZIndex = barraTitulo.ZIndex + 2
    Nub:Registrar(lineaAcento, "BackgroundColor3", "Accent")
    local gradLinea = Instance.new("UIGradient")
    gradLinea.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, 0.15),
        NumberSequenceKeypoint.new(0.8, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    })
    gradLinea.Parent = lineaAcento

    -- Reutiliza la conexion global de EventManager
    Utils.Arrastrable(barraTitulo, main, EventManager)

    local lblTitulo = Utils.Texto({
        Padre = barraTitulo, Texto = titulo,
        Posicion = UDim2.new(0, 12, 0, 2),
        Size = UDim2.new(0.6, 0, 0, 18),
        Fuente = Enum.Font.GothamBold, Tamano = 15, Color = Theme.TextDark,
        Categoria = "titulo", Truncar = true,
    })
    Nub:Registrar(lblTitulo, "TextColor3", "TextDark")

    local lblSub = Utils.Texto({
        Padre = barraTitulo, Texto = subtitulo,
        Posicion = UDim2.new(0, 12, 0, 19),
        Size = UDim2.new(0.6, 0, 0, 13),
        -- Contraste ajustado (0.35 -> 0.22): seguia siendo legible,
        -- pero mas apagado de lo necesario para un texto que incluye
        -- info util (autor + version de Nub), no solo decorativo.
        Tamano = 11, Color = Theme.TextDark, TextoTransparencia = 0.22,
        Categoria = "titulo", Truncar = true,
    })
    Nub:Registrar(lblSub, "TextColor3", "TextDark")

    -- Botones cerrar / minimizar
    local TAMANO_ICONO       = 20 -- tamaño visible del icono (plano, sin fondo)
    local TAMANO_MINIMO_TOQUE = 32 -- tamaño minimo del area tactil invisible

    local actualizadoresBotones = {}
    local function crearCompensadorTamano(boton)
        local escalaBoton = Instance.new("UIScale")
        escalaBoton.Parent = boton
        local function actualizar()
            local escalaGlobal = escalaUI.Scale
            if escalaGlobal <= 0 then escalaGlobal = 1 end
            -- Solo compensa el AREA TACTIL (invisible), nunca el icono
            escalaBoton.Scale = math.max(1, TAMANO_MINIMO_TOQUE / (TAMANO_ICONO * escalaGlobal))
        end
        actualizar()
        table.insert(actualizadoresBotones, actualizar)
        return escalaBoton
    end

    -- ── Confirmación antes de eliminar la interfaz ──────────────────
    -- El botón "✕" pide confirmar antes de destruir la ventana.
    -- Destruccion de la interfaz con la misma limpieza de registros que
    -- Ventana:Destruir() (sg.Destroying ya cancela tweens/loops activos).
    local function destruirInterfaz()
        registroTema         = {}
        indiceBusqueda       = {}
        registroEscalaTexto  = {}
        Nub.Elementos     = nuevaTablaElementos()
        _keybindsRegistrados = {}
        seccionesRegistradas = {}
        sg:Destroy()
    end

    local function mostrarConfirmacionDestruir()
        local fondo = Utils.Frame({
            Padre = sg, Size = UDim2.new(1, 0, 1, 0),
            Color = Color3.new(0, 0, 0), Transparencia = 0.5, Radio = false,
        })
        fondo.ZIndex = 500
        fondo.Active = true -- bloquea clicks/toques hacia el resto de la interfaz

        local card = Utils.Frame({
            Padre = fondo, Size = UDim2.new(0, 280, 0, 0),
            Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Panel, Radio = 10,
            Borde = true, ColorBorde = Theme.Border, GrosorBorde = 1,
            ClaveTemaBorde = "Border",
        })
        card.ZIndex = 501
        card.AutomaticSize = Enum.AutomaticSize.Y
        Nub:Registrar(card, "BackgroundColor3", "Panel")

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 12)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = card

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
        pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)
        pad.Parent = card

        local lblTitulo = Utils.Texto({
            Padre = card, Texto = "⚠️ ¿Eliminar la interfaz?",
            Size = UDim2.new(1, 0, 0, 20), Orden = 1,
            Fuente = Enum.Font.GothamBold, Tamano = 15,
        })
        lblTitulo.ZIndex = 502

        local lblCuerpo = Utils.Texto({
            Padre = card,
            Texto = "Esta acción no se puede revertir. Se cerrará la interfaz y se eliminarán todas sus conexiones.",
            Size = UDim2.new(1, 0, 0, 0), Orden = 2,
            Ajustar = true, Tamano = 12, TextoTransparencia = 0.15,
        })
        lblCuerpo.AutomaticSize = Enum.AutomaticSize.Y
        lblCuerpo.ZIndex = 502

        local filaBotones = Utils.Frame({
            Padre = card, Size = UDim2.new(1, 0, 0, 32),
            Transparencia = 1, Orden = 3,
        })
        filaBotones.ZIndex = 502

        local btnCancelar = Utils.BotonBase({
            Padre = filaBotones, Size = UDim2.new(0.5, -4, 1, 0),
            Posicion = UDim2.new(0, 0, 0, 0),
            Color = Theme.Fila, Transparencia = 0, Radio = 6,
        })
        btnCancelar.ZIndex = 503
        Utils.Hover(btnCancelar, btnCancelar)
        Nub:Registrar(btnCancelar, "BackgroundColor3", "Fila")
        local lblCancelar = Utils.Texto({
            Padre = btnCancelar, Texto = "Cancelar",
            Alineacion = Enum.TextXAlignment.Center, Tamano = 12,
            Fuente = Enum.Font.GothamMedium,
        })
        lblCancelar.ZIndex = 504

        local btnEliminar = Utils.BotonBase({
            Padre = filaBotones, Size = UDim2.new(0.5, -4, 1, 0),
            Posicion = UDim2.new(0.5, 4, 0, 0),
            Color = Color3.fromRGB(190, 60, 60), Transparencia = 0, Radio = 6,
        })
        btnEliminar.ZIndex = 503
        Utils.Hover(btnEliminar, btnEliminar)
        local lblEliminar = Utils.Texto({
            Padre = btnEliminar, Texto = "Eliminar",
            Alineacion = Enum.TextXAlignment.Center, Tamano = 12,
            Fuente = Enum.Font.GothamMedium, Color = Color3.fromRGB(255, 255, 255),
        })
        lblEliminar.ZIndex = 504
        Utils.EntradaModal(fondo, card)

        -- Cancelar: se queda todo exactamente como estaba, solo se
        -- cierra el dialogo.
        btnCancelar.MouseButton1Click:Connect(function()
            fondo:Destroy()
        end)

        -- Eliminar: misma limpieza de registros que hace
        -- Ventana:Destruir() (registroTema/indiceBusqueda/
        -- registroEscalaTexto). sg.Destroying ya tiene sus propios
        -- handlers para cancelar tweens/loops activos.
        btnEliminar.MouseButton1Click:Connect(function()
            fondo:Destroy()
            destruirInterfaz()
        end)
    end

    local btnCerrar = Utils.BotonBase({
        Padre = barraTitulo,
        Size = UDim2.new(0, TAMANO_ICONO + 12, 0, TAMANO_ICONO + 6),
        Posicion = UDim2.new(1, -20, 0, 17), Ancla = Vector2.new(0.5, 0.5),
        Color = Color3.fromRGB(200, 60, 60), Transparencia = 1, Radio = 6,
    })
    -- Icono "X" dibujado con dos barras rotadas, en vez del emoji ❌: el emoji
    -- cambia de forma y de color segun la fuente de cada ejecutor. Mismo patron
    -- que el tilde de Casilla.
    for _, rotacion in ipairs({45, -45}) do
        local barraX = Utils.Frame({
            Padre = btnCerrar, Size = UDim2.new(0, 18, 0, 3),
            Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
            Color = Color3.fromRGB(232, 76, 76), Radio = 2,
        })
        barraX.Rotation = rotacion
    end
    -- Leve destello de color al tocar (feedback sutil, sin caja fija) —
    -- estilo plano tipo Rayfield en vez de un boton solido siempre visible.
    btnCerrar.MouseButton1Down:Connect(function()
        Utils.Tween(btnCerrar, {BackgroundTransparency = 0.75}, Nub.Motion.FlashIn)
    end)
    btnCerrar.MouseButton1Up:Connect(function()
        Utils.Tween(btnCerrar, {BackgroundTransparency = 1}, Nub.Motion.Hover)
    end)
    Utils.ClickConfiable(btnCerrar, function()
        -- Nub.Opciones.ConfirmarCierre = false: la X destruye directo.
        if Nub.Opciones.ConfirmarCierre == false then
            destruirInterfaz()
        else
            mostrarConfirmacionDestruir()
        end
    end)
    local escalaBtnCerrar = crearCompensadorTamano(btnCerrar)

    -- El area tactil invisible de cada boton es mas grande que su
    -- icono visible (crearCompensadorTamano la agranda a
    -- TAMANO_MINIMO_TOQUE de diametro, para que sea mas facil tocarlos
    -- en movil), asi que la separacion entre los centros de "cerrar"
    -- y "minimizar" tiene que ser suficiente para que esas zonas
    -- invisibles tampoco se pisen entre si -- no solo los iconos
    -- visibles.
    local btnMin = Utils.BotonBase({
        Padre = barraTitulo,
        Size = UDim2.new(0, TAMANO_ICONO + 12, 0, TAMANO_ICONO + 6),
        Posicion = UDim2.new(1, -62, 0, 17), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.BackgroundDark, Transparencia = 1, Radio = 6,
    })
    local lineaMin = Utils.Frame({
        Padre = btnMin, Size = UDim2.new(0, 16, 0, 3),
        Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.TextDark, Radio = 2,
    })
    Nub:Registrar(lineaMin, "BackgroundColor3", "TextDark")
    Nub:Registrar(btnMin, "BackgroundColor3", "BackgroundDark")
    btnMin.MouseButton1Down:Connect(function()
        Utils.Tween(btnMin, {BackgroundTransparency = 0.7}, Nub.Motion.FlashIn)
    end)
    btnMin.MouseButton1Up:Connect(function()
        Utils.Tween(btnMin, {BackgroundTransparency = 1}, Nub.Motion.Hover)
    end)
    local xTags = -86
    local contenedorTags
    do
        local escalaBtnMin = crearCompensadorTamano(btnMin)
        local function reposicionarBotonMin()
            if not btnMin.Parent then return end
            local x, xT = -62, -86
            if Nub.Capacidades.EsTactil then
                local anchoCerrar = btnCerrar.Size.X.Offset * escalaBtnCerrar.Scale
                local anchoMin = btnMin.Size.X.Offset * escalaBtnMin.Scale
                x = -math.ceil(20 + anchoCerrar / 2 + anchoMin / 2)
                xT = x - math.ceil(anchoMin / 2) - 4
            end
            btnMin.Position = UDim2.new(1, x, 0, 17)
            xTags = xT
            if contenedorTags then
                contenedorTags.Position = UDim2.new(1, xTags, 0, 17)
            end
        end
        reposicionarBotonMin()
        table.insert(actualizadoresBotones, reposicionarBotonMin)
        Nub:RegistrarConexion(Nub.Eventos.TipoCambiado:Connect(reposicionarBotonMin))
    end

    Utils.ClickConfiable(btnMin, function()
        alternarVentana(false)
    end)

    -- Cada vez que cambia la escala general (auto por resolución, o el
    -- slider manual "Tamaño de la interfaz"), se recalculan los
    -- compensadores de los botones para que mantengan su tamaño mínimo
    -- cómodo de tocar.
    Nub:RegistrarConexion(
        escalaUI:GetPropertyChangedSignal("Scale"):Connect(function()
            for _, actualizar in ipairs(actualizadoresBotones) do
                pcall(actualizar)
            end
        end)
    )

    -- Referencia a main para AgregarPestanaPreinstalada
    local Ventana_main = main

    -- Orientacion: "vertical" (sidebar) o "horizontal" (top bar)
    local modoHorizontal = config.Orientacion == "horizontal"
    local anchoBarraLat  = modoHorizontal and 0 or 150
    local altoBarraHoriz = modoHorizontal and 36 or 0

    -- Barra lateral (tabs verticales)
    -- ScrollingFrame (no Frame plano): con muchos tabs (15+), la
    -- barra lateral se desbordaba hacia abajo sin forma de scrollear
    -- -- a diferencia de barraHoriz (mas abajo), que siempre fue
    -- scrolleable en su eje. Misma configuracion que esa, pero en Y.
    local barraLat = Instance.new("ScrollingFrame")
    barraLat.Size                  = UDim2.new(0, 150, 1, -34)
    barraLat.Position              = UDim2.new(0, 0, 0, 34)
    barraLat.BackgroundColor3      = Theme.PanelClaro
    barraLat.BorderSizePixel       = 0
    barraLat.Visible               = not modoHorizontal
    barraLat.ScrollingDirection    = Enum.ScrollingDirection.Y
    barraLat.CanvasSize            = UDim2.new(0, 0, 0, 0)
    barraLat.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    barraLat.ScrollBarThickness    = 3
    barraLat.ScrollBarImageColor3  = Theme.Accent
    barraLat.Parent                = main
    Nub:Registrar(barraLat, "BackgroundColor3", "PanelClaro")

    local layoutTabs = Instance.new("UIListLayout")
    layoutTabs.Padding   = UDim.new(0, 4)
    layoutTabs.SortOrder = Enum.SortOrder.LayoutOrder
    layoutTabs.Parent    = barraLat

    local padTabs = Instance.new("UIPadding")
    padTabs.PaddingTop   = UDim.new(0, 8)
    padTabs.PaddingLeft  = UDim.new(0, 6)
    padTabs.PaddingRight = UDim.new(0, 6)
    padTabs.Parent       = barraLat

    -- Barra horizontal (tabs horizontales, siempre creada, oculta segun orientacion)
    local barraHoriz = Instance.new("ScrollingFrame")
    barraHoriz.Size                  = UDim2.new(1, 0, 0, 36)
    barraHoriz.Position              = UDim2.new(0, 0, 0, 34)
    barraHoriz.BackgroundColor3      = Theme.PanelClaro
    barraHoriz.BorderSizePixel       = 0
    barraHoriz.Visible               = modoHorizontal
    barraHoriz.ScrollingDirection    = Enum.ScrollingDirection.X
    barraHoriz.CanvasSize            = UDim2.new(0, 0, 0, 0)
    barraHoriz.AutomaticCanvasSize   = Enum.AutomaticSize.X
    barraHoriz.ScrollBarThickness    = 3
    barraHoriz.ScrollBarImageColor3  = Theme.Accent
    barraHoriz.Parent                = main
    Nub:Registrar(barraHoriz, "BackgroundColor3", "PanelClaro")

    local layoutHoriz = Instance.new("UIListLayout")
    layoutHoriz.FillDirection       = Enum.FillDirection.Horizontal
    layoutHoriz.Padding             = UDim.new(0, 4)
    layoutHoriz.SortOrder           = Enum.SortOrder.LayoutOrder
    layoutHoriz.VerticalAlignment   = Enum.VerticalAlignment.Center
    layoutHoriz.Parent              = barraHoriz

    local padHoriz = Instance.new("UIPadding")
    padHoriz.PaddingLeft  = UDim.new(0, 8)
    padHoriz.PaddingRight = UDim.new(0, 8)
    padHoriz.PaddingTop   = UDim.new(0, 4)
    padHoriz.PaddingBottom = UDim.new(0, 4)
    padHoriz.Parent       = barraHoriz

    -- Contenedor de paginas — posicion segun orientacion activa
    local function posContenedor()
        if modoHorizontal then
            return UDim2.new(0, 0, 0, 70), UDim2.new(1, 0, 1, -70)
        else
            return UDim2.new(0, 150, 0, 34), UDim2.new(1, -150, 1, -34)
        end
    end

    local posP, sizeP = posContenedor()
    local contenedorPaginas = Utils.Frame({
        Padre = main,
        Size = sizeP, Posicion = posP,
        Transparencia = 1, Radio = false,
    })

    Nub:RegistrarConexion(
        UserInputService.InputBegan:Connect(function(input, procesado)
            if not procesado and input.KeyCode == teclaUI then
                alternarVentana(not ventanaAbierta)
            end
        end)
    )

    local Ventana = {Tabs = {}}
    local ordenTab, primeraTab = 0, true
    -- Transparencia del tinte con el que se marca la pestana activa en la barra
    -- lateral (acento muy suave; 1 = sin tinte).
    local TINTE_TAB_ACTIVA = 0.88

    -- ── BUSCADOR GLOBAL ─────────────────────────────────────────
    -- Estado "sin resultados": si la busqueda no coincide con nada, todas las
    -- secciones quedan ocultas y la pagina se veia en blanco. Este cartel (se
    -- crea la primera vez que hace falta) explica que no hay coincidencias.
    local estadoSinResultados, lblSinResultados = nil, nil
    local function actualizarSinResultados(mostrar, texto)
        if not mostrar then
            if estadoSinResultados then estadoSinResultados.Visible = false end
            return
        end
        if not estadoSinResultados then
            estadoSinResultados = Utils.Frame({
                Padre = contenedorPaginas, Size = UDim2.new(1, 0, 1, 0),
                Transparencia = 1, Radio = false,
            })
            estadoSinResultados.ZIndex = 5
            Utils.Texto({
                Padre = estadoSinResultados, Texto = "🔍",
                Size = UDim2.new(1, 0, 0, 36), Posicion = UDim2.new(0, 0, 0.5, -42),
                Alineacion = Enum.TextXAlignment.Center, Tamano = 26, TextoTransparencia = 0.3,
            })
            lblSinResultados = Utils.Texto({
                Padre = estadoSinResultados, Texto = "",
                Size = UDim2.new(1, -24, 0, 18), Posicion = UDim2.new(0, 12, 0.5, 0),
                Alineacion = Enum.TextXAlignment.Center, Tamano = 12, Truncar = true,
            })
            Utils.Texto({
                Padre = estadoSinResultados, Texto = "Prueba con otra palabra",
                Size = UDim2.new(1, -24, 0, 16), Posicion = UDim2.new(0, 12, 0.5, 20),
                Alineacion = Enum.TextXAlignment.Center, Tamano = 10, TextoTransparencia = 0.45,
            })
        end
        lblSinResultados.Text = 'Sin resultados para "' .. texto .. '"'
        estadoSinResultados.Visible = true
    end

    local function filtrarBusqueda(texto)
        texto = (texto or ""):lower()
        local buscandoActivo = texto ~= ""

        -- ── Secciones colapsables + buscador ──────────────────
        -- Mientras hay búsqueda activa, se expanden todas las
        -- secciones colapsables (las que no tengan match quedarán
        -- invisibles igual por la lógica de abajo, pero mantener
        -- el estado consistente evita parpadeos). Al limpiar la
        -- búsqueda, se restaura el estado previo guardado.
        --
        -- El guardado es perezoso: solo se captura el estado la
        -- PRIMERA vez que se entra a búsqueda activa para cada
        -- sección, y se limpia al restaurar. Así no se pisa el
        -- estado previo si el usuario escribe/borra varias veces
        -- sin llegar a texto vacío.
        for _, entrada in ipairs(seccionesRegistradas) do
            if entrada.colapsable then
                if buscandoActivo then
                    if entrada.colapsadaAntesDeBuscar == nil then
                        entrada.colapsadaAntesDeBuscar = entrada.colapsada
                    end
                    if entrada.colapsada then
                        entrada.AplicarColapsada(false)
                    end
                else
                    if entrada.colapsadaAntesDeBuscar ~= nil then
                        entrada.AplicarColapsada(entrada.colapsadaAntesDeBuscar)
                        entrada.colapsadaAntesDeBuscar = nil
                    end
                end
            end
        end

        for _, entrada in ipairs(indiceBusqueda) do
            -- Un control es visible si coincide con la busqueda (o no
            -- hay busqueda) Y ADEMAS cumple su propia condicion
            -- VisibleSi (si tiene una) -- si no se combinaran los dos,
            -- buscar podia "revivir" temporalmente un control que su
            -- VisibleSi queria mantener oculto.
            local coincide = texto == "" or entrada.texto:find(texto, 1, true) ~= nil
            entrada.fila.Visible = coincide and cumpleVisibilidadCondicional(entrada.fila)
        end

        local primerTabConMatch = nil
        for _, t in ipairs(Ventana.Tabs) do
            local tabTieneMatch = false
            for _, s in ipairs(t.Secciones) do
                local seccionTieneMatch = false
                for _, hijo in ipairs(s.contenedor:GetChildren()) do
                    if hijo:IsA("GuiObject") and hijo.Visible then
                        seccionTieneMatch = true
                        break
                    end
                end
                s.marco.Visible = (texto == "") or seccionTieneMatch
                if seccionTieneMatch then tabTieneMatch = true end
            end
            if texto ~= "" and tabTieneMatch and not primerTabConMatch then
                primerTabConMatch = t
            end
        end

        if texto ~= "" and primerTabConMatch and not primerTabConMatch.Pagina.Visible then
            primerTabConMatch.Seleccionar()
        end

        actualizarSinResultados(texto ~= "" and primerTabConMatch == nil, texto)
    end

    function Ventana:Buscar(texto)
        return filtrarBusqueda(texto)
    end

    if config.Buscador ~= false then
        -- OPTIMIZACION: debounce de 120ms. Sin esto, cada tecla
        -- presionada filtraba TODOS los controles buscables de
        -- inmediato; con debounce, solo se filtra una vez que el
        -- usuario deja de teclear un instante (evita filtrar 5 veces
        -- si escribe "combo" rapido). Se comparte entre las 2 cajas
        -- (vertical/horizontal) para no duplicar la logica.
        local busquedaId = 0
        local hiloBusqueda
        local function conectarBuscador(caja)
            caja:GetPropertyChangedSignal("Text"):Connect(function()
                busquedaId = busquedaId + 1
                local idActual = busquedaId
                local texto = caja.Text
                if hiloBusqueda then pcall(task.cancel, hiloBusqueda) end
                hiloBusqueda = task.delay(Nub.Motion.Hover, function()
                    if idActual == busquedaId then
                        filtrarBusqueda(texto)
                    end
                end)
            end)
        end

        local function crearCajaBuscador()
            local caja = Instance.new("TextBox")
            caja.BackgroundColor3 = Theme.Entrada
            caja.PlaceholderText  = "🔍 Buscar..."
            caja.Text             = ""
            caja.TextColor3       = Theme.Text
            caja.Font             = Enum.Font.Gotham
            caja.TextSize         = 11
            caja.ClearTextOnFocus = false
            caja.BorderSizePixel  = 0
            Utils.Corner(caja, 5)
            Nub:Registrar(caja, "BackgroundColor3", "Entrada")
            Nub:Registrar(caja, "TextColor3", "Text")
            Utils.AnilloFoco(caja)
            conectarBuscador(caja)
            return caja
        end

        -- Buscador para modo VERTICAL (sidebar): sin cambios respecto
        -- al comportamiento original, arriba de la lista de pestañas.
        local buscadorBox = crearCajaBuscador()
        buscadorBox.Size        = UDim2.new(1, 0, 0, 22)
        buscadorBox.LayoutOrder = 0
        buscadorBox.Parent      = barraLat

        -- Buscador para modo HORIZONTAL: antes NO existia ninguno
        -- visible, porque esta caja era hija de barraLat y esa barra
        -- se oculta entera (barraLat.Visible = false) al cambiar a
        -- tabs horizontales. Este segundo buscador es hijo de 'main'
        -- directamente, asi que no depende de barraLat para mostrarse,
        -- y se ubica arriba a la derecha de la barra de pestañas.
        local buscadorBoxHoriz = crearCajaBuscador()
        buscadorBoxHoriz.Size     = UDim2.new(0, 150, 0, 26)
        buscadorBoxHoriz.Position = UDim2.new(1, -158, 0, 39)
        buscadorBoxHoriz.ZIndex   = 10
        buscadorBoxHoriz.Visible  = modoHorizontal
        buscadorBoxHoriz.Parent   = main

        Ventana._buscadorBoxHoriz = buscadorBoxHoriz
    end

    -- ── SELECTOR DE TEMAS ────────────────────────────────────────
    function Ventana:AgregarSelectorTemas()
        if self._btnSelectorTemas then return self._btnSelectorTemas end

        local nombres = {}
        for nombre in pairs(Nub.ThemeManager.Temas) do
            table.insert(nombres, nombre)
        end
        table.sort(nombres)
        if #nombres == 0 then return end

        local indice = 1
        local btn = Utils.BotonBase({
            Padre = barraLat,
            Size = UDim2.new(1, 0, 0, 26),
            Color = Theme.Fila, Transparencia = 0,
            Orden = 9999, Radio = 8,
        })
        Nub:Registrar(btn, "BackgroundColor3", "Fila")
        Utils.Hover(btn, btn)
        local lbl = Utils.Texto({
            Padre = btn, Texto = "🎨 " .. nombres[indice],
            Tamano = 11, Alineacion = Enum.TextXAlignment.Center,
        })

        btn.MouseButton1Click:Connect(function()
            indice = (indice % #nombres) + 1
            lbl.Text = "🎨 " .. nombres[indice]
            Nub.ThemeManager:AplicarTema(nombres[indice])
        end)

        -- Permite que TM:AplicarTema (llamado desde CUALQUIER lado: el
        -- Dropdown de la pestaña Preinstalada, un tema custom por codigo,
        -- etc.) sincronice este label y el indice interno.
        self._btnSelectorTemas = btn
        self._SincronizarSelectorTemas = function(nombreAplicado)
            lbl.Text = "🎨 " .. (nombreAplicado or "Personalizado")
            if nombreAplicado then
                for i, n in ipairs(nombres) do
                    if n == nombreAplicado then indice = i break end
                end
            end
        end
        _ventanasConSelectorTemas[self] = true
        return btn
    end

    -- ── DESTRUIR ─────────────────────────────────────────────────
    -- Destruye la GUI de forma programatica y limpia los
    -- registros internos, equivalente a presionar el boton de cerrar.
    function Ventana:Destruir()
        if sg and sg.Parent then
            sg:Destroy()
        end
        registroTema         = {}
        indiceBusqueda       = {}
        registroEscalaTexto  = {}
        Nub.Elementos     = nuevaTablaElementos() -- fix de auditoria: ver comentario en CrearVentana
        _keybindsRegistrados = {}
        seccionesRegistradas = {}
    end

    -- Ventana:EstablecerBorde(spec)  borde con color, degradado y animacion.
    --   Ventana:EstablecerBorde("tema")
    --   Ventana:EstablecerBorde({ Color = { "Accent", Color3.fromRGB(255, 80, 120) }, Animar = true })
    --   Ventana:EstablecerBorde(nil)   -- vuelve al borde de siempre
    function Ventana:EstablecerBorde(spec)
        manejadorBordeVentana.Actualizar(spec)
    end

    -- ── POSICION DE LA VENTANA (API) ────────────────────────────
    -- Ventana:ResetearPosicion()  vuelve al centro (o a 'PosicionInicial').
    -- Ventana:GuardarPosicion()   escribe la posicion actual YA (true/false).
    -- Ventana:CargarPosicion()    aplica la posicion guardada (true/false).
    function Ventana:ResetearPosicion()
        POSICION_ORIGINAL_VENTANA = POSICION_CENTRO
        Utils.Tween(main, {Position = POSICION_CENTRO}, Nub.Motion.Page,
            Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    end

    function Ventana:GuardarPosicion()
        return escribirPosicionAhora()
    end

    function Ventana:CargarPosicion()
        local datos = leerPosicionGuardada()
        if not datos then return false end
        local vp = viewportActual()
        POSICION_ORIGINAL_VENTANA = UDim2.new(
            POSICION_CENTRO.X.Scale, POSICION_CENTRO.X.Offset + math.floor(datos.ox * vp.X + 0.5),
            POSICION_CENTRO.Y.Scale, POSICION_CENTRO.Y.Offset + math.floor(datos.oy * vp.Y + 0.5)
        )
        Utils.Tween(main, {Position = POSICION_ORIGINAL_VENTANA}, Nub.Motion.Page,
            Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
        task.delay(Nub.Motion.Page + 0.1, function()
            local corregido = mantenerEnPantalla()
            if corregido then POSICION_ORIGINAL_VENTANA = corregido end
        end)
        return true
    end

    function Ventana:Minimizar()
        alternarVentana(false)
    end

    function Ventana:Mostrar()
        alternarVentana(true)
    end

    function Ventana:EstaVisible()
        return ventanaAbierta
    end

    function Ventana:Resetear()
        for flag, elem in pairs(Nub.Elementos) do
            if elem._defecto ~= nil and not _flagsUI[flag] and not _flagsNoPersistir[flag]
                and type(elem.Set) == "function" then
                pcall(elem.Set, copiarDefecto(elem._defecto), true)
            end
        end
    end

    -- ── CAMBIAR ORIENTACIÓN DE TABS ──────────────────────────────
    -- Cambia entre tabs laterales y tabs superiores en caliente.
    -- Ventana:CambiarOrientacion("horizontal")
    -- Ventana:CambiarOrientacion("vertical")
    local animandoOrientacion = false
    function Ventana:CambiarOrientacion(modo)
        local nuevoHorizontal = (modo == "horizontal")
        local hayCambio = nuevoHorizontal ~= modoHorizontal
        modoHorizontal = nuevoHorizontal
        barraLat.Visible   = not modoHorizontal
        barraHoriz.Visible = modoHorizontal
        if self._buscadorBoxHoriz then
            self._buscadorBoxHoriz.Visible = modoHorizontal
        end
        local pos, size = posContenedor()
        Utils.Tween(contenedorPaginas, {Position = pos, Size = size}, Nub.Motion.Page)
        -- (Antes aca se pintaba la pestana activa con Theme.Accent. Eso era un
        -- bug: contradecia el diseno -- el fondo del boton es neutro y la
        -- activa se marca con la barrita y el tinte --, y como seleccionar()
        -- nunca lo deshacia, la pestana quedaba "pegada" en acento al cambiar
        -- de pestana despues de alternar la orientacion.)

        -- Animacion: la barra que aparece se desliza desde su borde con
        -- fade (la lateral desde la izquierda, la superior desde arriba)
        -- mientras el contenido se reacomoda con el tween de arriba. Solo
        -- con la ventana ya visible, y no si hay otra animacion de
        -- orientacion en curso (FundirEntrada toma como objetivo el valor
        -- actual, y a mitad de animacion dejaria transparencias a medias).
        if hayCambio and ventanaRevelada and not animandoOrientacion then
            animandoOrientacion = true
            local barra = modoHorizontal and barraHoriz or barraLat
            local final = barra.Position
            local dx, dy = 0, 0
            if modoHorizontal then dy = -16 else dx = -24 end
            barra.Position = UDim2.new(final.X.Scale, final.X.Offset + dx, final.Y.Scale, final.Y.Offset + dy)
            Utils.Tween(barra, {Position = final}, Nub.Motion.Page, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
            Utils.FundirEntrada(barra, Nub.Motion.Page, false)
            if modoHorizontal and self._buscadorBoxHoriz then
                Utils.FundirEntrada(self._buscadorBoxHoriz, Nub.Motion.Page, true)
            end
            task.delay(Nub.Motion.Page + 0.05, function()
                if barra.Parent then barra.Position = final end
                animandoOrientacion = false
            end)
        end
    end

    -- 📑 CREAR TAB — agrega una pestaña nueva a la ventana.
    function Ventana:ConstruirDesdeSchema(schema)
        local resultado = {}
        if type(schema) ~= "table" or type(schema.Tabs) ~= "table" then
            Nub:_RegistrarError("ConstruirDesdeSchema", "se esperaba { Tabs = { { Nombre, Icono, Secciones = { { Nombre, Controles } } } } }")
            return resultado
        end
        for _, defTab in ipairs(schema.Tabs) do
            local tab = Ventana:CrearTab(defTab.Nombre or "Tab", defTab.Icono)
            for _, defSec in ipairs(defTab.Secciones or {}) do
                local opcionesSeccion
                if defSec.Colapsable ~= nil or defSec.ColapsadaPorDefecto ~= nil then
                    opcionesSeccion = { Colapsable = defSec.Colapsable, ColapsadaPorDefecto = defSec.ColapsadaPorDefecto }
                end
                local seccion = tab:CrearSeccion(defSec.Nombre or "Sección", opcionesSeccion)
                for flag, elemento in pairs(seccion:Construir(defSec.Controles or {})) do
                    if type(flag) == "string" then resultado[flag] = elemento end
                end
            end
        end
        return resultado
    end

    local tagsLista = {}
    local anchosTags = {}
    local COLORES_TAG = COLORES_SEMANTICOS -- los mismos colores que usan los bordes

    function Ventana:AgregarTag(cfg)
        if type(cfg) == "string" then cfg = { Texto = cfg } end
        if type(cfg) ~= "table" or cfg == Ventana then cfg = {} end
        if not contenedorTags then
            contenedorTags = Utils.Frame({
                Padre = barraTitulo, Size = UDim2.new(0.5, 0, 0, 18),
                Posicion = UDim2.new(1, xTags, 0, 17), Ancla = Vector2.new(1, 0.5),
                Transparencia = 1, Radio = false,
            })
            contenedorTags.ClipsDescendants = true
            lblTitulo.Size = UDim2.new(0.42, 0, 0, 18)
            lblSub.Size = UDim2.new(0.42, 0, 0, 13)
            local layoutTags = Instance.new("UIListLayout")
            layoutTags.FillDirection = Enum.FillDirection.Horizontal
            layoutTags.HorizontalAlignment = Enum.HorizontalAlignment.Right
            layoutTags.VerticalAlignment = Enum.VerticalAlignment.Center
            layoutTags.SortOrder = Enum.SortOrder.LayoutOrder
            layoutTags.Padding = UDim.new(0, 4)
            layoutTags.Parent = contenedorTags
        end

        local pastilla = Utils.Frame({
            Padre = contenedorTags, Size = UDim2.new(0, 0, 0, 16),
            Color = COLORES_TAG.info, Orden = #contenedorTags:GetChildren(), Radio = 8,
        })
        pastilla.AutomaticSize = Enum.AutomaticSize.X
        local relleno = Instance.new("UIPadding")
        relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)
        relleno.Parent = pastilla
        table.insert(tagsLista, pastilla)
        local escalaEntrada = Instance.new("UIScale")
        escalaEntrada.Name = "__Nub_EntradaScale"
        escalaEntrada.Scale = 0.6
        escalaEntrada.Parent = pastilla
        Utils.Tween(escalaEntrada, {Scale = 1}, Nub.Motion.Expand, Nub.Motion.EasePop, Enum.EasingDirection.Out)
        local function reLayoutTags()
            if not (contenedorTags and contenedorTags.Parent) then return end
            local disponible = contenedorTags.AbsoluteSize.X
            local usado = 0
            for i = #tagsLista, 1, -1 do
                local t = tagsLista[i]
                if t.Parent then
                    if t.Visible and t.AbsoluteSize.X > 0 then anchosTags[t] = t.AbsoluteSize.X end
                    local ancho = anchosTags[t] or 0
                    local necesario = ancho + (usado > 0 and 4 * Utils.FactorEscalaUI(contenedorTags) or 0)
                    local cabe = usado + necesario <= disponible + 0.5
                    t.Visible = cabe
                    if cabe then usado = usado + necesario end
                end
            end
        end
        local reLayoutTagsDiferido = Utils.Diferir(reLayoutTags)
        Nub:RegistrarConexion(pastilla:GetPropertyChangedSignal("AbsoluteSize"):Connect(reLayoutTagsDiferido))
        Nub:RegistrarConexion(contenedorTags:GetPropertyChangedSignal("AbsoluteSize"):Connect(reLayoutTagsDiferido))
        task.defer(reLayoutTags)
        local lblTag = Utils.Texto({
            Padre = pastilla,
            Texto = ((cfg.Icono and (tostring(cfg.Icono) .. " ")) or "") .. tostring(cfg.Texto or "TAG"),
            Size = UDim2.new(0, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
            Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.GothamBold,
            Tamano = 10, Color = Color3.fromRGB(255, 255, 255), Categoria = "titulo",
        })
        lblTag.AutomaticSize = Enum.AutomaticSize.X

        local gradiente, tween
        local function limpiarColor()
            if tween then tween:Cancel(); tween = nil end
            if gradiente then gradiente:Destroy(); gradiente = nil end
            lblTag.TextStrokeTransparency = 1
        end
        local function animarGradiente()
            tween = TweenService:Create(gradiente,
                TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
                {Rotation = 360})
            tween:Play()
        end
        local function aplicarColor(color, animar)
            limpiarColor()
            if color == "rainbow" then
                pastilla.BackgroundColor3 = Color3.new(1, 1, 1)
                gradiente = Instance.new("UIGradient")
                gradiente.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 70, 70)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(240, 150, 50)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(235, 210, 60)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 200, 110)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(70, 150, 235)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(160, 90, 220)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 70, 70)),
                })
                gradiente.Parent = pastilla
                lblTag.TextStrokeTransparency = 0.45
                if animar ~= false then animarGradiente() end
                return
            end
            if type(color) == "table" and #color >= 2 then
                local valida = true
                for _, c in ipairs(color) do
                    if typeof(c) ~= "Color3" then valida = false end
                end
                if valida then
                    local puntos = {}
                    for i, c in ipairs(color) do
                        table.insert(puntos, ColorSequenceKeypoint.new((i - 1) / (#color - 1), c))
                    end
                    pastilla.BackgroundColor3 = Color3.new(1, 1, 1)
                    gradiente = Instance.new("UIGradient")
                    gradiente.Color = ColorSequence.new(puntos)
                    gradiente.Parent = pastilla
                    if animar == true then animarGradiente() end
                    return
                end
            end
            if type(color) == "string" then color = COLORES_TAG[color] or COLORES_TAG.info end
            if typeof(color) ~= "Color3" then color = COLORES_TAG.info end
            pastilla.BackgroundColor3 = color
        end
        aplicarColor(cfg.Color, cfg.Animar)
        pastilla.Destroying:Connect(function()
            if tween then tween:Cancel() end
        end)

        if type(cfg.Callback) == "function" then
            local botonTag = Utils.BotonBase({
                Padre = pastilla, Size = UDim2.new(1, 0, 1, 0),
                Color = Color3.new(1, 1, 1), Transparencia = 1, Radio = 8,
            })
            botonTag.ZIndex = lblTag.ZIndex + 1
            Utils.ClickConfiable(botonTag, function()
                ejecutarConFallback(cfg.Callback, "Tag " .. tostring(cfg.Texto or ""))
            end)
        end

        local retorno = { Instancia = pastilla }
        local function sinSelf(a, b, c)
            if a == retorno then return b, c end
            return a, b
        end
        retorno.SetTexto = function(a, b)
            local texto = sinSelf(a, b)
            lblTag.Text = ((cfg.Icono and (tostring(cfg.Icono) .. " ")) or "") .. tostring(texto)
        end
        retorno.SetColor = function(a, b, c)
            local color, animar = sinSelf(a, b, c)
            aplicarColor(color, animar)
        end
        retorno.Remover = function()
            limpiarColor()
            for i, t in ipairs(tagsLista) do
                if t == pastilla then table.remove(tagsLista, i) break end
            end
            anchosTags[pastilla] = nil
            if pastilla.Parent then pastilla:Destroy() end
            task.defer(reLayoutTags)
        end
        return retorno
    end

    function Ventana:AgregarDivisorSidebar(cfg)
        if type(cfg) ~= "table" or cfg == Ventana then cfg = {} end
        ordenTab = ordenTab + 1
        local alto = cfg.Texto and 22 or 9
        local marcoLat = Utils.Frame({
            Padre = barraLat, Size = UDim2.new(1, 0, 0, alto),
            Transparencia = 1, Orden = ordenTab, Radio = false,
        })
        if cfg.Texto then
            Utils.Texto({
                Padre = marcoLat, Texto = tostring(cfg.Texto),
                Size = UDim2.new(1, -8, 1, -4), Posicion = UDim2.new(0, 4, 0, 0),
                Fuente = Enum.Font.GothamBold, Tamano = 10, ColorTema = "TextDark",
                Categoria = "tabs", Truncar = true, TextoTransparencia = 0.2,
            })
        end
        local lineaLat = Utils.Frame({
            Padre = marcoLat, Size = UDim2.new(1, -8, 0, 1),
            Posicion = UDim2.new(0, 4, 1, -2), Color = Theme.Border,
            Transparencia = 0.4, Radio = false,
        })
        Nub:Registrar(lineaLat, "BackgroundColor3", "Border")

        local marcoHoriz = Utils.Frame({
            Padre = barraHoriz, Size = UDim2.new(0, 9, 0, 28),
            Transparencia = 1, Orden = ordenTab, Radio = false,
        })
        local lineaHoriz = Utils.Frame({
            Padre = marcoHoriz, Size = UDim2.new(0, 1, 0, 18),
            Posicion = UDim2.new(0, 4, 0.5, -9), Color = Theme.Border,
            Transparencia = 0.4, Radio = false,
        })
        Nub:Registrar(lineaHoriz, "BackgroundColor3", "Border")
        if ventanaRevelada then
            Utils.AnimarInsercion(marcoLat, "y")
            Utils.AnimarInsercion(marcoHoriz, "x")
        end
        return { InstanciaLat = marcoLat, InstanciaHoriz = marcoHoriz }
    end

    function Ventana:CrearTab(nombre, icono)
        nombre = nombre or "Tab"
        local colorIcono
        if type(icono) == "table" then
            colorIcono = icono.ColorIcono
            icono = icono.Icono
        end
        if type(icono) == "number" then icono = "rbxassetid://" .. tostring(math.floor(icono)) end
        icono = icono or "▪"
        local esImagen = type(icono) == "string" and icono:match("^rbxassetid://") ~= nil

        for _, tExistente in ipairs(self.Tabs) do
            if tExistente.Nombre == nombre then
                pcall(function()
                    Nub:Notificar({
                        Titulo = "⚠️ Pestaña duplicada",
                        Texto  = "Ya existe una pestaña llamada '" .. nombre .. "'. Se omitió la duplicada.",
                        Duracion = 4,
                    })
                end)
                return tExistente
            end
        end

        ordenTab = ordenTab + 1

        local nombreMostrado = nombre
        if icono ~= "" and not esImagen then
            local prefijoConEspacio = icono .. " "
            if nombre:sub(1, #prefijoConEspacio) == prefijoConEspacio then
                nombreMostrado = nombre:sub(#prefijoConEspacio + 1)
            elseif nombre:sub(1, #icono) == icono then
                nombreMostrado = nombre:sub(#icono + 1):gsub("^%s+", "")
            end
        end

        -- Botón lateral (barra vertical)
        local botonLat = Utils.BotonBase({
            Padre = barraLat,
            Size = UDim2.new(1, 0, 0, 30),
            Color = Theme.Fila, Transparencia = 0,
            Orden = ordenTab, Radio = 8,
        })
        -- Hitbox ampliado (30px visual -> 44px efectivo). Hijo de
        -- 'botonLat', no hermano dentro de 'barraLat' (que tiene su
        -- propio UIListLayout vertical de tabs, con solo 4px de gap
        -- entre tabs -- por eso el padding acá es mas conservador que
        -- en un control aislado como Toggle/Casilla: con 4px de gap,
        -- un padding de 7 ya genera ~10px de solape entre el hitbox de
        -- un tab y el del vecino. A vigilar en el retest.
        local hitboxTabLat = Utils.HitboxAmpliado(botonLat, 7)
        Utils.Hover(hitboxTabLat, botonLat)
        -- Registrado contra el tema para que el fondo se actualice al
        -- cambiar de tema.
        Nub:Registrar(botonLat, "BackgroundColor3", "Fila")

        -- La pestana activa se marca con la barrita lateral (accent = "esto
        -- esta activo") y con un tinte de acento MUY suave sobre el fondo. El
        -- fondo del boton en si sigue siendo neutro. Solo en la barra lateral:
        -- el boton horizontal tiene UIPadding y AutomaticSize.X, y un hijo de
        -- tamano relativo ahi se mediria mal; en horizontal manda la linea.
        local tinteLat = Utils.Frame({
            Padre = botonLat, Size = UDim2.new(1, 0, 1, 0),
            Color = Theme.Accent, Radio = 8,
        })
        tinteLat.BackgroundTransparency = 1
        Nub:Registrar(tinteLat, "BackgroundColor3", "Accent")

        local indicadorLat = Utils.Frame({
            Padre = botonLat, Size = UDim2.new(0, 3, 1, -8),
            Posicion = UDim2.new(0, 0, 0, 4),
            Color = Theme.Accent, Radio = 2,
        })
        indicadorLat.BackgroundTransparency = 1
        Nub:Registrar(indicadorLat, "BackgroundColor3", "Accent")

        local iconoLat = Utils.Texto({
            Padre = botonLat, Texto = esImagen and "" or icono,
            Size = UDim2.new(0, 26, 1, 0), Posicion = UDim2.new(0, 4, 0, 0), Tamano = 13,
            Alineacion = Enum.TextXAlignment.Center, Truncar = true,
            Categoria = "tabs", Color = colorIcono,
        })
        if esImagen then
            Utils.IconoImagen(botonLat, icono, colorIcono, 16, UDim2.new(0, 17, 0.5, 0))
        end
        local lblLat = Utils.Texto({
            Padre = botonLat, Texto = nombreMostrado,
            Size = UDim2.new(1, -36, 1, 0), Posicion = UDim2.new(0, 34, 0, 0),
            Fuente = Enum.Font.GothamMedium, Tamano = 12,
            Categoria = "tabs", Truncar = true,
        })

        -- Botón horizontal (barra superior)
        local botonHoriz = Utils.BotonBase({
            Padre = barraHoriz,
            Size = UDim2.new(0, 100, 0, 28),
            Color = Theme.Fila, Transparencia = 0,
            Orden = ordenTab, Radio = 8,
        })
        -- Mismo hitbox ampliado que botonLat (ver comentario ahi) -- la
        -- barra horizontal tiene el mismo gap chico (4px) entre tabs.
        local hitboxTabHoriz = Utils.HitboxAmpliado(botonHoriz, 7)
        Utils.Hover(hitboxTabHoriz, botonHoriz)
        -- Mismo fix que botonLat: registrar contra el tema para que
        -- el fondo se actualice al cambiar de tema, no solo al crear
        -- el tab.
        Nub:Registrar(botonHoriz, "BackgroundColor3", "Fila")
        local padH = Instance.new("UIPadding")
        padH.PaddingLeft  = UDim.new(0, 8)
        padH.PaddingRight = UDim.new(0, 8)
        padH.Parent = botonHoriz
        botonHoriz.AutomaticSize = Enum.AutomaticSize.X

        -- Mismo concepto que el indicador lateral, pero como una
        -- linea abajo (mas natural para tabs horizontales).
        local indicadorHoriz = Utils.Frame({
            Padre = botonHoriz, Size = UDim2.new(1, -8, 0, 2),
            Posicion = UDim2.new(0, 4, 1, -3),
            Color = Theme.Accent, Radio = 1,
        })
        indicadorHoriz.BackgroundTransparency = 1
        Nub:Registrar(indicadorHoriz, "BackgroundColor3", "Accent")

        -- Icono y texto como labels separados (igual que ya hacia el
        -- boton lateral): en vez de un solo texto "icono + nombre"
        -- concatenado, el icono queda en un ancho fijo y el texto
        -- trunca de forma independiente si no entra, en vez de
        -- desbordar o achicarse junto con el icono en pantallas
        -- angostas (movil).
        local lblHoriz
        if icono ~= "" then
            local iconoHoriz = Utils.Texto({
                Padre = botonHoriz, Texto = esImagen and "" or icono,
                Size = UDim2.new(0, 18, 1, 0), Posicion = UDim2.new(0, 8, 0, 0),
                Alineacion = Enum.TextXAlignment.Center, Tamano = 12,
                Categoria = "tabs", Color = colorIcono,
            })
            if esImagen then
                Utils.IconoImagen(botonHoriz, icono, colorIcono, 14, UDim2.new(0, 17, 0.5, 0))
            end
            lblHoriz = Utils.Texto({
                Padre = botonHoriz, Texto = nombreMostrado,
                Size = UDim2.new(1, -30, 1, 0), Posicion = UDim2.new(0, 26, 0, 0),
                Alineacion = Enum.TextXAlignment.Left, Truncar = true,
                Fuente = Enum.Font.GothamMedium, Tamano = 11,
                Categoria = "tabs",
            })
        else
            lblHoriz = Utils.Texto({
                Padre = botonHoriz,
                Texto = nombreMostrado,
                Alineacion = Enum.TextXAlignment.Center,
                Fuente = Enum.Font.GothamMedium, Tamano = 11,
                Categoria = "tabs",
            })
        end
        -- alias para compatibilidad con codigo anterior que use t.Boton
        local botonTab = botonLat

        local pagina = Instance.new("ScrollingFrame")
        pagina.Size                 = UDim2.new(1, 0, 1, 0)
        pagina.BackgroundTransparency = 1
        pagina.BorderSizePixel      = 0
        pagina.ScrollBarThickness   = 4
        pagina.ScrollBarImageColor3 = Theme.Accent
        pagina.CanvasSize           = UDim2.new(0, 0, 0, 0)
        pagina.AutomaticCanvasSize  = Enum.AutomaticSize.Y
        pagina.Visible              = primeraTab
        pagina.Parent               = contenedorPaginas

        local layoutPagina = Instance.new("UIListLayout")
        layoutPagina.Padding   = UDim.new(0, 22)
        layoutPagina.SortOrder = Enum.SortOrder.LayoutOrder
        layoutPagina.Parent    = pagina

        local padPagina = Instance.new("UIPadding")
        padPagina.PaddingTop,    padPagina.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
        padPagina.PaddingLeft,   padPagina.PaddingRight  = UDim.new(0, 12), UDim.new(0, 12)
        padPagina.Parent = pagina

        if primeraTab then
            indicadorLat.BackgroundTransparency   = 0
            indicadorHoriz.BackgroundTransparency = 0
            tinteLat.BackgroundTransparency       = TINTE_TAB_ACTIVA
        end
        primeraTab = false

        local function seleccionar()
            for _, t in ipairs(Ventana.Tabs) do
                t.Pagina.Visible = false
                Utils.Tween(t.IndicadorLat,   {BackgroundTransparency = 1}, Nub.Motion.Hover)
                Utils.Tween(t.IndicadorHoriz, {BackgroundTransparency = 1}, Nub.Motion.Hover)
                Utils.Tween(t.TinteLat,       {BackgroundTransparency = 1}, Nub.Motion.Hover)
            end
            pagina.Position = UDim2.new(0, 0, 0, 14)
            pagina.Visible = true
            Utils.Tween(pagina, {Position = UDim2.new(0, 0, 0, 0)}, Nub.Motion.Page, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            Utils.Tween(indicadorLat,   {BackgroundTransparency = 0}, Nub.Motion.Hover)
            Utils.Tween(indicadorHoriz, {BackgroundTransparency = 0}, Nub.Motion.Hover)
            Utils.Tween(tinteLat,       {BackgroundTransparency = TINTE_TAB_ACTIVA}, Nub.Motion.Hover)
            Nub.Eventos.TabCambiada:Fire(nombre)
        end
        Utils.ClickConfiable(hitboxTabLat, seleccionar, botonLat)
        Utils.ClickConfiable(hitboxTabHoriz, seleccionar, botonHoriz)

        -- BotonLat = lateral, BotonHoriz = horizontal, Boton = alias lateral
        local Tab = {
            Nombre     = nombre,
            Boton      = botonLat,
            BotonLat   = botonLat,
            BotonHoriz = botonHoriz,
            IndicadorLat   = indicadorLat,
            IndicadorHoriz = indicadorHoriz,
            TinteLat       = tinteLat,
            Pagina     = pagina,
            Seleccionar = seleccionar,
            Secciones  = {},
        }
        table.insert(Ventana.Tabs, Tab)

        local ordenSeccion = 0

        -- 📦 CREAR SECCIÓN — agrupa controles relacionados dentro de una pestaña.
        -- Segundo parámetro opcional 'cfg':
        --   Colapsable = false          -> desactiva el colapso (header solo texto, como antes).
        --   ColapsadaPorDefecto = true  -> arranca colapsada (solo tiene efecto si Colapsable ~= false).
        -- El estado colapsado NO persiste entre sesiones: es un ajuste
        -- visual efímero, no se guarda en el .json.
        function Tab:CrearDivisor(cfg)
            cfg = cfg or {}
            ordenSeccion = ordenSeccion + 1
            local marcoDivisor = Utils.Frame({
                Padre = pagina, Size = UDim2.new(1, 0, 0, cfg.Texto and 28 or 10),
                Transparencia = 1, Orden = ordenSeccion, Radio = false,
            })
            if cfg.Texto then
                Utils.Texto({
                    Padre = marcoDivisor, Texto = tostring(cfg.Texto),
                    Size = UDim2.new(1, -24, 1, -6), Posicion = UDim2.new(0, 12, 0, 0),
                    Fuente = Enum.Font.GothamBold, Tamano = 12, ColorTema = "TextDark",
                })
            end
            local linea = Utils.Frame({
                Padre = marcoDivisor, Size = UDim2.new(1, -24, 0, 1),
                Posicion = UDim2.new(0, 12, 1, -2), Color = Theme.Border,
                Transparencia = 0.4, Radio = false,
            })
            Nub:Registrar(linea, "BackgroundColor3", "Border")
            if ventanaRevelada then Utils.AnimarInsercion(marcoDivisor, "y") end
            return { Instancia = marcoDivisor }
        end

        function Tab:CrearSeccion(nombreSeccion, cfg)
            cfg = cfg or {}
            ordenSeccion = ordenSeccion + 1
            local colapsable = cfg.Colapsable ~= false
            local colapsadaPorDefecto = colapsable and (cfg.ColapsadaPorDefecto == true)
            -- Mismo alto que el header actual (label 22px + 4px de margen),
            -- para que las secciones colapsables y no colapsables midan
            -- exactamente lo mismo de alto cuando estan expandidas.
            local ALTO_HEADER = 26

            local marco = Utils.Frame({
                Padre = pagina,
                Size = UDim2.new(1, 0, 0, 0),
                Color = Theme.Panel, Orden = ordenSeccion, Radio = 8,
                Borde = true, ColorBorde = Theme.Border, TransparenciaBorde = 0.5,
                ClaveTemaBorde = "Border",
            })
            marco.AutomaticSize = Enum.AutomaticSize.Y
            Nub:Registrar(marco, "BackgroundColor3", "Panel")

            -- Header: boton transparente full-width con flecha + titulo
            -- si es colapsable; TextLabel suelto si no lo es (comportamiento
            -- identico al actual).
            local lblSeccion
            local flecha = nil
            local btnHeader = nil

            if colapsable then
                btnHeader = Utils.BotonBase({
                    Padre = marco,
                    Size = UDim2.new(1, 0, 0, ALTO_HEADER),
                    Posicion = UDim2.new(0, 0, 0, 0),
                    Transparencia = 1, Radio = false,
                })
                -- Hover sobre el header entero (no solo la flecha): asi
                -- se siente igual de interactivo que cualquier otro
                -- control clickeable de la libreria (fila, boton,
                -- RadioGroup...), en vez de ser el unico lugar de toda
                -- la interfaz donde una flechita sola tiene que
                -- comunicar sin ayuda "esto se puede tocar". El color
                -- base del header nunca cambia de estado por si solo
                -- (a diferencia de un RadioGroup), asi que
                -- obtenerColorBase esta fijo en Theme.Panel -- solo
                -- hace falta para que el hover no pise el color real
                -- si el tema cambia mientras el cursor esta encima.
                Utils.Hover(btnHeader, marco, nil, nil, function() return Theme.Panel end)

                -- Icono propio en vez de texto "▶"/"▼": un solo asset
                -- (chevron apuntando abajo) rotado -90° para el estado
                -- colapsado, en vez de dos glifos de texto distintos --
                -- mismo motivo que el resto de los reemplazos (el glifo
                -- no renderizaba en todos los dispositivos).
                flecha = Instance.new("ImageLabel")
                flecha.BackgroundTransparency = 1
                flecha.Image = "rbxassetid://83472139709682"
                flecha.ImageColor3 = Theme.AccentLight
                flecha.ScaleType = Enum.ScaleType.Fit
                flecha.Size = UDim2.new(0, 14, 0, 14)
                flecha.AnchorPoint = Vector2.new(0.5, 0.5)
                flecha.Position = UDim2.new(0, 13, 0.5, 0)
                flecha.Rotation = colapsadaPorDefecto and -90 or 0
                flecha.Parent = btnHeader
                Nub:Registrar(flecha, "ImageColor3", "AccentLight")

                lblSeccion = Utils.Texto({
                    Padre = btnHeader, Texto = nombreSeccion or "Sección",
                    Size = UDim2.new(1, -28, 0, ALTO_HEADER),
                    Posicion = UDim2.new(0, 24, 0, 0),
                    Fuente = Enum.Font.GothamBold, Tamano = 12,
                    Color = Theme.AccentLight,
                })
                Nub:Registrar(lblSeccion, "TextColor3", "AccentLight")
            else
                lblSeccion = Utils.Texto({
                    Padre = marco, Texto = nombreSeccion or "Sección",
                    Size = UDim2.new(1, -14, 0, 22), Posicion = UDim2.new(0, 10, 0, 4),
                    Fuente = Enum.Font.GothamBold, Tamano = 12, Color = Theme.AccentLight,
                })
                Nub:Registrar(lblSeccion, "TextColor3", "AccentLight")
            end

            local contenedor = Utils.Frame({
                Padre = marco,
                Size = UDim2.new(1, 0, 0, 0), Posicion = UDim2.new(0, 0, 0, ALTO_HEADER),
                Transparencia = 1, Radio = false,
            })
            contenedor.AutomaticSize = Enum.AutomaticSize.Y
            contenedor.Visible = not colapsadaPorDefecto

            -- Pop de entrada con UIScale (reemplaza al fade via CanvasGroup,
            -- que en Android era demasiado caro por el compositing offscreen
            -- que exige animar GroupTransparency cada frame). UIScale es un
            -- transform puro -- cero costo extra de render.
            local escalaContenedor = Instance.new("UIScale")
            escalaContenedor.Scale = 1
            escalaContenedor.Parent = contenedor

            local layoutC = Instance.new("UIListLayout")
            layoutC.Padding   = UDim.new(0, 12)
            layoutC.SortOrder = Enum.SortOrder.LayoutOrder
            layoutC.Parent    = contenedor

            local padC = Instance.new("UIPadding")
            padC.PaddingLeft,  padC.PaddingRight  = UDim.new(0, 10), UDim.new(0, 10)
            padC.PaddingTop    = UDim.new(0, 10)
            padC.PaddingBottom = UDim.new(0, 12)
            padC.Parent = contenedor

            -- Entrada del registro global de secciones. Se guarda con
            -- referencia directa a marco/contenedor/flecha, mas metodos
            -- para cambiar el estado -- filtrarBusqueda la usa para
            -- forzar expansion durante busqueda activa y para restaurar.
            local entradaSeccion = {
                marco = marco,
                contenedor = contenedor,
                flecha = flecha,
                colapsable = colapsable,
                colapsada = colapsadaPorDefecto,
                colapsadaAntesDeBuscar = nil,
                nombre = nombreSeccion,
            }

            local function aplicarColapsada(v, animar)
                entradaSeccion.colapsada = v
                if entradaSeccion.flecha then
                    local rotObjetivo = v and -90 or 0
                    if animar then
                        Utils.Tween(entradaSeccion.flecha, {Rotation = rotObjetivo}, Nub.Motion.Expand)
                    else
                        entradaSeccion.flecha.Rotation = rotObjetivo
                    end
                end

                local cont = entradaSeccion.contenedor
                if not animar then
                    -- Instantaneo: lo que usa filtrarBusqueda al forzar
                    -- expansion/restauracion durante una busqueda. Con
                    -- muchas secciones a la vez, animar cada una se
                    -- sentiria lento y caotico -- ahi se prioriza que
                    -- el resultado de la busqueda aparezca ya.
                    cont.Visible = not v
                    return
                end

                -- Animado: lo que dispara el click en el header. El
                -- truco es apagar AutomaticSize SOLO durante la
                -- animacion (para poder animar Size.Y a mano) y
                -- reactivarlo al terminar, para que 'marco' (que tiene
                -- su propio AutomaticSize.Y siguiendo a 'cont') se vea
                -- encoger/crecer en sincro sin pelear contra el motor
                -- de layout el resto del tiempo.
                local DURACION = Nub.Motion.Expand
                if v then
                    -- Colapsar: animar desde el alto actual hasta 0, y
                    -- recien ahi ocultar (si para entonces sigue
                    -- colapsada -- por si el usuario la reabrio a mitad
                    -- de la animacion).
                    -- Reset inmediato (sin tween) de la escala ANTES de
                    -- medir el alto: si el usuario colapsa a mitad de la
                    -- animacion de apertura (ver rama expandir), Scale
                    -- puede estar en un valor intermedio (ej. 0.95) y
                    -- AbsoluteSize.Y reportaria un alto ligeramente
                    -- afectado por esa escala parcial, no el real.
                    if escalaContenedor.Scale ~= 1 then
                        escalaContenedor.Scale = 1
                    end
                    local altoActual = cont.AbsoluteSize.Y
                    cont.ClipsDescendants = true
                    cont.AutomaticSize = Enum.AutomaticSize.None
                    cont.Size = UDim2.new(1, 0, 0, altoActual)
                    Utils.Tween(cont, {Size = UDim2.new(1, 0, 0, 0)}, DURACION, Nub.Motion.EaseSalir, Enum.EasingDirection.In)
                    task.delay(DURACION, function()
                        if entradaSeccion.colapsada then
                            cont.Visible = false
                        end
                    end)
                else
                    -- Expandir: medir el alto real PRIMERO, con 'cont'
                    -- todavia invisible (Roblox calcula AbsoluteSize
                    -- igual sin necesidad de que se vea, asi que no hay
                    -- flash de contenido a tamaño completo antes de
                    -- animar). Recien con el alto objetivo en mano se
                    -- fija Size=0, se muestra, y se anima hacia arriba.
                    cont.AutomaticSize = Enum.AutomaticSize.Y
                    task.defer(function()
                        if entradaSeccion.colapsada then return end -- se volvio a colapsar mientras esperabamos el frame
                        local altoObjetivo = cont.AbsoluteSize.Y
                        cont.AutomaticSize = Enum.AutomaticSize.None
                        cont.Size = UDim2.new(1, 0, 0, 0)
                        cont.ClipsDescendants = true
                        cont.Visible = true
                        -- Pop de escala en vez de fade: arranca al 92% y
                        -- sube a 100% junto con el crecimiento de altura.
                        -- Sensacion similar al fade, pero sin compositing
                        -- offscreen (por eso no traba en Android).
                        escalaContenedor.Scale = 0.92
                        Utils.Tween(escalaContenedor, {Scale = 1}, DURACION, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
                        Utils.Tween(cont, {Size = UDim2.new(1, 0, 0, altoObjetivo)}, DURACION, Nub.Motion.EaseEntrar, Enum.EasingDirection.Out)
                        task.delay(DURACION, function()
                            if not entradaSeccion.colapsada then
                                cont.AutomaticSize = Enum.AutomaticSize.Y
                                cont.ClipsDescendants = false
                            end
                        end)
                    end)
                end
            end
            entradaSeccion.AplicarColapsada = aplicarColapsada

            if colapsable and btnHeader then
                Utils.ClickConfiable(btnHeader, function()
                    aplicarColapsada(not entradaSeccion.colapsada, true)
                end)
            end

            table.insert(Tab.Secciones, {marco = marco, contenedor = contenedor})
            table.insert(seccionesRegistradas, entradaSeccion)

            local Seccion = {}
            local orden   = 0
            local function siguienteOrden() orden = orden + 1; return orden end

            -- Helper: fila con label a la izquierda
            local function crearCabecera(alto, texto, anchoLabel, offsetX, modo)
                local fila = Utils.Fila(contenedor, alto, siguienteOrden(), Theme.Fila)
                Nub:Registrar(fila, "BackgroundColor3", "Fila")
                Utils.Hover(fila, fila)
                if modo ~= "fijo" then
                    local lblD = Utils.Texto({Padre = fila, Texto = texto,
                        Size = UDim2.new(anchoLabel or 1, offsetX or -50, 1, 0),
                        Tamano = 12, Ajustar = true})
                    if modo ~= "manual" then Utils.HacerFilaDinamica(fila, lblD, alto, 7) end
                    return fila, lblD
                end
                -- Truncar = true (en vez de asignar .TextTruncate aca
                -- afuera) activa el ajuste automatico de ancho de
                -- Utils.Texto -- el texto se achica lo necesario para
                -- entrar completo antes de recurrir al corte con "...".
                local lbl = Utils.Texto({Padre = fila, Texto = texto, Size = UDim2.new(anchoLabel or 1, offsetX or -50, 1, 0), Tamano = 12, Truncar = true})
                return fila, lbl
            end

            -- Helper interno compartido por Toggle y Casilla (auditoria,
            -- Propuesta 4: "REFACCIONAR CONTROLES BASE"). Antes esta
            -- logica -- Flag, registro en Elementos, bind de Tecla,
            -- disparo de Callback, Set/Get -- estaba duplicada palabra
            -- por palabra en los dos controles. La unica diferencia real
            -- entre Toggle y Casilla es el DIBUJO (perilla+circulo vs
            -- caja+check), asi que eso es lo unico que queda afuera,
            -- en la funcion 'crearVisual' que recibe cada uno.
            --
            -- 'crearVisual(fila, obtenerValor)' debe devolver:
            --   clicable          -> instancia con MouseButton1Click (lo que se toca para alternar)
            --   actualizarVisual(v) -> anima el dibujo especifico a un valor dado
            -- 'obtenerValor()' existe para que 'crearVisual' pueda leer
            -- el valor VIGENTE (no solo el inicial) desde closures de
            -- tema (Nub:Registrar) que se re-evaluan mas adelante,
            -- exactamente igual a como funcionaba antes con el upvalue
            -- 'valor' directo.
            local function crearControlBooleano(tipoNombre, cfg, crearVisual)
                cfg = cfg or {}
                validarCallback(tipoNombre, cfg)
                local flag  = cfg.Flag or cfg.Texto or (tipoNombre .. "_" .. tostring(math.random(1e5, 1e6)))
                local valor = cfg.Defecto or false
                Nub.Flags[flag] = valor

                local fila, lbl = crearCabecera(32, cfg.Texto or tipoNombre)
                agregarTooltipTexto(fila, cfg.Texto or tipoNombre, cfg.Tooltip, lbl)
                registrarBuscable(fila, cfg.Texto or tipoNombre, cfg.VisibleSi)

                local function obtenerValor() return valor end
                local visual = crearVisual(fila, obtenerValor)

                local function actualizar(v, disparar)
                    if type(v) ~= "boolean" then
                        Nub:_RegistrarError(tipoNombre .. ".Set (valor no booleano)",
                            "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                            " en vez de boolean. Se ignoró.")
                        return
                    end
                    valor = v
                    Nub.Flags[flag] = v
                    visual.actualizarVisual(v)

                    aplicarDesactivarSiCorresponde(cfg, v)

                    if disparar and cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "control", v)
                    end
                end
                -- Hitbox ampliado: el toque responde en un area 10px mas
                -- grande por lado que el visual (22px -> 42px efectivo),
                -- sin cambiar el tamaño ni la posicion de la perilla/caja
                -- que se ve en pantalla. Ver Utils.HitboxAmpliado. Este
                -- control esta aislado (no tiene otro control pegado al
                -- lado en la misma fila), asi que se puede subir el
                -- padding sin generar riesgo de solape con un vecino.
                local hitboxBooleano = Utils.HitboxAmpliado(visual.clicable, 10)
                Utils.ClickConfiable(hitboxBooleano, function() actualizar(not valor, true) end, visual.clicable)

                if cfg.Tecla then
                    Nub:RegistrarConexion(
                        UserInputService.InputBegan:Connect(function(input, procesado)
                            if procesado then return end
                            if input.KeyCode == cfg.Tecla then actualizar(not valor, true) end
                        end)
                    )
                end

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        actualizar(v, dispararCallback or false)
                    end,
                    Get = function() return valor end,
                }
                if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor) end
                return {
                    Set = function(...) actualizar(normalizarArgSet(...), true) end,
                    Get = function() return valor end,
                }
            end

            -- 🔘 BOTON — ejecuta un Callback al presionarlo (Async = true muestra un spinner mientras corre).
            function Seccion:Boton(cfg)
                cfg = cfg or {}
                validarCallback("Botón", cfg)
                -- A diferencia de Toggle/Casilla (que pueden usarse solo
                -- para guardar un flag sin Callback), un Boton SIN
                -- Callback no tiene ninguna utilidad -- no persiste
                -- estado para leer despues. Aca si vale la pena avisar
                -- aunque el Callback este simplemente ausente.
                if cfg.Callback == nil then
                    advertirDev("Botón", cfg.Texto, "no tiene 'Callback'. Este botón no hará nada al presionarlo.")
                end
                local fila = Utils.BotonBase({
                    Padre = contenedor,
                    Size = UDim2.new(1, 0, 0, 32),
                    Color = Theme.Fila, Transparencia = 0,
                    Orden = siguienteOrden(), Radio = 8,
                })
                Nub:Registrar(fila, "BackgroundColor3", "Fila")
                Utils.Hover(fila, fila)
                -- Icono opcional (emoji o caracter unicode): se
                -- antepone al texto del mismo label, igual que ya
                -- hace CrearTab con su parametro 'icono' -- no agrega
                -- una segunda instancia de texto, solo concatena.
                local textoConIcono = cfg.Texto or "Botón"
                if cfg.Icono and cfg.Icono ~= "" then
                    textoConIcono = cfg.Icono .. " " .. textoConIcono
                end
                local lblBoton = Utils.Texto({Padre = fila, Texto = textoConIcono, RichText = cfg.RichText})
                local lblInteract
                if cfg.Interact ~= nil then
                    local margenDer = cfg.Async and 36 or 10
                    lblBoton.Size = UDim2.new(0.6, -12, 1, 0)
                    lblInteract = Utils.Texto({
                        Padre = fila, Texto = tostring(cfg.Interact),
                        Size = UDim2.new(0.4, -margenDer, 1, 0), Posicion = UDim2.new(0.6, 0, 0, 0),
                        Alineacion = Enum.TextXAlignment.Right, Tamano = 12,
                        Color = Theme.AccentLight, ColorTema = "AccentLight", Truncar = true,
                    })
                end
                agregarTooltipTexto(fila, cfg.Texto or "Botón", cfg.Tooltip, lblBoton)
                registrarBuscable(fila, cfg.Texto or "Botón", cfg.VisibleSi)

                -- Spinner opcional (solo se crea si Async = true alguna vez
                -- se activa), un pequeño caracter giratorio a la derecha.
                local spinner, hiloGiro
                local function activarSpinner(activo)
                    if activo and not spinner then
                        spinner = Utils.Texto({
                            Padre = fila, Texto = "◐",
                            Size = UDim2.new(0, 20, 1, 0),
                            Posicion = UDim2.new(1, -28, 0, 0),
                            Alineacion = Enum.TextXAlignment.Center,
                            Tamano = 14, Color = Theme.AccentLight,
                        })
                        Nub:Registrar(spinner, "TextColor3", "AccentLight")
                    end
                    if not spinner then return end
                    spinner.Visible = activo
                    if activo then
                        hiloGiro = Nub:RegistrarHilo(task.spawn(function()
                            while spinner and spinner.Visible do
                                Utils.Tween(spinner, {Rotation = spinner.Rotation + 360}, Nub.Motion.Spin, Nub.Motion.EaseLineal)
                                task.wait(Nub.Motion.Spin)
                            end
                        end))
                    end
                end

                local flashId = 0
                -- RACE CONDITION CORREGIDA: un boton Async=true no tenia
                -- ningun candado contra volver a tocarlo mientras su
                -- Callback anterior TODAVIA estaba corriendo (ej.
                -- "Guardar ahora" tocado 3 veces rapido = 3 guardados
                -- corriendo en paralelo, cada uno terminando en un
                -- momento distinto e intentando apagar el spinner por
                -- su cuenta). Con Callbacks no-idempotentes esto podia
                -- ser un problema real, no solo cosmetico.
                local enCurso = false
                Utils.ClickConfiable(fila, function()
                    if cfg.Async and enCurso then return end
                    flashId = flashId + 1
                    local idActual = flashId
                    Utils.Tween(fila, {BackgroundColor3 = Theme.Accent}, Nub.Motion.FlashIn)
                    task.delay(0.1, function()
                        if idActual == flashId and fila and fila.Parent then
                            Utils.Tween(fila, {BackgroundColor3 = Theme.Fila}, Nub.Motion.Expand)
                        end
                    end)
                    if cfg.Callback then
                        if cfg.Async then
                            enCurso = true
                            activarSpinner(true)
                            task.spawn(function()
                                ejecutarConFallback(cfg.Callback, cfg.Texto or "control")
                                enCurso = false
                                if fila and fila.Parent then activarSpinner(false) end
                            end)
                        else
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "control")
                        end
                    end
                end)
                if lblInteract then
                    local proxy = Utils.EnvolverInstancia(fila)
                    rawset(proxy, "SetInteract", function(a, b)
                        local texto = (a == proxy) and b or a
                        lblInteract.Text = tostring(texto)
                    end)
                    rawset(proxy, "GetInteract", function() return lblInteract.Text end)
                    return proxy
                end
                return fila
            end

            -- ── COLUMNAS ────────────────────────────────────────────────
            -- Divide una seccion en dos columnas. Devuelve DOS sub-secciones con
            -- los mismos controles que Seccion (Toggle, Slider, Input...), cada
            -- una escribiendo en su columna:
            --   local izq, der = Seccion:Columnas({ Proporcion = 0.5, Separacion = 12, MinimoAncho = 400 })
            --   izq:Toggle({ Texto = "A", Flag = "a" })
            --   der:Toggle({ Texto = "B", Flag = "b" })
            -- Por debajo de MinimoAncho (en px "base", sin contar la escala de la
            -- interfaz) las columnas se apilan en una sola.
            --
            -- Como los controles capturan 'contenedor' por upvalue, no se pueden
            -- apuntar a otro padre. Por eso cada llamada crea el control en la
            -- seccion y mueve a su columna las filas NUEVAS: se toma una foto de
            -- los hijos de 'contenedor' ANTES de la llamada y se mueve todo hijo
            -- grafico que aparezca DESPUES. (La foto tiene que ser del contenedor,
            -- no de la columna: si no, "todo es nuevo" y se mueve la fila
            -- equivocada.)
            local CONTROLES_EN_COLUMNAS = {
                "Boton", "Toggle", "Casilla", "Slider", "RangeSlider", "NumberStepper",
                "Input", "TagInput", "Dropdown", "RadioGroup", "ColorPicker", "Keybind",
                "Label", "Progreso", "Parrafo", "Divider", "Imagen", "Grupo", "Construir",
            }

            function Seccion:Columnas(cfg)
                if type(cfg) ~= "table" or cfg == Seccion then cfg = {} end
                local proporcion  = math.clamp(tonumber(cfg.Proporcion) or 0.5, 0.15, 0.85)
                local separacion  = math.clamp(tonumber(cfg.Separacion) or 12, 0, 40)
                local minimoAncho = tonumber(cfg.MinimoAncho) or 400

                local filaCols = Utils.Frame({
                    Padre = contenedor, Size = UDim2.new(1, 0, 0, 0),
                    Orden = siguienteOrden(), Transparencia = 1, Radio = false,
                })
                filaCols.AutomaticSize = Enum.AutomaticSize.Y

                local layoutCols = Instance.new("UIListLayout")
                layoutCols.FillDirection = Enum.FillDirection.Horizontal
                layoutCols.SortOrder = Enum.SortOrder.LayoutOrder
                layoutCols.Padding = UDim.new(0, separacion)
                layoutCols.Parent = filaCols

                local function crearColumna(orden)
                    local col = Utils.Frame({
                        Padre = filaCols, Size = UDim2.new(0.5, 0, 0, 0),
                        Orden = orden, Transparencia = 1, Radio = false,
                    })
                    col.AutomaticSize = Enum.AutomaticSize.Y
                    local layout = Instance.new("UIListLayout")
                    layout.Padding = UDim.new(0, 12)
                    layout.SortOrder = Enum.SortOrder.LayoutOrder
                    layout.Parent = col
                    return col
                end
                local colIzq, colDer = crearColumna(1), crearColumna(2)

                local apilado = nil
                local function reLayoutColumnas()
                    if not (filaCols and filaCols.Parent) then return end
                    local ancho = filaCols.AbsoluteSize.X / Utils.FactorEscalaUI(filaCols)
                    if ancho <= 0 then return end
                    local debeApilar = ancho < minimoAncho
                    if debeApilar == apilado then return end
                    apilado = debeApilar
                    if debeApilar then
                        layoutCols.FillDirection = Enum.FillDirection.Vertical
                        colIzq.Size = UDim2.new(1, 0, 0, 0)
                        colDer.Size = UDim2.new(1, 0, 0, 0)
                    else
                        layoutCols.FillDirection = Enum.FillDirection.Horizontal
                        colIzq.Size = UDim2.new(proporcion, -separacion / 2, 0, 0)
                        colDer.Size = UDim2.new(1 - proporcion, -separacion / 2, 0, 0)
                    end
                end
                Nub:RegistrarConexion(
                    filaCols:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutColumnas))
                )
                -- Antes de medir, las columnas arrancan en modo "dos columnas".
                colIzq.Size = UDim2.new(proporcion, -separacion / 2, 0, 0)
                colDer.Size = UDim2.new(1 - proporcion, -separacion / 2, 0, 0)
                task.defer(reLayoutColumnas)

                local function crearSubseccion(columna)
                    local sub = { Instancia = columna }
                    for _, nombre in ipairs(CONTROLES_EN_COLUMNAS) do
                        sub[nombre] = function(_, cfgControl)
                            local funcion = Seccion[nombre]
                            if type(funcion) ~= "function" then
                                advertirDev("Columnas", nombre, "este control no existe en Seccion.")
                                return nil
                            end
                            local previos = {}
                            for _, hijo in ipairs(contenedor:GetChildren()) do previos[hijo] = true end
                            local resultado = funcion(Seccion, cfgControl)
                            for _, hijo in ipairs(contenedor:GetChildren()) do
                                if not previos[hijo] and hijo:IsA("GuiObject") then
                                    hijo.Parent = columna
                                end
                            end
                            return resultado
                        end
                    end
                    return sub
                end

                return crearSubseccion(colIzq), crearSubseccion(colDer)
            end

            function Seccion:Grupo(cfg)
                if type(cfg) ~= "table" or cfg == Seccion then cfg = {} end
                local ALTO_GRUPO = math.clamp(cfg.Alto or 32, 26, 60)
                local ANCHO_MINIMO = cfg.AnchoMinimo or 120
                local GAP = 8
                local filaGrupo = Utils.Frame({
                    Padre = contenedor, Size = UDim2.new(1, 0, 0, ALTO_GRUPO),
                    Transparencia = 1, Orden = siguienteOrden(), Radio = false,
                })
                local layoutGrupo = Instance.new("UIListLayout")
                layoutGrupo.FillDirection = Enum.FillDirection.Horizontal
                layoutGrupo.SortOrder = Enum.SortOrder.LayoutOrder
                layoutGrupo.Padding = UDim.new(0, GAP)
                layoutGrupo.Parent = filaGrupo

                local botonesGrupo = {}
                local function reLayoutGrupo()
                    if not (filaGrupo and filaGrupo.Parent) then return end
                    local total = #botonesGrupo
                    if total == 0 then return end
                    local ancho = filaGrupo.AbsoluteSize.X / Utils.FactorEscalaUI(filaGrupo)
                    local vertical = total > 1 and ancho > 0 and ancho < total * ANCHO_MINIMO
                    layoutGrupo.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
                    for i, fila in ipairs(botonesGrupo) do
                        fila.LayoutOrder = i
                        fila.Size = vertical and UDim2.new(1, 0, 0, ALTO_GRUPO)
                            or UDim2.new(1 / total, -math.ceil(GAP * (total - 1) / total), 1, 0)
                    end
                    filaGrupo.Size = vertical
                        and UDim2.new(1, 0, 0, total * ALTO_GRUPO + (total - 1) * GAP)
                        or UDim2.new(1, 0, 0, ALTO_GRUPO)
                end
                Nub:RegistrarConexion(filaGrupo:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutGrupo)))

                local grupo = { Instancia = filaGrupo }
                function grupo:Boton(cfgBoton)
                    if self ~= grupo then cfgBoton = self end
                    local boton = Seccion:Boton(cfgBoton or {})
                    local fila = boton.Fila or boton.Instancia
                    if not fila then return boton end
                    fila.Parent = filaGrupo
                    table.insert(botonesGrupo, fila)
                    reLayoutGrupo()
                    task.defer(reLayoutGrupo)
                    return boton
                end
                return grupo
            end

            function Seccion:Imagen(cfg)
                cfg = cfg or {}
                if type(cfg.Url) ~= "string" or cfg.Url == "" then
                    advertirDev("Imagen", cfg.Texto, "falta 'Url' (usa rbxassetid://...).")
                elseif cfg.Url:match("^https?://") then
                    advertirDev("Imagen", cfg.Texto, "Roblox no carga imágenes por URL web; usa rbxassetid://...")
                end
                local relacion
                if type(cfg.Aspecto) == "string" then
                    local w, h = cfg.Aspecto:match("^(%d+):(%d+)$")
                    if w and h and tonumber(h) > 0 then relacion = tonumber(w) / tonumber(h) end
                elseif type(cfg.Aspecto) == "number" and cfg.Aspecto > 0 then
                    relacion = cfg.Aspecto
                end
                local altoFijo = math.clamp(cfg.Alto or 120, 40, 400)

                local fila = Utils.Frame({
                    Padre = contenedor, Size = UDim2.new(1, 0, 0, relacion and 0 or altoFijo),
                    Transparencia = 1, Orden = siguienteOrden(), Radio = false,
                })
                if relacion then
                    local aspecto = Instance.new("UIAspectRatioConstraint")
                    aspecto.AspectRatio = relacion
                    aspecto.DominantAxis = Enum.DominantAxis.Width
                    aspecto.Parent = fila
                end
                local img = Instance.new("ImageLabel")
                img.BackgroundColor3 = Theme.Fila
                img.BorderSizePixel = 0
                img.Image = type(cfg.Url) == "string" and cfg.Url or ""
                local escalas = { Fit = Enum.ScaleType.Fit, Crop = Enum.ScaleType.Crop, Stretch = Enum.ScaleType.Stretch }
                img.ScaleType = escalas[cfg.Escala] or (relacion and Enum.ScaleType.Crop or Enum.ScaleType.Fit)
                img.Size = UDim2.new(1, 0, 1, 0)
                img.Parent = fila
                Utils.Corner(img, cfg.Radio or 8)
                Nub:Registrar(img, "BackgroundColor3", "Fila")

                return {
                    Set = function(...)
                        local url = normalizarArgSet(...)
                        if type(url) == "string" then img.Image = url end
                    end,
                    Get = function() return img.Image end,
                    Instancia = img,
                }
            end

            -- 📄 PARRAFO — bloque de texto informativo, sin interacción.
            function Seccion:Parrafo(cfg)
                cfg = cfg or {}
                local marco2 = Utils.Frame({
                    Padre = contenedor, Size = UDim2.new(1, 0, 0, 0),
                    Color = Theme.Fila, Orden = siguienteOrden(), Radio = 8,
                })
                marco2.AutomaticSize = Enum.AutomaticSize.Y
                Nub:Registrar(marco2, "BackgroundColor3", "Fila")

                local interno = Utils.Frame({Padre = marco2, Size = UDim2.new(1, 0, 0, 0), Transparencia = 1})
                interno.AutomaticSize = Enum.AutomaticSize.Y

                local layoutP = Instance.new("UIListLayout")
                layoutP.Padding   = UDim.new(0, 2)
                layoutP.SortOrder = Enum.SortOrder.LayoutOrder
                layoutP.Parent    = interno

                local padP = Instance.new("UIPadding")
                padP.PaddingTop,    padP.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
                padP.PaddingLeft,   padP.PaddingRight  = UDim.new(0, 10), UDim.new(0, cfg.MiniaturaUrl and 72 or 10)
                padP.Parent = interno

                if type(cfg.ImagenUrl) == "string" and cfg.ImagenUrl ~= "" then
                    local imagenParrafo = Instance.new("ImageLabel")
                    imagenParrafo.BackgroundColor3 = Theme.Entrada
                    imagenParrafo.BorderSizePixel = 0
                    imagenParrafo.Image = cfg.ImagenUrl
                    imagenParrafo.ScaleType = cfg.ImagenEscala == "Fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
                    imagenParrafo.Size = UDim2.new(1, 0, 0, math.clamp(cfg.ImagenAlto or 110, 40, 300))
                    imagenParrafo.LayoutOrder = 0
                    imagenParrafo.Parent = interno
                    Utils.Corner(imagenParrafo, 6)
                    Nub:Registrar(imagenParrafo, "BackgroundColor3", "Entrada")
                end

                if type(cfg.MiniaturaUrl) == "string" and cfg.MiniaturaUrl ~= "" then
                    local miniatura = Instance.new("ImageLabel")
                    miniatura.BackgroundColor3 = Theme.Entrada
                    miniatura.BorderSizePixel = 0
                    miniatura.Image = cfg.MiniaturaUrl
                    miniatura.ScaleType = Enum.ScaleType.Crop
                    miniatura.Size = UDim2.new(0, 52, 0, 52)
                    miniatura.AnchorPoint = Vector2.new(1, 0)
                    miniatura.Position = UDim2.new(1, -10, 0, 8)
                    miniatura.Parent = marco2
                    Utils.Corner(miniatura, 8)
                    Nub:Registrar(miniatura, "BackgroundColor3", "Entrada")
                    local altoMinimo = Instance.new("UISizeConstraint")
                    altoMinimo.MinSize = Vector2.new(0, 68)
                    altoMinimo.Parent = marco2
                end

                if cfg.Titulo then
                    local lblTituloP = Utils.Texto({
                        Padre = interno, Texto = cfg.Titulo,
                        Size = UDim2.new(1, 0, 0, 0),
                        Fuente = Enum.Font.GothamBold, Tamano = 13,
                        Color = Theme.Highlight, Ajustar = true, Orden = 1,
                        RichText = cfg.RichText,
                    })
                    lblTituloP.AutomaticSize = Enum.AutomaticSize.Y
                    Nub:Registrar(lblTituloP, "TextColor3", "Highlight")
                end

                local lblContenido = Utils.Texto({
                    Padre = interno, Texto = cfg.Contenido or "",
                    Size = UDim2.new(1, 0, 0, 0),
                    Tamano = 12, Color = Theme.Text, Ajustar = true,
                    Orden = 2, RichText = cfg.RichText,
                })
                lblContenido.AutomaticSize = Enum.AutomaticSize.Y
                Nub:Registrar(lblContenido, "TextColor3", "Text")

                if cfg.Descripcion then
                    local botonMas = Utils.BotonBase({
                        Padre = interno, Size = UDim2.new(1, 0, 0, 22),
                        Color = Theme.Fila, Transparencia = 1, Orden = 3, Radio = 4,
                    })
                    local lblMas = Utils.Texto({
                        Padre = botonMas, Texto = "+ Más información",
                        Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
                        Tamano = 11, Color = Theme.AccentLight, ColorTema = "AccentLight",
                    })
                    local lblExtra = Utils.Texto({
                        Padre = interno, Texto = tostring(cfg.Descripcion),
                        Size = UDim2.new(1, 0, 0, 0), Tamano = 11, Ajustar = true,
                        Color = Theme.TextDark, ColorTema = "TextDark", Orden = 4, RichText = cfg.RichText,
                    })
                    lblExtra.AutomaticSize = Enum.AutomaticSize.Y
                    lblExtra.Visible = false
                    Utils.ClickConfiable(botonMas, function()
                        lblExtra.Visible = not lblExtra.Visible
                        lblMas.Text = lblExtra.Visible and "- Menos información" or "+ Más información"
                    end)
                end

                local botonesParrafo = {}
                if type(cfg.Botones) == "table" and #cfg.Botones > 0 then
                    local totalBotones = #cfg.Botones
                    local filaBotonesP = Utils.Frame({
                        Padre = interno, Size = UDim2.new(1, 0, 0, 30),
                        Transparencia = 1, Orden = 5, Radio = false,
                    })
                    local layoutBotonesP = Instance.new("UIListLayout")
                    layoutBotonesP.FillDirection = Enum.FillDirection.Horizontal
                    layoutBotonesP.Padding = UDim.new(0, 8)
                    layoutBotonesP.SortOrder = Enum.SortOrder.LayoutOrder
                    layoutBotonesP.Parent = filaBotonesP
                    for i, defBoton in ipairs(cfg.Botones) do
                        local principal = defBoton.Variante == "primary"
                        local peligro = defBoton.Variante == "danger"
                        local btnP = Utils.BotonBase({
                            Padre = filaBotonesP,
                            Size = UDim2.new(1 / totalBotones, -math.ceil(8 * (totalBotones - 1) / totalBotones), 1, 0),
                            Color = peligro and Color3.fromRGB(190, 60, 60) or (principal and Theme.Accent or Theme.Entrada),
                            Transparencia = 0, Radio = 6,
                        })
                        btnP.LayoutOrder = i
                        if principal then Nub:Registrar(btnP, "BackgroundColor3", "Accent")
                        elseif not peligro then Nub:Registrar(btnP, "BackgroundColor3", "Entrada") end
                        Utils.Texto({
                            Padre = btnP, Texto = tostring(defBoton.Texto or "OK"),
                            Alineacion = Enum.TextXAlignment.Center, Tamano = 12, Truncar = true,
                            Fuente = Enum.Font.GothamMedium,
                            Color = (principal or peligro) and Color3.fromRGB(255, 255, 255) or nil,
                        })
                        Utils.ClickConfiable(btnP, function()
                            if type(defBoton.Callback) == "function" then
                                ejecutarConFallback(defBoton.Callback, defBoton.Texto or "Parrafo")
                            end
                        end, btnP)
                        table.insert(botonesParrafo, btnP)
                    end
                end

                return {
                    Instancia = marco2,
                    Botones = botonesParrafo,
                    Set = function(...)
                        local texto = normalizarArgSet(...)
                        if type(texto) ~= "string" and type(texto) ~= "number" then
                            Nub:_RegistrarError("Parrafo.Set (valor inválido)",
                                "recibió " .. typeof(texto) .. " en vez de string/number. Se ignoró.")
                            return
                        end
                        lblContenido.Text = tostring(texto)
                    end,
                }
            end

            -- 📊 PROGRESO — barra de progreso NO interactiva (solo
            -- lectura visual, actualizable con Set(0-100)). Pensada
            -- para cooldowns, progreso de auto-farm, carga de datos,
            -- etc. -- a diferencia de Slider, el usuario no puede
            -- arrastrarla.
            function Seccion:Progreso(cfg)
                cfg = cfg or {}
                local flag  = cfg.Flag or cfg.Texto or ("Progreso_" .. tostring(math.random(1e5, 1e6)))
                local valor = math.clamp(cfg.Defecto or 0, 0, 100)
                -- Se marca como no-persistente ANTES de escribir, y se
                -- escribe directo a _flagsReales (no via Nub.Flags):
                -- mismo patron que Label -- si se escribiera por el
                -- proxy, cada Progreso creado dispararia
                -- marcarCambioPendiente() y forzaria un ciclo de
                -- autoguardado que, para cuando corre, no guarda nada
                -- util (el flag ya esta marcado como no-persistente).
                _flagsNoPersistir[flag] = true
                _flagsReales[flag] = valor

                local ALTO_FILA = 44
                local fila, lbl = crearCabecera(ALTO_FILA, cfg.Texto or "Progreso", nil, nil, "fijo")
                lbl.Size = UDim2.new(1, -70, 0, 18)
                lbl.Position = UDim2.new(0, 10, 0, 4)
                agregarTooltipTexto(fila, cfg.Texto or "Progreso", cfg.Tooltip, lbl)
                registrarBuscable(fila, cfg.Texto or "Progreso", cfg.VisibleSi)

                local lblValor = Utils.Texto({
                    Padre = fila, Texto = math.floor(valor) .. "%",
                    Size = UDim2.new(0, 50, 0, 18),
                    Posicion = UDim2.new(1, -60, 0, 4),
                    Alineacion = Enum.TextXAlignment.Right,
                    Color = Theme.AccentLight, Tamano = 11,
                })
                Nub:Registrar(lblValor, "TextColor3", "AccentLight")

                local fondo = Utils.Frame({
                    Padre = fila, Size = UDim2.new(1, -20, 0, 6),
                    Posicion = UDim2.new(0, 10, 0, 28),
                    Color = Theme.Entrada, Radio = 3,
                })
                Nub:Registrar(fondo, "BackgroundColor3", "Entrada")

                local relleno = Utils.Frame({
                    Padre = fondo, Size = UDim2.new(valor / 100, 0, 1, 0),
                    Color = Theme.Accent, Radio = 3,
                })
                Nub:Registrar(relleno, "BackgroundColor3", "Accent")
                Utils.GradienteAcento(relleno)

                local ultimoProgresoAnimado = valor
                local function fijar(v)
                    if type(v) ~= "number" then
                        Nub:_RegistrarError("Progreso.Set (valor no numérico)",
                            "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                            " en vez de number. Se ignoró.")
                        return
                    end
                    valor = math.clamp(v, 0, 100)
                    Utils.Tween(relleno, {Size = UDim2.new(valor / 100, 0, 1, 0)}, Nub.Motion.Expand)
                    -- El numero tambien sube suavemente (no solo la barra).
                    local desde = ultimoProgresoAnimado
                    ultimoProgresoAnimado = valor
                    Utils.TweenNumero(desde, valor, Nub.Motion.Page, function(n)
                        if lblValor and lblValor.Parent then
                            lblValor.Text = math.floor(n + 0.5) .. "%"
                        end
                    end, Nub.Motion.EaseEntrar)
                    _flagsReales[flag] = valor
                end

                Nub.Elementos[flag] = {
                    Set = function(v) fijar(v) end,
                    Get = function() return valor end,
                }
                return {
                    -- Set(...) normalizado: acepta tanto Progreso.Set(40)
                    -- (correcto) como Progreso:Set(40) (error de sintaxis
                    -- comun) -- ver comentario junto a normalizarArgSet.
                    Set = function(...) fijar(normalizarArgSet(...)) end,
                    Get = function() return valor end,
                }
            end

            -- ➖ DIVIDER — separador visual liviano entre grupos de
            -- controles relacionados dentro de una misma seccion.
            -- A diferencia de Parrafo (que trae caja de fondo, titulo,
            -- padding interno), esto es solo una linea delgada con un
            -- texto opcional al lado -- pensado para no competir
            -- visualmente con los controles reales.
            function Seccion:Divider(cfg)
                cfg = cfg or {}
                local conTexto = cfg.Texto ~= nil
                local fila = Utils.Frame({
                    Padre = contenedor, Size = UDim2.new(1, 0, 0, conTexto and 38 or 18),
                    Orden = siguienteOrden(), Transparencia = 1, Radio = false,
                })

                if conTexto then
                    local barraAcento = Utils.Frame({
                        Padre = fila, Size = UDim2.new(0, 3, 0, 16),
                        Posicion = UDim2.new(0, 2, 0, 13), Color = Theme.Accent, Radio = 2,
                    })
                    Nub:Registrar(barraAcento, "BackgroundColor3", "Accent")
                    Utils.Texto({
                        Padre = fila, Texto = tostring(cfg.Texto),
                        Size = UDim2.new(1, -16, 0, 22), Posicion = UDim2.new(0, 14, 0, 10),
                        Fuente = Enum.Font.GothamBold, Tamano = 12, ColorTema = "AccentLight",
                        Truncar = true,
                    })
                    local linea = Utils.Frame({
                        Padre = fila, Size = UDim2.new(1, 0, 0, 2),
                        Posicion = UDim2.new(0, 0, 1, -4), Color = Theme.Accent, Radio = false,
                    })
                    Nub:Registrar(linea, "BackgroundColor3", "Accent")
                    local degradado = Instance.new("UIGradient")
                    degradado.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.1),
                        NumberSequenceKeypoint.new(0.6, 0.65),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    degradado.Parent = linea
                else
                    local linea = Utils.Frame({
                        Padre = fila, Size = UDim2.new(1, 0, 0, 2),
                        Posicion = UDim2.new(0, 0, 0.5, -1), Color = Theme.Accent, Radio = false,
                    })
                    Nub:Registrar(linea, "BackgroundColor3", "Accent")
                    local degradado = Instance.new("UIGradient")
                    degradado.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(0.5, 0.4),
                        NumberSequenceKeypoint.new(1, 1),
                    })
                    degradado.Parent = linea
                end
                return { Instancia = fila }
            end

            -- ── LABEL (texto dinámico) ──────────────────────────
            -- Control simple para mostrar un valor que cambia (uso interno).
            -- Util para estados, contadores, info en tiempo real.
            -- Retorna: { Set(valor), Get() }
            function Seccion:Label(cfg)
                cfg = cfg or {}
                local flag  = cfg.Flag or ("Label_" .. tostring(math.random(1e5, 1e6)))
                local valor = tostring(cfg.Valor or "")
                _flagsNoPersistir[flag] = true

                local fila, lbl = crearCabecera(32, cfg.Texto or "Label", 1, -126)
                if cfg.Descripcion then
                    lbl.Position = UDim2.new(0, 28, lbl.Position.Y.Scale, lbl.Position.Y.Offset)
                    lbl.Size = UDim2.new(lbl.Size.X.Scale, lbl.Size.X.Offset - 20, lbl.Size.Y.Scale, lbl.Size.Y.Offset)
                    Utils.AnexarDescripcion(fila, contenedor, siguienteOrden(), cfg.Descripcion, UDim2.new(1, -126, 1, 0))
                end
                agregarTooltipTexto(fila, cfg.Texto or "Label", cfg.Tooltip, lbl)
                registrarBuscable(fila, cfg.Texto or "Label", cfg.VisibleSi)

                local lblValor = Utils.Texto({
                    Padre = fila,
                    Texto = valor,
                    Size = UDim2.new(0, 120, 1, 0),
                    Posicion = UDim2.new(1, -126, 0, 0),
                    Alineacion = Enum.TextXAlignment.Right,
                    Color = Theme.AccentLight,
                    Tamano = 12,
                    Truncar = true,
                    RichText = cfg.RichText,
                })
                -- Registrado con una FUNCION (no la clave fija
                -- "AccentLight") para que SetColor() sobreviva a un
                -- cambio de tema: si se registrara contra la clave fija,
                -- el proximo AplicarTema() pisaria silenciosamente el
                -- color personalizado con el color del tema, sin que el
                -- developer lo haya pedido. Con la funcion, cada refresco
                -- de tema pregunta "cual es el color correcto ahora" y
                -- devuelve 'colorPersonalizado' mientras siga seteado.
                local colorPersonalizado = nil
                Nub:Registrar(lblValor, "TextColor3", function()
                    return colorPersonalizado or Theme.AccentLight
                end)

                -- Se escribe directo a _flagsReales (sigue siendo
                -- legible con Nub:ObtenerFlag(flag) / Elementos[flag]
                -- .Get(), como siempre), sin pasar por el proxy que
                -- dispara guardado, y 'flag' queda marcado en
                -- _flagsNoPersistir para que tampoco se cuele en el
                -- .json si el guardado se dispara por OTRO control
                -- mientras tanto.
                local function fijar(v)
                    if type(v) ~= "string" and type(v) ~= "number" then
                        Nub:_RegistrarError("Label.Set (valor inválido)",
                            "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                            " en vez de string/number. Se ignoró.")
                        return
                    end
                    valor = tostring(v)
                    lblValor.Text = valor
                    _flagsReales[flag] = v
                end

                _flagsReales[flag] = cfg.Valor
                Nub.Elementos[flag] = {
                    Set = function(v) fijar(v) end,
                    Get = function() return valor end,
                }

                -- SetColor: cambia el color del valor mostrado, puntualmente.
                -- Gracias al registro por funcion de arriba, sobrevive a
                -- cambios de tema -- queda "pegado" hasta que el developer
                -- llame SetColor() de nuevo con otro valor.
                local function setColor(color)
                    if typeof(color) ~= "Color3" then
                        Nub:_RegistrarError("Label.SetColor (valor no es Color3)",
                            "flag '" .. tostring(flag) .. "' recibió " .. typeof(color) ..
                            " en vez de Color3. Se ignoró.")
                        return
                    end
                    colorPersonalizado = color
                    lblValor.TextColor3 = color
                end

                -- Auto-update: opcional, solo si el dev paso 'Cada' + 'Actualizar'.
                -- El callback 'Actualizar' se llama cada 'Cada' segundos, y su
                -- retorno se aplica al label como si fuera un Set() (pero sin
                -- disparar Callback -- un Label no tiene Callback, es solo display).
                -- Se registra en _labelsAutoActualizables (weak key = la instancia
                -- del label) -- ver el loop unico de Heartbeat mas arriba en el
                -- archivo, que es el que realmente llama a 'Actualizar'.
                if cfg.Cada and cfg.Actualizar and type(cfg.Actualizar) == "function" then
                    local cada = tonumber(cfg.Cada)
                    if cada and cada >= 0.05 then -- piso de 50ms: evita que alguien ponga 0.001 y sature
                        _labelsAutoActualizables[lblValor] = {
                            cada    = cada,
                            fn      = cfg.Actualizar,
                            aplicar = fijar,
                            flag    = flag,
                            proxima = os.clock() + cada,
                        }
                    else
                        advertirDev("Label", cfg.Texto,
                            "'Cada' debe ser un número >= 0.05. Auto-update desactivado.")
                    end
                end

                return {
                    Set      = function(...) fijar(normalizarArgSet(...)) end,
                    SetTexto = function(...) fijar(normalizarArgSet(...)) end, -- alias
                    SetColor = setColor,
                    Get      = function() return valor end,
                }
            end

            -- ✅ TOGGLE — interruptor on/off, con exclusión mutua opcional vía Desactivar.
            function Seccion:Toggle(cfg)
                return crearControlBooleano("Toggle", cfg, function(fila, obtenerValor)
                    local perilla = Utils.BotonBase({
                        Padre = fila, Size = UDim2.new(0, 44, 0, 22),
                        Posicion = UDim2.new(1, -50, 0.5, -11),
                        Color = obtenerValor() and Theme.Accent or Theme.Apagado,
                        Transparencia = 0, Radio = 11,
                    })
                    Nub:Registrar(perilla, "BackgroundColor3", function()
                        return obtenerValor() and Theme.Accent or Theme.Apagado
                    end)
                    local circulo = Utils.Frame({
                        Padre = perilla, Size = UDim2.new(0, 18, 0, 18),
                        Posicion = obtenerValor()
                            and UDim2.new(1, -20, 0.5, -9)
                            or  UDim2.new(0,  2, 0.5, -9),
                        Color = Theme.Text, Radio = 9,
                    })
                    Nub:Registrar(circulo, "BackgroundColor3", "Text")

                    return {
                        clicable = perilla,
                        actualizarVisual = function(v)
                            Utils.Tween(perilla, {BackgroundColor3 = v and Theme.Accent or Theme.Apagado}, Nub.Motion.Expand, Nub.Motion.EaseSuave, Enum.EasingDirection.Out)
                            Utils.Tween(circulo, {
                                Position = v
                                    and UDim2.new(1, -20, 0.5, -9)
                                    or  UDim2.new(0,  2, 0.5, -9)
                            }, Nub.Motion.Page, Nub.Motion.EasePop, Enum.EasingDirection.Out)
                        end,
                    }
                end)
            end

            -- ☑️ CASILLA — checkbox equivalente a Toggle, con otro estilo visual.
            function Seccion:Casilla(cfg)
                return crearControlBooleano("Casilla", cfg, function(fila, obtenerValor)
                    local caja = Utils.BotonBase({
                        Padre = fila, Size = UDim2.new(0, 22, 0, 22),
                        Posicion = UDim2.new(1, -30, 0.5, -11),
                        Color = obtenerValor() and Theme.Accent or Theme.Entrada,
                        Transparencia = 0, Radio = 5,
                    })
                    Nub:Registrar(caja, "BackgroundColor3", function()
                        return obtenerValor() and Theme.Accent or Theme.Entrada
                    end)
                    local strokeCasilla = Utils.Stroke(caja, Theme.Border, 1, 0.3)
                    Nub:Registrar(strokeCasilla, "Color", "Border")

                    -- El check se dibuja con 2 barritas rotadas en vez de
                    -- usar el caracter de fuente "✓": ese glifo se renderiza
                    -- distinto (y a veces mal centrado, pareciendo una
                    -- flechita) segun la fuente que use cada ejecutor. Con
                    -- formas propias se ve identico en todos lados.
                    local check = Utils.Frame({
                        Padre = caja, Size = UDim2.new(1, 0, 1, 0), Color = Theme.Text, Transparencia = 1,
                    })
                    local trazoCorto = Utils.Frame({
                        Padre = check, Size = UDim2.new(0, 7, 0, 2),
                        Posicion = UDim2.new(0.5, -7, 0.5, 1), Color = Theme.Text,
                        Transparencia = obtenerValor() and 0 or 1, Radio = 1,
                    })
                    trazoCorto.Rotation = 45
                    local trazoLargo = Utils.Frame({
                        Padre = check, Size = UDim2.new(0, 12, 0, 2),
                        Posicion = UDim2.new(0.5, -3, 0.5, -4), Color = Theme.Text,
                        Transparencia = obtenerValor() and 0 or 1, Radio = 1,
                    })
                    trazoLargo.Rotation = -45
                    Nub:Registrar(trazoCorto, "BackgroundColor3", "Text")
                    Nub:Registrar(trazoLargo, "BackgroundColor3", "Text")

                    return {
                        clicable = caja,
                        actualizarVisual = function(v)
                            Utils.Tween(caja, {BackgroundColor3 = v and Theme.Accent or Theme.Entrada}, Nub.Motion.Hover)
                            Utils.Tween(trazoCorto, {BackgroundTransparency = v and 0 or 1}, Nub.Motion.Hover)
                            Utils.Tween(trazoLargo, {BackgroundTransparency = v and 0 or 1}, Nub.Motion.Hover)
                        end,
                    }
                end)
            end

            -- 🎚️ SLIDER — elige un número dentro de un rango, arrastrando o escribiendo el valor.
            function Seccion:Slider(cfg)
                cfg = cfg or {}
                validarCallback("Slider", cfg)
                local flag      = cfg.Flag or cfg.Texto or ("Slider_" .. tostring(math.random(1e5, 1e6)))
                local minimo    = cfg.Min or 0
                local maximo    = cfg.Max or 100
                if minimo >= maximo then
                    advertirDev("Slider", cfg.Texto, "'Min' (" .. minimo .. ") es mayor o igual a 'Max' (" .. maximo .. "). Se ajustó Max a Min + 1 para evitar que la barra se rompa.")
                    maximo = minimo + 1
                end
                local incremento = cfg.Incremento or 1
                if incremento <= 0 then
                    advertirDev("Slider", cfg.Texto, "'Incremento' (" .. tostring(cfg.Incremento) .. ") debe ser mayor a 0. Se usó 1.")
                    incremento = 1
                end
                do
                    local pasos = (maximo - minimo) / incremento
                    if math.abs(pasos - math.floor(pasos + 0.5)) > 1e-6 then
                        advertirDev("Slider", cfg.Texto, "'Incremento' (" .. incremento .. ") no divide el rango " .. minimo .. "-" .. maximo .. ": el máximo no se puede alcanzar (el último valor es " .. (minimo + math.floor(pasos) * incremento) .. ").")
                    end
                end
                local sufijo    = cfg.Sufijo or ""
                if cfg.Defecto == nil then
                    advertirDev("Slider", cfg.Texto, "no tiene 'Defecto'. Se usó el mínimo (" .. minimo .. ") por defecto.")
                end
                local valor     = math.clamp(cfg.Defecto or minimo, minimo, maximo)
                Nub.Flags[flag] = valor

                local fila = Utils.Fila(contenedor, 54, siguienteOrden(), Theme.Fila)
                Nub:Registrar(fila, "BackgroundColor3", "Fila")
                Utils.Hover(fila, fila)
                registrarBuscable(fila, cfg.Texto or "Slider", cfg.VisibleSi)
                local lblSlider = Utils.Texto({
                    Padre = fila, Texto = cfg.Texto or "Slider",
                    Size = UDim2.new(1, -120, 0, 0),
                    Posicion = UDim2.new(0, 8, 0, 7),
                    Ajustar = true,
                })
                lblSlider.AutomaticSize = Enum.AutomaticSize.Y

                agregarTooltipTexto(fila, cfg.Texto or "Slider", cfg.Tooltip, lblSlider, -118)

                local inputValor = Instance.new("TextBox")
                inputValor.Size             = UDim2.new(0, 110, 0, 34)
                inputValor.Position         = UDim2.new(1, -116, 0, 7)
                inputValor.BackgroundColor3 = Theme.Entrada
                inputValor.Text             = tostring(valor) .. sufijo
                inputValor.TextColor3       = Theme.Highlight
                inputValor.Font             = Enum.Font.GothamBold
                inputValor.TextSize         = 16
                inputValor.TextXAlignment   = Enum.TextXAlignment.Center
                inputValor.BorderSizePixel  = 0
                inputValor.ClearTextOnFocus = false
                inputValor.Parent = fila
                Utils.Corner(inputValor, 6)
                Nub:Registrar(inputValor, "BackgroundColor3", "Entrada")
                Nub:Registrar(inputValor, "TextColor3", "Highlight")
                Utils.AnilloFoco(inputValor)

                local function redondear(v)
                    -- Con incrementos no enteros (ej. 0.3) dividir/multiplicar
                    -- por 'incremento' directamente acumula error de punto
                    -- flotante. Se opera con el factor inverso (1/incremento)
                    -- para minimizarlo.
                    local factor = 1 / incremento
                    return math.clamp(
                        math.floor((v - minimo) * factor + 0.5) / factor + minimo,
                        minimo, maximo
                    )
                end

                -- Quita el sufijo SIN patrones Lua (evita bugs con "%" en sliders %)
                local function quitarSufijo(texto)
                    if sufijo ~= "" and texto:sub(-#sufijo) == sufijo then
                        return texto:sub(1, -#sufijo - 1)
                    end
                    return texto
                end

                -- OPTIMIZACION: no reescribe el TextBox si el texto que
                -- mostraria es identico al que ya tiene (evita tocar la
                -- instancia en cada evento de arrastre).
                -- Contador animado SOLO en cambios por codigo (Set, carga
                -- de perfil): el TextBox muestra el numero subiendo o
                -- bajando suavemente al valor nuevo. Durante un arrastre
                -- el texto sigue al cursor sin tween (feedback directo).
                -- El valor real (Nub.Flags, Callback) siempre se
                -- actualiza instantaneo -- esto solo toca el TEXTO.
                -- 'ultimoTextoAnimado' se usa como clave de cancelacion
                -- del tween activo (mismo callback en cada llamada).
                -- Cantidad de decimales del Incremento (0.25 -> 2). Asi el
                -- contador muestra 0.30 y no 0 o 1 al animar valores decimales.
                local decimales = 0
                do
                    local dec = tostring(incremento):match("%.(%d+)$")
                    if dec then decimales = #dec end
                end
                local function formatearValor(n)
                    if decimales > 0 then return string.format("%." .. decimales .. "f", n) end
                    return tostring(math.floor(n + 0.5))
                end

                local ultimoTextoAnimado = valor
                local function animarTextoVisible(v, instantaneo)
                    if instantaneo or math.abs(ultimoTextoAnimado - v) < 0.01 then
                        ultimoTextoAnimado = v
                        local nuevoTexto = formatearValor(v) .. sufijo
                        if inputValor.Text ~= nuevoTexto then
                            inputValor.Text = nuevoTexto
                        end
                        return
                    end
                    local desde = ultimoTextoAnimado
                    ultimoTextoAnimado = v
                    Utils.TweenNumero(desde, v, Nub.Motion.Page, function(n)
                        if inputValor and inputValor.Parent then
                            -- Se muestra en la grilla del slider (no valores intermedios)
                            inputValor.Text = formatearValor(redondear(n)) .. sufijo
                        end
                    end, Nub.Motion.EaseEntrar)
                end
                local function actualizarTextoVisible(v)
                    -- Compatibilidad: los llamados existentes de esta
                    -- funcion siguen comportandose igual (instantaneo).
                    -- El flujo animado solo lo usa Set (cambios por
                    -- codigo); el arrastre actualiza el texto sin
                    -- animar, ver procesarNuevoValor.
                    animarTextoVisible(v, true)
                end

                -- OPTIMIZACION PRINCIPAL: cache del ultimo valor YA
                -- PROCESADO. La barra visual (relleno, dentro de
                -- crearBarraArrastrable) se sigue moviendo con cada
                -- pixel para que el arrastre se sienta fluido, pero
                -- actualizar Nub.Flags, el TextBox y ejecutar el
                -- Callback del desarrollador es lo "caro" — con
                -- Incremento > 1 es comun que varios movimientos
                -- consecutivos redondeen al mismo escalon (ej. 51..55
                -- todos dan 55). Solo corre cuando el valor
                -- redondeado cambia de verdad.
                local ultimoProcesado = valor

                local function procesarNuevoValor(vCrudo)
                    local v = redondear(vCrudo)
                    if v == ultimoProcesado then return end
                    ultimoProcesado = v
                    valor = v
                    Nub.Flags[flag] = v
                    -- Durante el arrastre el numero del TextBox sigue al
                    -- cursor sin tween (feedback directo). El valor real
                    -- ya fue actualizado arriba -- esto solo toca el
                    -- TEXTO de display.
                    animarTextoVisible(v, true)
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "control", v)
                    end
                end

                local barraSlider, _, fijarVisual = crearBarraArrastrable({
                    Padre = fila,
                    Size = UDim2.new(1, -160, 0, 10),
                    Posicion = UDim2.new(0, 8, 0, 38),
                    Min = minimo, Max = maximo, Valor = valor,
                    Incremento = incremento, Pasos = cfg.Pasos,
                    DiametroManija = 22,
                    AltoHitbox = Nub.Capacidades.EsTactil and 18 or 30,
                    PadHitboxX = Nub.Capacidades.EsTactil and 0 or 10,
                    OnCambio = procesarNuevoValor,
                })

                local PAD_S, GAP_S, ALTO_INPUT = 7, 10, 34
                local function reLayoutSlider()
                    if not (fila and fila.Parent) then return end
                    local e = Utils.FactorEscalaUI(fila)
                    local hLbl = math.ceil(lblSlider.AbsoluteSize.Y / e)
                    if hLbl <= 0 then hLbl = lblSlider.TextSize + 4 end
                    local hTop = math.max(hLbl, ALTO_INPUT)
                    lblSlider.Position = UDim2.new(0, 8, 0, PAD_S + math.floor((hTop - hLbl) / 2))
                    inputValor.Position = UDim2.new(1, -116, 0, PAD_S + math.floor((hTop - ALTO_INPUT) / 2))
                    local yBarra = PAD_S + hTop + GAP_S
                    barraSlider.Position = UDim2.new(0, 8, 0, yBarra)
                    fila.Size = UDim2.new(1, 0, 0, yBarra + 10 + 14)
                end
                Nub:RegistrarConexion(lblSlider:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutSlider)))
                task.defer(reLayoutSlider)

                inputValor.FocusLost:Connect(function(enterPressed)
                    if not enterPressed then return end
                    local texto = quitarSufijo(inputValor.Text):gsub("%s+", "")
                    local num   = tonumber(texto)
                    if num then
                        num = redondear(num)
                        ultimoProcesado = num
                        valor = num
                        Nub.Flags[flag] = num
                        actualizarTextoVisible(num)
                        fijarVisual(num)
                        Utils.FlashFeedback(inputValor, true, Theme.Entrada)
                        if cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "Slider", num)
                        end
                    else
                        actualizarTextoVisible(valor)
                        Utils.FlashFeedback(inputValor, false, Theme.Entrada)
                    end
                end)

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        if typeof(v) ~= "number" then
                            Nub:_RegistrarError("Slider.Set (valor no numérico)",
                                "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                                " en vez de number. Se ignoró.")
                            return
                        end
                        v = redondear(v)
                        ultimoProcesado = v
                        valor = v
                        Nub.Flags[flag] = v
                        animarTextoVisible(v, false)
                        fijarVisual(v)
                        -- dispararCallback=true lo usa SaveManager al
                        -- restaurar un guardado: sin esto el valor
                        -- quedaba "cargado" pero el efecto real (ej.
                        -- redimensionar la ventana) nunca se aplicaba.
                        if dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "control", v)
                        end
                    end,
                    Get = function() return valor end,
                }
                return {
                    Set = function(...)
                        Nub.Elementos[flag].Set(normalizarArgSet(...), true)
                    end,
                    Get = function() return valor end,
                }
            end

            -- 🎚️ RANGESLIDER — doble manija para elegir un rango Min–Max
            -- en una sola barra (ej. distancia 20-80, cooldown 5-15).
            -- Set/Get y Callback trabajan con {min=, max=} -- mismo
            -- estilo con nombres que el resto de la API publica (Texto=,
            -- Flag=, etc.), en vez de un array posicional {a, b}.
            function Seccion:RangeSlider(cfg)
                cfg = cfg or {}
                validarCallback("RangeSlider", cfg)
                local flag      = cfg.Flag or cfg.Texto or ("RangeSlider_" .. tostring(math.random(1e5, 1e6)))
                local minimo    = cfg.Min or 0
                local maximo    = cfg.Max or 100
                if minimo >= maximo then
                    advertirDev("RangeSlider", cfg.Texto, "'Min' (" .. minimo .. ") es mayor o igual a 'Max' (" .. maximo .. "). Se ajustó Max a Min + 1 para evitar que la barra se rompa.")
                    maximo = minimo + 1
                end
                local incremento = cfg.Incremento or 1
                if incremento <= 0 then
                    advertirDev("RangeSlider", cfg.Texto, "'Incremento' (" .. tostring(cfg.Incremento) .. ") debe ser mayor a 0. Se usó 1.")
                    incremento = 1
                end
                do
                    local pasos = (maximo - minimo) / incremento
                    if math.abs(pasos - math.floor(pasos + 0.5)) > 1e-6 then
                        advertirDev("RangeSlider", cfg.Texto, "'Incremento' (" .. incremento .. ") no divide el rango " .. minimo .. "-" .. maximo .. ": el máximo no se puede alcanzar (el último valor es " .. (minimo + math.floor(pasos) * incremento) .. ").")
                    end
                end
                local sufijo      = cfg.Sufijo or ""
                if cfg.Defecto == nil then
                    advertirDev("RangeSlider", cfg.Texto, "no tiene 'Defecto'. Se usó el rango completo (" .. minimo .. "-" .. maximo .. ") por defecto.")
                end
                local defecto = cfg.Defecto or {}
                local valorMin = math.clamp(defecto.min or minimo, minimo, maximo)
                local valorMax = math.clamp(defecto.max or maximo, minimo, maximo)
                if valorMin > valorMax then
                    -- Defecto invertido (min > max): se intercambian en
                    -- vez de romper la barra -- mismo espiritu que el
                    -- ajuste automatico de Min/Max de arriba.
                    valorMin, valorMax = valorMax, valorMin
                end
                -- Se guarda una COPIA en Flags (mismo motivo que Dropdown
                -- Multi via clonarTabla): evita que un script externo que
                -- mute Nub.Flags[flag] directamente a mano corrompa el
                -- estado interno del control sin pasar por Set().
                local function flagActual()
                    return {min = valorMin, max = valorMax}
                end
                Nub.Flags[flag] = flagActual()

                local fila = Utils.Fila(contenedor, 54, siguienteOrden(), Theme.Fila)
                Nub:Registrar(fila, "BackgroundColor3", "Fila")
                Utils.Hover(fila, fila)
                registrarBuscable(fila, cfg.Texto or "RangeSlider", cfg.VisibleSi)
                local lblSlider = Utils.Texto({
                    Padre = fila, Texto = cfg.Texto or "RangeSlider",
                    Size = UDim2.new(1, -170, 0, 18),
                    Posicion = UDim2.new(0, 8, 0, 6),
                    Truncar = true,
                })
                agregarTooltipTexto(fila, cfg.Texto or "RangeSlider", cfg.Tooltip, lblSlider, -118)

                -- Etiqueta de valores en vez de dos TextBox editables:
                -- con doble manija, escribir a mano un numero y saber a
                -- cual de las dos aplica es mas confuso que util -- el
                -- arrastre ya cubre el caso de uso normal. Se mantiene
                -- el mismo ancho/posicion que ocupaba el TextBox del
                -- Slider simple para no romper el layout de la fila.
                local lblValores = Utils.Texto({
                    Padre = fila,
                    Size = UDim2.new(0, 110, 0, 18),
                    Posicion = UDim2.new(1, -116, 0, 6),
                    Alineacion = Enum.TextXAlignment.Right,
                    Fuente = Enum.Font.GothamBold, Tamano = 13,
                    Color = Theme.Highlight,
                })
                Nub:Registrar(lblValores, "TextColor3", "Highlight")

                local function redondear(v)
                    local factor = 1 / incremento
                    return math.clamp(
                        math.floor((v - minimo) * factor + 0.5) / factor + minimo,
                        minimo, maximo
                    )
                end

                local function actualizarTextoVisible()
                    lblValores.Text = tostring(valorMin) .. sufijo .. " – " .. tostring(valorMax) .. sufijo
                end
                actualizarTextoVisible()

                -- Igual que Slider: cache de lo ultimo YA PROCESADO
                -- (post-redondeo) para no tocar Flags/TextLabel/Callback
                -- en cada pixel de arrastre si el valor redondeado no
                -- cambio de verdad respecto al ultimo evento.
                local ultimoMin, ultimoMax = valorMin, valorMax

                local function procesarNuevoRango(vMinCrudo, vMaxCrudo)
                    local vMin = redondear(vMinCrudo)
                    local vMax = redondear(vMaxCrudo)
                    if vMin > vMax then vMin, vMax = vMax, vMin end
                    if vMin == ultimoMin and vMax == ultimoMax then return end
                    ultimoMin, ultimoMax = vMin, vMax
                    valorMin, valorMax = vMin, vMax
                    Nub.Flags[flag] = flagActual()
                    actualizarTextoVisible()
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                    end
                end

                local _, fijarVisual = crearBarraArrastrableRango({
                    Padre = fila,
                    Size = UDim2.new(1, -170, 0, 10),
                    Posicion = UDim2.new(0, 8, 0, 38),
                    DiametroManija = 20,
                    AltoHitbox = Nub.Capacidades.EsTactil and 18 or 22,
                    PadHitboxX = Nub.Capacidades.EsTactil and 0 or 10,
                    Min = minimo, Max = maximo,
                    ValorMin = valorMin, ValorMax = valorMax,
                    -- Mismo motivo que en Slider: la barra visual se
                    -- mueve pixel a pixel para que el arrastre se sienta
                    -- fluido; el redondeo/Flags/Callback (procesarNuevoRango)
                    -- solo corre cuando el escalon realmente cambia.
                    ObtenerMin = function() return ultimoMin end,
                    ObtenerMax = function() return ultimoMax end,
                    OnCambio = procesarNuevoRango,
                })

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        if type(v) ~= "table" or v.min == nil or v.max == nil then
                            Nub:_RegistrarError("RangeSlider.Set (valor invalido)",
                                "flag '" .. tostring(flag) .. "' esperaba {min=, max=} y recibió " .. typeof(v) .. ". Se ignoró.")
                            return
                        end
                        local vMin = redondear(math.clamp(v.min, minimo, maximo))
                        local vMax = redondear(math.clamp(v.max, minimo, maximo))
                        if vMin > vMax then vMin, vMax = vMax, vMin end
                        ultimoMin, ultimoMax = vMin, vMax
                        valorMin, valorMax = vMin, vMax
                        Nub.Flags[flag] = flagActual()
                        actualizarTextoVisible()
                        fijarVisual(vMin, vMax)
                        -- dispararCallback=true lo usa SaveManager al
                        -- restaurar un guardado -- mismo patron que Slider.
                        if dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                        end
                    end,
                    Get = function() return flagActual() end,
                }
                return {
                    Set = function(...)
                        Nub.Elementos[flag].Set(normalizarArgSet(...), true)
                    end,
                    Get = function() return flagActual() end,
                }
            end

            -- 🏷️ TAGINPUT — lista de strings libres como "chips"
            -- (ej. palabras clave, nombres de jugador a ignorar).
            -- Valor: ARRAY {"tag1","tag2"} -- no dict como Dropdown
            -- Multi, porque aca no hay opciones predefinidas contra las
            -- que hacer lookup, y el orden de insercion importa para
            -- mostrar los chips en el orden en que el usuario los cargo.
            function Seccion:TagInput(cfg)
                cfg = cfg or {}
                validarCallback("TagInput", cfg)
                local flag         = cfg.Flag or cfg.Texto or ("TagInput_" .. tostring(math.random(1e5, 1e6)))
                local maxCaracteres = cfg.MaxCaracteres or 200
                local maxTags       = cfg.MaxTags -- nil = ilimitado

                -- 'tags' es la lista interna ordenada. 'tagsLower' es un
                -- set paralelo SOLO para dedupe O(1) -- nunca se expone,
                -- nunca se guarda (evita el mismo riesgo de mutacion
                -- externa que 'seleccion' en Dropdown, ver clonarTabla).
                local tags = {}
                local tagsLower = {}
                for _, t in ipairs(cfg.Defecto or {}) do
                    if type(t) == "string" then
                        local limpio = t:gsub("^%s+", ""):gsub("%s+$", "")
                        if limpio ~= "" and not tagsLower[limpio:lower()] then
                            table.insert(tags, limpio)
                            tagsLower[limpio:lower()] = true
                        end
                    end
                end
                local function flagActual()
                    -- Copia -- mismo motivo que clonarTabla en Dropdown:
                    -- el array que se guarda en Flags no puede ser el
                    -- mismo que muta el control por dentro.
                    local copia = {}
                    for i, t in ipairs(tags) do copia[i] = t end
                    return copia
                end
                Nub.Flags[flag] = flagActual()

                local fila = Utils.Fila(contenedor, 66, siguienteOrden(), Theme.Fila)
                Nub:Registrar(fila, "BackgroundColor3", "Fila")
                Utils.Hover(fila, fila)
                registrarBuscable(fila, cfg.Texto or "TagInput", cfg.VisibleSi)
                local lblTitulo = Utils.Texto({
                    Padre = fila, Texto = cfg.Texto or "TagInput",
                    Size = UDim2.new(1, -16, 0, 18),
                    Posicion = UDim2.new(0, 8, 0, 6),
                    Truncar = true,
                })
                agregarTooltipTexto(fila, cfg.Texto or "TagInput", cfg.Tooltip, lblTitulo)

                -- Contenedor de chips: UIListLayout horizontal con Wrap,
                -- igual que pediria cualquier flujo de "burbujas" -- cada
                -- chip es un Frame chico con su label + boton ✕ propio.
                local contenedorChips = Utils.Frame({
                    Padre = fila,
                    Size = UDim2.new(1, -16, 0, 0),
                    Posicion = UDim2.new(0, 8, 0, 28),
                    Color = Theme.Entrada, Transparencia = 1, Radio = false,
                })
                local layoutChips = Instance.new("UIListLayout")
                layoutChips.FillDirection = Enum.FillDirection.Horizontal
                layoutChips.Wraps = true
                layoutChips.SortOrder = Enum.SortOrder.LayoutOrder
                layoutChips.Padding = UDim.new(0, 4)
                layoutChips.Parent = contenedorChips

                local caja = Instance.new("TextBox")
                caja.Size             = UDim2.new(1, -16, 0, 26)
                caja.Position         = UDim2.new(0, 8, 0, 32)
                caja.BackgroundColor3 = Theme.Entrada
                caja.PlaceholderText  = cfg.Placeholder or "Escribí y presioná Enter o tocá afuera…"
                caja.Text             = ""
                caja.TextColor3       = Theme.Highlight
                caja.Font             = Enum.Font.Gotham
                caja.TextSize         = 12
                caja.ClearTextOnFocus = false
                caja.BorderSizePixel  = 0
                caja.Parent = fila
                Utils.Corner(caja, 4)
                Nub:Registrar(caja, "BackgroundColor3", "Entrada")
                Nub:Registrar(caja, "TextColor3", "Highlight")
                Utils.AnilloFoco(caja)

                caja:GetPropertyChangedSignal("Text"):Connect(function()
                    if #caja.Text > maxCaracteres then
                        caja.Text = caja.Text:sub(1, maxCaracteres)
                        Utils.FlashFeedback(caja, false, Theme.Entrada)
                    end
                end)

                local dibujarChips -- forward decl (chipEliminar la usa)
                -- Encoge el chip que sale y recien despues redibuja la lista.
                local function animarSalidaChip(indice, alTerminar)
                    local chipSaliente = nil
                    for _, hijo in ipairs(contenedorChips:GetChildren()) do
                        if hijo:IsA("GuiObject") and hijo.LayoutOrder == indice then
                            chipSaliente = hijo
                            break
                        end
                    end
                    if not chipSaliente then return alTerminar() end
                    local escalaSalida = Instance.new("UIScale")
                    escalaSalida.Scale = 1
                    escalaSalida.Parent = chipSaliente
                    Utils.Tween(escalaSalida, {Scale = 0.01}, Nub.Motion.Hover, Nub.Motion.EaseSalir, Enum.EasingDirection.In)
                    task.delay(Nub.Motion.Hover, alTerminar)
                end


                local function agregarUnTag(crudo)
                    local limpio = crudo:gsub("^%s+", ""):gsub("%s+$", "")
                    if limpio == "" then return false end
                    if tagsLower[limpio:lower()] then return false end -- dedupe silencioso
                    if maxTags and #tags >= maxTags then
                        Utils.FlashFeedback(caja, false, Theme.Entrada)
                        return false
                    end
                    table.insert(tags, limpio)
                    tagsLower[limpio:lower()] = true
                    return true
                end

                -- Entrada de texto -> tags: separador es SOLO la coma
                -- (Enter final incluido) -- el espacio NO separa, para
                -- que "farm pvp" tipeado de corrido siga siendo 1 tag.
                -- split(",") -> trim -> dedupe(lower) -> insert, y los
                -- fragmentos vacios post-trim ("farm,,pvp") se descartan
                -- sin generar chip fantasma.
                local function procesarTextoCrudo(texto)
                    local huboCambio = false
                    for fragmento in (texto .. ","):gmatch("([^,]*),") do
                        if agregarUnTag(fragmento) then huboCambio = true end
                    end
                    return huboCambio
                end

                local function commitCaja()
                    if procesarTextoCrudo(caja.Text) then
                        Nub.Flags[flag] = flagActual()
                        dibujarChips(#tags)
                        if cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                        end
                    end
                    caja.Text = ""
                end

                -- Enter dispara FocusLost con enterPressed=true en
                -- Roblox -- una sola conexion cubre tipear+Enter Y
                -- pegar+click-afuera (el pegado con coma ya llega aca
                -- como texto crudo, sin conexion aparte).
                caja.FocusLost:Connect(function(_enterPressed)
                    commitCaja()
                end)

                -- Backspace con caja vacia = borrar el ultimo chip. NO
                -- es un evento nativo de TextBox (FocusLost no lo ve) --
                -- requiere InputBegan global + chequear IsFocused(),
                -- registrado con RegistrarConexion para que se limpie
                -- solo al destruir la ventana (mismo patron que el resto
                -- de conexiones globales del archivo, ver EventManager).
                Nub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, procesado)
                    if procesado then return end
                    if input.KeyCode == Enum.KeyCode.Backspace
                       and caja:IsFocused() and caja.Text == "" and #tags > 0 then
                        local indiceUltimo = #tags
                        local eliminado = table.remove(tags)
                        tagsLower[eliminado:lower()] = nil
                        Nub.Flags[flag] = flagActual()
                        animarSalidaChip(indiceUltimo, dibujarChips)
                        if cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                        end
                    end
                end))

                local function quitarTagPorIndice(i)
                    local eliminado = table.remove(tags, i)
                    if not eliminado then return end
                    tagsLower[eliminado:lower()] = nil
                    Nub.Flags[flag] = flagActual()
                    animarSalidaChip(i, dibujarChips)
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                    end
                end

                -- Redibuja TODOS los chips desde cero -- lista tipica de
                -- pocos elementos (nombres, palabras clave), no vale la
                -- pena un diff incremental para esto.
                local function reLayoutChips()
                    if not (fila and fila.Parent) then return end
                    local e = Utils.FactorEscalaUI(fila)
                    local altoChips = (#tags > 0) and math.ceil(layoutChips.AbsoluteContentSize.Y / e) or 0
                    contenedorChips.Size = UDim2.new(1, -16, 0, altoChips)
                    local yCaja = 28 + altoChips + (altoChips > 0 and 6 or 4)
                    caja.Position = UDim2.new(0, 8, 0, yCaja)
                    fila.Size = UDim2.new(1, 0, 0, yCaja + 26 + 8)
                end
                local reLayoutChipsDiferido = Utils.Diferir(reLayoutChips)
                Nub:RegistrarConexion(layoutChips:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(reLayoutChipsDiferido))
                Nub:RegistrarConexion(fila:GetPropertyChangedSignal("AbsoluteSize"):Connect(reLayoutChipsDiferido))

                dibujarChips = function(nuevoIdx)
                    for _, hijo in ipairs(contenedorChips:GetChildren()) do
                        if not hijo:IsA("UIListLayout") and not hijo:IsA("UIPadding") then hijo:Destroy() end
                    end
                    for i, t in ipairs(tags) do
                        local okMedida, medida = pcall(function()
                            return TextService:GetTextSize(t, 12, Enum.Font.GothamBold, Vector2.new(1000, 24)).X
                        end)
                        local anchoTexto = okMedida and math.ceil(medida) or (#t * 7)
                        local chip = Utils.Frame({
                            Padre = contenedorChips,
                            Size = UDim2.new(0, anchoTexto + 10 + 24, 0, 24),
                            Color = Theme.Accent, Radio = 12, Orden = i,
                        })
                        Nub:Registrar(chip, "BackgroundColor3", "Accent")
                        if nuevoIdx and i == nuevoIdx then
                            -- Chip recien agregado: entra con pop
                            local escalaChip = Instance.new("UIScale")
                            escalaChip.Scale = 0.6
                            escalaChip.Parent = chip
                            Utils.Tween(escalaChip, {Scale = 1}, Nub.Motion.Expand, Nub.Motion.EasePop, Enum.EasingDirection.Out)
                        end
                        Utils.Texto({
                            Padre = chip, Texto = t,
                            Size = UDim2.new(0, anchoTexto + 2, 1, 0),
                            Posicion = UDim2.new(0, 10, 0, 0),
                            Tamano = 12, Fuente = Enum.Font.GothamBold,
                            Color = Color3.fromRGB(255, 255, 255),
                            Alineacion = Enum.TextXAlignment.Left, Categoria = "titulo",
                        })
                        local btnX = Instance.new("TextButton")
                        btnX.BackgroundTransparency = 1
                        btnX.Text = "×"
                        btnX.Font = Enum.Font.GothamBold
                        btnX.TextSize = 16
                        btnX.TextColor3 = Color3.fromRGB(255, 255, 255)
                        btnX.AutoButtonColor = false
                        btnX.Size = UDim2.new(0, 22, 1, 0)
                        btnX.Position = UDim2.new(1, -24, 0, 0)
                        btnX.Parent = chip
                        btnX.MouseButton1Click:Connect(function()
                            quitarTagPorIndice(i)
                        end)
                    end
                    task.defer(reLayoutChips)
                end
                dibujarChips()

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        if type(v) ~= "table" then
                            Nub:_RegistrarError("TagInput.Set (valor invalido)",
                                "flag '" .. tostring(flag) .. "' esperaba un array de strings y recibió " .. typeof(v) .. ". Se ignoró.")
                            return
                        end
                        tags = {}
                        tagsLower = {}
                        for _, t in ipairs(v) do
                            if type(t) == "string" then
                                local limpio = t:gsub("^%s+", ""):gsub("%s+$", "")
                                if limpio ~= "" and not tagsLower[limpio:lower()] then
                                    table.insert(tags, limpio)
                                    tagsLower[limpio:lower()] = true
                                end
                            end
                        end
                        Nub.Flags[flag] = flagActual()
                        dibujarChips()
                        if dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                        end
                    end,
                    Get = function() return flagActual() end,
                }
                return {
                    Set = function(...)
                        Nub.Elementos[flag].Set(normalizarArgSet(...), true)
                    end,
                    Get = function() return flagActual() end,
                }
            end

            -- 🔢 NUMBERSTEPPER — campo numérico con botones −/+ a los
            -- lados. Precision exacta (como Input) mas ayuda de botones
            -- (como Slider) sin necesitar arrastre. Para valores donde
            -- el slider es impreciso: puertos, cantidades exactas, IDs.
            function Seccion:NumberStepper(cfg)
                cfg = cfg or {}
                validarCallback("NumberStepper", cfg)
                local flag = cfg.Flag or cfg.Texto or ("NumberStepper_" .. tostring(math.random(1e5, 1e6)))

                local minimo = cfg.Min or 0
                local maximo = cfg.Max or 100
                if minimo >= maximo then
                    advertirDev("NumberStepper", cfg.Texto, "'Min' (" .. minimo .. ") es mayor o igual a 'Max' (" .. maximo .. "). Se ajustó Max a Min + 1.")
                    maximo = minimo + 1
                end
                local incremento = cfg.Incremento or 1
                if incremento <= 0 then
                    advertirDev("NumberStepper", cfg.Texto, "'Incremento' (" .. tostring(cfg.Incremento) .. ") debe ser mayor a 0. Se usó 1.")
                    incremento = 1
                end
                local decimales = cfg.Decimales
                if decimales == nil then
                    -- Cuenta decimales de 'incremento' (ej. 0.1 -> 1, 0.25 -> 2)
                    local texto = tostring(incremento)
                    local punto = texto:find("%.")
                    decimales = punto and (#texto - punto) or 0
                elseif decimales < 0 then
                    advertirDev("NumberStepper", cfg.Texto, "'Decimales' (" .. decimales .. ") no puede ser negativo. Se usó 0.")
                    decimales = 0
                end
                local prefijo = cfg.Prefijo or ""
                local sufijo  = cfg.Sufijo or ""

                local function redondear(v)
                    -- Mismo patron que Slider: factor inverso para
                    -- minimizar error de punto flotante con incrementos
                    -- no enteros.
                    local factor = 1 / incremento
                    return math.clamp(
                        math.floor((v - minimo) * factor + 0.5) / factor + minimo,
                        minimo, maximo
                    )
                end

                local valor
                if cfg.Defecto == nil then
                    valor = minimo
                elseif type(cfg.Defecto) ~= "number" then
                    advertirDev("NumberStepper", cfg.Texto, "'Defecto' debe ser number. Se usó 'Min' (" .. minimo .. ").")
                    valor = minimo
                else
                    local clampeado = math.clamp(cfg.Defecto, minimo, maximo)
                    local snapeado = redondear(clampeado)
                    if math.abs(snapeado - clampeado) > 1e-9 then
                        advertirDev("NumberStepper", cfg.Texto,
                            "'Defecto' (" .. cfg.Defecto .. ") no esta alineado a 'Incremento' (" .. incremento .. "). Se ajustó a " .. snapeado .. ".")
                    end
                    valor = snapeado
                end
                Nub.Flags[flag] = valor

                local function formatear(v)
                    local texto
                    if decimales > 0 then
                        texto = string.format("%." .. decimales .. "f", v)
                    else
                        texto = tostring(math.floor(v + 0.5))
                    end
                    return prefijo .. texto .. sufijo
                end

                -- Quita prefijo/sufijo sin patrones Lua (mismo motivo que
                -- Slider: evita bugs con caracteres magicos como "%").
                local function quitarAfijos(texto)
                    if prefijo ~= "" and texto:sub(1, #prefijo) == prefijo then
                        texto = texto:sub(#prefijo + 1)
                    end
                    if sufijo ~= "" and texto:sub(-#sufijo) == sufijo then
                        texto = texto:sub(1, -#sufijo - 1)
                    end
                    return texto
                end

                local ALTO_FILA = 32
                local fila, lbl = crearCabecera(ALTO_FILA, cfg.Texto or "NumberStepper", 1, -176)
                agregarTooltipTexto(fila, cfg.Texto or "NumberStepper", cfg.Tooltip, lbl)
                registrarBuscable(fila, cfg.Texto or "NumberStepper", cfg.VisibleSi)

                -- Zona derecha: [ − ] [ caja ] [ + ], 144px totales,
                -- anclada a 8px del borde derecho de la fila.
                local ANCHO_BOTON = 36
                local ANCHO_CAJA  = 80
                local GAP = 4
                local ALTO_CONTROL = 28
                local X0 = -168

                local btnMenos = Utils.BotonBase({
                    Padre = fila, Color = Theme.Entrada, Transparencia = 0, Radio = 5,
                    Size = UDim2.new(0, ANCHO_BOTON, 0, ALTO_CONTROL),
                    Posicion = UDim2.new(1, X0, 0.5, -ALTO_CONTROL/2),
                })
                Nub:Registrar(btnMenos, "BackgroundColor3", "Entrada")
                Utils.Texto({
                    Padre = btnMenos, Texto = "−",
                    Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
                    Alineacion = Enum.TextXAlignment.Center,
                    Fuente = Enum.Font.GothamBold, Tamano = 20,
                })

                local caja = Instance.new("TextBox")
                caja.Size = UDim2.new(0, ANCHO_CAJA, 0, ALTO_CONTROL)
                caja.Position = UDim2.new(1, X0 + ANCHO_BOTON + GAP, 0.5, -ALTO_CONTROL/2)
                caja.BackgroundColor3 = Theme.Entrada
                caja.Text = formatear(valor)
                caja.TextColor3 = Theme.Highlight
                caja.Font = Enum.Font.GothamBold
                caja.TextSize = 12
                caja.TextXAlignment = Enum.TextXAlignment.Center
                caja.ClearTextOnFocus = false
                caja.BorderSizePixel = 0
                caja.Parent = fila
                Utils.Corner(caja, 5)
                Nub:Registrar(caja, "BackgroundColor3", "Entrada")
                Nub:Registrar(caja, "TextColor3", "Highlight")
                Utils.AnilloFoco(caja)

                local btnMas = Utils.BotonBase({
                    Padre = fila, Color = Theme.Entrada, Transparencia = 0, Radio = 5,
                    Size = UDim2.new(0, ANCHO_BOTON, 0, ALTO_CONTROL),
                    Posicion = UDim2.new(1, X0 + ANCHO_BOTON + GAP + ANCHO_CAJA + GAP, 0.5, -ALTO_CONTROL/2),
                })
                Nub:Registrar(btnMas, "BackgroundColor3", "Entrada")
                Utils.Texto({
                    Padre = btnMas, Texto = "+",
                    Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
                    Alineacion = Enum.TextXAlignment.Center,
                    Fuente = Enum.Font.GothamBold, Tamano = 20,
                })

                local function aplicarCambio(signo)
                    local nuevo = redondear(valor + signo * incremento)
                    if nuevo == valor then return end -- ya esta en Min/Max
                    valor = nuevo
                    Nub.Flags[flag] = valor
                    caja.Text = formatear(valor)
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor)
                    end
                end

                -- Auto-repeat: click simple aplica 1 paso; mantener
                -- presionado repite tras un delay inicial de 0.4s, luego
                -- cada 0.1s. El guard 'idPresion' invalida loops viejos
                -- si el usuario suelta y vuelve a presionar rapido --
                -- sin esto, dos loops corriendo a la vez duplicarian los
                -- pasos. 'btn.Parent' en la condicion del while es el
                -- auto-stop si la ventana se destruye mientras se
                -- mantiene presionado.
                local idPresion = 0
                local function iniciarPresion(signo, btn)
                    idPresion = idPresion + 1
                    local miId = idPresion
                    aplicarCambio(signo)
                    task.spawn(function()
                        task.wait(0.4)
                        while idPresion == miId and btn.Parent do
                            aplicarCambio(signo)
                            task.wait(0.1)
                        end
                    end)
                end
                local function detenerPresion()
                    idPresion = idPresion + 1
                end

                Nub:RegistrarConexion(btnMenos.MouseButton1Down:Connect(function()
                    iniciarPresion(-1, btnMenos)
                end))
                Nub:RegistrarConexion(btnMenos.MouseButton1Up:Connect(detenerPresion))
                Nub:RegistrarConexion(btnMenos.MouseLeave:Connect(detenerPresion))

                Nub:RegistrarConexion(btnMas.MouseButton1Down:Connect(function()
                    iniciarPresion(1, btnMas)
                end))
                Nub:RegistrarConexion(btnMas.MouseButton1Up:Connect(detenerPresion))
                Nub:RegistrarConexion(btnMas.MouseLeave:Connect(detenerPresion))

                -- Escribir directo + Enter: mismo patron que Slider/Input
                -- con Tipo="number". Se chequea enterPressed (igual que
                -- ambos) para no reprocesar si el usuario solo toco la
                -- caja por error y click-afuera sin escribir nada --
                -- si no, se dispara un flash de validacion sin sentido.
                -- Si no parsea, revierte + flash rojo.
                caja.FocusLost:Connect(function(enterPressed)
                    if not enterPressed then return end
                    local texto = quitarAfijos(caja.Text)
                    local num = tonumber(texto)
                    if not num then
                        caja.Text = formatear(valor)
                        Utils.FlashFeedback(caja, false, Theme.Entrada)
                        return
                    end
                    local nuevo = redondear(num)
                    valor = nuevo
                    Nub.Flags[flag] = valor
                    caja.Text = formatear(valor)
                    Utils.FlashFeedback(caja, true, Theme.Entrada)
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor)
                    end
                end)

                -- Flechas arriba/abajo con foco en la caja: atajo gratis
                -- de teclado. Si el motor no dispara InputBegan para
                -- flechas con un TextBox enfocado, este bloque
                -- simplemente no hace nada -- no afecta el resto del
                -- control.
                Nub:RegistrarConexion(caja.InputBegan:Connect(function(input)
                    if not caja:IsFocused() then return end
                    if input.KeyCode == Enum.KeyCode.Up then
                        aplicarCambio(1)
                    elseif input.KeyCode == Enum.KeyCode.Down then
                        aplicarCambio(-1)
                    end
                end))

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        if type(v) ~= "number" then
                            Nub:_RegistrarError("NumberStepper.Set (valor no numérico)",
                                "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) .. " en vez de number. Se ignoró.")
                            return
                        end
                        valor = redondear(v)
                        Nub.Flags[flag] = valor
                        caja.Text = formatear(valor)
                        if dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor)
                        end
                    end,
                    Get = function() return valor end,
                }
                return {
                    Set = function(...)
                        Nub.Elementos[flag].Set(normalizarArgSet(...), true)
                    end,
                    Get = function() return valor end,
                }
            end

            -- 📝 INPUT — cuadro de texto para que el usuario escriba.
            function Seccion:Input(cfg)
                cfg = cfg or {}
                validarCallback("Input", cfg)
                local flag  = cfg.Flag or cfg.Texto or ("Input_" .. tostring(math.random(1e5, 1e6)))
                local valor = cfg.Defecto or ""
                Nub.Flags[flag] = valor

                local esArea = cfg.Tipo == "textarea"
                local altoArea = math.clamp(cfg.Alto or 100, 50, 400)
                local PAD_A, GAP_A = 9, 8
                local fila, lblInput
                if esArea then
                    fila, lblInput = crearCabecera(32, cfg.Texto or "Input", nil, nil, "manual")
                    lblInput.AutomaticSize = Enum.AutomaticSize.Y
                    lblInput.Size = UDim2.new(1, -20, 0, 0)
                    lblInput.Position = UDim2.new(0, 10, 0, PAD_A)
                else
                    fila, lblInput = crearCabecera(32, cfg.Texto or "Input", 0.45)
                end
                agregarTooltipTexto(fila, cfg.Texto or "Input", cfg.Tooltip, lblInput)
                registrarBuscable(fila, cfg.Texto or "Input", cfg.VisibleSi)

                local caja = Instance.new("TextBox")
                caja.Size             = UDim2.new(0.5, -12, 0, 26)
                caja.Position         = UDim2.new(0.5, 0, 0.5, -13)
                caja.BackgroundColor3 = Theme.Entrada
                caja.Text             = tostring(valor)
                caja.PlaceholderText  = cfg.Placeholder or ""
                caja.TextColor3       = Theme.Highlight
                caja.Font             = Enum.Font.Gotham
                caja.TextSize         = 13
                caja.ClearTextOnFocus = false
                caja.BorderSizePixel  = 0
                caja.Parent = fila
                Utils.Corner(caja, 4)
                Nub:Registrar(caja, "BackgroundColor3", "Entrada")
                Nub:Registrar(caja, "TextColor3", "Highlight")
                Utils.AnilloFoco(caja)

                if esArea then
                    caja.Size             = UDim2.new(1, -20, 0, altoArea)
                    caja.Position         = UDim2.new(0, 10, 0, PAD_A + 24 + GAP_A)
                    caja.MultiLine        = true
                    caja.TextWrapped      = true
                    caja.TextXAlignment   = Enum.TextXAlignment.Left
                    caja.TextYAlignment   = Enum.TextYAlignment.Top
                    caja.ClipsDescendants = true
                    local relleno = Instance.new("UIPadding")
                    relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                    relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
                    relleno.Parent = caja
                end

                -- Limite de caracteres. Evita que un texto gigante
                -- pegado por el usuario (o pegado por error) rompa el
                -- calculo de tamaño del cuadro en ejecutores de gama baja.
                local maxCaracteres = cfg.MaxCaracteres or (esArea and 2000 or 200)

                -- Contador visible ("160/200") en la esquina inferior
                -- derecha del campo, pero SOLO cuando el texto se acerca
                -- al limite (>= 80%). Mostrarlo siempre (ej. "4/200" en
                -- un campo donde el usuario escribio "farm") es ruido
                -- visual permanente sin aportar nada -- el contador tiene
                -- mas sentido como AVISO ("te estas por quedar sin
                -- espacio") que como display de estado constante.
                -- cfg.OcultarContador = true lo desactiva del todo, por
                -- si un campo puntual no lo necesita ni como aviso.
                local umbralContador = math.floor(maxCaracteres * 0.8)
                local lblContador, pildoraContador, paddingCaja
                local COLOR_AVISO = Color3.fromRGB(215, 160, 50)
                local COLOR_LIMITE = Color3.fromRGB(190, 60, 60)
                if not cfg.OcultarContador then
                    pildoraContador = Utils.Frame({
                        Padre = caja, Size = UDim2.new(0, 0, 0, 16),
                        Posicion = esArea and UDim2.new(1, -6, 1, -6) or UDim2.new(1, -6, 0.5, 0),
                        Ancla = esArea and Vector2.new(1, 1) or Vector2.new(1, 0.5),
                        Color = COLOR_AVISO, Radio = 8,
                    })
                    pildoraContador.AutomaticSize = Enum.AutomaticSize.X
                    pildoraContador.Visible = false
                    pildoraContador.ZIndex = caja.ZIndex + 2
                    local rellenoPildora = Instance.new("UIPadding")
                    rellenoPildora.PaddingLeft, rellenoPildora.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)
                    rellenoPildora.Parent = pildoraContador
                    lblContador = Utils.Texto({
                        Padre = pildoraContador, Texto = "",
                        Size = UDim2.new(0, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
                        Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.GothamBold,
                        Tamano = 10, Color = Color3.fromRGB(255, 255, 255), Categoria = "titulo",
                    })
                    lblContador.AutomaticSize = Enum.AutomaticSize.X
                    lblContador.ZIndex = pildoraContador.ZIndex + 1
                    if not esArea then
                        paddingCaja = Instance.new("UIPadding")
                        paddingCaja.Parent = caja
                    end
                end

                local function actualizarContador()
                    if not lblContador then return end
                    local n = #caja.Text
                    local visible = n >= umbralContador
                    pildoraContador.Visible = visible
                    if visible then
                        lblContador.Text = n .. "/" .. maxCaracteres
                        pildoraContador.BackgroundColor3 = (n >= maxCaracteres) and COLOR_LIMITE or COLOR_AVISO
                    end
                    if paddingCaja then
                        paddingCaja.PaddingRight = UDim.new(0, visible and 58 or 0)
                    end
                end
                actualizarContador()

                caja:GetPropertyChangedSignal("Text"):Connect(function()
                    if #caja.Text > maxCaracteres then
                        caja.Text = caja.Text:sub(1, maxCaracteres)
                        Utils.FlashFeedback(caja, false, Theme.Entrada)
                    end
                    actualizarContador()
                end)

                caja.FocusLost:Connect(function(entrar)
                    local textoLimpio = caja.Text:gsub("^%s+", ""):gsub("%s+$", "")
                    local valorFinal = textoLimpio

                    -- Validacion opcional (aditiva, no rompe el uso
                    -- normal de texto libre si no se pasa Tipo). Los dos
                    -- casos soportados: "number" (con Min/Max clampeados
                    -- si se pasan, entrega un numero real al Callback) y
                    -- "pattern" (un patron Lua que el texto final debe
                    -- matchear entero). Si la validacion falla, se
                    -- restaura el ultimo valor VALIDO en vez de dejar
                    -- pasar el texto invalido -- consistente con como ya
                    -- se maneja un Hex invalido en ColorPicker.
                    if cfg.Tipo == "number" then
                        local n = tonumber(textoLimpio)
                        if not n then
                            caja.Text = tostring(valor)
                            Utils.FlashFeedback(caja, false, Theme.Entrada)
                            return
                        end
                        if cfg.Min and n < cfg.Min then n = cfg.Min end
                        if cfg.Max and n > cfg.Max then n = cfg.Max end
                        valorFinal = n
                    elseif cfg.Tipo == "pattern" and cfg.Regex then
                        -- Se ancla el patron a la cadena completa
                        -- (^patron$) para que "matchear en algun punto"
                        -- no cuente como valido -- ej. Regex = "%d+" no
                        -- deberia aceptar "12a3". Si el propio Regex ya
                        -- trae ^/$ (lo idiomatico para mucha gente), se
                        -- limpian antes de anclar: en un patron Lua, un
                        -- '^' fuera de la primera posicion NO es ancla,
                        -- es literal -- pasar Regex = "^%d+$" sin esta
                        -- limpieza terminaria en "^^%d+$$", que nunca
                        -- matchea nada. Con la limpieza, el patron
                        -- funciona igual con o sin anclas explicitas.
                        local patronLimpio = cfg.Regex:gsub("^%^", ""):gsub("%$$", "")
                        if not textoLimpio:match("^" .. patronLimpio .. "$") then
                            caja.Text = tostring(valor)
                            Utils.FlashFeedback(caja, false, Theme.Entrada)
                            return
                        end
                    end

                    valor = valorFinal
                    caja.Text = tostring(valorFinal)
                    Nub.Flags[flag] = valor
                    -- Flash solo si habia algo que validar (Tipo
                    -- definido) -- un Input de texto libre sin Tipo no
                    -- "valida" nada, asi que un flash verde en cada
                    -- Enter seria ruido sin significado real.
                    if cfg.Tipo == "number" or cfg.Tipo == "pattern" then
                        Utils.FlashFeedback(caja, true, Theme.Entrada)
                    end
                    if (entrar or esArea) and cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "Input", valor)
                    end
                end)

                if esArea then
                    local function reLayoutArea()
                        if not (fila and fila.Parent) then return end
                        local e = Utils.FactorEscalaUI(fila)
                        local hLbl = math.ceil(lblInput.AbsoluteSize.Y / e)
                        if hLbl <= 0 then hLbl = lblInput.TextSize + 4 end
                        local yCaja = PAD_A + hLbl + GAP_A
                        caja.Position = UDim2.new(0, 10, 0, yCaja)
                        fila.Size = UDim2.new(1, 0, 0, yCaja + altoArea + PAD_A)
                    end
                    Nub:RegistrarConexion(lblInput:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutArea)))
                    task.defer(reLayoutArea)
                end

                local function fijar(v)
                    if type(v) ~= "string" and type(v) ~= "number" then
                        Nub:_RegistrarError("Input.Set (valor inválido)",
                            "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                            " en vez de string/number. Se ignoró.")
                        return false
                    end
                    valor = v
                    caja.Text = tostring(v)
                    Nub.Flags[flag] = v
                    return true
                end

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        if fijar(v) and dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "Input", v)
                        end
                    end,
                    Get = function() return valor end,
                }
                return {
                    Set = function(...)
                        local v = normalizarArgSet(...)
                        if fijar(v) and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "Input", v)
                        end
                    end,
                    Get = function() return valor end,
                }
            end

            -- 🔘 RADIO GROUP — alternativa a Dropdown cuando hay pocas
            -- opciones (2-4 es el caso tipico): todas quedan visibles
            -- en una fila horizontal, sin desplegar nada. Selección
            -- única, igual que un Dropdown sin Multi.
            function Seccion:RadioGroup(cfg)
                cfg = cfg or {}
                validarCallback("RadioGroup", cfg)
                local flag     = cfg.Flag or cfg.Texto or ("RadioGroup_" .. tostring(math.random(1e5, 1e6)))
                local opciones = cfg.Opciones or {}
                local opcionesVistas, opcionesUnicas = {}, {}
                for _, op in ipairs(opciones) do
                    if opcionesVistas[op] then
                        advertirDev("RadioGroup", cfg.Texto, "opción duplicada (se ignora): " .. tostring(op))
                    else
                        opcionesVistas[op] = true
                        table.insert(opcionesUnicas, op)
                    end
                end
                opciones = opcionesUnicas
                local valor    = cfg.Defecto or opciones[1]
                Nub.Flags[flag] = valor

                local PAD_V, GAP_TITULO, GAP_BOTONES = 9, 8, 10
                local fila, lbl = crearCabecera(60, cfg.Texto or "RadioGroup", nil, nil, "manual")
                lbl.AutomaticSize = Enum.AutomaticSize.Y
                lbl.Size = UDim2.new(1, -20, 0, 0)
                lbl.Position = UDim2.new(0, 10, 0, PAD_V)
                agregarTooltipTexto(fila, cfg.Texto or "RadioGroup", cfg.Tooltip, lbl)
                registrarBuscable(fila, cfg.Texto or "RadioGroup", cfg.VisibleSi)

                local filaBotones = Utils.Frame({
                    Padre = fila, Size = UDim2.new(1, -20, 0, 32),
                    Posicion = UDim2.new(0, 10, 0, PAD_V + 20 + GAP_TITULO), Transparencia = 1,
                })
                local lblRef
                local layoutBotones = Instance.new("UIListLayout")
                layoutBotones.FillDirection   = Enum.FillDirection.Horizontal
                layoutBotones.Padding         = UDim.new(0, GAP_BOTONES)
                layoutBotones.SortOrder       = Enum.SortOrder.LayoutOrder
                layoutBotones.Parent          = filaBotones

                local botonesOp = {}

                local function refrescarVisual()
                    for opcion, btn in pairs(botonesOp) do
                        local activo = (opcion == valor)
                        Utils.Tween(btn, {BackgroundColor3 = activo and Theme.Accent or Theme.Entrada}, Nub.Motion.Hover)
                        local lblBtn = btn:FindFirstChildOfClass("TextLabel")
                        if lblBtn then lblBtn.TextColor3 = activo and Theme.Text or Theme.TextDark end
                    end
                end

                local function esOpcionValida(v)
                    for _, op in ipairs(opciones) do
                        if op == v then return true end
                    end
                    return false
                end

                local function elegir(opcion)
                    if opcion == valor then return end
                    if not esOpcionValida(opcion) then
                        Nub:_RegistrarError("RadioGroup.Set (opción inválida)",
                            "flag '" .. tostring(flag) .. "' recibió " .. tostring(opcion) ..
                            ", que no está en la lista de Opciones. Se ignoró.")
                        return
                    end
                    valor = opcion
                    Nub.Flags[flag] = valor
                    refrescarVisual()
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "RadioGroup", valor)
                    end
                end

                for i, opcion in ipairs(opciones) do
                    local activo = (opcion == valor)
                    local btn = Utils.BotonBase({
                        Padre = filaBotones,
                        Size = UDim2.new(1 / math.max(#opciones, 1), -math.floor(GAP_BOTONES * (math.max(#opciones, 1) - 1) / math.max(#opciones, 1) + 0.5), 1, 0),
                        Color = activo and Theme.Accent or Theme.Entrada,
                        Transparencia = 0, Radio = 6, Orden = i,
                    })
                    -- obtenerColorBase compartido con el Nub:Registrar
                    -- de abajo: mismo criterio de "cual es el color
                    -- correcto ahora" tanto para el tema como para el
                    -- hover -- evita que Hover revierta a un color viejo
                    -- si 'valor' cambio mientras el dedo/cursor seguia
                    -- encima (ver comentario en Utils.Hover).
                    local function colorBaseBtn()
                        return (opcion == valor) and Theme.Accent or Theme.Entrada
                    end
                    -- Hitbox ampliado (24px visual -> 38px efectivo). Se crea
                    -- como HIJO de 'btn' (ver Utils.HitboxAmpliado) para no
                    -- interferir con 'layoutBotones', el UIListLayout
                    -- horizontal que organiza los botones de opcion entre si.
                    -- Padding conservador (7, no mas): con 6px de gap entre
                    -- opciones, ya genera ~8px de solape con el vecino.
                    local hitboxBtn = Utils.HitboxAmpliado(btn, 7)
                    Utils.Hover(hitboxBtn, btn, nil, nil, colorBaseBtn)
                    Nub:Registrar(btn, "BackgroundColor3", colorBaseBtn)
                    local lblBtn = Utils.Texto({
                        Padre = btn, Texto = tostring(opcion),
                        Size = UDim2.new(1, 0, 1, 0),
                        Alineacion = Enum.TextXAlignment.Center,
                        Tamano = 13, Truncar = true,
                        Color = activo and Theme.Text or Theme.TextDark,
                    })
                    if not lblRef then lblRef = lblBtn end
                    Nub:Registrar(lblBtn, "TextColor3", function()
                        return (opcion == valor) and Theme.Text or Theme.TextDark
                    end)
                    Utils.ClickConfiable(hitboxBtn, function() elegir(opcion) end, btn)
                    botonesOp[opcion] = btn
                end

                local function reLayoutRadio()
                    if not (fila and fila.Parent) then return end
                    local e = Utils.FactorEscalaUI(fila)
                    local hLbl = math.ceil(lbl.AbsoluteSize.Y / e)
                    if hLbl <= 0 then hLbl = lbl.TextSize + 4 end
                    local tamBtn = lblRef and lblRef.TextSize or 13
                    local hBtn = math.max(32, tamBtn + 18)
                    filaBotones.Position = UDim2.new(0, 10, 0, PAD_V + hLbl + GAP_TITULO)
                    filaBotones.Size = UDim2.new(1, -20, 0, hBtn)
                    fila.Size = UDim2.new(1, 0, 0, PAD_V + hLbl + GAP_TITULO + hBtn + PAD_V)
                end
                Nub:RegistrarConexion(lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutRadio)))
                if lblRef then
                    Nub:RegistrarConexion(lblRef:GetPropertyChangedSignal("TextSize"):Connect(Utils.Diferir(reLayoutRadio)))
                end
                task.defer(reLayoutRadio)

                local function fijar(v)
                    if not esOpcionValida(v) then
                        Nub:_RegistrarError("RadioGroup.Set (opción inválida)",
                            "flag '" .. tostring(flag) .. "' recibió " .. tostring(v) ..
                            ", que no está en la lista de Opciones. Se ignoró.")
                        return
                    end
                    valor = v
                    refrescarVisual()
                    Nub.Flags[flag] = v
                end

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        fijar(v)
                        if dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "RadioGroup", v)
                        end
                    end,
                    Get = function() return valor end,
                }
                return {
                    Set = function(...) elegir(normalizarArgSet(...)) end,
                    Get = function() return valor end,
                }
            end

            -- 📋 DROPDOWN — lista desplegable de opciones (simple o Multi), con buscador si hay más de 8.
            function Seccion:Dropdown(cfg)
                cfg = cfg or {}
                validarCallback("Dropdown", cfg)
                local flag     = cfg.Flag or cfg.Texto or ("Dropdown_" .. tostring(math.random(1e5, 1e6)))
                local function normalizarEntradas(lista)
                    local nuevasOpciones, nuevaMeta, pendienteSep = {}, {}, false
                    local vistas = {}
                    local function esNueva(titulo)
                        if vistas[titulo] then
                            advertirDev("Dropdown", cfg.Texto, "opción duplicada (se ignora): " .. tostring(titulo))
                            return false
                        end
                        vistas[titulo] = true
                        return true
                    end
                    for _, e in ipairs(lista or {}) do
                        if type(e) == "string" then
                            if esNueva(e) then
                                table.insert(nuevasOpciones, e)
                                if pendienteSep and #nuevasOpciones > 1 then nuevaMeta[e] = { sep = true } end
                                pendienteSep = false
                            end
                        elseif type(e) == "table" then
                            if e.Tipo == "Divider" then
                                pendienteSep = true
                            elseif type(e.Titulo) == "string" and e.Titulo ~= "" and esNueva(e.Titulo) then
                                table.insert(nuevasOpciones, e.Titulo)
                                nuevaMeta[e.Titulo] = {
                                    Descripcion = e.Descripcion, Icono = e.Icono,
                                    Locked = e.Locked == true, LockedTitle = e.LockedTitle,
                                    sep = pendienteSep and #nuevasOpciones > 1,
                                }
                                pendienteSep = false
                            end
                        end
                    end
                    return nuevasOpciones, nuevaMeta
                end
                local entradas = clonarTabla(cfg.Opciones or {})
                local opciones, meta = normalizarEntradas(entradas)
                local multi    = cfg.Multi or false
                local seleccion = {}
                if multi then
                    for _, v in ipairs(cfg.Defecto or {}) do seleccion[v] = true end
                elseif cfg.Defecto then
                    seleccion[cfg.Defecto] = true
                end
                -- Se guarda una COPIA en Flags, no la tabla 'seleccion' en si
                -- -- ver 'clonarTabla' arriba, evita que un script externo
                -- que mute Nub.Flags[flag] directamente corrompa el
                -- estado visual interno del control.
                Nub.Flags[flag] = multi and clonarTabla(seleccion) or cfg.Defecto

                local UMBRAL_BUSQUEDA = 8
                local conBusqueda     = #opciones > UMBRAL_BUSQUEDA
                local ALTO_FILA       = 32
                local ALTO_BUSQUEDA   = conBusqueda and 24 or 0

                local marco = Utils.Frame({
                    Padre = contenedor,
                    Size = UDim2.new(1, 0, 0, ALTO_FILA),
                    Color = Theme.Fila, Orden = siguienteOrden(), Recortar = true,
                })
                Nub:Registrar(marco, "BackgroundColor3", "Fila")
                registrarBuscable(marco, cfg.Texto or "Dropdown", cfg.VisibleSi)

                local cabecera = Utils.BotonBase({Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA)})
                local flechaDropdown
                Utils.Hover(cabecera, marco, nil, nil, nil, function(entrando)
                    if not (Nub.Opciones.MicroInteracciones and flechaDropdown and flechaDropdown.Parent) then return end
                    Utils.Tween(flechaDropdown, {
                        ImageColor3 = entrando and Theme.Text:Lerp(Color3.new(1, 1, 1), Nub.Motion.HoverIntensidad) or Theme.Text
                    }, Nub.Motion.Hover)
                end)
                local lbl = Utils.Texto({
                    Padre = marco,
                    Size = UDim2.new(1, cfg.Tooltip and -52 or -30, 0, ALTO_FILA),
                    Truncar = true,
                })
                do
                    -- Icono propio en vez de texto "▼" (mismo motivo que
                    -- los demas reemplazos). Sin Color explicito el
                    -- TextLabel original tomaba el tema "Text" via
                    -- Utils.Texto -- se preserva el mismo tinte aca.
                    flechaDropdown = Instance.new("ImageLabel")
                    flechaDropdown.BackgroundTransparency = 1
                    flechaDropdown.Image = "rbxassetid://83472139709682"
                    flechaDropdown.ScaleType = Enum.ScaleType.Fit
                    flechaDropdown.Size = UDim2.new(0, 10, 0, 10)
                    flechaDropdown.AnchorPoint = Vector2.new(0.5, 0.5)
                    flechaDropdown.Position = UDim2.new(1, -12, 0.5, 0)
                    flechaDropdown.Parent = marco
                    Nub:Registrar(flechaDropdown, "ImageColor3", "Text")
                end
                if cfg.Tooltip then agregarTooltip(marco, UDim2.new(1, -46, 0, 6), cfg.Tooltip) end

                local searchBox
                local function crearBuscador()
                    searchBox = Instance.new("TextBox")
                    searchBox.Size             = UDim2.new(1, -8, 0, ALTO_BUSQUEDA - 4)
                    searchBox.Position         = UDim2.new(0, 4, 0, ALTO_FILA + 2)
                    searchBox.BackgroundColor3 = Theme.Entrada
                    searchBox.Text             = ""
                    searchBox.PlaceholderText  = "🔍 Buscar..."
                    searchBox.TextColor3       = Theme.Text
                    searchBox.Font             = Enum.Font.Gotham
                    searchBox.TextSize         = 10
                    searchBox.BorderSizePixel  = 0
                    searchBox.ClearTextOnFocus = false
                    searchBox.Parent = marco
                    Utils.Corner(searchBox, 4)
                    Nub:Registrar(searchBox, "BackgroundColor3", "Entrada")
                    Nub:Registrar(searchBox, "TextColor3", "Text")
                    Utils.AnilloFoco(searchBox)
                end
                if conBusqueda then crearBuscador() end

                local listaOp = Utils.Frame({
                    Padre = marco,
                    Size = UDim2.new(1, 0, 0, #opciones * 32),
                    Posicion = UDim2.new(0, 0, 0, ALTO_FILA + ALTO_BUSQUEDA),
                    Transparencia = 1,
                })
                local layoutOp = Instance.new("UIListLayout")
                layoutOp.Padding   = UDim.new(0, 4)
                layoutOp.SortOrder = Enum.SortOrder.LayoutOrder
                layoutOp.Parent    = listaOp

                local function valorMostrado()
                    if multi then
                        local nombres = {}
                        for _, o in ipairs(opciones) do
                            if seleccion[o] then table.insert(nombres, o) end
                        end
                        return #nombres > 0 and table.concat(nombres, ", ") or "Ninguno"
                    end
                    for k, v in pairs(seleccion) do if v then return k end end
                    return "Ninguno"
                end
                local function actualizarLabel()
                    lbl.Text = (cfg.Texto or "Dropdown") .. ": " .. valorMostrado()
                end
                actualizarLabel()

                local botonesOp = {}
                local strokesOp = {}
                local function crearOpcion(opcion, indiceOp, onClick)
                    local info = meta[opcion]
                    local bloqueada = info ~= nil and info.Locked == true
                    local btn = Utils.BotonBase({
                        Padre = listaOp,
                        Size = UDim2.new(1, 0, 0, 28),
                        Color = seleccion[opcion] and Theme.Accent or Theme.Entrada,
                        Transparencia = bloqueada and 0.45 or 0, Orden = indiceOp, Radio = 4,
                    })
                    Nub:Registrar(btn, "BackgroundColor3", function()
                        return seleccion[opcion] and Theme.Accent or Theme.Entrada
                    end)
                    local textoTitulo = ((info and info.Icono) and (tostring(info.Icono) .. " ") or "") .. opcion
                    local textoDerecha = info and (bloqueada and ("🔒 " .. tostring(info.LockedTitle or "Bloqueado")) or info.Descripcion)
                    if textoDerecha then
                        Utils.Texto({
                            Padre = btn, Texto = textoTitulo, Tamano = 12,
                            Size = UDim2.new(0.55, -12, 1, 0), Posicion = UDim2.new(0, 12, 0, 0), Truncar = true,
                            TextoTransparencia = bloqueada and 0.45 or 0,
                        })
                        Utils.Texto({
                            Padre = btn, Texto = tostring(textoDerecha), Tamano = 10,
                            Size = UDim2.new(0.45, -10, 1, 0), Posicion = UDim2.new(0.55, 0, 0, 0),
                            Alineacion = Enum.TextXAlignment.Right, Truncar = true,
                            Color = Theme.TextDark, ColorTema = "TextDark", TextoTransparencia = 0.1,
                        })
                    else
                        Utils.Texto({
                            Padre = btn, Texto = textoTitulo, Tamano = 12,
                            Size = UDim2.new(1, -20, 1, 0), Posicion = UDim2.new(0, 12, 0, 0),
                        })
                    end
                    if info and info.sep then
                        local separador = Utils.Frame({
                            Padre = btn, Size = UDim2.new(1, -8, 0, 1),
                            Posicion = UDim2.new(0, 4, 0, -2), Color = Theme.Border,
                            Transparencia = 0.3, Radio = false,
                        })
                        Nub:Registrar(separador, "BackgroundColor3", "Border")
                    end
                    -- Hitbox ampliado (22px visual -> 34px efectivo). Hijo
                    -- de 'btn', no hermano dentro de 'listaOp' (que tiene su
                    -- propio UIListLayout vertical). Padding mas chico que
                    -- en otros controles a proposito: 'listaOp' tiene solo
                    -- 2px de gap entre opciones, el mas apretado de toda la
                    -- libreria -- subir mas el padding aca generaria mucho
                    -- solape entre opciones consecutivas.
                    local hitboxOp = Utils.HitboxAmpliado(btn, 2)
                    Utils.ClickConfiable(hitboxOp, function()
                        if bloqueada then return end
                        onClick(opcion)
                    end, btn)
                    botonesOp[opcion] = btn

                    -- Stroke propio para "primera coincidencia al buscar" --
                    -- separado del color de fondo (que ya indica "seleccionado")
                    -- para que ambos estados se puedan ver a la vez sin
                    -- confundirse. Arranca invisible.
                    strokesOp[opcion] = Utils.Stroke(btn, Theme.Highlight, 1.5, 1)
                    Nub:Registrar(strokesOp[opcion], "Color", "Highlight")
                end

                local function refrescarVisual()
                    for opcion, btn in pairs(botonesOp) do
                        btn.BackgroundColor3 = seleccion[opcion] and Theme.Accent or Theme.Entrada
                    end
                    actualizarLabel()
                end

                local function opcionesVisiblesActuales()
                    local n = 0
                    for _, btn in pairs(botonesOp) do if btn.Visible then n = n + 1 end end
                    return n
                end

                -- Se guarda en una variable de closure para que el
                -- handler de Enter (mas abajo) sepa cual es "la primera"
                -- sin tener que recalcularla desde cero.
                local primeraCoincidencia = nil

                local function filtrarOpciones(texto)
                    texto = texto:lower()
                    for opcion, btn in pairs(botonesOp) do
                        btn.Visible = texto == "" or opcion:lower():find(texto, 1, true) ~= nil
                    end
                    listaOp.Size = UDim2.new(1, 0, 0, math.max(opcionesVisiblesActuales(), 1) * 32)

                    -- Primera coincidencia: se recorre 'opciones' (el
                    -- array en orden original) en vez de 'botonesOp'
                    -- (tabla hash, sin orden garantizado) para que
                    -- "primera" sea consistente con lo que el usuario
                    -- ve arriba de la lista.
                    local anterior = primeraCoincidencia
                    primeraCoincidencia = nil
                    if texto ~= "" then
                        for _, opcion in ipairs(opciones) do
                            local btn = botonesOp[opcion]
                            if btn and btn.Visible then
                                primeraCoincidencia = opcion
                                break
                            end
                        end
                    end
                    if anterior ~= primeraCoincidencia then
                        if anterior and strokesOp[anterior] then
                            strokesOp[anterior].Transparency = 1
                        end
                        if primeraCoincidencia and strokesOp[primeraCoincidencia] then
                            strokesOp[primeraCoincidencia].Transparency = 0
                        end
                    end
                end

                local alternar
                local actualizarOpciones -- forward-declare, se define despues de elegir()/obtenerValor()
                local function agregarOpcion(...)
                    local nueva = normalizarArgSet(...)
                    if type(nueva) ~= "string" or nueva == "" then return false end
                    for _, o in ipairs(opciones) do
                        if o == nueva then return false end
                    end
                    local copia = clonarTabla(entradas)
                    table.insert(copia, nueva)
                    actualizarOpciones(copia)
                    return true
                end

                local function eliminarOpcion(...)
                    local objetivo = normalizarArgSet(...)
                    local copia, encontrada = {}, false
                    for _, e in ipairs(entradas) do
                        local titulo = type(e) == "string" and e or (type(e) == "table" and e.Titulo or nil)
                        if titulo == objetivo then encontrada = true else table.insert(copia, e) end
                    end
                    if not encontrada then return false end
                    actualizarOpciones(copia)
                    return true
                end

                local function limpiarOpciones()
                    actualizarOpciones({})
                end

                local function elegir(opcion, sinAlternar)
                    if multi then
                        seleccion[opcion] = not seleccion[opcion] or nil
                    else
                        seleccion = {[opcion] = true}
                    end
                    Nub.Flags[flag] = multi and clonarTabla(seleccion) or opcion
                    refrescarVisual()
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "Dropdown", multi and clonarTabla(seleccion) or opcion)
                    end
                    if not multi and not sinAlternar then alternar() end
                end

                -- Validacion de Set publico: en modo simple, 'v' tiene que
                -- ser una de las Opciones; en modo Multi, 'v' tiene que ser
                -- una tabla (no valida cada elemento individualmente, para
                -- no ser demasiado estricto con listas armadas a mano).
                local function esValorValidoDropdown(v)
                    if multi then return type(v) == "table" end
                    for _, op in ipairs(opciones) do
                        if op == v then return true end
                    end
                    return false
                end

                for i, opcion in ipairs(opciones) do
                    crearOpcion(opcion, i, elegir)
                end

                alternar = hacerExpandible(marco, ALTO_FILA, function()
                    local n = conBusqueda and opcionesVisiblesActuales() or #opciones
                    return ALTO_FILA + ALTO_BUSQUEDA + math.max(n, 1) * 32 + 4
                end)


                Utils.ClickConfiable(cabecera, function()
                    local abierto = alternar()
                    if conBusqueda then
                        searchBox.Visible = abierto
                        if abierto then
                            searchBox.Text = ""
                            filtrarOpciones("")
                            if not Nub.Capacidades.EsTactil then searchBox:CaptureFocus() end
                        else
                            searchBox:ReleaseFocus()
                        end
                    end
                end)

                local function conectarBuscador()
                    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                        filtrarOpciones(searchBox.Text)
                        Utils.Tween(marco, {
                            Size = UDim2.new(1, 0, 0,
                                ALTO_FILA + ALTO_BUSQUEDA +
                                math.max(opcionesVisiblesActuales(), 1) * 32 + 4
                            )
                        }, 0.1)
                    end)

                    -- Enter en el buscador selecciona la primera
                    -- coincidencia visible (la misma que se resalta con
                    -- el Stroke en filtrarOpciones). FocusLost trae un
                    -- booleano indicando si se cerro el foco por Enter
                    -- especificamente (y no por click afuera, Tab, etc.)
                    searchBox.FocusLost:Connect(function(conEnter)
                        if conEnter and primeraCoincidencia then
                            elegir(primeraCoincidencia)
                        end
                    end)
                end
                if conBusqueda then conectarBuscador() end

                -- Get() retorna el valor seleccionado real, no el texto de display
                local function obtenerValor()
                    if multi then return clonarTabla(seleccion) end
                    for k, v in pairs(seleccion) do if v then return k end end
                    return nil
                end

                -- Reconstruye las filas de opciones desde una nueva lista,
                -- sin recrear el marco/cabecera/searchBox. Pensado para
                -- casos como el listado de perfiles de SaveManager, donde
                -- las opciones cambian despues de creado el Dropdown
                -- (guardar/eliminar un perfil). No dispara Callback ni
                -- toca Flags directamente -- solo redibuja y, si la
                -- seleccion actual ya no existe, la limpia.
                actualizarOpciones = function(nuevasOpciones)
                    nuevasOpciones = nuevasOpciones or {}
                    entradas = clonarTabla(nuevasOpciones)
                    local normalizadas, nuevaMeta = normalizarEntradas(nuevasOpciones)
                    local reconstruir = next(nuevaMeta) ~= nil or next(meta) ~= nil

                    -- Reutiliza todo lo que ya existe bajo el mismo
                    -- texto de opcion (botonesOp ya esta indexado por
                    -- opcion, no por posicion -- es la clave natural
                    -- para esto) y solo destruye/crea lo que cambio.
                    local nuevasComoSet = {}
                    if not reconstruir then
                        for _, o in ipairs(normalizadas) do nuevasComoSet[o] = true end
                    end

                    for opcionVieja, btn in pairs(botonesOp) do
                        if not nuevasComoSet[opcionVieja] then
                            btn:Destroy()
                            botonesOp[opcionVieja] = nil
                            strokesOp[opcionVieja] = nil
                        end
                    end

                    opciones = normalizadas
                    meta = nuevaMeta
                    primeraCoincidencia = nil

                    if multi then
                        local limpio = {}
                        for _, o in ipairs(opciones) do
                            if seleccion[o] then limpio[o] = true end
                        end
                        seleccion = limpio
                        Nub.Flags[flag] = clonarTabla(seleccion)
                    else
                        local actual = obtenerValor()
                        local existe = false
                        for _, o in ipairs(opciones) do
                            if o == actual then existe = true; break end
                        end
                        if not existe then
                            seleccion = {}
                            Nub.Flags[flag] = nil
                        end
                    end

                    -- Segunda pasada: crea SOLO las opciones que no
                    -- existian, y en cualquier caso reordena LayoutOrder
                    -- de todas (existentes y nuevas) para que el
                    -- UIListLayout las muestre en el orden pedido -- un
                    -- botonn reutilizado puede necesitar moverse de
                    -- posicion aunque no haya que recrearlo.
                    for i, opcion in ipairs(opciones) do
                        if botonesOp[opcion] then
                            botonesOp[opcion].LayoutOrder = i
                        else
                            crearOpcion(opcion, i, elegir)
                        end
                    end

                    conBusqueda = #opciones > UMBRAL_BUSQUEDA
                    ALTO_BUSQUEDA = conBusqueda and 24 or 0
                    if conBusqueda and not searchBox then
                        crearBuscador()
                        conectarBuscador()
                    end
                    if searchBox then searchBox.Visible = false end
                    listaOp.Position = UDim2.new(0, 0, 0, ALTO_FILA + ALTO_BUSQUEDA)
                    listaOp.Size = UDim2.new(1, 0, 0, math.max(#opciones, 1) * 32)
                    actualizarLabel()
                end

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        if not esValorValidoDropdown(v) then
                            Nub:_RegistrarError("Dropdown.Set (valor inválido)",
                                "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                                (multi and " (se esperaba una tabla, Multi=true)" or " (no está en la lista de Opciones)") .. ". Se ignoró.")
                            return
                        end
                        -- Se clona 'v' al adoptarlo: si no, 'seleccion' quedaria
                        -- apuntando a la MISMA tabla que le paso quien llamo a
                        -- Set(), y si esa tabla se sigue usando/mutando afuera
                        -- (ej. SaveManager reusando el mismo objeto decodificado
                        -- de JSON), el control cambiaria solo, sin pasar por
                        -- ninguna de sus propias funciones.
                        if multi then seleccion = clonarTabla(v) else seleccion = {[v] = true} end
                        refrescarVisual()
                        Nub.Flags[flag] = multi and clonarTabla(seleccion) or v
                        -- Igual que en los demas controles: SaveManager
                        -- necesita poder pedir que se dispare el
                        -- Callback al restaurar un guardado.
                        if dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "Dropdown", multi and clonarTabla(seleccion) or v)
                        end
                    end,
                    Get = obtenerValor,
                    ActualizarOpciones = actualizarOpciones,
                    AgregarOpcion = agregarOpcion,
                    EliminarOpcion = eliminarOpcion,
                    LimpiarOpciones = limpiarOpciones,
                }
                return {
                    Set = function(...)
                        local v = normalizarArgSet(...)
                        if not esValorValidoDropdown(v) then
                            Nub:_RegistrarError("Dropdown.Set (valor inválido)",
                                "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                                (multi and " (se esperaba una tabla, Multi=true)" or " (no está en la lista de Opciones)") .. ". Se ignoró.")
                            return
                        end
                        if multi then
                            seleccion = clonarTabla(v)
                            refrescarVisual()
                            Nub.Flags[flag] = clonarTabla(seleccion)
                            if cfg.Callback then
                                ejecutarConFallback(cfg.Callback, cfg.Texto or "Dropdown", clonarTabla(seleccion))
                            end
                        else
                            elegir(v, true)
                        end
                    end,
                    Get = obtenerValor,
                    -- Nueva API aditiva: permite refrescar las opciones de un
                    -- Dropdown ya creado (ej. re-listar perfiles guardados)
                    -- sin recrear el control ni romper Set/Get existentes.
                    ActualizarOpciones = actualizarOpciones,
                    AgregarOpcion = agregarOpcion,
                    EliminarOpcion = eliminarOpcion,
                    LimpiarOpciones = limpiarOpciones,
                }
            end

            -- 🌈 COLOR PICKER — selector de color con barras deslizantes R/G/B.
            function Seccion:ColorPicker(cfg)
                cfg = cfg or {}
                validarCallback("ColorPicker", cfg)
                local flag        = cfg.Flag or cfg.Texto or ("Color_" .. tostring(math.random(1e5, 1e6)))
                local colorActual = cfg.Defecto or Color3.fromRGB(255, 255, 255)
                Nub.Flags[flag] = colorActual

                local ALTO_FILA = 32
                local marco = Utils.Frame({
                    Padre = contenedor,
                    Size = UDim2.new(1, 0, 0, ALTO_FILA),
                    Color = Theme.Fila, Orden = siguienteOrden(), Recortar = true,
                })
                Nub:Registrar(marco, "BackgroundColor3", "Fila")

                local cabecera = Utils.BotonBase({Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA)})
                local muestra
                Utils.Hover(cabecera, marco, nil, nil, nil, function(entrando)
                    if not (Nub.Opciones.MicroInteracciones and muestra and muestra.Parent) then return end
                    local trazoMuestra = muestra:FindFirstChildOfClass("UIStroke")
                    if not trazoMuestra then return end
                    Utils.Tween(trazoMuestra, {Color = entrando and Theme.Accent or Theme.Border}, Nub.Motion.Hover)
                end)
                Utils.Texto({
                    Padre = marco, Texto = cfg.Texto or "Color",
                    Size = UDim2.new(1, cfg.Tooltip and -68 or -46, 0, ALTO_FILA),
                    Truncar = true,
                })
                muestra = Utils.Frame({
                    Padre = marco, Size = UDim2.new(0, 30, 0, 16),
                    Posicion = UDim2.new(1, -36, 0, 5),
                    Color = colorActual, Radio = 4,
                    Borde = true, ColorBorde = Theme.Border, TransparenciaBorde = 0.3,
                    ClaveTemaBorde = "Border",
                })
                if cfg.Tooltip then agregarTooltip(marco, UDim2.new(1, -68, 0, 6), cfg.Tooltip) end
                registrarBuscable(marco, cfg.Texto or "Color", cfg.VisibleSi)

                -- Estilo: "RGB" (3 sliders + hex + muestras, como siempre) o "2D"
                -- (cuadrado saturacion/valor + barra de matiz, y tambien hex y
                -- muestras). Sin 'Estilo' se usa Nub.Opciones.ColorPickerEstiloPredeterminado.
                local estilo = cfg.Estilo or Nub.Opciones.ColorPickerEstiloPredeterminado or "RGB"
                if estilo ~= "RGB" and estilo ~= "2D" then
                    advertirDev("ColorPicker", cfg.Texto, "Estilo '" .. tostring(estilo) .. "' no reconocido (usa \"RGB\" o \"2D\"). Se usó \"RGB\".")
                    estilo = "RGB"
                end
                local usar2D = (estilo == "2D")
                -- Altos de las filas visibles del panel + 4px entre filas:
                --   RGB: muestras 22 + 3 canales de 22 + hex 22 = 110 + 4*4 = 126
                --   2D : muestras 22 + cuadrado 100 + matiz 14 + hex 22 = 158 + 3*4 = 170
                local ALTO_PANEL = usar2D and 170 or 126

                local panel = Utils.Frame({
                    Padre = marco, Size = UDim2.new(1, -16, 0, ALTO_PANEL),
                    Posicion = UDim2.new(0, 8, 0, ALTO_FILA + 2), Transparencia = 1,
                })
                local layoutPanel = Instance.new("UIListLayout")
                layoutPanel.Padding   = UDim.new(0, 4)
                layoutPanel.SortOrder = Enum.SortOrder.LayoutOrder
                layoutPanel.Parent    = panel

                local r = colorActual.R * 255
                local g = colorActual.G * 255
                local b = colorActual.B * 255
                local fijarVisualR, fijarVisualG, fijarVisualB

                local hexBox = nil

                -- OPTIMIZACION (igual que el Slider): cachea el ultimo
                -- color YA PROCESADO. Con una barra mas ancha que 255px
                -- puede haber varios eventos de arrastre que redondeen
                -- al mismo valor entero de canal; solo se recalcula
                -- Flags/muestra/Callback cuando el color realmente cambia.
                local ultimoColorProcesado = colorActual

                local function aHex(c)
                    return string.format("#%02X%02X%02X",
                        math.floor(c.R * 255 + 0.5),
                        math.floor(c.G * 255 + 0.5),
                        math.floor(c.B * 255 + 0.5))
                end

                local function actualizarColor()
                    local nuevoColor = Color3.fromRGB(
                        math.clamp(math.floor(r + 0.5), 0, 255),
                        math.clamp(math.floor(g + 0.5), 0, 255),
                        math.clamp(math.floor(b + 0.5), 0, 255)
                    )
                    if nuevoColor == ultimoColorProcesado then return end
                    ultimoColorProcesado = nuevoColor
                    colorActual = nuevoColor
                    muestra.BackgroundColor3 = colorActual
                    if hexBox then hexBox.Text = aHex(colorActual) end
                    Nub.Flags[flag] = colorActual
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "ColorPicker", colorActual)
                    end
                end

                local function canalRGB(nombre, orden, getV, setV)
                    local filaMini = Utils.Frame({
                        Padre = panel, Size = UDim2.new(1, 0, 0, 22),
                        Orden = orden, Transparencia = 1,
                    })
                    -- En estilo 2D los canales siguen existiendo (otros caminos
                    -- como las muestras o el hex los actualizan), pero no se ven.
                    if usar2D then filaMini.Visible = false end
                    Utils.Texto({
                        Padre = filaMini, Texto = nombre,
                        Size = UDim2.new(0, 14, 1, 0),
                        Fuente = Enum.Font.GothamBold, Tamano = 10,
                    })
                    local _, _, fv = crearBarraArrastrable({
                        Padre = filaMini,
                        Size = UDim2.new(1, -18, 0, 6),
                        Posicion = UDim2.new(0, 18, 0.5, -3),
                        Min = 0, Max = 255, Valor = getV(),
                        OnCambio = function(v) setV(v); actualizarColor() end,
                    })
                    return fv
                end

                fijarVisualR = canalRGB("R", 1, function() return r end, function(v) r = v end)
                fijarVisualG = canalRGB("G", 2, function() return g end, function(v) g = v end)
                fijarVisualB = canalRGB("B", 3, function() return b end, function(v) b = v end)

                local picker2D = nil
                if usar2D then
                    picker2D = crearColorPicker2D({
                        Padre = panel, AltoCuadro = 100, AltoHue = 14,
                        OrdenCuadro = 1, OrdenHue = 2,
                    })
                    picker2D.sincronizarDeColor3(colorActual)
                    picker2D.conectarOnCambio(function(c)
                        r, g, b = c.R * 255, c.G * 255, c.B * 255
                        actualizarColor()
                    end)
                end

                -- Paleta de swatches: colores comunes en un click, sin
                -- tener que escribir hex o mover 3 sliders para llegar
                -- a rojo/verde/azul/blanco/negro puro. Orden 0 para
                -- quedar ANTES de los canales RGB (orden 1-3) y del
                -- hex (orden 4) dentro del mismo UIListLayout.
                local COLORES_COMUNES = {
                    Color3.fromRGB(255, 0, 0),     Color3.fromRGB(0, 255, 0),
                    Color3.fromRGB(0, 120, 255),   Color3.fromRGB(255, 255, 0),
                    Color3.fromRGB(255, 0, 255),   Color3.fromRGB(0, 255, 255),
                    Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 20),
                }
                local filaSwatches = Utils.Frame({
                    Padre = panel, Size = UDim2.new(1, 0, 0, 22),
                    Orden = 0, Transparencia = 1,
                })
                local layoutSwatches = Instance.new("UIListLayout")
                layoutSwatches.FillDirection   = Enum.FillDirection.Horizontal
                layoutSwatches.Padding         = UDim.new(0, 4)
                layoutSwatches.SortOrder       = Enum.SortOrder.LayoutOrder
                layoutSwatches.Parent          = filaSwatches
                for i, colorSwatch in ipairs(COLORES_COMUNES) do
                    local swatch = Utils.BotonBase({
                        Padre = filaSwatches, Size = UDim2.new(0, 20, 0, 20),
                        Color = colorSwatch, Transparencia = 0, Radio = 4,
                        Orden = i,
                    })
                    local strokeSwatch = Utils.Stroke(swatch, Theme.Border, 1, 0.4)
                    Nub:Registrar(strokeSwatch, "Color", "Border")
                    -- Hitbox ampliado (20px visual -> 34px efectivo). Hijo
                    -- de 'swatch', no hermano dentro de 'filaSwatches' (que
                    -- tiene su propio UIListLayout horizontal, con 4px de
                    -- gap entre swatches -- padding conservador por la
                    -- misma razon que en RadioGroup/tabs).
                    local hitboxSwatch = Utils.HitboxAmpliado(swatch, 7)
                    Utils.ClickConfiable(hitboxSwatch, function()
                        -- Mismo patron que intentarAplicarHex: se
                        -- actualizan r/g/b, se refresca el visual de
                        -- los 3 sliders, y recien ahi se aplica.
                        r, g, b = colorSwatch.R * 255, colorSwatch.G * 255, colorSwatch.B * 255
                        fijarVisualR(r); fijarVisualG(g); fijarVisualB(b)
                        actualizarColor()
                        if picker2D then picker2D.sincronizarDeColor3(colorActual) end
                    end, swatch)
                end

                -- Fila de Hex: escribir un color valido (con o sin '#',
                -- 3 o 6 digitos) actualiza los 3 sliders RGB de una vez.
                -- Se valida al perder el foco (FocusLost), no en cada
                -- tecla, para no interrumpir mientras el usuario todavia
                -- esta escribiendo un valor a medio completar.
                local filaHex = Utils.Frame({
                    Padre = panel, Size = UDim2.new(1, 0, 0, 22),
                    Orden = 4, Transparencia = 1,
                })
                Utils.Texto({
                    Padre = filaHex, Texto = "Hex",
                    Size = UDim2.new(0, 28, 1, 0),
                    Fuente = Enum.Font.GothamBold, Tamano = 10,
                })
                hexBox = Instance.new("TextBox")
                hexBox.Size = UDim2.new(1, -32, 1, 0)
                hexBox.Position = UDim2.new(0, 32, 0, 0)
                hexBox.BackgroundColor3 = Theme.Entrada
                hexBox.BorderSizePixel = 0
                hexBox.Font = Enum.Font.Code
                hexBox.TextSize = 12
                hexBox.TextColor3 = Theme.Text
                hexBox.PlaceholderText = "#RRGGBB"
                hexBox.ClearTextOnFocus = false
                hexBox.Text = aHex(colorActual)
                hexBox.Parent = filaHex
                Utils.Corner(hexBox, 4)
                Nub:Registrar(hexBox, "BackgroundColor3", "Entrada")
                Nub:Registrar(hexBox, "TextColor3", "Text")
                Utils.AnilloFoco(hexBox)

                local function intentarAplicarHex(texto)
                    local limpio = texto:gsub("^#", ""):gsub("%s", "")
                    if #limpio == 3 then
                        -- Forma corta #RGB -> #RRGGBB (cada digito se duplica)
                        limpio = limpio:sub(1,1):rep(2) .. limpio:sub(2,2):rep(2) .. limpio:sub(3,3):rep(2)
                    end
                    if #limpio ~= 6 or limpio:match("%X") then
                        -- Invalido: se restaura el hex del color actual,
                        -- sin tocar Flags/Callback ni marcar error --
                        -- es un typo del usuario mientras escribe, no
                        -- una falla del script.
                        hexBox.Text = aHex(colorActual)
                        Utils.FlashFeedback(hexBox, false, Theme.Entrada)
                        return
                    end
                    local rr = tonumber(limpio:sub(1,2), 16)
                    local gg = tonumber(limpio:sub(3,4), 16)
                    local bb = tonumber(limpio:sub(5,6), 16)
                    r, g, b = rr, gg, bb
                    fijarVisualR(r); fijarVisualG(g); fijarVisualB(b)
                    actualizarColor()
                    if picker2D then picker2D.sincronizarDeColor3(colorActual) end
                    Utils.FlashFeedback(hexBox, true, Theme.Entrada)
                end

                hexBox.FocusLost:Connect(function()
                    intentarAplicarHex(hexBox.Text)
                end)

                local alternar = hacerExpandible(marco, ALTO_FILA, function() return ALTO_FILA + ALTO_PANEL + 4 end)
                Utils.ClickConfiable(cabecera, function() alternar() end)

                -- Funcion interna de Set (sin callback, para SaveManager)
                local function fijarColor(v)
                    if typeof(v) ~= "Color3" then
                        Nub:_RegistrarError("ColorPicker.Set (valor no es Color3)",
                            "flag '" .. tostring(flag) .. "' recibió " .. typeof(v) ..
                            " en vez de Color3. Se ignoró.")
                        return false
                    end
                    colorActual = v
                    ultimoColorProcesado = v
                    r = v.R * 255; g = v.G * 255; b = v.B * 255
                    muestra.BackgroundColor3 = v
                    if hexBox then hexBox.Text = aHex(v) end
                    Nub.Flags[flag] = v
                    fijarVisualR(r); fijarVisualG(g); fijarVisualB(b)
                    if picker2D then picker2D.sincronizarDeColor3(v) end
                    return true
                end

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback)
                        if fijarColor(v) and dispararCallback and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "ColorPicker", v)
                        end
                    end,
                    Get = function() return colorActual end,
                }
                return {
                    -- Publico: actualiza visual Y dispara callback.
                    -- No reusa actualizarColor() aca -- fijarColor()
                    -- ya deja ultimoColorProcesado = v, asi que
                    -- actualizarColor() siempre veia "nuevoColor ==
                    -- ultimoColorProcesado" y cortaba antes de llegar
                    -- al Callback. Este Set dispara el Callback
                    -- directamente, sin pasar por esa cache (que esta
                    -- pensada para el arrastre en vivo, no para un
                    -- Set externo puntual).
                    Set = function(...)
                        local v = normalizarArgSet(...)
                        if fijarColor(v) and cfg.Callback then
                            ejecutarConFallback(cfg.Callback, cfg.Texto or "ColorPicker", v)
                        end
                    end,
                    Get = function() return colorActual end,
                }
            end

            -- ⌨️ KEYBIND — asigna una tecla como atajo; se adapta solo a gamepad o botón táctil según el dispositivo.
            -- Con cfg.ConModificadores = true (nuevo), tambien registra
            -- si Ctrl/Shift/Alt estaban presionados al capturar la
            -- tecla -- 'valor' pasa de ser un Enum.KeyCode suelto a una
            -- tabla {KeyCode=, Ctrl=, Shift=, Alt=}. Sin esa opcion, el
            -- comportamiento es identico al de siempre (KeyCode suelto).
            function Seccion:Keybind(cfg)
                cfg = cfg or {}
                validarCallback("Keybind", cfg)
                local flag     = cfg.Flag or cfg.Texto or ("Keybind_" .. tostring(math.random(1e5, 1e6)))
                local conMods  = cfg.ConModificadores or false
                -- Modo de la tecla:
                --   "Press"  (default): Callback(tecla) cada vez que se presiona.
                --   "Hold":   Callback(true) al presionar y Callback(false) al soltar.
                --   "Toggle": Callback(bool) alternando en cada pulsacion. La tecla
                --             asignada sigue siendo el valor del Flag (se guarda como
                --             siempre); el estado on/off vive en el flag aparte
                --             "<Flag>_estado", que NO se guarda en perfiles.
                local modo = cfg.Modo or "Press"
                if modo ~= "Press" and modo ~= "Hold" and modo ~= "Toggle" then
                    advertirDev("Keybind", cfg.Texto, "Modo '" .. tostring(modo) .. "' no reconocido (usa \"Press\", \"Hold\" o \"Toggle\"). Se usó \"Press\".")
                    modo = "Press"
                end
                local estadoToggle = false
                local sostenida = false -- Hold: la tecla esta presionada AHORA
                local flagEstado = flag .. "_estado"
                local defecto  = cfg.Defecto or (conMods and {KeyCode = Enum.KeyCode.Unknown} or Enum.KeyCode.Unknown)
                -- Si conMods esta activo pero Defecto vino como un
                -- Enum.KeyCode suelto (cfg.Defecto = Enum.KeyCode.F, sin
                -- envolver en tabla), el 'or' de arriba no lo agarra
                -- porque un EnumItem ya es truthy. Se normaliza aca para
                -- que 'valor' siempre sea del tipo que conMods espera.
                if conMods and typeof(defecto) ~= "table" then
                    defecto = {KeyCode = defecto, Ctrl = false, Shift = false, Alt = false}
                end
                local valor    = defecto
                local esperando = false
                local conexionCaptura = nil
                -- Blindaje del listener persistente: cuando el usuario acaba de
                -- asignar una tecla nueva (dentro del mismo evento InputBegan que
                -- cierra la captura), el listener persistente NO debe disparar el
                -- Callback para ese mismo tecleo. Esto funciona porque el listener
                -- persistente se conecta ANTES que la conexion de captura (FIFO de
                -- Roblox), asi que siempre ve 'esperando = true' todavia. Pero esa
                -- dependencia de orden de conexion es invisible: si un refactor
                -- futuro moviera la creacion del listener persistente despues de
                -- algun :Connect de captura, el doble disparo aparecería sin aviso.
                -- Este flag cierra ese agujero sin depender del orden.
                local _asignadaEnEsteFrame = false
                Nub.Flags[flag] = valor
                if modo == "Toggle" then
                    _flagsNoPersistir[flagEstado] = true
                    Nub.Flags[flagEstado] = false
                end

                -- Se anota en el registro global de Keybinds (ver
                -- '_keybindsRegistrados' arriba) para poder detectar
                -- si en algun momento otro Keybind termina usando la
                -- misma combinacion de tecla.
                local entryConflicto = { flag = flag, texto = cfg.Texto or "Keybind" }
                entryConflicto.GetValor = function() return valor end
                table.insert(_keybindsRegistrados, entryConflicto)

                -- Texto de un modificador+tecla: "Ctrl+Shift+F". Si no
                -- hay modificadores activos, es identico al modo simple.
                local function textoTecla(v)
                    if not conMods then
                        return (v == Enum.KeyCode.Unknown) and "Ninguna" or v.Name
                    end
                    -- Defensivo: si por algun motivo 'v' llega como un
                    -- Enum.KeyCode suelto en vez de la tabla esperada
                    -- (Set() externo, algun otro punto de entrada), se
                    -- envuelve en vez de intentar indexar .KeyCode sobre
                    -- un EnumItem y romper con error.
                    if typeof(v) ~= "table" then
                        v = {KeyCode = v, Ctrl = false, Shift = false, Alt = false}
                    end
                    if not v or v.KeyCode == Enum.KeyCode.Unknown then return "Ninguna" end
                    local partes = {}
                    if v.Ctrl then table.insert(partes, "Ctrl") end
                    if v.Shift then table.insert(partes, "Shift") end
                    if v.Alt then table.insert(partes, "Alt") end
                    table.insert(partes, v.KeyCode.Name)
                    return table.concat(partes, "+")
                end

                local sufijoModo = (modo ~= "Press") and ("  [" .. modo .. "]") or ""
                local fila, lblTeclaLabel = crearCabecera(32, (cfg.Texto or "Tecla") .. sufijoModo, 1, -72)
                agregarTooltipTexto(fila, (cfg.Texto or "Tecla") .. sufijoModo, cfg.Tooltip, lblTeclaLabel)
                registrarBuscable(fila, cfg.Texto or "Tecla", cfg.VisibleSi)

                -- Sin teclado fisico/bluetooth (movil tactil puro), esperar
                -- a que llegue una tecla no tiene sentido: nunca va a pasar.
                -- Si en cambio hay un GAMEPAD conectado (control Bluetooth),
                -- se puede capturar un boton del control — mas fiel a lo que
                -- el desarrollador pidio (una tecla/boton que dispare algo)
                -- que forzar directamente el modo "boton de accion". Solo
                -- si no hay NI teclado NI gamepad, el boton se convierte en
                -- accion directa (equivalente a "presionar" la tecla
                -- asignada con un toque).
                local sinTeclado = not Nub.Capacidades.Teclado
                local conGamepad = sinTeclado and Nub.Capacidades.Gamepad
                local soloAccionDirecta = sinTeclado and not conGamepad

                local btnTecla = Utils.BotonBase({
                    Padre = fila, Size = UDim2.new(0, 60, 0, 18),
                    Posicion = UDim2.new(1, -66, 0.5, -9),
                    Color = Theme.Entrada, Transparencia = 0, Radio = 4,
                })
                Nub:Registrar(btnTecla, "BackgroundColor3", "Entrada")
                Utils.Hover(btnTecla, btnTecla, 0.12)
                local lblTecla = Utils.Texto({
                    Padre = btnTecla, Texto = soloAccionDirecta and "▶ Usar" or textoTecla(valor),
                    Alineacion = Enum.TextXAlignment.Center,
                    Color = Theme.Highlight, Tamano = 10,
                })
                Nub:Registrar(lblTecla, "TextColor3", "Highlight")

                local function esTeclaValida(tecla)
                    if typeof(tecla) == "EnumItem" then return true end
                    if type(tecla) == "table" and typeof(tecla.KeyCode) == "EnumItem" then return true end
                    return false
                end

                local function dispararCallbackKeybind(arg)
                    if cfg.Callback then
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "Keybind", arg)
                    end
                end

                -- Lo que pasa al ACTIVAR la tecla (en el juego o, en tactil puro,
                -- con un toque), segun el modo.
                local function accionPresionar()
                    if modo == "Toggle" then
                        estadoToggle = not estadoToggle
                        Nub.Flags[flagEstado] = estadoToggle
                        dispararCallbackKeybind(estadoToggle)
                    elseif modo == "Hold" then
                        sostenida = true
                        dispararCallbackKeybind(true)
                    else
                        dispararCallbackKeybind(valor)
                    end
                end

                -- Solo Hold: al soltar. Si la tecla nunca llego a registrarse como
                -- presionada (p. ej. se escribia en un TextBox) no manda un false
                -- suelto.
                local function accionSoltar()
                    if modo == "Hold" and sostenida then
                        sostenida = false
                        dispararCallbackKeybind(false)
                    end
                end

                -- Solo en modo Toggle el control devuelto expone el estado on/off.
                local function agregarEstadoKeybind(objeto)
                    if modo == "Toggle" then
                        objeto.GetEstado = function() return estadoToggle end
                        objeto.SetEstado = function(...)
                            local v = normalizarArgSet(...)
                            if type(v) ~= "boolean" then
                                Nub:_RegistrarError("Keybind.SetEstado", "se esperaba boolean, llegó " .. typeof(v))
                                return
                            end
                            estadoToggle = v
                            Nub.Flags[flagEstado] = v
                            dispararCallbackKeybind(v)
                        end
                    end
                    return objeto
                end

                local function actualizarTecla(tecla, disparar)
                    if not esTeclaValida(tecla) then
                        Nub:_RegistrarError("Keybind.Set (valor inválido)",
                            "flag '" .. tostring(flag) .. "' recibió " .. typeof(tecla) ..
                            " en vez de Enum.KeyCode" .. (conMods and " o tabla {KeyCode,...}" or "") .. ". Se ignoró.")
                        return
                    end
                    -- Si se reasigna la tecla mientras estaba sostenida, se suelta primero.
                    accionSoltar()
                    valor = tecla
                    Nub.Flags[flag] = tecla
                    if not soloAccionDirecta then lblTecla.Text = textoTecla(tecla) end
                    -- Solo en modo Press el Callback recibe la tecla. En Hold/Toggle el
                    -- Callback habla de ESTADO (bool): restaurar o asignar una tecla no
                    -- debe llamarlo con una tecla.
                    if disparar and modo == "Press" then
                        dispararCallbackKeybind(tecla)
                    end
                end

                -- Listener persistente de la tecla asignada. 'Seccion:Keybind'
                -- dispara el Callback UNICAMENTE cuando el usuario presiona la
                -- tecla asignada en el juego, no cuando la asigna. El Callback
                -- tampoco se dispara al reasignar la tecla (aunque la nueva
                -- tecla coincida con la vieja). Este comportamiento fue
                -- cambiado en v2.11.2: antes el Callback se disparaba tambien
                -- al cerrar la captura de una tecla nueva (actualizarTecla(v,
                -- true)) -- lo cual hacia que un Callback tipo "toggle" ya
                -- arrancara alternado apenas se asignaba la tecla, antes de
                -- que el usuario la presionara ni una vez en el juego.
                --
                -- Sin este listener, presionar la tecla asignada en el juego
                -- no hacia absolutamente nada -- el desarrollador tenia que
                -- armar su propio UserInputService.InputBegan aparte,
                -- comparando contra Nub.Flags[suFlag], si queria que la
                -- tecla realmente disparara algo de forma repetida.
                --
                -- Este listener queda vivo mientras la ventana viva (se registra con
                -- RegistrarConexion, así la limpieza automática lo desconecta al
                -- destruir la ventana o re-ejecutar el script), y dispara el Callback
                -- cada vez que el usuario presiona la combinación asignada.
                --
                -- Detalles importantes:
                --   * 'esperando' (durante una captura nueva) bloquea este listener,
                --     para no disparar el Callback dos veces si el usuario presiona
                --     justo la tecla que ya estaba asignada mientras la reasigna.
                --   * '_asignadaEnEsteFrame' cierra el mismo agujero sin depender del
                --     orden de conexion entre este listener y el de captura (ver
                --     comentario junto a su declaracion, mas arriba).
                --   * 'procesado' se respeta -- si el usuario está escribiendo en un
                --     TextBox (chat, un Input de la propia interfaz, etc.), Roblox
                --     marca el input como procesado y NO se dispara el atajo.
                --   * En modo ConModificadores, se exige match exacto de Ctrl/Shift/Alt
                --     en el momento del InputBegan. En modo simple, los modificadores
                --     se ignoran (una tecla "F" dispara siempre, con o sin Ctrl).
                local function crearListenerTeclaPersistente()
                    Nub:RegistrarConexion(
                        UserInputService.InputBegan:Connect(function(input, procesado)
                            if procesado then return end
                            if esperando then return end
                            if _asignadaEnEsteFrame then return end

                            local k, c, s, a = _descomponerTecla(valor)
                            if k == Enum.KeyCode.Unknown then return end
                            if input.KeyCode ~= k then return end

                            if conMods then
                                local ctrlAhora  = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                                    or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                                local shiftAhora = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                                    or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                                local altAhora   = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
                                    or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                                if ctrlAhora ~= c or shiftAhora ~= s or altAhora ~= a then
                                    return
                                end
                            end

                            accionPresionar()
                        end)
                    )

                    -- Hold necesita saber cuando se suelta la tecla. En Press y
                    -- Toggle no se registra esta conexion para no gastar listeners.
                    if modo == "Hold" then
                        Nub:RegistrarConexion(
                            UserInputService.InputEnded:Connect(function(input)
                                if not sostenida then return end
                                local k = _descomponerTecla(valor)
                                if input.KeyCode == k then accionSoltar() end
                            end)
                        )
                    end
                end

                if soloAccionDirecta then
                    -- Boton de accion directa: cada toque "presiona" la
                    -- tecla asignada (o la que haya por defecto), sin
                    -- necesidad de capturar ningun input de teclado.
                    local function destellarBoton()
                        Utils.Tween(btnTecla, {BackgroundColor3 = Theme.Accent}, Nub.Motion.FlashIn)
                        task.delay(0.12, function()
                            if btnTecla and btnTecla.Parent then
                                Utils.Tween(btnTecla, {BackgroundColor3 = Theme.Entrada}, Nub.Motion.Expand)
                            end
                        end)
                    end

                    if modo == "Hold" then
                        -- En tactil puro "mantener" = mantener el dedo sobre el boton:
                        -- Callback(true) al tocar y Callback(false) al soltar.
                        local function esToque(input)
                            return input.UserInputType == Enum.UserInputType.Touch
                                or input.UserInputType == Enum.UserInputType.MouseButton1
                        end
                        Nub:RegistrarConexion(btnTecla.InputBegan:Connect(function(input)
                            if not esToque(input) then return end
                            Utils.Tween(btnTecla, {BackgroundColor3 = Theme.Accent}, Nub.Motion.FlashIn)
                            accionPresionar()
                        end))
                        Nub:RegistrarConexion(btnTecla.InputEnded:Connect(function(input)
                            if not esToque(input) then return end
                            Utils.Tween(btnTecla, {BackgroundColor3 = Theme.Entrada}, Nub.Motion.Expand)
                            accionSoltar()
                        end))
                    else
                        Utils.ClickConfiable(btnTecla, function()
                            destellarBoton()
                            accionPresionar()
                        end)
                    end

                    -- Mantener presionado: en tactil puro no se puede escuchar
                    -- una tecla de teclado, pero SI se puede rotar entre un
                    -- set corto de teclas comunes para que la tecla asignada
                    -- se pueda cambiar sin depender de un teclado fisico.
                    local teclasComunesTactil = {
                        Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.Q,
                        Enum.KeyCode.R, Enum.KeyCode.T, Enum.KeyCode.G,
                    }
                    local conexionLongPress
                    local okLP, resultLP = pcall(function()
                        if modo == "Hold" then return nil end -- mantener = accion, no rotar tecla
                        return UserInputService.TouchLongPress:Connect(function(touchPositions, state)
                            if state ~= Enum.UserInputState.Begin then return end
                            local pos = touchPositions[1]
                            if not pos then return end
                            local absPos, absSize = btnTecla.AbsolutePosition, btnTecla.AbsoluteSize
                            if pos.X < absPos.X or pos.X > absPos.X + absSize.X
                                or pos.Y < absPos.Y or pos.Y > absPos.Y + absSize.Y then
                                return
                            end
                            local idxActual = table.find(teclasComunesTactil, valor)
                            local siguiente = teclasComunesTactil[(idxActual or 0) % #teclasComunesTactil + 1]
                            -- Si conMods esta activo, 'valor' es una
                            -- tabla {KeyCode,...} -- table.find nunca
                            -- la va a matchear contra la lista de
                            -- Enum.KeyCode sueltos (arranca siempre
                            -- desde el primero, lo cual es aceptable),
                            -- pero el siguiente valor asignado debe
                            -- mantener el MISMO tipo que 'valor' ya
                            -- tiene, para no mezclar tabla/EnumItem
                            -- entre una asignacion y la siguiente.
                            local nuevoValor = conMods
                                and {KeyCode = siguiente, Ctrl = false, Shift = false, Alt = false}
                                or siguiente
                            _revisarConflictoKeybind(entryConflicto, nuevoValor)
                            actualizarTecla(nuevoValor, false)
                            pcall(function()
                                Nub:Notificar({ Titulo = "⌨️ Tecla asignada", Texto = tostring(siguiente.Name), Duracion = 1.5 })
                            end)
                        end)
                    end)
                    if okLP and resultLP then
                        conexionLongPress = resultLP
                        Nub:RegistrarConexion(conexionLongPress)
                    end
                    -- Si TouchLongPress no esta disponible en este
                    -- ejecutor, el boton sigue funcionando igual para
                    -- "presionar" la tecla asignada (MouseButton1Click
                    -- de arriba) -- solo se pierde la posibilidad de
                    -- rotar entre teclas comunes con un toque largo.

                    Nub.Elementos[flag] = {
                        Set = function(v, dispararCallback) actualizarTecla(v, dispararCallback or false) end,
                        Get = function() return valor end,
                    }
                    return agregarEstadoKeybind({
                        Set = function(...) actualizarTecla(normalizarArgSet(...), true) end,
                        Get = function() return valor end,
                    })
                end

                if conGamepad then
                    -- Captura un boton de gamepad (ButtonA, DPadUp, etc.)
                    -- en vez de una tecla de teclado. Misma logica de
                    -- "esperando" que el modo teclado, solo que escucha
                    -- cualquier UserInputType que empiece con "Gamepad".
                    Utils.ClickConfiable(btnTecla, function()
                        if esperando then return end
                        esperando = true
                        lblTecla.Text = "..."
                        btnTecla.BackgroundColor3 = Theme.Accent

                        conexionCaptura = UserInputService.InputBegan:Connect(function(input, procesado)
                            if procesado or not esperando then return end
                            if input.UserInputType.Name:sub(1, 7) == "Gamepad"
                            and input.KeyCode ~= Enum.KeyCode.Unknown then
                                esperando = false
                                btnTecla.BackgroundColor3 = Theme.Entrada
                                if conexionCaptura then
                                    conexionCaptura:Disconnect()
                                    conexionCaptura = nil
                                end
                                _revisarConflictoKeybind(entryConflicto, input.KeyCode)
                                _asignadaEnEsteFrame = true
                                task.defer(function() _asignadaEnEsteFrame = false end)
                                actualizarTecla(input.KeyCode, false)
                            end
                        end)
                        Nub:RegistrarConexion(conexionCaptura)

                        task.delay(5, function()
                            if esperando then
                                esperando = false
                                lblTecla.Text = textoTecla(valor)
                                btnTecla.BackgroundColor3 = Theme.Entrada
                                if conexionCaptura then
                                    conexionCaptura:Disconnect()
                                    conexionCaptura = nil
                                end
                            end
                        end)
                    end)

                    crearListenerTeclaPersistente()

                    Nub.Elementos[flag] = {
                        Set = function(v, dispararCallback) actualizarTecla(v, dispararCallback or false) end,
                        Get = function() return valor end,
                    }
                    return agregarEstadoKeybind({
                        Set = function(...) actualizarTecla(normalizarArgSet(...), true) end,
                        Get = function() return valor end,
                    })
                end


                Utils.ClickConfiable(btnTecla, function()
                    if esperando then return end
                    esperando = true
                    lblTecla.Text = "..."
                    btnTecla.BackgroundColor3 = Theme.Accent

                    conexionCaptura = UserInputService.InputBegan:Connect(function(input, procesado)
                        if procesado or not esperando then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard
                        and input.KeyCode ~= Enum.KeyCode.Unknown then
                            -- En modo ConModificadores, una tecla que ES
                            -- en si misma un modificador (Ctrl/Shift/Alt
                            -- solos) no cuenta como la tecla principal --
                            -- se sigue esperando a que llegue la tecla
                            -- real mientras esos modificadores siguen
                            -- presionados.
                            local esSoloModificador = conMods and (
                                input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl or
                                input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or
                                input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt
                            )
                            if esSoloModificador then return end

                            esperando = false
                            btnTecla.BackgroundColor3 = Theme.Entrada
                            if conexionCaptura then
                                conexionCaptura:Disconnect()
                                conexionCaptura = nil
                            end

                            local nuevoValor
                            if conMods then
                                nuevoValor = {
                                    KeyCode = input.KeyCode,
                                    Ctrl  = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl),
                                    Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift),
                                    Alt   = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt),
                                }
                            else
                                nuevoValor = input.KeyCode
                            end
                            _revisarConflictoKeybind(entryConflicto, nuevoValor)
                            _asignadaEnEsteFrame = true
                            task.defer(function() _asignadaEnEsteFrame = false end)
                            actualizarTecla(nuevoValor, false)
                        end
                    end)
                    Nub:RegistrarConexion(conexionCaptura)

                    task.delay(5, function()
                        if esperando then
                            esperando = false
                            lblTecla.Text = textoTecla(valor)
                            btnTecla.BackgroundColor3 = Theme.Entrada
                            if conexionCaptura then
                                conexionCaptura:Disconnect()
                                conexionCaptura = nil
                            end
                        end
                    end)
                end)

                crearListenerTeclaPersistente()

                Nub.Elementos[flag] = {
                    Set = function(v, dispararCallback) actualizarTecla(v, dispararCallback or false) end,
                    Get = function() return valor end,
                }
                return agregarEstadoKeybind({
                    Set = function(...) actualizarTecla(normalizarArgSet(...), true) end,
                    Get = function() return valor end,
                })
            end

            local TIPOS_SCHEMA = {
                Boton = true, Toggle = true, Casilla = true, Slider = true, RangeSlider = true,
                NumberStepper = true, Input = true, TagInput = true, Dropdown = true,
                RadioGroup = true, ColorPicker = true, Keybind = true, Label = true,
                Progreso = true, Parrafo = true, Divider = true, Imagen = true,
            }

            function Seccion:Construir(lista)
                local resultado = {}
                if type(lista) ~= "table" then
                    advertirDev("Construir", nil, "se esperaba una lista de controles.")
                    return resultado
                end
                for i, def in ipairs(lista) do
                    if type(def) ~= "table" then
                        advertirDev("Construir", nil, "la posición " .. i .. " no es una tabla.")
                    else
                        local cfgControl = clonarTabla(def)
                        local nombreControl = cfgControl.Control
                        cfgControl.Control = nil
                        if nombreControl == nil and TIPOS_SCHEMA[cfgControl.Tipo] then
                            nombreControl = cfgControl.Tipo
                            cfgControl.Tipo = nil
                        end
                        if not (nombreControl and TIPOS_SCHEMA[nombreControl] and type(Seccion[nombreControl]) == "function") then
                            advertirDev("Construir", def.Texto, "tipo desconocido en la posición " .. i .. ": " .. tostring(nombreControl))
                        else
                            local elemento = Seccion[nombreControl](Seccion, cfgControl)
                            resultado[i] = elemento
                            if cfgControl.Flag ~= nil then resultado[cfgControl.Flag] = elemento end
                        end
                    end
                end
                return resultado
            end

            for _, nombreControl in ipairs({
                "Boton", "Toggle", "Casilla", "Slider", "RangeSlider", "NumberStepper",
                "Input", "TagInput", "Dropdown", "RadioGroup", "ColorPicker", "Keybind",
            }) do
                Utils.EnvolverControlBloqueable(Seccion, contenedor, nombreControl)
            end

            return Seccion
        end

        -- Entrada de la pestaña: solo fade (sin UIScale: escalar el boton
        -- re-mediria sus textos truncables en cada frame y puede desplazar
        -- a las pestañas vecinas dentro del UIListLayout).
        if ventanaRevelada then
            Utils.FundirEntrada(botonLat, Nub.Motion.Expand, true)
            Utils.FundirEntrada(botonHoriz, Nub.Motion.Expand, true)
        end
        return Tab
    end

    -- ── PESTAÑA PREINSTALADA ────────────────────────────────────
    -- Esta pestaña SIEMPRE viene con la interfaz (no hay que crearla,
    -- ya está incluida en toda ventana que se genere con Nub).
    -- Trae: info del sistema (ejecutor, versión, FPS), apariencia
    -- (tema de color + orientación de tabs), configuración
    -- (guardar/cargar/exportar/importar) y atajos de teclado.
    -- Se puede pasar Ventana.PestanaPreinstalada = false en CrearVentana
    -- si por algún motivo no se quiere incluir.
    function Ventana:AgregarPestanaPreinstalada(cfg)
        cfg = cfg or {}

        local sysTab = self:CrearTab(cfg.Nombre or "🔧 Preinstalada", "🛠️")

        -- ── Sección: Información ────────────────────────────────
        local secInfo = sysTab:CrearSeccion("Información")

        secInfo:Label({ Texto = "Ejecutor",        Flag = "sys_exec",    Valor = detectarEjecutor() })
        secInfo:Label({ Texto = "Versión",         Flag = "sys_version", Valor = Nub.Version })
        secInfo:Label({ Texto = "Interfaz",        Flag = "sys_creditos", Valor = "nub protegido" })
        local lblFps = secInfo:Label({ Texto = "FPS", Flag = "sys_fps", Valor = "–" })
        local lblFrameTime = secInfo:Label({ Texto = "Frame Time", Flag = "sys_frametime", Valor = "–" })
        local lblEstado = secInfo:Label({ Texto = "Estado", Flag = "sys_estado", Valor = "–" })
        local lblSalud = secInfo:Label({
            Texto = "💚 Salud de la interfaz",
            Flag = "sys_health",
            Valor = "🟢 Calculando...",
            Tooltip = "Evalua objetos de la UI, conexiones registradas y FPS. Verde = bien, Amarillo = atencion, Rojo = problema.",
        })

        -- Memoria: NO todos los ejecutores exponen Stats correctamente
        -- (algunos la bloquean, otros devuelven 0 siempre). Se prueba
        -- una vez con pcall; si falla o da 0, directamente no se crea
        -- el label -- mejor omitirlo que mostrar un dato falso.
        local statsOk, statsService = pcall(function() return game:GetService("Stats") end)
        local lblMemoria
        if statsOk and statsService then
            local okMem, memInicial = pcall(function()
                return statsService:GetTotalMemoryUsageMb()
            end)
            if okMem and type(memInicial) == "number" and memInicial > 0 then
                -- "~" y la aclaracion en el Tooltip dejan claro que es
                -- un aproximado del proceso completo del cliente (no
                -- solo de este script), no una medicion exacta.
                lblMemoria = secInfo:Label({
                    Texto = "Memoria (aprox.)", Flag = "sys_memoria", Valor = "–",
                    Tooltip = "Uso de memoria aproximado de todo el cliente de Roblox, no solo de este script. Puede variar segun el ejecutor.",
                })
            end
        end

        -- Contador de FPS via RunService.Heartbeat, registrado con
        -- RegistrarConexion igual que cualquier otra conexion -- se
        -- limpia solo junto con el resto de la ventana.
        local ultimo, frames = os.clock(), 0
        local inicioSalud = os.clock()
        -- Baseline de objetos/conexiones tomado 5s despues de abrir
        -- la ventana (una vez que todos los tabs, botones, tooltips,
        -- etc. ya terminaron de crearse). Comparar CRECIMIENTO desde
        -- ahi es mucho mas fiable que un numero absoluto: una UI con
        -- muchos tabs arranca con cientos de conexiones sin que eso
        -- sea un problema; lo que si delata una fuga es que ese
        -- numero siga subiendo con el tiempo sin motivo.
        local baseline = nil
        Nub:RegistrarConexion(RunService.Heartbeat:Connect(function()
            frames = frames + 1
            local ahora = os.clock()
            if ahora - ultimo >= 1 then
                local intervalo = ahora - ultimo

                -- Referencia de salud: SIEMPRE a los 5s, mire o no la pestana.
                -- (Si dependiera de que la pestana este abierta, se tomaria la
                -- primera vez que la abras -- quiza minutos despues -- y no
                -- detectaria el crecimiento desde el inicio.)
                if not baseline and (ahora - inicioSalud) >= 5 then
                    local instanciaActiva = _G.Nub_InstanciaActiva
                    baseline = {
                        objetos = _contadorInstanciasUI,
                        conexiones = (instanciaActiva and instanciaActiva.Conexiones and #instanciaActiva.Conexiones) or 0,
                    }
                end

                -- Si nadie lo esta viendo (otra pestana abierta, o la ventana
                -- oculta/minimizada) no se escribe ningun label ni se consulta
                -- la memoria. El contador de frames sigue corriendo (es casi
                -- gratis) y se reinicia, asi el FPS de la primera lectura al
                -- volver es correcto.
                if not (ventanaAbierta and sysTab.Pagina.Visible) then
                    frames, ultimo = 0, ahora
                    return
                end

                local fps = math.round(frames / intervalo)
                local frameTimeMs = math.round((intervalo / frames) * 1000 * 10) / 10

                local elemFps = Nub.Elementos["sys_fps"]
                if elemFps then elemFps.Set(fps .. " FPS") end

                local elemFt = Nub.Elementos["sys_frametime"]
                if elemFt then elemFt.Set(frameTimeMs .. " ms") end

                local elemEstado = Nub.Elementos["sys_estado"]
                if elemEstado then
                    local texto
                    if fps >= 50 then texto = "🟢 Excelente"
                    elseif fps >= 30 then texto = "🟡 Normal"
                    else texto = "🔴 Degradado" end
                    elemEstado.Set(texto)
                end

                if lblMemoria then
                    local okMem, memMb = pcall(function()
                        return statsService:GetTotalMemoryUsageMb()
                    end)
                    local elemMem = Nub.Elementos["sys_memoria"]
                    if okMem and elemMem then
                        elemMem.Set("~" .. math.round(memMb) .. " MB")
                    end
                end

                -- Indicador de salud: CRECIMIENTO de objetos/conexiones
                -- desde el baseline (no el valor absoluto, que varia
                -- mucho segun cuantos tabs/botones tenga cada UI) +
                -- el FPS que ya se calculo arriba.
                local elemSalud = Nub.Elementos["sys_health"]
                if elemSalud then
                    -- Se lee el contador de instancias en tiempo real,
                    -- sin recorrer el arbol de la GUI.
                    local objCount = _contadorInstanciasUI

                    local conexiones = 0
                    local instancia = _G.Nub_InstanciaActiva
                    if instancia and instancia.Conexiones then
                        conexiones = #instancia.Conexiones
                    end

                    if not baseline and (ahora - inicioSalud) >= 5 then
                        baseline = { objetos = objCount, conexiones = conexiones }
                    end

                    local problemas = {}
                    local estado = "🟢 Excelente"

                    if not baseline then
                        estado = "⚪ Calculando..."
                    else
                        local crecObj = objCount - baseline.objetos
                        local crecCon = conexiones - baseline.conexiones

                        if crecObj > 1500 then
                            estado = "🔴 Crítico"
                            table.insert(problemas, "+" .. crecObj .. " objetos desde el inicio")
                        elseif crecObj > 600 then
                            estado = "🟡 Atención"
                        end

                        if crecCon > 100 then
                            estado = "🔴 Crítico"
                            table.insert(problemas, "+" .. crecCon .. " conexiones desde el inicio")
                        elseif crecCon > 50 and estado == "🟢 Excelente" then
                            estado = "🟡 Atención"
                        end
                    end

                    if fps < 20 then
                        estado = "🔴 Crítico"
                        table.insert(problemas, "FPS " .. fps)
                    elseif fps < 30 and estado == "🟢 Excelente" then
                        estado = "🟡 Atención"
                    end

                    local texto = estado
                    if #problemas > 0 then
                        texto = texto .. " (" .. table.concat(problemas, ", ") .. ")"
                    end
                    elemSalud.Set(texto)
                end

                frames, ultimo = 0, ahora
            end
        end))

        -- ── Sección: Diagnóstico del entorno ─────────────────────
        -- Una sola sección que agrupa: donde corre, que soporta y que
        -- advertencias hay. Se recalcula en cada CrearVentana (no cada
        -- frame): el entorno no cambia en caliente salvo el viewport,
        -- y eso ya lo maneja el listener en vivo de Capacidades.
        local secDiag = sysTab:CrearSeccion("🖥️ Diagnóstico del entorno")

        local C = Nub.Capacidades

        -- Entorno: descripcion corta y legible. Se arma con las
        -- piezas disponibles para que se lea como una sola frase.
        local function descripcionEntorno()
            local partes = { C.Tipo }
            if C.Plataforma then table.insert(partes, C:NombrePlataforma()) end
            local input
            if C.EsTouchOnly then input = "Solo táctil"
            elseif C.TieneMouse and C.Teclado then input = "Mouse + Teclado"
            elseif C.TieneTouch then input = "Táctil + Otros"
            elseif C.Gamepad then input = "Gamepad"
            else input = "Sin input detectado" end
            table.insert(partes, input)
            return table.concat(partes, " · ")
        end

        secDiag:Label({
            Texto = "Entorno",
            Flag  = "diag_entorno",
            Valor = descripcionEntorno(),
            Tooltip = "Tipo de dispositivo detectado, plataforma del sistema y método de entrada principal. Si la clasificación no es correcta, puedes forzarla con Nub:ForzarTipo().",
        })

        secDiag:Label({
            Texto = "Ejecutor",
            Flag  = "diag_ejecutor",
            Valor = detectarEjecutor(),
            Tooltip = "Nombre del ejecutor detectado. 'Desconocido' suele indicar un ejecutor poco común o Roblox Studio.",
        })

        secDiag:Label({
            Texto = "Viewport",
            Flag  = "diag_viewport",
            Valor = (function()
                local v = C.ViewportSize
                return math.floor(v.X) .. " x " .. math.floor(v.Y)
            end)(),
            Tooltip = "Resolución lógica actual de la cámara. Se actualiza en vivo si rotás la pantalla o redimensionás la ventana.",
        })

        -- Conteo de features soportadas con semáforo
        local totalFeatures, soportadasFeatures = 0, 0
        local listaAdvertencias = {}
        for _, f in ipairs(Nub.Features) do
            totalFeatures = totalFeatures + 1
            local r = Nub:VerificarSoporte(f.nombre)
            if r.ok then
                soportadasFeatures = soportadasFeatures + 1
            elseif f.nivel ~= "requerido" then
                table.insert(listaAdvertencias, {
                    nivel = f.nivel, nombre = f.nombre, mensaje = r.mensaje or "",
                })
            end
        end

        local emoji
        if soportadasFeatures == totalFeatures then emoji = "🟢"
        elseif soportadasFeatures >= totalFeatures - 2 then emoji = "🟡"
        else emoji = "🔴" end

        secDiag:Label({
            Texto = "Funciones soportadas",
            Flag  = "diag_features",
            Valor = soportadasFeatures .. "/" .. totalFeatures .. " " .. emoji,
            Tooltip = "Cuántas funciones opcionales de Nub están disponibles en este entorno. Las que no, se listan como advertencias abajo.",
        })

        -- Advertencias: SOLO se crean si hay algo que avisar. Si todo
        -- está bien, la sección termina en el label de arriba y no
        -- agrega ruido.
        --
        -- Usa Parrafo, no Label: Label reserva una columna fija de
        -- 120px para el valor y trunca con "..." si no entra -- pensado
        -- para valores cortos que cambian en vivo (FPS, ping), no para
        -- oraciones descriptivas como estas ("La GUI puede ser
        -- detectada por anti-cheats."). Parrafo no trunca, ajusta el
        -- texto a varias líneas y ocupa el ancho completo de la fila.
        if #listaAdvertencias > 0 then
            secDiag:Divider({ Texto = "⚠️ Advertencias del sistema" })
            for _, adv in ipairs(listaAdvertencias) do
                local ico = (adv.nivel == "recomendado") and "🔴" or "🟡"
                secDiag:Parrafo({
                    Titulo    = ico .. " " .. adv.nombre .. " (" .. adv.nivel .. ")",
                    Contenido = adv.mensaje,
                })
            end
        end

        -- Botón de diagnóstico completo (a consola, no a portapapeles
        -- -- setclipboard puede no existir en este entorno, y para
        -- eso justamente sirve este panel).
        secDiag:Boton({
            Texto = "🩺 Imprimir diagnóstico completo en consola",
            Tooltip = "Vuelca toda la información de entorno y capacidades en la consola (F9). Útil para reportar bugs.",
            Callback = function()
                Nub:Profiler()
                local d = Nub:DiagnosticoCompleto()
                print(("[Nub] Entorno: %s · %s"):format(d.Tipo, d.Plataforma))
                print(("[Nub] Ejecutor: %s · Viewport: %dx%d"):format(
                    d.Ejecutor, math.floor(d.Viewport.X), math.floor(d.Viewport.Y)))
                print(("[Nub] Features: %d/%d soportadas"):format(d.FeaturesOk, d.FeaturesTotal))
                if d.Forzado then
                    print(("[Nub] Tipo forzado manualmente: %s"):format(d.Forzado))
                end
                for _, adv in ipairs(d.Advertencias) do
                    print(("[Nub]   %s %s — %s"):format(
                        adv.nivel == "recomendado" and "🔴" or "🟡", adv.nombre, adv.mensaje))
                end
            end,
        })

        local tiposForzables = { "Auto", "PC", "Movil", "Tablet", "Consola" }
        local forzadoActual = _G.Nub_TipoForzado or "Auto"
        if not table.find(tiposForzables, forzadoActual) then forzadoActual = "Auto" end
        secDiag:Dropdown({
            Texto    = "🖥️ Forzar tipo de dispositivo",
            Flag     = "diag_forzar_tipo",
            Opciones = tiposForzables,
            Defecto  = forzadoActual,
            Tooltip  = "Úsalo solo si la interfaz detectó mal tu dispositivo (por ejemplo, una tablet clasificada como móvil). 'Auto' vuelve a la detección automática.",
            Callback = function(v)
                if v == "Auto" then Nub:LiberarForzado() else Nub:ForzarTipo(v) end
            end,
        })
        Nub:MarcarComoUI("diag_forzar_tipo")

        -- ── Sección: Apariencia ─────────────────────────────────
        local secAp = sysTab:CrearSeccion("Apariencia")

        -- Selector de tema unico.
        local nombresTemas = {}
        for nombre in pairs(Nub.ThemeManager.Temas) do
            table.insert(nombresTemas, nombre)
        end
        table.sort(nombresTemas)

        secAp:Dropdown({
            Texto    = "🎨 Apariencia",
            Flag     = "sys_tema",
            Opciones = nombresTemas,
            Defecto  = Themes.Predeterminado,
            Tooltip  = "Cambia el color y el brillo de toda la interfaz. 'Blanco' usa fondo claro con texto oscuro; los demas usan fondo oscuro con texto claro.",
            Callback = function(v)
                Nub.ThemeManager:AplicarTema(v)
                Nub:Notificar({ Titulo = "Tema", Texto = "'" .. v .. "' aplicado", Duracion = 2 })
            end,
        })

        -- Orientacion de tabs
        secAp:Dropdown({
            Texto    = "📐 Orientación de tabs",
            Flag     = "sys_orientacion",
            Opciones = { "vertical", "horizontal" },
            Defecto  = modoHorizontal and "horizontal" or "vertical",
            Tooltip  = "Lateral o barra superior",
            Callback = function(v) self:CambiarOrientacion(v) end,
        })

        -- Escala manual de la interfaz (se combina con el auto-ajuste
        -- por resolución de pantalla que ya corre en segundo plano)
        secAp:Slider({
            Texto      = "📏 Tamaño de la interfaz",
            Flag       = "sys_escala",
            Min        = 70,
            Max        = 130,
            Incremento = 5,
            Sufijo     = "%",
            Defecto    = ESCALA_INTERFAZ_INICIAL,
            Tooltip    = "Ajusta el tamaño general de la interfaz (ventana, botones, espaciados), además del ajuste automático según tu resolución de pantalla",
            Callback   = function(v)
                escalaManual = v / 100
                recalcularEscala()
            end,
        })

        -- NEW: ancho y alto ajustables por separado. A diferencia del
        -- slider de arriba (que agranda TODO proporcionalmente), estos
        -- dos cambian la FORMA de la ventana: mas ancha sin ser mas
        -- alta, o mas alta sin ser mas ancha.
        secAp:Slider({
            Texto      = "↔️ Ancho de la ventana",
            Flag       = "sys_ancho",
            Min        = 70,
            Max        = 130,
            Incremento = 5,
            Sufijo     = "%",
            Defecto    = 100,
            Tooltip    = "Hace la ventana más ancha o más angosta, sin cambiar su altura",
            Callback   = function(v)
                factorAncho = v / 100
                actualizarTamanoVentana()
                recalcularEscala()
            end,
        })

        secAp:Slider({
            Texto      = "↕️ Alto de la ventana",
            Flag       = "sys_alto",
            Min        = 70,
            Max        = 130,
            Incremento = 5,
            Sufijo     = "%",
            Defecto    = 100,
            Tooltip    = "Hace la ventana más alta o más baja, sin cambiar su ancho",
            Callback   = function(v)
                factorAlto = v / 100
                actualizarTamanoVentana()
                recalcularEscala()
            end,
        })

        -- Escala de texto (unificada: antes habia un slider separado
        -- para "tamaño de texto de pestañas" y otro para "tamaño de
        -- texto general" -- se fusionan en uno solo, ya que en la
        -- practica el usuario los mueve siempre juntos).
        secAp:Slider({
            Texto      = "🔡 Tamaño del texto",
            Flag       = "sys_escala_texto",
            Min        = 80,
            Max        = 150,
            Incremento = 5,
            Sufijo     = "%",
            Defecto    = ESCALA_TEXTO_INICIAL,
            Tooltip    = "Agranda o achica la letra de pestañas, toggles, casillas, sliders, títulos y el resto de la interfaz, sin cambiar el tamaño de los botones",
            Callback   = function(v)
                aplicarEscalaTexto("tabs", v / 100)
                aplicarEscalaTexto("general", v / 100)
            end,
        })

        -- Posicion de la ventana: recordarla entre ejecuciones y volver al centro.
        if fsDisponible() then
            secAp:Toggle({
                Texto    = "📍 Recordar posición",
                Flag     = "sys_recordar_pos",
                Defecto  = guardarPosActual,
                Tooltip  = "Recuerda dónde dejaste la ventana la próxima vez que ejecutes este script. Apagado, siempre abre en el centro.",
                Callback = function(v) guardarPosActual = (v == true) end,
            })
        end
        secAp:Boton({
            Texto    = "🎯 Resetear posición",
            Tooltip  = "Devuelve la ventana al centro de la pantalla",
            Callback = function()
                Ventana:ResetearPosicion()
                Nub:Notificar({ Titulo = "Posición", Texto = "Ventana centrada", Duracion = 2 })
            end,
        })

        -- Borde de la ventana: estilos con degradado y animacion, con los colores
        -- de la interfaz (o los que elijas).
        local bordeUI = { estilo = "Normal", animar = true, grosor = 2,
            c1 = Theme.Accent, c2 = Theme.AccentLight }
        do
            local spec = especBordeInicial
            local colorSpec = spec
            if type(spec) == "table" and spec[1] == nil then
                colorSpec = spec.Color
                if spec.Grosor then bordeUI.grosor = math.clamp(math.floor(tonumber(spec.Grosor) or 2), 1, 6) end
                if spec.Animar ~= nil then bordeUI.animar = (spec.Animar == true) end
            end
            if colorSpec == nil or colorSpec == false or colorSpec == "ninguno" then
                bordeUI.estilo = "Normal"
            elseif colorSpec == "tema" then bordeUI.estilo = "Tema"
            elseif colorSpec == "acento" then bordeUI.estilo = "Acento"
            elseif colorSpec == "rainbow" then bordeUI.estilo = "Arcoíris"
            else
                bordeUI.estilo = "Personalizado"
                if typeof(colorSpec) == "Color3" then
                    bordeUI.c1 = colorSpec
                elseif type(colorSpec) == "table" then
                    if typeof(colorSpec[1]) == "Color3" then bordeUI.c1 = colorSpec[1] end
                    if typeof(colorSpec[2]) == "Color3" then bordeUI.c2 = colorSpec[2] end
                end
            end
        end
        local function aplicarBordeDesdeUI()
            local colorSpec
            if bordeUI.estilo == "Tema" then colorSpec = "tema"
            elseif bordeUI.estilo == "Acento" then colorSpec = "acento"
            elseif bordeUI.estilo == "Arcoíris" then colorSpec = "rainbow"
            elseif bordeUI.estilo == "Personalizado" then colorSpec = { bordeUI.c1, bordeUI.c2 } end
            if colorSpec == nil then
                Ventana:EstablecerBorde(nil)
            else
                Ventana:EstablecerBorde({ Color = colorSpec, Grosor = bordeUI.grosor, Animar = bordeUI.animar })
            end
        end

        secAp:Dropdown({
            Texto    = "🌈 Borde de la ventana",
            Flag     = "sys_borde_estilo",
            Opciones = { "Normal", "Tema", "Acento", "Arcoíris", "Personalizado" },
            Defecto  = bordeUI.estilo,
            Tooltip  = "Normal: el borde de siempre. Tema: degradado con los colores de la interfaz. Acento: un solo color. Arcoíris: animado. Personalizado: usa los dos colores de abajo.",
            Callback = function(v) bordeUI.estilo = v; aplicarBordeDesdeUI() end,
        })
        secAp:Toggle({
            Texto    = "✨ Animar el borde",
            Flag     = "sys_borde_animar",
            Defecto  = bordeUI.animar,
            Tooltip  = "Hace girar el degradado del borde. En un color liso no se nota.",
            Callback = function(v) bordeUI.animar = (v == true); aplicarBordeDesdeUI() end,
        })
        secAp:Slider({
            Texto      = "Grosor del borde",
            Flag       = "sys_borde_grosor",
            Min = 1, Max = 6, Incremento = 1, Sufijo = " px",
            Defecto    = bordeUI.grosor,
            Callback   = function(v) bordeUI.grosor = v; aplicarBordeDesdeUI() end,
        })
        secAp:ColorPicker({
            Texto    = "Borde: color 1",
            Flag     = "sys_borde_c1",
            Defecto  = bordeUI.c1,
            Tooltip  = "Solo con el estilo Personalizado",
            Callback = function(c) bordeUI.c1 = c; aplicarBordeDesdeUI() end,
        })
        secAp:ColorPicker({
            Texto    = "Borde: color 2",
            Flag     = "sys_borde_c2",
            Defecto  = bordeUI.c2,
            Tooltip  = "Solo con el estilo Personalizado",
            Callback = function(c) bordeUI.c2 = c; aplicarBordeDesdeUI() end,
        })

        -- Todos los ajustes de esta seccion son de LA INTERFAZ, no del
        -- script/juego que la usa: quedan fuera del sistema de
        -- PERFILES por completo y viven en su propio guardado
        -- (ver seccion "Configuración" mas abajo -> Guardar/Cargar/
        -- Eliminar de Preinstalada).
        Nub:MarcarComoUI({
            "sys_tema", "sys_orientacion", "sys_escala",
            "sys_ancho", "sys_alto", "sys_escala_texto", "sys_recordar_pos",
            "sys_borde_estilo", "sys_borde_animar", "sys_borde_grosor",
            "sys_borde_c1", "sys_borde_c2",
        })

        -- ── Sección: Configuración ──────────────────────────────
        -- Los 3 botones de aca SOLO afectan los ajustes de ESTA
        -- pestaña (tema, orientacion, escala, ancho/alto, tamaño de
        -- texto) -- usan SM:GuardarUI/CargarUI/EliminarUI, que operan
        -- unicamente sobre flags marcados con MarcarComoUI. Jamas
        -- tocan ni leen los perfiles de script (esos son la seccion
        -- "Perfiles de script" de mas abajo, con su propio Guardar/
        -- Cargar/Eliminar, completamente separado de este).
        local secCfg = sysTab:CrearSeccion("Configuración")
        local NOMBRE_GUARDADO_UI = "preinstalada"

        secCfg:Boton({
            Texto    = "💾 Guardar",
            Tooltip  = "Guarda SOLO los ajustes de esta pestaña (tema, tamaños, orientación)",
            Async    = true,
            Callback = function()
                Nub.SaveManager:GuardarUI(NOMBRE_GUARDADO_UI)
            end,
        })

        secCfg:Boton({
            Texto    = "📂 Cargar",
            Tooltip  = "Carga los ajustes guardados de esta pestaña",
            Async    = true,
            Callback = function()
                Nub.SaveManager:CargarUI(NOMBRE_GUARDADO_UI)
            end,
        })

        secCfg:Boton({
            Texto    = "🗑️ Eliminar",
            Tooltip  = "Borra el guardado de esta pestaña (no afecta perfiles de script)",
            Async    = true,
            Callback = function()
                local ok = Nub.SaveManager:EliminarUI(NOMBRE_GUARDADO_UI)
                Nub:Notificar({
                    Titulo = "Preinstalada",
                    Texto  = ok and "Guardado eliminado" or "No había nada guardado",
                    Duracion = 3,
                })
            end,
        })

        -- ── Sección: Perfiles de script ─────────────────────────
        -- Sistema COMPLETAMENTE INDEPENDIENTE del de arriba. Usa
        -- SM:Guardar/Cargar/Listar/Eliminar (sin sufijo "UI"), que
        -- operan sobre TODOS los flags del script que usa Nub
        -- (Toggles, Sliders, Dropdowns, etc. que el desarrollador cree
        -- en sus propios tabs) EXCEPTO los marcados con MarcarComoUI
        -- -- es decir, nunca incluyen ni sobreescriben nada de la
        -- seccion "Configuración" de arriba. Aparece automaticamente
        -- en cualquier script que use Nub, sin que el desarrollador
        -- tenga que escribir codigo para tenerlo.
        local secPerfiles = sysTab:CrearSeccion("Perfiles de script")
        local perfilSeleccionadoUI = nil

        local dropdownPerfilesUI = secPerfiles:Dropdown({
            Texto    = "Perfil",
            Flag     = "sys_perfil_elegido",
            Opciones = Nub.SaveManager:Listar(),
            Tooltip  = "Configuraciones guardadas del script (no de esta pestaña)",
            Callback = function(v) perfilSeleccionadoUI = v end,
        })
        Nub:MarcarComoUI("sys_perfil_elegido") -- la SELECCION en si es un ajuste de interfaz, no un valor de perfil

        secPerfiles:Boton({
            Texto    = "🔄 Refrescar lista",
            Tooltip  = "Vuelve a leer los perfiles guardados en disco",
            Callback = function()
                dropdownPerfilesUI.ActualizarOpciones(Nub.SaveManager:Listar())
            end,
        })

        secPerfiles:Boton({
            Texto    = "📂 Cargar perfil seleccionado",
            Async    = true,
            Callback = function()
                if not perfilSeleccionadoUI then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = "Elegí un perfil primero", Duracion = 3 })
                    return
                end
                Nub.SaveManager:CambiarPerfil(self, perfilSeleccionadoUI)
            end,
        })

        secPerfiles:Input({
            Texto       = "Nombre para guardar",
            Flag        = "sys_nombre_nuevo_perfil",
            Placeholder = "ej: farm, pvp, raids...",
            Tooltip     = "Nombre del perfil a crear o sobreescribir",
        })
        Nub:MarcarComoUI("sys_nombre_nuevo_perfil") -- texto de gestion de perfiles, no config de juego

        secPerfiles:Boton({
            Texto    = "💾 Guardar como nuevo perfil",
            Async    = true,
            Callback = function()
                local nombreNuevo = Nub:ObtenerFlag("sys_nombre_nuevo_perfil")
                if not nombreNuevo or nombreNuevo == "" then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = "Escribí un nombre arriba primero", Duracion = 3 })
                    return
                end
                Nub.SaveManager:CambiarPerfil(self, nombreNuevo)
                dropdownPerfilesUI.ActualizarOpciones(Nub.SaveManager:Listar())
            end,
        })

        secPerfiles:Boton({
            Texto    = "🗑️ Eliminar perfil seleccionado",
            Async    = true,
            Callback = function()
                if not perfilSeleccionadoUI then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = "Elegí un perfil primero", Duracion = 3 })
                    return
                end
                local ok = Nub.SaveManager:Eliminar(perfilSeleccionadoUI)
                Nub:Notificar({
                    Titulo = "Perfiles",
                    Texto  = ok and ("'" .. perfilSeleccionadoUI .. "' eliminado") or "No se pudo eliminar",
                    Duracion = 3,
                })
                if ok then
                    perfilSeleccionadoUI = nil
                    dropdownPerfilesUI.ActualizarOpciones(Nub.SaveManager:Listar())
                end
            end,
        })

        local function refrescarListaPerfiles()
            dropdownPerfilesUI.ActualizarOpciones(Nub.SaveManager:Listar())
        end

        secPerfiles:Input({
            Texto         = "Texto del perfil (exportar / importar)",
            Flag          = "sys_perfil_texto",
            Tipo          = "textarea",
            Alto          = 90,
            MaxCaracteres = 60000,
            Placeholder   = "Aquí aparece el perfil exportado. Pega uno para importarlo...",
            Tooltip       = "Exportar escribe aquí el contenido del perfil seleccionado. Para importar, pega el texto aquí",
        })
        Nub:MarcarComoUI("sys_perfil_texto")

        local grupoPerfilesA = secPerfiles:Grupo()
        grupoPerfilesA:Boton({
            Texto    = "📑 Duplicar",
            Tooltip  = "Copia el perfil seleccionado con el nombre escrito arriba",
            Callback = function()
                local nombreNuevo = Nub:ObtenerFlag("sys_nombre_nuevo_perfil")
                if not perfilSeleccionadoUI or not nombreNuevo or nombreNuevo == "" then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = "Elegí un perfil y escribí el nombre nuevo", Duracion = 3 })
                    return
                end
                local ok, motivo = Nub.SaveManager:Duplicar(perfilSeleccionadoUI, nombreNuevo)
                Nub:Notificar({ Titulo = ok and "📑 Perfil duplicado" or "Perfiles", Texto = ok and nombreNuevo or tostring(motivo), Duracion = 3 })
                if ok then refrescarListaPerfiles() end
            end,
        })
        grupoPerfilesA:Boton({
            Texto    = "✏️ Renombrar",
            Tooltip  = "Cambia el nombre del perfil seleccionado al escrito arriba",
            Callback = function()
                local nombreNuevo = Nub:ObtenerFlag("sys_nombre_nuevo_perfil")
                if not perfilSeleccionadoUI or not nombreNuevo or nombreNuevo == "" then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = "Elegí un perfil y escribí el nombre nuevo", Duracion = 3 })
                    return
                end
                local ok, motivo = Nub.SaveManager:Renombrar(perfilSeleccionadoUI, nombreNuevo)
                Nub:Notificar({ Titulo = ok and "✏️ Perfil renombrado" or "Perfiles", Texto = ok and (motivo or nombreNuevo) or tostring(motivo), Duracion = 3 })
                if ok then
                    perfilSeleccionadoUI = nil
                    refrescarListaPerfiles()
                end
            end,
        })

        local grupoPerfilesB = secPerfiles:Grupo()
        grupoPerfilesB:Boton({
            Texto    = "📤 Exportar",
            Tooltip  = "Escribe el perfil seleccionado en la caja de arriba y lo copia al portapapeles si el ejecutor lo permite",
            Callback = function()
                if not perfilSeleccionadoUI then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = "Elegí un perfil primero", Duracion = 3 })
                    return
                end
                local texto, copiado = Nub.SaveManager:Exportar(perfilSeleccionadoUI)
                if not texto then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = tostring(copiado), Duracion = 3 })
                    return
                end
                Nub.Elementos["sys_perfil_texto"].Set(texto, false)
                Nub:Notificar({
                    Titulo = "📤 Perfil exportado",
                    Texto  = copiado and "Copiado al portapapeles" or "Copia el texto de la caja",
                    Duracion = 3,
                })
            end,
        })
        grupoPerfilesB:Boton({
            Texto    = "📥 Importar",
            Tooltip  = "Crea un perfil nuevo con el nombre escrito arriba a partir del texto de la caja",
            Callback = function()
                local nombreNuevo = Nub:ObtenerFlag("sys_nombre_nuevo_perfil")
                if not nombreNuevo or nombreNuevo == "" then
                    Nub:Notificar({ Titulo = "Perfiles", Texto = "Escribí el nombre del perfil nuevo", Duracion = 3 })
                    return
                end
                local ok, motivo = Nub.SaveManager:Importar(nombreNuevo, Nub:ObtenerFlag("sys_perfil_texto"))
                Nub:Notificar({ Titulo = ok and "📥 Perfil importado" or "Perfiles", Texto = ok and nombreNuevo or tostring(motivo), Duracion = 3 })
                if ok then refrescarListaPerfiles() end
            end,
        })

        secPerfiles:Parrafo({
            Titulo    = "Exclusivo del script",
            Contenido = "Este sistema guarda y carga la configuración del script que usa Nub (sliders, toggles, dropdowns, etc.). No tiene relación con la sección 'Configuración' de arriba, que es solo de esta pestaña.",
        })

        -- ── Sección: Atajos ─────────────────────────────────────
        local secHist = sysTab:CrearSeccion("Historial de cambios")
        local lblHistorial = secHist:Label({
            Texto   = "Cambios registrados",
            Flag    = "sys_historial_estado",
            Valor   = "Nada que deshacer",
            Tooltip = "Se registran los cambios de los controles del script (no los de esta pestaña)",
        })
        local grupoHistorial = secHist:Grupo()
        grupoHistorial:Boton({
            Texto    = "↩️ Deshacer",
            Callback = function()
                local ok, entrada = Nub:Deshacer()
                Nub:Notificar({
                    Titulo = ok and "↩️ Deshecho" or "Historial",
                    Texto  = ok and Nub:DescribirCambio(entrada) or "No hay nada que deshacer",
                    Duracion = 2,
                })
            end,
        })
        grupoHistorial:Boton({
            Texto    = "↪️ Rehacer",
            Callback = function()
                local ok, entrada = Nub:Rehacer()
                Nub:Notificar({
                    Titulo = ok and "↪️ Rehecho" or "Historial",
                    Texto  = ok and Nub:DescribirCambio(entrada) or "No hay nada que rehacer",
                    Duracion = 2,
                })
            end,
        })
        Nub:RegistrarConexion(Nub.Eventos.HistorialCambiado:Connect(function(nDeshacer, nRehacer)
            local texto = (nDeshacer == 0 and nRehacer == 0) and "Nada que deshacer"
                or (nDeshacer .. " para deshacer · " .. nRehacer .. " para rehacer")
            pcall(function() lblHistorial.Set(texto) end)
        end))

        local secAtajos = sysTab:CrearSeccion("Atajos de teclado")
        secAtajos:Parrafo({
            Titulo    = "⌨️ Teclas rápidas",
            Contenido = "RightCtrl — mostrar / ocultar interfaz\n"
                     .. "Botón minimizar (—) — colapsa la ventana\n"
                     .. "Botón cerrar (✕) — destruye la GUI",
        })

        self._pestanaSistema = sysTab
        return sysTab
    end

    -- Atajo para cambiar tema desde fuera
    function Ventana:CambiarTema(nombre)
        Nub.ThemeManager:AplicarTema(nombre)
        Nub:Notificar({ Titulo = "🎨 Tema", Texto = "'" .. nombre .. "' aplicado", Duracion = 2 })
    end

    -- Guardar ref al main para acceso externo (opcional)
    Ventana._main = Ventana_main

    -- La pestaña Preinstalada viene SIEMPRE incluida por defecto.
    -- Para quitarla (no recomendado) hay que pasar explicitamente
    -- PestanaPreinstalada = false al crear la ventana.
    if config.PestanaPreinstalada ~= false then
        local cfg2 = type(config.PestanaPreinstalada) == "table"
            and config.PestanaPreinstalada or {}
        Ventana:AgregarPestanaPreinstalada(cfg2)
    end

    -- ── AUTO-GUARDADO NATIVO ─────────────────────────────────────
    -- Por defecto la persistencia esta SIEMPRE activa (no hay que
    -- configurar nada): al mover un slider o activar un toggle, la
    -- libreria lo guarda sola en segundo plano, y la proxima vez que
    -- se ejecute el script, cada control vuelve a su ultima posicion
    -- automaticamente. Se puede desactivar con AutoGuardar = false.
    local nombreConfig = config.NombreConfig or "autosave"
    Ventana.NombreConfig = nombreConfig

    -- OJO: se lee 'Ventana.NombreConfig' (el campo, no el upvalue
    -- 'nombreConfig' de arriba) a proposito -- asi, si algo cambia ese
    -- campo despues de crear la ventana (ej. SM:CambiarPerfil, ver mas
    -- abajo en SaveManager), estas dos funciones automaticamente
    -- empiezan a guardar/cargar bajo el nombre nuevo sin tener que
    -- recrear la ventana.
    function Ventana:GuardarConfiguracion()
        return Nub.SaveManager:Guardar(Ventana.NombreConfig)
    end

    function Ventana:CargarConfiguracion()
        return Nub.SaveManager:Cargar(Ventana.NombreConfig)
    end

    if config.AutoGuardar ~= false and fsDisponible() then
        -- Esta ventana queda como "la activa" para que el proxy de
        -- Nub.Flags sepa a donde guardar cuando el usuario toque
        -- cualquier control.
        ventanaActivaGuardado = Ventana

        -- Carga silenciosa e inmediata al iniciar (silenciosa en el
        -- sentido de "sin bloquear ni pedir confirmacion" -- SI avisa
        -- con una notificacion breve si encuentra un guardado previo,
        -- para que el usuario sepa que sus ajustes volvieron).
        -- task.defer corre apenas termina este frame, ya con todos
        -- los controles creados y listos para recibir el Set().
        --
        -- Se cargan los DOS sistemas de guardado por separado: el
        -- perfil de script activo (CargarSilencioso, carpeta de
        -- perfiles) y los ajustes de la pestaña Preinstalada
        -- (CargarUI, carpeta separada). Antes solo se cargaba el
        -- primero -- el tema, la escala y el ancho/alto guardados
        -- en Preinstalada nunca se restauraban solos al reabrir el
        -- script, habia que entrar y tocar "Cargar" a mano.
        task.defer(function()
            local ok, err = pcall(function() Nub.SaveManager:CargarSilencioso(Ventana.NombreConfig) end)
            if not ok then Nub:_RegistrarError("AutoCarga", err) end

            local okUI, errUI = pcall(function() Nub.SaveManager:CargarUI("preinstalada") end)
            if not okUI then Nub:_RegistrarError("AutoCarga (Preinstalada)", errUI) end
        end)

        -- Respaldo: guardar tambien al cerrar la ventana, por si el
        -- ciclo periodico de abajo (cada 10s) no llego a correr antes
        -- de que el juego se cierre de golpe. Tambien apaga el loop
        -- compartido -- sin esto seguiria corriendo indefinidamente
        -- en el fondo tras destruir la ventana (RegistrarHilo limpia
        -- el hilo, pero el 'while' necesita su propia condicion de
        -- salida para no quedar esperando un task.wait que nunca mas
        -- va a hacer nada util).
        sg.Destroying:Connect(function()
            loopAutoguardadoActivo = false
            local ok, err = pcall(function() Nub.SaveManager:GuardarSilencioso(Ventana.NombreConfig) end)
            if not ok then Nub:_RegistrarError("AutoGuardado (cierre)", err) end
        end)

        -- El unico ciclo periodico de autoguardado es iniciarLoopAutoguardado()
        -- (definido arriba, junto a marcarCambioPendiente): revisa cada
        -- 10s si hubo cambios y guarda solo entonces. Reemplaza al
        -- guardado incondicional anterior de 60s, que escribia el
        -- archivo aunque nada hubiera cambiado.
        iniciarLoopAutoguardado()
    end

    -- Se completa aca (y no antes) porque el objeto Ventana recien
    -- termino de construirse en este punto. El registro en si
    -- (Conexiones/Hilos/Dibujos/Instancias) ya existia desde el
    -- inicio de la funcion -- esto solo agrega la referencia para
    -- que CrearVentanaConSeguridad pueda detectar conflictos.
    if _G.Nub_InstanciaActiva then
        _G.Nub_InstanciaActiva.Ventana = Ventana
    end

    return Ventana
    end)

    if not ok then
        warn("[Nub] Error crítico creando la ventana:", resultado)
        pcall(function()
            Nub:Notificar({
                Titulo = "⚠️ nub protegido",
                Texto  = "No se pudo crear la interfaz. Revisa la consola.",
                Duracion = 6,
            })
        end)
        -- Objeto "fantasma": cualquier metodo llamado sobre el (CrearTab,
        -- CrearSeccion, Toggle, etc.) no hace nada y no revienta el script
        -- que lo esta usando (ej. un ESP que sigue corriendo su logica
        -- aunque la UI no se haya podido dibujar).
        local fantasma = {}
        local function noOperacion() return fantasma end
        setmetatable(fantasma, { __index = function() return noOperacion end })
        return fantasma
    end

    return resultado
end

-- ══════════════════════════════════════════════════════════════
--  CrearVentanaConSeguridad( config )
-- ══════════════════════════════════════════════════════════════
-- Igual que CrearVentana, pero si ya hay otra ventana de Nub
-- abierta (de otro script cargado en la misma sesion del ejecutor),
-- pregunta antes de reemplazarla en vez de pisarla en silencio.
--
-- A diferencia de CrearVentana (que siempre limpia todo sin avisar,
-- pensado para cuando el MISMO script se re-ejecuta), esta variante
-- es para cuando se cargan dos scripts DISTINTOS y no queres perder
-- el que ya estaba corriendo sin querer.
--
-- Parametros: la misma tabla que CrearVentana.
-- Retorna: la ventana creada, o nil si el usuario elige "No".
function Nub:CrearVentanaConSeguridad(config)
    config = config or {}
    local nombreConfig  = config.NombreConfig or "autosave"
    -- Un flag por script (no uno global): asi la preferencia de un
    -- script no pisa la de otro. Se guarda dentro del propio
    -- NombreConfig del script que la marco (ver mas abajo), asi que
    -- tiene que cargarse ANTES de decidir si mostrar el modal --
    -- CrearVentana normalmente restaura los flags con task.defer
    -- (un frame despues), pero aca lo necesitamos ya, en esta misma
    -- linea, para poder saltarnos el modal si corresponde.
    local flagRecordar = "AutoReemplazar_" .. (config.Titulo or "default")
    pcall(function() Nub.SaveManager:CargarSilencioso(nombreConfig) end)

    if Nub.Flags[flagRecordar] == true then
        local activa = _G.Nub_InstanciaActiva
        if activa and activa.Ventana and activa.Ventana.Destruir then
            pcall(function() activa.Ventana:Destruir() end)
        end
        return Nub:CrearVentana(config)
    end

    local instanciaActiva = _G.Nub_InstanciaActiva
    local ventanaActual   = instanciaActiva and instanciaActiva.Ventana

    -- Sin conflicto: no hay ventana previa viva, crear directo.
    -- (CrearVentana ya se encarga de dejar Ventana/Titulo en el
    -- registro para la proxima comparacion.)
    if not (ventanaActual and ventanaActual._main and ventanaActual._main.Parent) then
        return Nub:CrearVentana(config)
    end

    -- Hay conflicto: se pregunta con Nub:Dialogo (mismo modal, mismo borde y
    -- mismos botones que el resto de los dialogos). Antes este dialogo se armaba
    -- aparte con Utils.BotonBase SIN indicar 'Transparencia' -- y BotonBase es
    -- transparente por defecto --, asi que los botones Si/No y la casilla
    -- "No volver a preguntar" quedaban invisibles (solo se veian sus textos).
    local tituloActual    = instanciaActiva.Titulo or "Interfaz actual"
    local tituloNuevo     = config.Titulo or "Script sin título"
    local subtituloNuevo  = config.Subtitulo or "Desconocido"

    -- Pausa sincronica: el script ENTRANTE se detiene aqui hasta que el
    -- usuario elija, para que no siga creando tabs o botones sobre una
    -- ventana que todavia no existe.
    local eventoPausa = Instance.new("BindableEvent")
    local respuestaAceptada, decisionTomada, recordarMarcado = false, false, false
    local function decidir(acepta, recordar)
        if decisionTomada then return end
        decisionTomada = true
        respuestaAceptada = acepta
        recordarMarcado = (recordar == true)
        eventoPausa:Fire()
    end

    local modal = Nub:Dialogo({
        Tipo = "warning",
        Titulo = "Nuevo script detectado",
        Contenido = string.format(
            "Se detectó un nuevo script: \"%s\" (%s)\n¿Desea ejecutarlo? Se cerrará la interfaz actual \"%s\".",
            tituloNuevo, subtituloNuevo, tituloActual
        ),
        Ancho = 340,
        Casilla = { Texto = "No volver a preguntar por este script" },
        Botones = {
            { Texto = "No", Variante = "neutral", Callback = function(marcada) decidir(false, marcada) end },
            { Texto = "Sí, reemplazar", Variante = "primary", Callback = function(marcada) decidir(true, marcada) end },
        },
    })
    if not modal then
        eventoPausa:Destroy()
        return nil -- no hay donde mostrar el modal: no se reemplaza nada
    end
    -- Si el modal se cierra por otra via (p. ej. se destruye la ventana), cuenta
    -- como "No". 'defer': al pulsar un boton, Confirmar cierra el modal ANTES de
    -- llamar al Callback; el defer deja que ese Callback decida primero.
    modal.Fondo.Destroying:Connect(function()
        task.defer(function() decidir(false, false) end)
    end)

    eventoPausa.Event:Wait()
    eventoPausa:Destroy()

    if not respuestaAceptada then
        return nil
    end

    pcall(function() ventanaActual:Destruir() end)
    local nuevaVentana = Nub:CrearVentana(config)

    if recordarMarcado then
        -- Recien ahora, con la ventana nueva ya creada, el proxy de
        -- Flags guarda contra el NombreConfig de ESTE script (que
        -- CrearVentana acaba de dejar como el activo para guardado)
        -- y no contra el de la ventana que se acaba de cerrar.
        Nub.Flags[flagRecordar] = true
        pcall(function() nuevaVentana:GuardarConfiguracion() end)
    end

    pcall(function()
        Nub:Notificar({
            Titulo = "✅ Script cambiado",
            Texto  = "Ahora ejecutando: " .. tituloNuevo,
            Duracion = 3,
        })
    end)

    return nuevaVentana
end


-- ══════════════════════════════════════════════════════════════
--  SAVE MANAGER
-- ══════════════════════════════════════════════════════════════
Nub.SaveManager = {}
local SM = Nub.SaveManager
SM.Carpeta = "Nub/Config"
-- Carpeta separada para el guardado exclusivo de la pestaña
-- "Preinstalada" (tema, buscador, etc.) -- ver SM:GuardarUI/CargarUI
-- mas abajo. Distinta de SM.Carpeta a proposito: son dos sistemas de
-- archivos independientes, no se listan ni se pisan entre si.
SM.CarpetaUI = "Nub/Config/_ui"

function SM:Configurar(carpeta) self.Carpeta = carpeta or self.Carpeta end

local function asegurarCarpeta()
    if not (fsDisponible() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local ruta = ""
    for parte in SM.Carpeta:gmatch("[^/]+") do
        ruta = ruta == "" and parte or (ruta .. "/" .. parte)
        if not isfolder(ruta) then pcall(makefolder, ruta) end
    end
end

local function asegurarCarpetaUI()
    if not (fsDisponible() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local ruta = ""
    for parte in SM.CarpetaUI:gmatch("[^/]+") do
        ruta = ruta == "" and parte or (ruta .. "/" .. parte)
        if not isfolder(ruta) then pcall(makefolder, ruta) end
    end
end

function SM:Guardar(nombre)
    nombre = nombre or "default"
    if not fsDisponible() then
        Nub:Notificar({Titulo = "SaveManager", Texto = "Ejecutor sin soporte de archivos.", Duracion = 4})
        return false
    end
    asegurarCarpeta()
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    -- Todo el trabajo (empaquetar Color3 a {R,G,B}, codificar, escribir)
    -- corre dentro del mismo pcall.
    local huboCambios = true
    local ok, err = pcall(function()
        local datos = empaquetarFlagsParaGuardar(_flagsReales)
        local json = HttpService:JSONEncode(datos)

        -- Verificacion manual: antes de sobreescribir, se compara
        -- contra lo que ya hay en disco (si existe). Esto es lo que
        -- permite que el boton "Guardar" funcione tambien como un
        -- "estoy al dia?" -- si nada cambio desde el ultimo guardado
        -- (automatico o manual), no hace falta tocar el archivo, y el
        -- usuario se entera de que su configuracion ya estaba
        -- actualizada en vez de ver siempre el mismo mensaje generico.
        if type(isfile) == "function" and isfile(ruta) then
            local okLeer, jsonExistente = pcall(readfile, ruta)
            if okLeer and jsonExistente == json then
                huboCambios = false
            end
        end

        if huboCambios then
            writefile(ruta, json)
        end
    end)
    if ok then
        if huboCambios then
            Nub:Notificar({Titulo = "Configuración guardada", Texto = nombre .. ".json", Duracion = 3})
        else
            Nub:Notificar({Titulo = "✅ Ya estaba al día", Texto = nombre .. ".json sin cambios pendientes", Duracion = 3})
        end
    else
        Nub:_RegistrarError("SaveManager:Guardar", err)
        Nub:Notificar({Titulo = "❌ No se pudo guardar", Texto = tostring(err):sub(1, 100), Duracion = 5})
    end
    return ok
end

-- Igual que Guardar, pero sin notificacion visual. La usa el
-- autoguardado nativo para no llenar la pantalla de avisos cada vez
-- que el usuario mueve un slider. Si falla, igual queda registrado en
-- el log interno (Nub:ObtenerErrores()) aunque no se notifique.
function SM:GuardarSilencioso(nombre)
    nombre = nombre or "default"
    if not Nub.Capacidades.Archivos then
        avisarCapacidadFaltante("archivos", "⚠️ Sin acceso a archivos",
            "Tu ejecutor no soporta guardar configuraciones. Los ajustes se perderán al cerrar.")
        return false
    end
    asegurarCarpeta()
    local ok, err = pcall(function()
        local datos = empaquetarFlagsParaGuardar(_flagsReales)
        local json = HttpService:JSONEncode(datos)
        writefile(SM.Carpeta .. "/" .. nombre .. ".json", json)
    end)
    if not ok then Nub:_RegistrarError("SaveManager:GuardarSilencioso", err) end
    return ok
end

function SM:Cargar(nombre)
    nombre = nombre or "default"
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    if not (fsDisponible() and type(isfile) == "function" and isfile(ruta)) then return false end

    local okLeer, contenido = pcall(readfile, ruta)
    if not okLeer then
        Nub:_RegistrarError("SaveManager:Cargar (leer archivo)", contenido)
        return false
    end
    local okDecode, datos = pcall(function() return HttpService:JSONDecode(contenido) end)
    if not okDecode then
        Nub:_RegistrarError("SaveManager:Cargar (decodificar JSON)", datos)
        return false
    end
    datos = prepararDatosCargados(datos)

    _cargandoDesdeArchivo = true
    local okBucle, errBucle = pcall(function()
        for flag, valorCrudo in pairs(datos) do
            local valor = desempaquetarValorCargado(valorCrudo)
            Nub.Flags[flag] = valor
            if Nub.Elementos[flag] then
                -- El 'true' es clave: le pide al control que DISPARE su
                -- Callback ademas de actualizar el valor visual. Antes
                -- Set() se llamaba en modo "silencioso" (sin Callback),
                -- asi que controles como los sliders de tamaño/escala de
                -- la pestaña Preinstalada quedaban con el numero correcto
                -- guardado pero SIN aplicar el efecto real (la ventana no
                -- se redimensionaba, el texto no se reescalaba, etc.).
                local okSet, errSet = pcall(Nub.Elementos[flag].Set, valor, true)
                if not okSet then
                    Nub:_RegistrarError("SaveManager:Cargar (flag '" .. tostring(flag) .. "')", errSet)
                    Nub:Notificar({Titulo = "⚠️ Error al cargar", Texto = "Flag '" .. tostring(flag) .. "' falló, ver consola", Duracion = 4})
                end
            end
        end
    end)
    -- Se resetea SIEMPRE, incluso si algo revento dentro del bucle --
    -- de lo contrario el guard quedaria trabado en 'true' para
    -- siempre, y ningun cambio real del usuario despues de una carga
    -- fallida volveria a marcarse para autoguardado.
    _cargandoDesdeArchivo = false
    if not okBucle then
        Nub:_RegistrarError("SaveManager:Cargar (bucle de restauracion)", errBucle)
    end
    _revisarConflictosAlCargar()
    Nub:Notificar({Titulo = "Configuración cargada", Texto = nombre .. ".json", Duracion = 3})
    return true
end

-- Cambia el "perfil" (archivo de configuracion) activo de una ventana:
-- guarda el perfil actual bajo su nombre viejo, redirige
-- GuardarConfiguracion/CargarConfiguracion y el autoguardado nativo
-- al nombre nuevo, y carga ese archivo si ya existe.
--
--   Nub.SaveManager:CambiarPerfil(Ventana, "Farm")
--   Nub.SaveManager:CambiarPerfil(Ventana, "PvP")
--
-- Nota: la infraestructura de archivos multiples YA existia (Guardar/
-- Cargar siempre aceptaron un 'nombre' -- podias hacer esto a mano
-- llamando SM:Guardar("Farm") y SM:Cargar("PvP") vos mismo). Esto es
-- solo el metodo de conveniencia que ademas actualiza
-- 'Ventana.NombreConfig' para que el autoguardado y GuardarConfiguracion/
-- CargarConfiguracion tambien apunten al perfil nuevo.
function SM:CambiarPerfil(ventana, nombre)
    if type(ventana) ~= "table" or type(nombre) ~= "string" or nombre == "" then
        Nub:_RegistrarError("SaveManager:CambiarPerfil", "Se esperaba (Ventana, nombre) validos")
        return false
    end

    if ventana.NombreConfig then
        SM:GuardarSilencioso(ventana.NombreConfig)
    end

    ventana.NombreConfig = nombre

    local existiaPerfil = SM:Cargar(nombre)
    if not existiaPerfil then
        -- No es un error: es normal la primera vez que se usa un
        -- perfil nuevo. Se avisa igual para que quede claro que no
        -- cargo ajustes viejos (y no que fallo silenciosamente).
        Nub:Notificar({Titulo = "Perfil nuevo", Texto = "'" .. nombre .. "' no tenia guardado previo", Duracion = 3})
    end
    return true
end

-- Igual que Cargar, pero sin notificacion visual (para la carga
-- automatica al iniciar el script).
function SM:CargarSilencioso(nombre)
    nombre = nombre or "default"
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    if not (fsDisponible() and type(isfile) == "function" and isfile(ruta)) then return false end

    local okLeer, contenido = pcall(readfile, ruta)
    if not okLeer then
        Nub:_RegistrarError("SaveManager:CargarSilencioso (leer archivo)", contenido)
        return false
    end
    local okDecode, datos = pcall(function() return HttpService:JSONDecode(contenido) end)
    if not okDecode then
        Nub:_RegistrarError("SaveManager:CargarSilencioso (decodificar JSON)", datos)
        return false
    end
    datos = prepararDatosCargados(datos)

    _cargandoDesdeArchivo = true
    local okBucle, errBucle = pcall(function()
        for flag, valorCrudo in pairs(datos) do
            local valor = desempaquetarValorCargado(valorCrudo)
            Nub.Flags[flag] = valor
            if Nub.Elementos[flag] then
                -- Misma razón que en SM:Cargar: hay que disparar el
                -- Callback real, no solo mover el control visualmente.
                local okSet, errSet = pcall(Nub.Elementos[flag].Set, valor, true)
                if not okSet then
                    Nub:_RegistrarError("SaveManager:CargarSilencioso (flag '" .. tostring(flag) .. "')", errSet)
                end
            end
        end
    end)
    _cargandoDesdeArchivo = false
    if not okBucle then
        Nub:_RegistrarError("SaveManager:CargarSilencioso (bucle de restauracion)", errBucle)
    end
    _revisarConflictosAlCargar()
    -- "Silencioso" se referia solo a que no interrumpe con dialogos ni
    -- console spam en cada guardado automatico -- pero toda carga
    -- (perfil o UI) debe confirmarse al usuario con una notificacion,
    -- para que sepa que su configuracion previa efectivamente se
    -- restauro al abrir el script.
    Nub:Notificar({ Titulo = "Configuración cargada", Texto = nombre .. ".json", Duracion = 3 })
    return true
end

function SM:Listar()
    if not (fsDisponible() and type(listfiles) == "function") then return {} end
    local resultado = {}
    local ok, archivos = pcall(listfiles, SM.Carpeta)
    if ok then
        for _, ruta in ipairs(archivos) do
            local nombre = ruta:match("([^/\\]+)%.json$")
            if nombre then table.insert(resultado, nombre) end
        end
    end
    return resultado
end

-- Elimina un archivo de perfil guardado. No toca Nub.Flags ni la
-- ventana actual: solo borra el .json en disco. Si el perfil borrado
-- es el que la ventana tiene activo (ventana.NombreConfig), el
-- caller es responsable de decidir que hacer despues (ej: cambiar a
-- "default").
function SM:Eliminar(nombre)
    if type(nombre) ~= "string" or nombre == "" then
        Nub:_RegistrarError("SaveManager:Eliminar", "Se esperaba un nombre de perfil valido")
        return false
    end
    if not (fsDisponible() and type(isfile) == "function" and type(delfile) == "function") then
        return false
    end
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    if not isfile(ruta) then
        return false
    end
    local ok, err = pcall(delfile, ruta)
    if not ok then
        Nub:_RegistrarError("SaveManager:Eliminar (delfile)", err)
        return false
    end
    return true
end

-- ══════════════════════════════════════════════════════════════
--  GUARDADO EXCLUSIVO DE LA PESTAÑA "PREINSTALADA"
-- ══════════════════════════════════════════════════════════════
-- Sistema INDEPENDIENTE del guardado de perfiles de arriba. Solo
-- incluye los Flags marcados con Nub:MarcarComoUI(flag) -- tema,
-- estado del buscador, cualquier otro ajuste propio de la interfaz.
-- Vive en su propia carpeta (SM.CarpetaUI) para que jamas se mezcle,
-- liste o sobreescriba junto con los perfiles de script (SM:Guardar/
-- Cargar/Listar/Eliminar de arriba, que a su vez ya excluyen estos
-- flags automaticamente -- ver 'soloUI' en empaquetarFlagsParaGuardar).

local function nombrePerfilValido(nombre)
    if type(nombre) ~= "string" then return false end
    local limpio = nombre:match("^%s*(.-)%s*$")
    if limpio == "" or #limpio > 60 or limpio:find('[/\\:*?"<>|%c]') then return false end
    return true, limpio
end

function SM:Duplicar(origen, destino)
    local okO, nombreO = nombrePerfilValido(origen)
    local okD, nombreD = nombrePerfilValido(destino)
    if not (okO and okD) then return false, "Nombre de perfil inválido" end
    if not (fsDisponible() and type(isfile) == "function") then return false, "Ejecutor sin soporte de archivos" end
    asegurarCarpeta()
    local rutaO = SM.Carpeta .. "/" .. nombreO .. ".json"
    local rutaD = SM.Carpeta .. "/" .. nombreD .. ".json"
    if not isfile(rutaO) then return false, "No existe el perfil de origen" end
    if isfile(rutaD) then return false, "Ya existe un perfil con ese nombre" end
    local ok, err = pcall(function() writefile(rutaD, readfile(rutaO)) end)
    if not ok then
        Nub:_RegistrarError("SaveManager:Duplicar", err)
        return false, "No se pudo copiar el perfil"
    end
    return true
end

function SM:Renombrar(origen, destino)
    local ok, motivo = SM:Duplicar(origen, destino)
    if not ok then return false, motivo end
    local _, nombreO = nombrePerfilValido(origen)
    if not SM:Eliminar(nombreO) then return true, "Copiado, pero no se pudo borrar el original" end
    return true
end

function SM:Exportar(nombre)
    local okN, nombreLimpio = nombrePerfilValido(nombre)
    if not okN then return nil, "Nombre de perfil inválido" end
    if not (fsDisponible() and type(isfile) == "function") then return nil, "Ejecutor sin soporte de archivos" end
    local ruta = SM.Carpeta .. "/" .. nombreLimpio .. ".json"
    if not isfile(ruta) then return nil, "No existe el perfil" end
    local okL, texto = pcall(readfile, ruta)
    if not okL then return nil, "No se pudo leer el perfil" end
    local copiado = false
    if type(setclipboard) == "function" then
        copiado = (pcall(setclipboard, texto))
    end
    return texto, copiado
end

function SM:Importar(nombre, texto, sobreescribir)
    local okN, nombreLimpio = nombrePerfilValido(nombre)
    if not okN then return false, "Nombre de perfil inválido" end
    if type(texto) ~= "string" or texto:match("^%s*$") then return false, "No hay texto para importar" end
    if #texto > 200000 then return false, "El texto es demasiado grande" end
    if not (fsDisponible() and type(isfile) == "function") then return false, "Ejecutor sin soporte de archivos" end
    local okJ, datos = pcall(function() return HttpService:JSONDecode(texto) end)
    if not okJ or type(datos) ~= "table" then return false, "El texto no es un perfil válido" end
    asegurarCarpeta()
    local ruta = SM.Carpeta .. "/" .. nombreLimpio .. ".json"
    if isfile(ruta) and not sobreescribir then return false, "Ya existe un perfil con ese nombre" end
    local ok, err = pcall(writefile, ruta, texto)
    if not ok then
        Nub:_RegistrarError("SaveManager:Importar", err)
        return false, "No se pudo guardar el perfil"
    end
    return true
end

function SM:GuardarUI(nombre)
    nombre = nombre or "default"
    if not fsDisponible() then
        Nub:Notificar({Titulo = "SaveManager", Texto = "Ejecutor sin soporte de archivos.", Duracion = 4})
        return false
    end
    asegurarCarpetaUI()
    local ruta = SM.CarpetaUI .. "/" .. nombre .. ".json"
    local huboCambios = true
    local ok, err = pcall(function()
        local datos = empaquetarFlagsParaGuardar(_flagsReales, true)
        local json = HttpService:JSONEncode(datos)

        -- Misma verificacion manual que SM:Guardar: si el archivo ya
        -- tiene exactamente estos valores, no se reescribe, y se
        -- notifica que ya estaba al dia en vez de "guardado" generico.
        if type(isfile) == "function" and isfile(ruta) then
            local okLeer, jsonExistente = pcall(readfile, ruta)
            if okLeer and jsonExistente == json then
                huboCambios = false
            end
        end

        if huboCambios then
            writefile(ruta, json)
        end
    end)
    if ok then
        if huboCambios then
            Nub:Notificar({Titulo = "Preinstalada guardada", Texto = nombre .. ".json", Duracion = 3})
        else
            Nub:Notificar({Titulo = "✅ Ya estaba al día", Texto = nombre .. ".json sin cambios pendientes", Duracion = 3})
        end
    else
        Nub:_RegistrarError("SaveManager:GuardarUI", err)
        Nub:Notificar({Titulo = "❌ No se pudo guardar", Texto = tostring(err):sub(1, 100), Duracion = 5})
    end
    return ok
end

function SM:CargarUI(nombre)
    nombre = nombre or "default"
    local ruta = SM.CarpetaUI .. "/" .. nombre .. ".json"
    if not (fsDisponible() and type(isfile) == "function" and isfile(ruta)) then return false end

    local okLeer, contenido = pcall(readfile, ruta)
    if not okLeer then
        Nub:_RegistrarError("SaveManager:CargarUI (leer archivo)", contenido)
        return false
    end
    local okDecode, datos = pcall(function() return HttpService:JSONDecode(contenido) end)
    if not okDecode then
        Nub:_RegistrarError("SaveManager:CargarUI (decodificar JSON)", datos)
        return false
    end
    datos = prepararDatosCargados(datos)

    _cargandoDesdeArchivo = true
    local okBucle, errBucle = pcall(function()
        for flag, valorCrudo in pairs(datos) do
            -- Solo se restauran flags que efectivamente estan marcados
            -- como de UI -- un .json de esta carpeta manipulado a mano no
            -- deberia poder escribir flags de perfil de script por esta via.
            if _flagsUI[flag] then
                local valor = desempaquetarValorCargado(valorCrudo)
                Nub.Flags[flag] = valor
                if Nub.Elementos[flag] then
                    -- Mismo pcall defensivo que ya usan SM:Cargar y
                    -- SM:CargarSilencioso -- este bloque no lo tenia,
                    -- asi que un solo flag roto (ej. un tema que ya no
                    -- existe) hubiera cortado la restauracion de todos
                    -- los demas flags de UI a mitad de camino.
                    local okSet, errSet = pcall(Nub.Elementos[flag].Set, valor, true)
                    if not okSet then
                        Nub:_RegistrarError("SaveManager:CargarUI (flag '" .. tostring(flag) .. "')", errSet)
                    end
                end
            end
        end
    end)
    _cargandoDesdeArchivo = false
    if not okBucle then
        Nub:_RegistrarError("SaveManager:CargarUI (bucle de restauracion)", errBucle)
    end
    _revisarConflictosAlCargar()
    Nub:Notificar({Titulo = "Preinstalada cargada", Texto = nombre .. ".json", Duracion = 3})
    return true
end

-- Lista los .json guardados de la pestaña Preinstalada (misma logica
-- que SM:Listar, pero apuntando a SM.CarpetaUI).
function SM:ListarUI()
    if not (fsDisponible() and type(listfiles) == "function") then return {} end
    local resultado = {}
    local ok, archivos = pcall(listfiles, SM.CarpetaUI)
    if ok then
        for _, ruta in ipairs(archivos) do
            local nombre = ruta:match("([^/\\]+)%.json$")
            if nombre then table.insert(resultado, nombre) end
        end
    end
    return resultado
end

-- Elimina un guardado de Preinstalada. Misma logica defensiva que
-- SM:Eliminar, apuntando a SM.CarpetaUI.
function SM:EliminarUI(nombre)
    if type(nombre) ~= "string" or nombre == "" then
        Nub:_RegistrarError("SaveManager:EliminarUI", "Se esperaba un nombre de guardado valido")
        return false
    end
    if not (fsDisponible() and type(isfile) == "function" and type(delfile) == "function") then
        return false
    end
    local ruta = SM.CarpetaUI .. "/" .. nombre .. ".json"
    if not isfile(ruta) then
        return false
    end
    local ok, err = pcall(delfile, ruta)
    if not ok then
        Nub:_RegistrarError("SaveManager:EliminarUI (delfile)", err)
        return false
    end
    return true
end

for _, nombreFuncion in ipairs({ "CargarSilencioso", "CargarUI" }) do
    local original = SM[nombreFuncion]
    if type(original) == "function" then
        SM[nombreFuncion] = function(...)
            local resultado = table.pack(original(...))
            Nub:LimpiarHistorial()
            return table.unpack(resultado, 1, resultado.n)
        end
    end
end


-- ══════════════════════════════════════════════════════════════
--  THEME MANAGER
-- ══════════════════════════════════════════════════════════════
Nub.ThemeManager = {}
local TM = Nub.ThemeManager
TM.Temas = Themes.Lista

local transparenciaBaseBorde = setmetatable({}, {__mode = "k"})

function TM:AplicarTema(nombreOTabla)
    local tabla = type(nombreOTabla) == "string" and self.Temas[nombreOTabla] or nombreOTabla
    if not tabla then return end
    for clave, valor in pairs(tabla) do Theme[clave] = valor end

    -- Transicion suave de colores: solo si la ventana ya es visible (al
    -- armarse, o al restaurar el tema guardado bajo el splash, se aplica
    -- directo) y solo para lo que se ve: lo que esta dentro de una pestaña
    -- oculta se asigna directo (no vale la pena animar cientos de
    -- instancias que nadie esta viendo).
    local animar = Nub._ventanaRevelada == true
    local paginasOcultas = {}
    if animar then
        local activa = _G.Nub_InstanciaActiva
        local ventana = activa and activa.Ventana
        if ventana and ventana.Tabs then
            for _, tab in ipairs(ventana.Tabs) do
                if tab.Pagina and not tab.Pagina.Visible then
                    table.insert(paginasOcultas, tab.Pagina)
                end
            end
        end
    end
    local function estaEnPaginaOculta(instancia)
        for _, pagina in ipairs(paginasOcultas) do
            if instancia:IsDescendantOf(pagina) then return true end
        end
        return false
    end

    for _, entrada in ipairs(registroTema) do
        if entrada.instancia and entrada.instancia.Parent then
            local nuevoValor
            if type(entrada.claveTema) == "function" then
                local ok, resultado = pcall(entrada.claveTema)
                if ok then nuevoValor = resultado end
            else
                nuevoValor = Theme[entrada.claveTema]
            end
            if nuevoValor ~= nil then
                intentarSilencioso(
                    "ThemeManager: aplicar " .. tostring(entrada.propiedad),
                    function()
                        local instancia, propiedad = entrada.instancia, entrada.propiedad
                        if animar and typeof(nuevoValor) == "Color3"
                        and typeof(instancia[propiedad]) == "Color3"
                        and not estaEnPaginaOculta(instancia) then
                            Utils.Tween(instancia, {[propiedad] = nuevoValor}, Nub.Motion.Page,
                                Nub.Motion.EaseSuave, Enum.EasingDirection.InOut)
                        else
                            instancia[propiedad] = nuevoValor
                        end
                    end
                )
            end
        end
    end

    local bordeAdaptativo = Nub.Opciones.BordeAdaptativo == true
    if bordeAdaptativo or next(transparenciaBaseBorde) ~= nil then
        local fondo = Theme.Background
        local oscuro = true
        if typeof(fondo) == "Color3" then
            oscuro = (0.299 * fondo.R + 0.587 * fondo.G + 0.114 * fondo.B) < 0.5
        end
        for _, entrada in ipairs(registroTema) do
            local trazo = entrada.instancia
            if entrada.claveTema == "Border" and trazo and trazo.Parent and trazo:IsA("UIStroke") then
                local base = transparenciaBaseBorde[trazo]
                if not bordeAdaptativo then
                    if base then
                        trazo.Transparency = base
                        transparenciaBaseBorde[trazo] = nil
                    end
                elseif base or trazo.Transparency < 0.99 then
                    base = base or trazo.Transparency
                    transparenciaBaseBorde[trazo] = base
                    trazo.Transparency = oscuro and (base + (1 - base) * 0.3) or (base * 0.6)
                end
            end
        end
    end

    -- Sincronizar el selector de temas de la barra lateral en TODAS las
    -- ventanas que lo tengan, sin importar desde donde se aplico el tema.
    local nombreAplicado = type(nombreOTabla) == "string" and nombreOTabla or nil
    for ventana in pairs(_ventanasConSelectorTemas) do
        if ventana._SincronizarSelectorTemas then
            pcall(ventana._SincronizarSelectorTemas, nombreAplicado)
        end
    end

    Nub.Eventos.TemaCambiado:Fire(nombreAplicado)
end

function TM:AgregarTema(nombre, tabla)
    if type(nombre) == "string" and type(tabla) == "table" then
        self.Temas[nombre] = tabla
    end
end

function TM:GuardarTemaActual()
    if not fsDisponible() then return false end
    asegurarCarpeta()
    local ok, json = pcall(function()
        -- Guarda los colores mas importantes del tema actual
        local datos = {}
        for clave, valor in pairs(Theme) do
            datos[clave] = {valor.R, valor.G, valor.B}
        end
        return HttpService:JSONEncode(datos)
    end)
    if not ok then return false end
    return pcall(writefile, SM.Carpeta .. "/tema.json", json)
end


-- ══════════════════════════════════════════════════════════════
--  FIN DE LA LIBRERIA — se devuelve la tabla para uso externo
-- ══════════════════════════════════════════════════════════════
-- Uso desde tu script:
--   local Nub = loadstring(readfile("Nub_v2.3_Libreria.lua"))()
--   local Ventana = Nub:CrearVentana({ Titulo = "Mi Script" })
--   local Tab = Ventana:CrearTab("Principal", "🏠")
--   local Seccion = Tab:CrearSeccion("Opciones")
--   Seccion:Toggle({ Texto = "Mi Toggle", Callback = function(v) end })
--
-- AUTO-LIMPIEZA (evita duplicados al re-ejecutar el script):
-- Nub:CrearVentana() ya limpia automaticamente TODO lo que haya
-- quedado de una ejecucion anterior. Para que tambien limpie los
-- recursos de TU script (ej. un ESP con RenderStepped, Drawing, etc.),
-- registralos asi apenas los crees:
--   Nub:RegistrarConexion(RunService.RenderStepped:Connect(miLoop))
--   Nub:RegistrarHilo(task.spawn(miFuncion))
--   Nub:RegistrarDibujo(Drawing.new("Line"))
--   Nub:RegistrarInstancia(algunaInstanciaSuelta)
return Nub
