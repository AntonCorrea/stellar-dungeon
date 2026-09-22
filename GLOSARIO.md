# 🗡️ Glosario — Stellar Dungeon

Catálogo completo de **enemigos** e **items** (recursos, armas, frascos, forja y cosméticos).
Salvo nota, todo vive en la **cartera on-chain** (mock `Chain`) y se firma con transacción.

> **Cartera (mock testnet):** `GBAY3…QGQ` · cada escritura suma 1 tx al HUD · las armas forjadas son **tokens únicos**.

---

## 🦹 Enemigos

Todos sueltan **monedas** (suman al tesoro on-chain). Además, por tipo:
- **recurso** con su `drop_chance`,
- **arma/frasco** con rollos independientes (ver [loot por enemigo](#loot-por-enemigo)).

| # | Sprite | Nombre | HP | Daño | Vel | Alcance (aggro) | Paso (s) | Ataque (s) | Monedas | Recurso (chance) |
|---|--------|--------|----|------|-----|--------|----------|------------|---------|------------------|
| 1 | Rata | **Wogol** · "Rata de Alcantarilla" | 25 | 4 | 55 | 5 | 1.5 | 1.6 | 1 | Madera (20%) |
| 2 | Goblin | **Goblin** | 20 | 3 | 72 | 5 | 1.2 | 1.4 | 1 | Madera (15%) |
| 3 | Diablillo | **Imp** | 14 | 4 | 95 | 6 | 0.7 | 1.1 | 2 | Cobre (20%) |
| 4 | Esqueleto | **Skelet** · "Esqueleto Guardián" | 40 | 8 | 70 | 7 | 1.0 | 1.2 | 2 | Cobre (40%) |
| 5 | Calabaza | **Pumpkin** · "Calabaza" | 45 | 9 | 62 | 6 | 1.0 | 1.1 | 3 | Cobre (40%) |
| 6 | Orco | **Demonio Smith** (Masked Orc) | 60 | 12 | 85 | 8 | 0.8 | 1.0 | 3 | Hierro (60%) |
| 7 | Orco | **Guerrero Orco** (Orc Warrior) | 65 | 12 | 70 | 8 | 0.9 | 1.0 | 5 | Hierro (60%) |
| 8 | Zombi | **Gran Zombi** (Big Zombie) | 70 | 10 | 42 | 6 | 1.3 | 1.5 | 4 | Hierro (50%) |
| 9 | Ogro | **Ogro** | 120 | 16 | 48 | 7 | 1.1 | 1.3 | 8 | Plata (70%) |
| 10 | Demonio | **Demonio Mayor** (Big Demon) | 90 | 14 | 78 | 9 | 0.8 | 0.9 | 7 | Plata (60%) |
| 11 | Caballero | **Capitán de la Torre** ⚜️ | 150 | 13 | 75 | 9 | 0.7 | 0.9 | 20 | **Tinte Real (100%)** |

> **Composición de la mazmorra** (pool de spawn fijo + jefe): Goblin ×2 · Wogol ×3 · Imp ×1 · Skelet ×3 · Calabaza ×1 · Demonio Smith ×2 · Guerrero Orco ×1 · Gran Zombi ×1 · Ogro ×1 · Demonio Mayor ×1 · **Capitán** ×1.

### ⚜️ El Capitán (jefe, 2 fases)

- Espera en la **sala santuario** (la más lejana al spawn, ≥14 tiles) — la **brújula** del HUD lo señala.
- **FASE 2** al llegar al 50% de HP: velocidad ×1.6, daño ×1.5 (13 → 19), tintura de furia roja y escala ×1.55.
- Caído → **victoria** (festejo con stats) + suelta: 20 monedas, **Tinte Real (100%)**, **Espada dorada (100%)**, Frasco rojo (100%).

### Loot por enemigo

| Enemigo | Armas (rollo) | Frascos (rollo) |
|---|---|---|
| Wogol | Cuchillo 5% | Frasco rojo 12% |
| Goblin | Hacha arrojadiza 6% · Cuchillo 4% | Frasco rojo 10% |
| Imp | Cuchillo 5% | Frasco azul 8% |
| Skelet | Espada oxidada 12% · Hacha 5% | Frasco rojo 15% |
| Calabaza | Machete 10% · Arco corto 8% | Frasco amarillo 8% |
| Demonio Smith | Maza 12% · Katana 8% | Frasco rojo 20% · azul 5% |
| Guerrero Orco | Hacha de guerra 15% · Espada serrucho 10% | Frasco azul 15% |
| Gran Zombi | Martillo 12% · Cuchilla 8% | Frasco rojo 18% |
| Ogro | Martillo grande 20% · Hacha doble 12% | Frasco rojo 22% |
| Demonio Mayor | Espada de caballero 15% · Espada de gema roja 10% | Frasco amarillo 15% |
| Capitán | **Espada dorada 100%** | Frasco rojo 100% |

---

## ⛏️ Recursos y minería

Se minan rompiendo **vetas** (hit con el pico; `mine_power = 1 manos · 2 pico de madera · 3 pico de cobre`).
Se queman en la forja y se muestran tintados en el inventario.

| Recurso | Sprite | Vetas por mazmorra | Distancia mínima al spawn |
|---|---|---|---|
| 🪵 **Madera** | moneda marrón | 5 | 4 tiles |
| 🟠 **Cobre** | moneda naranja | 3 | 6 tiles |
| ⚙️ **Hierro** | moneda gris | 2 | 8 tiles |
| 🪙 **Plata** | moneda plateada | 1 | 10 tiles |

**Además:** monedas de oro (¤) que sueltan los enemigos → **tesoro** del leaderboard on-chain; y **4 frascos rojos** tirados en el piso (configurable).

---

## 🧰 Herramientas

| Item | Nombre | Efecto | Obtención |
|---|---|---|---|
| `pico_madera` | Pico de Madera | `mine_power` 2 | Inicial (cartera de nacimiento) |
| `pico_cobre` | Pico de Cobre | `mine_power` 3 | **Forja:** madera 1 + cobre 1 |

---

## ⚔️ Armas

El daño del jugador = la **mejor arma** de la cartera (auto-equip, `★` en el inventario).
Base 12; daño final = daño del arma + bonus de calidad (solo forjadas).

### Armas de drop (26)

| Icono | Nombre | Daño | Fuente |
|---|---|---|---|
| `weapon_knife` | Cuchillo | 12 | **Inicial** · Wogol 5% · Goblin 4% · Imp 5% |
| `weapon_rusty_sword` | Espada oxidada | 13 | Skelet 12% |
| `weapon_spear` | Lanza | 13 | — (futura) |
| `weapon_throwing_axe` | Hacha arrojadiza | 13 | Goblin 6% |
| `weapon_bow` | Arco corto | 13 | Calabaza 8% |
| `weapon_axe` | Hacha | 14 | Skelet 5% |
| `weapon_anime_sword` | Espada anime | 14 | — (futura) |
| `weapon_cleaver` | Cuchilla | 14 | Gran Zombi 8% |
| `weapon_regular_sword` | Espada común | 15 | — (futura) |
| `weapon_hammer` | Martillo | 15 | Gran Zombi 12% |
| `weapon_baton_with_spikes` | Porra con púas | 15 | — (futura) |
| `weapon_machete` | Machete | 15 | Calabaza 10% |
| `weapon_red_magic_staff` | Báculo rojo | 15 | — (futura) |
| `weapon_mace` | Maza | 16 | Demonio Smith 12% |
| `weapon_saw_sword` | Espada serrucho | 16 | Guerrero Orco 10% |
| `weapon_big_hammer` | Martillo grande | 16 | Ogro 20% |
| `weapon_bow_2` | Arco largo | 16 | — (futura) |
| `weapon_katana` | Katana | 17 | Demonio Smith 8% |
| `weapon_green_magic_staff` | Báculo verde | 17 | — (futura) |
| `weapon_duel_sword` | Espada de duelo | 18 | — (futura; icono del Mandoble) |
| `weapon_double_axe` | Hacha doble | 18 | Ogro 12% |
| `weapon_waraxe` | Hacha de guerra | 18 | Guerrero Orco 15% |
| `weapon_knight_sword` | Espada de caballero | 19 | Demonio Mayor 15% |
| `weapon_lavish_sword` | Espada suntuosa | 20 | — (futura) |
| `weapon_red_gem_sword` | Espada de gema roja | 20 | Demonio Mayor 10% |
| `weapon_golden_sword` | Espada dorada | 21 | **Capitán 100%** |

### Armas forjadas (tokens únicos con suerte)

| Receta | Nombre | Daño base | Costo | Icono |
|---|---|---|---|---|
| `espada_cobre` | Espada de Cobre | 14 | madera 1 + cobre 2 | `weapon_rusty_sword` |
| `mandoble_hierro` | Mandoble de Hierro | 18 | hierro 3 | `weapon_duel_sword` |
| `hacha_plata` | Hacha de Plata | 22 | hierro 2 + plata 2 | `weapon_waraxe` |

> 🎲 **Calidades** (suerte del tiro): **Común +0** (55%) · **Fina +2** (25%) · **Superior +4** (14%) · **Épica +8** (6%).
> Cada forja mintea un **token único e inmutable** (`espada_cobre_f0`, …) con su daño final: base + bonus. Se muestran en el inventario con nombre + calidad y `★` si están equipadas.

---

## 🧪 Frascos (consumibles)

| Item | Nombre | Efecto | Fuente |
|---|---|---|---|
| `flask_red` | Frasco rojo | +25 HP | **Inicial ×1** · drops (ver tabla) · 4 tirados en el piso |
| `flask_blue` | Frasco azul | +25 HP | Imp 8% · Demonio Smith 5% · Guerrero Orco 15% |
| `flask_green` | Frasco verde | +25 HP | — (futura) |
| `flask_yellow` | Frasco amarillo | +25 HP | Calabaza 8% · Demonio Mayor 15% |

> Usarlos firma `use_item` on-chain (se descuenta de la cartera) y cura hasta el máximo de 100 HP.

---

## 🎨 Cosmético

| Item | Nombre | Efecto | Fuente |
|---|---|---|---|
| `tinte_real` | Tinte Real | **Aura dorada** permanente en el jugador mientras esté en cartera | Capitán (100%) |

---

## 📦 Items planificados (LOCKED, sin mecánica aún)

`escudo_cobre` · `coraza_hierro` — figuran en el spec de 8 items on-chain; todavía no tienen receta ni mecánica.

---

## 🔗 Referencia rápida de IDs on-chain

- **Recursos:** `madera` `cobre` `hierro` `plata`
- **Herramientas:** `pico_madera` `pico_cobre`
- **Armas de drop:** `weapon_*` (26, ver tabla)
- **Armas forjadas:** `espada_cobre` `mandoble_hierro` `hacha_plata` (+ token `_fN`)
- **Frascos:** `flask_red` `flask_blue` `flask_green` `flask_yellow`
- **Cosmético:** `tinte_real` (drop del jefe)
- **Monedas:** `coin` → tesoro on-chain