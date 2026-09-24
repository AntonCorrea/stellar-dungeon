# Stellar Dungeon 🔥⛓️

RPG 2D top-down en grilla (estilo *Shattered Pixel Dungeon*) hecho en **Godot 4.4**, con progresión on-chain sobre **Stellar** (testnet). El mundo: mazmorra generada proceduralmente, minería, forja con suerte, combate y un jefe de dos fases.

> 📅 Proyecto del **Argentina Builder Challenge 2026** — Demo Day: sáb 26/9.

---

## Requisitos

- **Godot 4.4.1** (o superior 4.4.x). Descargar desde <https://godotengine.org/download/archive/4.4.1-stable/>
- Windows/Linux/macOS. El renderer configurado es **GL Compatibility** (anda en casi cualquier GPU).

## Cómo correrlo

1. Cloná el repo:
   ```bash
   git clone <url-del-repo> stellar-dungeon
   cd stellar-dungeon
   ```
2. Abrí el **Godot Project Manager** → *Import* → seleccioná `project.godot` → *Import & Edit*.
3. Presioná **F5** (o *Play*).

> El proyecto usa el autoload `Chain.gd`, un **mock** de la cadena Stellar: no hace falta RPC ni credenciales para jugar. El backend real (relé Node + contrato Rust `forge_ledger`) se integra más adelante detrás de esa misma interfaz (ver [On-chain](#on-chain)).

### Modo de prueba (headless)

```bash
# Boot de la escena principal (pantalla de título; 60 frames y sale)
godot --headless --path . --quit-after 60

# Suite de tests
godot --headless --path . res://tests/test_smoke.tscn
godot --headless --path . res://tests/test_day4.tscn
godot --headless --path . res://tests/test_theme.tscn
godot --headless --path . res://tests/test_combat.tscn
godot --headless --path . res://tests/test_day5.tscn
godot --headless --path . res://tests/test_day6.tscn
godot --headless --path . res://tests/test_forge_ledger.tscn
```

### Builds descargables (Linux / Windows / Web)

`.github/workflows/build.yml` exporta el juego (release) en cada push a
`main` usando los presets de `export_presets.cfg` (`Linux`, `Windows Desktop`,
`Web`) y sube `Linux`/`Windows` como **artifacts** de la Action (pestaña
*Actions* → el run → *Artifacts*, sin instalar Godot). El export Web se hace
a mano (o agregalo al mismo workflow) para subir a itch.io/Render — ver
"Local vs. servidor hosteado" más abajo para conectarlo a un relé real.

```bash
# Local, con Godot instalado:
godot --headless --path . --export-release "Linux" dist/linux/stellar-dungeon.x86_64
godot --headless --path . --export-release "Windows Desktop" dist/windows/stellar-dungeon.exe
godot --headless --path . --export-release "Web" dist/web/index.html
```

## Controles

| Acción | Teclas |
|---|---|
| Moverse | `WASD` o flechas |
| Atacar | `Espacio` o clic izquierdo |
| Inventario (abrir/cerrar) | `E` (o `I`) |
| Forja | Clic sobre la forja (cerca) |
| Usar frasco | Clic sobre el slot del frasco en el inventario |
| Pausar / reanudar | `Esc` |
| Reintentar (morir / victoria / pausa) | `R` |

La partida arranca en una **pantalla de título** (`Enter`/`Space` para jugar, `Esc` para salir).

## Loop de juego

1. **Explorá** la mazmorra generada (8 salas, enemigos, vetas y pociones tiradas en el piso).
2. **Miná** vetas con el pico: madera 🪵, cobre 🟠, hierro ⚙️ y plata 🪙.
3. **Forjá** en el brasero quemando materiales. Las **armas forjadas salen con suerte**: calidad **Común / Fina / Superior / Épica** que suma/merma daño, cada una es un **token único** de la cartera, y la tirada es **determinista por seed** (xorshift) — idéntica en el juego y en el contrato on-chain, verificable en tests.
4. **Combatí**: el daño del jugador = el arma **de mayor daño** que tenga en cartera (auto-equip).
5. **Derrotá al Capitán** (jefe, 2 fases: entra en *FASE 2* al 50% HP) y llevate el **Tinte Real** (drop 100%, cosmético: aura dorada).

### Recetas de la forja

| Receta | Costo | Resultado |
|---|---|---|
| Pico de Cobre | madera 1 + cobre 1 | herramienta (mina mejor) |
| Espada de Cobre | madera 1 + cobre 2 | arma dmg base 14 + calidad |
| Mandoble de Hierro | hierro 3 | arma dmg base 18 + calidad |
| Hacha de Plata | hierro 2 + plata 2 | arma dmg base 22 + calidad |

**Calidades** (tiro al forjar): Común `+0` 55% · Fina `+2` 25% · Superior `+4` 14% · Épica `+8` 6%.

### Enemigos y loot

| Sprite | Nombre | Suelta |
|---|---|---|
| Rata | Wogol | monedas, arma/frasco |
| Goblin | Goblin | monedas, arma/frasco |
| Diablillo | Imp | monedas, arma/frasco |
| Esqueleto | Skelet | monedas, arma/frasco |
| Calabaza | Pumpkin | monedas, arma/frasco |
| Demonio Smith | Masked Orc | monedas, arma/frasco |
| Guerrero Orco | Orc Warrior | monedas, arma/frasco |
| Gran Zombi | Big Zombie | monedas, arma/frasco |
| Ogro | Ogre | monedas, arma/frasco |
| Demonio Mayor | Big Demon | monedas, arma/frasco |
| Capitán de la Torre | Jefe (knight) | monedas, arma, **Tinte Real (100%)** |

Las armas equipables (dmg 12–21) salen de los drops y se auto-equipan; íconos y nombres vienen de los frames del pack (Lanza, Arco corto/largo, Machete, Martillo, Hacha doble, Báculos, Espada de caballero, Gema roja, etc.).

📖 **Catálogo completo** (statísticas, loot, recetas y calidades): [GLOSARIO.md](GLOSARIO.md).

## Tests

CI (`.github/workflows/ci.yml`) corre toda la suite en modo **mock** en cada
push/PR a `main`. `test_chain_http` queda afuera (necesita el relé real de
`stellar-dungeon-backend`, repo privado — no hay token compartido entre
ambos repos todavía): se sigue corriendo a mano, ver más abajo.

Suite en `tests/`, corren headless con `--headless --path . res://tests/test_X.tscn`:

| Test | Cubre |
|---|---|
| `test_smoke` | Boot, HUD, corazones, inventario inicial |
| `test_day4` | Recursos, forja (picos queman madera/cobre) |
| `test_theme` | Pisos y muros por tema de sala |
| `test_combat` | Ataques, enemigos, drops y banner de FASE 2 |
| `test_day5` | Jefe (2 fases), sala del jefe, Tinte Real, leaderboard |
| `test_day6` | Auto-equip, frascos, drops con sprite, pociones del piso, forja |
| `test_forge_ledger` | **Cruce Godot↔contrato**: misma tabla de calidad (seed → calidad) que `forge_ledger` en Rust, cobertura 55/25/14/6 y craft con seed = contador |
| `test_chain_http` | **F7 — protocolo Godot↔relé** (`chain_http.gd`): mina, forja, quema y lee tesoro/leaderboard vía HTTP; verifica calidad == `rollQuality(seed del token)`. Agnostico al modo: corre con relé **mock** y con relé **real** (testnet). |
| `test_offline_sync` | **F8 — cola offline**: corta la red (apunta `relay_url` a un puerto muerto), mina/forja local, verifica que se encole y que la cartera offline sea correcta; reconecta y verifica que sincronice sin duplicar. |

### Jugar conectado al contrato (modo `relay` — Fase 7)

El juego tiene dos backends detrás de la misma interfaz (`Chain.gd`, spec congelada): el **mock** (default, lo juega sin red) y el **relay** (HTTP al relé Node, que forja contra el contrato en testnet — la calidad la tira **el contrato**, no el juego).

```
# 1) Levantar el relé (en stellar-dungeon-backend/relay, ver su README):
#    Modo real (testnet): setear RELAY_CONTRACT_MODE/RELAY_RPC_URL/RELAY_SECRET… y `node src/index.js`

# 2) Correr el juego (o el test) apuntando al relé:
$env:CHAIN_BACKEND = "relay"          # "mock" por defecto; "relay" para on-chain
$env:CHAIN_URL     = "http://localhost:8787"   # opcional
godot --headless --path . res://tests/test_chain_http.tscn
```

En modo `relay` el HUD muestra la cartera que el relé puede firmar (jugador dev, de `/health`), no una dirección inventada.

### Local vs. servidor hosteado (build Web)

`Chain.gd` elige el backend en este orden — así el mismo build sirve para jugar
sin red, para la demo local con el relé en tu máquina, y para un build Web
público apuntando a un relé hosteado:

1. **Desktop / headless** (Godot editor, `--headless`, tests, PowerShell):
   variables de entorno `CHAIN_BACKEND` / `CHAIN_URL` (arriba).
2. **Build Web exportado** (no hay variables de entorno en el navegador):
   query string de la URL, vía `scripts/web_query.gd`:
   ```
   https://tu-usuario.itch.io/stellar-dungeon                          # mock (local, sin red)
   https://tu-usuario.itch.io/stellar-dungeon?backend=relay&url=https://tu-relay.onrender.com
   ```
3. Sin nada de lo anterior: **mock** (default, 100% jugable offline).

El hosting gratis del relé (Render, plan free) está documentado en
`stellar-dungeon-backend/relay/README.md` → sección "Hosting gratis (Render)".

### Wallet por jugador y modo offline (Fase 8)

Dos cosas más que resuelve `chain_http.gd` cuando `CHAIN_BACKEND=relay`:

- **Wallet propia**: al arrancar, el juego genera y persiste un id local
  opaco (`user://chain_offline.json`, NO es una clave privada) y se lo manda
  al relé por `GET /identity`. El relé le deriva una dirección Stellar
  **propia y estable** (siempre la misma para esa instalación) en vez de la
  cartera compartida de antes — sigue siendo custodial (el relé firma por
  vos, ver `relay/README.md` → "Identidad por jugador"), pero cada jugador ya
  tiene sus propias armas y su propio inventario on-chain. Si el relé es
  viejo y no tiene `/identity`, cae con gracia a la cartera compartida.
- **Offline**: si `mine`/`claim_drop`/`craft`/`use_item`/`treasure` no pueden
  salir a la red, se aplican igual sobre una cartera espejo guardada en disco
  (misma lógica que el mock: recetas, costos, tirada de calidad) y se encolan
  con un id único. Apenas hay señal de nuevo (al boot, antes de la próxima
  escritura, o cada 15s por un timer) la cola se reintenta contra el relé con
  el MISMO id — el relé lo deduplica (`op_id`, ver backend), así que un
  reintento nunca duplica una acción que ya se había procesado. `transfer`
  queda afuera a propósito: mover un ítem a otro jugador sin confirmar que
  llegó del otro lado es el único caso donde "aplicar local y esperar" puede
  perder el ítem de verdad.
- Mientras hay acciones sin sincronizar, `Chain.get_pending_count()` las
  cuenta y `Chain.is_online()` dice si el último pedido a la red se completó
  — útil si querés mostrarlo en el HUD (no está cableado a la UI todavía).

## Estructura del proyecto

```
stellar-dungeon/
├── project.godot            # autoloads: Chain (mock Stellar), Sfx
├── scenes/                  # title, main, player, enemy, hud, forge, drop, ore…
├── scripts/
│   ├── chain.gd             # ⛓️ interfaz on-chain (spec congelada; mock + switch a relay)
│   ├── chain_http.gd        # F7: el "mozo" HTTP (traduce los verbos de Chain al relé)
│   ├── web_query.gd         # lee ?backend=&url= de la URL (build Web, sin env vars)
│   ├── level.gd             # generación de mazmorra, spawns, ore, forja
│   ├── player.gd            # movimiento, ataque, auto-equip, heal
│   ├── enemy.gd             # enemigos + jefe con FASE 2 y barra de boss
│   ├── hud.gd               # inventario (grilla) + forja + brújula/pausa/victoria
│   ├── items.gd             # metadata: daños, nombres, calidades, frascos
│   ├── title.gd             # pantalla de título (Enter para jugar)
│   └── sfx.gd               # sonidos (packs CC0, pitch aleatorio)
├── assets/
│   ├── frames/              # sprites 16x16 (0x72 tileset)
│   ├── sprite_frames/       # SpriteFrames para animaciones
│   ├── tileset/             # tilesets de pisos/muros
│   └── Minifantasy_Dungeon_SFX/  # SFX CC0 (Leohpaz)
├── tests/                   # 8 tests headless
└── tools/make_frames.ps1    # helper para generar los frames PNG
```

## On-chain

El juego no se conecta directo a la red: usa el autoload **`Chain.gd`** como interfaz única (hoy **mock** con latencia simulada, firmas y sync de inventario). Daños, curado y equipamiento son locales de partida; la cadena registra posesión, minería, crafting (tokens únicos) y consumo.

- **Spec congelada**: `chain-spec.md` (en la carpeta `stellar-dungeon-backend/` del workspace, fuera del repo) incluye apéndices:
  - `use_item` (consumo de frascos) y tokens nuevos;
  - craft de armas = **token único por arma** con stats deterministas: la tirada de calidad es `xorshift32(seed)` (seed = contador de forja, igual que el contrato `forge_ledger`, ver `test_forge_ledger`).
- **Backend**: relé en **Node** + contrato en **Rust** (`forge_ledger`) sobre Stellar **testnet**, implementando la interfaz de `Chain.gd` contra `soroban-rpc`. Cada arma forjada se mintea como token inmutable (id único, sin re-minteo).

## Créditos / assets

- Tileset y sprites: **0x72 DungeonTileset II** (16×16, CC0) — <https://0x72.itch.io/dungeontileset-ii>
- SFX: **Minifantasy Dungeon SFX Pack** de Leohpaz (CC0) — <https://leohpaz.itch.io/minifantasy-dungeon-sfx-pack>
- BGM (pendiente): **HydroGene – High Quality 16-bit Music** (CC0) — <https://hydrogene.itch.io/high-quality-16-bit-music>

## Roadmap

- [x] Mazmorra procedural (8 salas), minería, forja, combate, jefe 2 fases
- [x] Inventario en grilla y panel de forja con armas de stats deterministas (tirada cruzada con el contrato)
- [x] Pantalla de título, pausa, brújula hacia el jefe e indicador on-chain en el HUD
- [x] Suite de tests headless
- [x] Backend on-chain real (Node relé + contrato Rust) detrás de `Chain.gd`
- [x] CI (Godot headless + relé + contrato Rust) y hosting gratis del relé (Render)
- [ ] BGM (crossfade exploración → boss)
- [ ] Guardar/levantar partida (base building)
- [ ] Pulido + guion demo + Loom 90s (post-challenge)

---

> ⚠️ Usá el `.gitignore` incluido (excluye `.godot/` y `dist/`). Los docs de diseño (`plan-juego-godot.md`, `idea3-rpg-mazmorra.md`, `chain-spec.md`…) y el PNG 0x72 original viven en `stellar-dungeon-backend/` fuera del repo: podés copiarlos a `docs/` si querés versionarlos.