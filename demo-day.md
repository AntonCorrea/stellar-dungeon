# Stellar Dungeon — Guion de Demo Day (sáb 26/9)

Objetivo: demostrar en **90 segundos** un juego real cuyo **smart contract** decide parte de la jugabilidad, con 3 capas visibles: **juego (Godot) → relé (Node) → contrato (Soroban testnet)**.

- Contrato vivo: `CCEEBLMRH55A7WDKAD6JSRINYPR7HBSP3YBPSP5C6OKW6VNCUSLUL2GM`
- Jugador dev: `GCPVO2PGNWRRA3SSDFUCDUEKHUDHNIACLWHJX7GVX6CGSXSDABKRF4F7`
- Explorer contrato: `https://stellar.expert/explorer/testnet/contract/CCEEBLMRH55A7WDKAD6JSRINYPR7HBSP3YBPSP5C6OKW6VNCUSLUL2GM`

---

## 0. PITCH (el corazón de la demo, aprendelo de memoria)

> **10 segundos:** "Stellar Dungeon es un RPG 2D donde cada arma que forjas es tuya de verdad: es un token único escrito en la blockchain de Stellar. Y la suerte de la forja no la tira el juego: la tira un smart contract desplegado en testnet."

> **Variante 30 segundos (si piden más contexto):**
> "Los juegos usualmente guardan tu loot en una base de datos que te pueden quitar. Acá cada arma es un activo on-chain, verificable por cualquiera. El juego arma la partida, pero la **rareza de cada arma — Común, Fina, Superior o Épica — la decide un contrato Soroban**, con tirada determinista y anti-replay: la suerte es auditable, no trucable."

---

## 1. SETUP ANTES DE LA DEMO (todo listo, no hacer nada en vivo)

- [ ] Terminar el relé real: `cd stellar\relay` → `.\start-live.ps1` (ventana 1, queda abierta)
- [ ] Verificar: `Invoke-RestMethod http://localhost:8787/health` → `mode:"real"`, `dev_player:"GCPVO…"`
- [ ] **Pre-calentar on-chain**: forjar 1 arma antes (ya existen `espada_cobre_f0` y `_f1`). Así el explorer/token se puede mostrar al instante.
- [ ] Abrir el juego: `cd stellar-dungeon` → `.\play-live.ps1` (ventana 2)
- [ ] Tener la pestaña del **explorer del contrato** abierta y cargada (ventana 3)
- [ ] Tener abierto `http://localhost:8787/forge-stats/espada_cobre_f0` (ventana 4, muestra el JSON del contrato)
- [ ] Tener una veta de madera/cobre cerca del player (o minar de más antes: el inventario del relé persiste)

**Regla de oro**: nunca dependas de una tx en vivo para el golpe visual. El "momento wow" del explorer se muestra con un token ya forjado; la forja en vivo demuestra que sigue funcionando.

---

## 2. TIMELINE EXACTO (90 segundos)

| Tiempo | Qué hacés | Qué decís (aproximado) |
|---|---|---|
| **0–08s** | Juego en pantalla. Mové al player 2-3 pasos. | *"Este es Stellar Dungeon, un dungeon crawler 2D. Lo que vas a ver: juego, y atrás, blockchain real."* |
| **08–20s** | **Miná** una veta (madera + cobre). Mostrá el HUD subiendo (E para inventario). | *"Mino recursos: madera y cobre. Hasta acá, normal — cualquier juego."* |
| **20–35s** | **Forjá** la espada en el brasero (madera 1 + cobre 2). El HUD muestra el token nuevo y su calidad. ⏱️ *La tx on-chain tarda 2-5 s → narrá el silencio.* | *"Ahora la parte que NO es normal: forjo una espada. Mientras el contrato procesa… (pausa)… ahí está: `espada_cobre_fN`, calidad Fina, +2 de daño."* |
| **35–55s** | 🔗 **MOMENTO WEB3**: mostrá el **JSON del contrato** (ventana 4: `forge-stats/{token}`) y/o **explorer** (ventana 3). | *"Esa calidad no salió del juego. Preguntale al contrato: acá está la metadata escrita on-chain — base, quality 1, dmg 16. `espada_cobre_f0` ya está en la cadena desde antes; este es su registro inmutable."* |
| **55–75s** | **MOMENTO SMART CONTRACT**: mostrá el explorer del contrato (transacciones recientes). Contá las 3 garantías. | *"Tres cosas que un server no te puede prometer: 1) el arma es un token único, la misma nieve se emite una sola vez; 2) la suerte es determinista por seed y anti-replay — una seed usada, no se repite; 3) si la forja falla on-chain, no se quema nada (atomicidad)."* |
| **75–90s** | Cierre. Lanzá el leaderboard (o el HUD) y el pitch de 10s. | *"Cada arma que llevás en el dungeon deja de ser un número en una base de datos y pasa a ser un activo que te pertenece y que cualquiera puede verificar. Stellar Dungeon."* |

---

## 3. LOS 3 "MOMENTOS TÉCNICOS" QUE DEJAN EN CLARO WEB3 + SMART CONTRACT

1. **El token es real (web3)** — mostrar `forge-stats/espada_cobre_f0` devolviendo `{base, quality, dmg}` directamente del contrato, no del juego ni del relé.
2. **La suerte es del contrato (smart contract)** — la calidad del HUD == la metadata on-chain; y es determinista: `quality = rollQuality(seed)`, verificable porque las 16 seeds del fixture son idénticas entre Godot, Node y Rust.
3. **Integridad (lo que un server solo no garantiza)** — atomicidad (quema solo si el contrato acepta) y anti-replay (cada seed una sola vez). Si alguien pregunta "¿por qué blockchain acá?", esta es la respuesta: **propiedad y auditabilidad del loot.**

---

## 4. PLAN B (si la red/testnet falla en plena demo)

- Si el **relé** se cae: relanzar `start-live.ps1` (1 comando, 3 segundos).
- Si **testnet** no responde: jugar en modo **mock** (abrir el juego sin `CHAIN_BACKEND`) — el juego sigue siendo 100% jugable; decís la verdad: *"la demo sigue, la capa on-chain se muestra con las capturas"* (tener 2 capturas del explorer/mineria en el escritorio por si acaso).
- **NUNCA pretender que algo on-chain es lo que no es.** La honestidad es parte del pitch (jugador dev: el relé firma una keypair propia expuesta en `/health`).

---

## 5. CHECKLIST FINAL DEL DÍA (5 minutos antes)

- [ ] Ventana 1: relé real corriendo (`mode: real`)
- [ ] Ventana 2: juego abierto, player cerca de una veta
- [ ] Ventana 3: explorer del contrato cargado
- [ ] Ventana 4: `forge-stats/espada_cobre_f0` en JSON
- [ ] Tecla `E` lista para mostrar inventario; `Space` para atacar
- [ ] El pitch de 10 s repetido 3 veces en voz alta
- [ ] Capturas de respaldo en el escritorio (mock mode)

---

## 6. DATOS QUE TE PUEDEN PREGUNTAR (y sus respuestas)

| Pregunta | Respuesta |
|---|---|
| ¿Dónde está la billetera? | Es el **jugador dev** `GCPVO…`. La llave privada vive en el relé (derivada de su secret, honesta y expuesta en `/health`); el juego solo ve la dirección pública. |
| ¿Qué costo tiene una forja? | Testnet, gratis. La tx la paga el relé (`GDP2Y…`). En mainnet sería barato (presupuesto Soroban ~0.01 XLM). |
| ¿Por qué no Freighter? | El juego corre en Godot sin navegador. Freighter (firma real del jugador) se documentó como próximo paso: `/tx/prepare` + `/tx/submit` en el relé. En la demo el relé firma por el jugador dev — transparente. |
| ¿Los recursos/tesoro están on-chain? | No — minería, frascos y tesoro son off-chain (ledger del relé, `relay.db`). **On-chain vive solo el loot forjado**: las armas únicas (NFT de juego: ver sección 7). Eso es deliberado: el contrato guarda lo que importa poseer. |
| ¿Cómo sé que la suerte no está trucada? | El contrato es determinista: `quality = xorshift(seed)`. Las 16 seeds del fixture son idénticas entre Rust, Node y Godot (test `test_forge_ledger`). La seed la indica el propio token (`_fN`): cualquiera puede re-verificar. |

---

## 7. ¿ES UN NFT? (respuesta preparada)

**Respuesta corta: sí — en esencia es un NFT, y tiene más "on-chain" que muchos NFT de colección.**

| Propiedad de NFT | Tu arma (`espada_cobre_f0`) | Dónde se ve en el código |
|---|---|---|
| **Única** | No se puede forjar dos veces el mismo token (anti-replay `UsedSeed` + guarda `TokenExists`) | `lib.rs` líneas 261–270 |
| **No fungible** | Cada una tiene calidad/daño distintos (Común, Fina, Superior, Épica) | `WeaponMetadata` |
| **Con dueño** | El contrato guarda `owner: Address` y la lista `PlayerWeapons(player)` | `lib.rs` 182 y 318 |
| **Metadata on-chain** | Base, calidad y daño viven en el storage del contrato (persistente) | `lib.rs` 293 |
| **Transferible y quemable** | `transfer` y `burn` en el contrato (el relé ya enruta `/transfer` on-chain) | `lib.rs` 323 y 364 |

**Diferencias con un "NFT de foto" (Bored Ape, etc.):**

1. **No tiene imagen** — un NFT de colección es una imagen con un token al lado (y la imagen muchas veces vive *afuera*, en IPFS). Tu espada no tiene dibujo: **todo** (receta, calidad, dueño) está adentro del contrato. No hay nada "afuera" que se pueda perder.
2. **No sigue el estándar de marketplace** — no es tipo ERC-721 y no aparece en OpenSea. Es metadata de un contrato propio, con utilidad de juego.
3. **No se vende todavía** — se puede transferir entre jugadores (`transfer`), pero no hay subasta. Es un activo de juego, no de arte.
4. **Vive en testnet** — real pero de práctica y gratis. En mainnet sería exactamente lo mismo, con valor de verdad.

**Frase para el pitch:** *"Cada arma que forjas es un activo único on-chain: su receta, su calidad y su dueño están escritos en el contrato, no en una base de datos que el servidor puede borrar. Tiene el mismo ADN que un NFT — pero sin la imagen: el objeto entero vive en la cadena."*

**Respuesta de una línea si preguntan "¿es un NFT?":** *"Es un NFT de juego: único, con dueño, transferible y quemable on-chain — solo que en vez de arte, guarda estadísticas que se usan en el dungeon."*

---

## 8. ¿POR QUÉ STELLAR? (respuesta preparada)

**Frase de una línea:** *"Elegimos Stellar porque Soroban te deja programar contratos en Rust baratos, rápidos y auditables — y porque Stellar nace como red de pagos, donde un loot algún día puede valer algo real."*

| Razón | Por qué importa para el juego |
|---|---|
| **Barato** | Cada forja = 1 transacción. En redes con gas caro, forjar 5 armas arruina al jugador. En Stellar cuesta fracciones de centavo (testnet: gratis). |
| **Rápido** | Finalidad en ~5 s: la espada aparece mientras narrás la pausa. Un juego no puede esperar minutos de confirmación por cada veta. |
| **Contratos en Rust (Soroban)** | El contrato `forge_ledger` está en Rust, con 22 tests que demuestran que es determinista: misma seed → misma calidad en Rust, Node y Godot. Esa propiedad es la que permite probar "la suerte no está trucada". |
| **Unicidad y anti-replay garantizadas por la red** | Que una seed no se repita y que un token no se emita dos veces lo garantiza la cadena, no nuestro servidor. Esta es la respuesta a "¿por qué no una base de datos?". |
| **Nace como red de pagos** | Stellar es una red pensada para dinero (XLM, anclas, puentes a fiat). El loot que forjas pide a gritos convertirse en economía real algún día: comprar, vender, canjear. Ese es el "utility NFT". |

**Si preguntan "¿por qué no una base de datos?"** — *"Una base de datos puede prometer unicidad y dueño, pero la promesa la cumple el servidor que la controla: si mañana lo apago o lo truco, la promesa se cae. Acá la unicidad, la propiedad y el anti-replay los garantiza la red, y cualquiera puede verificar la metadata sin pedirme permiso."*

**Honestidad que suma (no esconder):** es testnet, no hay economía real todavía, y las armas no son un token estándar de mercado — son metadata de contrato. Decirlo primero hace el pitch más creíble.

---

## 9. REPO / LINKS PARA MOSTRAR SI PIDEN CÓDIGO

- Contrato Rust: `stellar/forge_ledger/contracts/forge_ledger/src/lib.rs` (22 tests)
- Relé Node: `stellar/relay` (21 tests, `npm run verify` = verificación en vivo)
- Juego Godot: `stellar-dungeon` (8 tests headless, `test_forge_ledger` cruza Godot↔Rust)
- Verificación en vivo: `npm run verify` en `stellar/relay`