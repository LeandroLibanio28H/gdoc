# GDOC – Game Dev O'Clock

**GDOC** is a modular library for game development in [Odin](https://odin-lang.org/), focused on performance, clarity, and reusability.

> ⚙️ Built by [Leandro Libanio](https://libaniol.com).

---

## ✨ Features

🔸 **Sparse Set** implementation (manual and auto ID allocation)  
🔸 **Minimalist ECS** (Entity Component System) built on sparse sets

---

## 🦉 Phylosofy

- Designed for performance, simplicity, and modularity
- No OOP – built to work with Odin's idioms
- Clean API with high-level ergonomics

---

## ⚡ Getting Started

Add as a submodule:

```bash
git submodule add https://github.com/LeandroLibanio28H/gdoc.git
```

---

## 📦 Modules

### `sparse_set`

A blazing-fast sparse set implementation with two modes:

- `Sparse_Set_Auto` – IDs are automatically generated. Use like a performant list.
- `Sparse_Set_Manual` – IDs are user-defined. Great for syncing between multiple sets.

### `ecs`

A minimal ECS built on top of sparse_set, focused on:

- Automatic entity creation via Sparse_Set_Auto
- Per-component sparse sets
- Dynamic queries over registered components

---

## 📁 Directory Structure
```bash
gdoc/
├── sparse_set/
│   └── sparse_set.odin
│   └── sparse_set_private.odin #for private procedures
│   └── sparse_set_test.odin # unit tests
├── ecs/
│   └── ecs.odin
│   └── ecs_private.odin #for private procedures
│   └── ecs_test.odin # unit tests
└── README.md
```

---

## ✅ Requirements
- Odin (Latest Version)
- No external dependencies

---

## 📬 Feedback & Contributions

GDOC is modular and opinionated — if you're using it in your projects or want to contribute:

- Open an issue or PR
- Share your thoughts!
