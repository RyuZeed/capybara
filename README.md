# ⚡ RITOD HUB - MULTI-GAME AUTO LOADER (V3.3)

Script otomatisasi multi-game canggih (*Modular & Universal Edition*) untuk Roblox dengan sistem deteksi `PlaceId` otomatis.

---

### 🚀 Cara Menjalankan Script di Roblox Executor

Salin dan tempel **1 baris perintah di bawah ini** ke dalam Executor Anda (Delta, Solara, Wave, Xeno, Codex, Arceus X, dll):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/RyuZeed/capybara/main/main.lua"))()
```

---

### 🎮 Game yang Didukung (*Auto-Detect*):

| Game | Place ID | File Controller | Folder Modul |
| :--- | :---: | :---: | :---: |
| 🎰 **Roll Anime To fight** | `107653945083776` | `roll_anime.lua` | `modules/roll_anime/` |
| 🐾 **Capybaras vs Plants** | `104973076655377` | `capybara.lua` | `modules/capybara/` |

---

### 📁 Struktur Arsitektur Repository

```text
📁 RitodHub/
├── 📄 main.lua                     <-- 🎮 Universal Master Launcher (Auto-Detect PlaceId)
├── 📄 roll_anime.lua               <-- ⚡ UI Controller Roll Anime (Ultra HD 700x460)
├── 📄 capybara.lua                 <-- 👑 UI Controller Capybara vs Plants
├── 📄 push.bat                     <-- 🚀 1-Click Auto Commit & Push ke GitHub
├── 📄 README.md                    <-- 📖 Panduan & Dokumentasi
│
└── 📁 modules/
    ├── 📁 roll_anime/              <-- 🎰 Modul Mesin Roll Anime
    │   ├── 📄 anti_afk.lua         (3-Layer Hardware Keypulse & Idle Bypass)
    │   ├── 📄 config_manager.lua   (RitodHub/RollAnimeForFight/<Username>.json)
    │   ├── 📄 catalog.lua          (Filter 13 Secret & 14 God Unit Asli)
    │   └── 📄 auto_roll.lua        (Engine Auto Roll & Unit Pedestal Sniper)
    │
    └── 📁 capybara/                <-- 🐾 Modul Mesin Capybara
        ├── 📄 anti_afk.lua         (Anti-AFK Capybara)
        ├── 📄 auto_claim.lua       (Klaim Playtime & Daily Rewards)
        ├── 📄 auto_delete.lua      (Smart Auto Delete & Filter Tanaman Sampah/Common)
        ├── 📄 auto_tutorial.lua    (12 Steps Full Auto Tutorial)
        ├── 📄 graphics.lua         (Potato Graphics, Farm Mode, Anti-Lag)
        └── 📄 pink_remover.lua     (Destroyer Notifikasi Pink)
```

---

### ✨ Fitur Unggulan

#### 🎰 Roll Anime To fight:
* **Auto Roll & Unit Sniper**: Otomatis roll dan auto-buy unit target di pedestal (Secret, God, Mythic, dll).
* **Strict Unit Catalog**: Akurasi katalog 13 Secret & 14 God unit asli (tanpa clone/sub-unit).
* **Per-User Persistent Config**: Menyimpan settingan dan pilihan unit otomatis ke `RitodHub/RollAnimeForFight/<Username>.json`.
* **Auto-Resume**: Otomatis melanjutkan roll saat rejoin/relog jika fitur aktif sebelumnya.
* **Stationary Safe Approach**: Karakter mendekat secara aman ke tombol roll tanpa resiko void/jatuh.

#### 🐾 Capybaras vs Plants:
* **Auto Delete Plant**: Otomatis membersihkan & menghapus tanaman Common/sampah dengan proteksi tanaman terbaik (Equipped Protection).
* **Auto Tutorial 1-12**: Menyelesaikan tutorial awal game secara instan dari awal hingga boss Scarlet Carrot.
* **Smart Auto Claim**: Otomatis mengklaim Playtime Rewards & Daily Rewards.
* **Potato Engine & Farm Mode**: Layar redup + FPS cap ke 5 untuk menghemat daya GPU & CPU saat AFK.
* **Zero Lag Pink Remover**: Membersihkan pesan popup warning tanpa lag.

---

### 🛡️ Sistem Anti-AFK 24/7 (3-Layer Bypass)
Semua game dilengkapi modul Anti-AFK multi-layer:
1. Pemutus koneksi `player.Idled`.
2. Hardware virtual keypulse (`RightShift` simulation) setiap 45 detik untuk mereset timer 20 menit Roblox.
3. Metatable hook pencegah pemanggilan `player:Kick()`.
