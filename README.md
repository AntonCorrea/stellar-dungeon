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

### Jugar conectado al contrato (modo `relay` — Fase 7)

El juego tiene dos backends detrás de la misma interfaz (`Chain.gd`, spec congelada): el **mock** (default, lo juega sin red) y el **relay** (HTTP al relé Node, que forja contra el contrato en testnet — la calidad la tira **el contrato**, no el juego).

```
# 1) Levantar el relé (en stellar/relay, ver su README):
#    Modo real (testnet): setear RELAY_CONTRACT_MODE/RELAY_RPC_URL/RELAY_SECRET… y `node src/index.js`

# 2) Correr el juego (o el test) apuntando al relé:
$env:CHAIN_BACKEND = "relay"          # "mock" por defecto; "relay" para on-chain
$env:CHAIN_URL     = "http://localhost:8787"   # opcional
godot --headless --path . res://tests/test_chain_http.tscn
```

En modo `relay` el HUD muestra la cartera que el relé puede firmar (jugador dev, de `/health`), no una dirección inventada.

## Estructura del proyecto

```
stellar-dungeon/
├── project.godot            # autoloads: Chain (mock Stellar), Sfx
├── scenes/                  # title, main, player, enemy, hud, forge, drop, ore…
├── scripts/
│   ├── chain.gd             # ⛓️ interfaz on-chain (spec congelada; mock + switch a relay)
│   ├── chain_http.gd        # F7: el "mozo" HTTP (traduce los verbos de Chain al relé)
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

- **Spec congelada**: `chain-spec.md` (en la carpeta `stellar/` del workspace, fuera del repo) incluye apéndices:
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
- [ ] Backend on-chain real (Node relé + contrato Rust) detrás de `Chain.gd`
- [ ] BGM (crossfade exploración → boss)
- [ ] Guardar/levantar partida (base building)
- [ ] Pulido + guion demo + Loom 90s (post-challenge)

---

> ⚠️ Usá el `.gitignore` incluido (excluye `.godot/` y `dist/`). Los docs de diseño (`plan-juego-godot.md`, `idea3-rpg-mazmorra.md`, `chain-spec.md`…) y el PNG 0x72 original viven en `stellar/` fuera del repo: podés copiarlos a `docs/` si querés versionarlos.