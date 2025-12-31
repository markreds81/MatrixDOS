# Matrix DOS Demo

A **Matrix-style digital rain demo** written for **MS-DOS** using **Turbo Pascal 7.0**, designed to run on real vintage hardware (386 / 486) as well as DOSBox-compatible emulators.

This project was born as a **retro-programming exercise** and a tribute to 1990s demo-scene techniques: direct VGA access, BIOS font manipulation, custom color palettes, and timer-driven animations.

---

## ✨ Features

- VGA text mode **80×50**
- Custom font loaded via BIOS (`INT 10h`)
- Digital rain effect with multiple brightness levels (afterglow)
- Animated intro logo with fade effects
- Optimized for slow CPUs (tested on **386 SX @ 16 MHz**)
- No external libraries required

---

## 🖥️ Requirements

### Real hardware
- CPU: Intel 80386 or higher
- Video: VGA-compatible card
- RAM: minimum 2 MB
- OS: **MS-DOS / IBM DOS**

### Software
- **Turbo Pascal 7.0**
- DOSBox (optional, for development/emulation)

---

## 🛠️ Building

Open the project in **Turbo Pascal 7.0** and compile normally:

```

Compile → Compile

```

Or from the command line:

```

TPC MATRIX.PAS

```

The resulting executable will be `MATRIX.EXE`.

---

## ▶️ Running

From real DOS or DOSBox:

```

MATRIX

```

The demo relies on the system timer; animation speed will vary depending on CPU performance.

---

## ⚙️ Technical notes

- Direct access to VGA text memory
- Manual video page management
- User font loading via BIOS (`INT 10h, AX=1100h`)
- Color palette programming through VGA DAC
- Pure text-mode rendering (no bitmap graphics)

---

## 🎯 Project goals

- Explore pre-3D-acceleration rendering techniques
- Understand real DOS-era hardware constraints
- Recreate iconic visual effects with period-correct tools
- Provide a foundation for future demos (fire, plasma, 3D wireframe)

---

## 📜 License

This project is released under the **MIT License**.  
Feel free to study, modify, and reuse it for your own retro-computing experiments.

---

## 🤝 Contributing

Pull requests and suggestions are welcome, especially if you:
- test the demo on real hardware
- further optimize performance
- add new demo-scene effects

---

## ❤️ Final note

Written with passion for retro-computing,  
when **16 MHz were more than enough**.
```
