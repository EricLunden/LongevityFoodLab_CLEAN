# List Card Padding Diagram

## Card Structure Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         ZStack (Card Container)                  │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Button (Card Content)                                    │  │
│  │                                                           │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  HStack (spacing: 12)                               │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────┐  ┌──────────────┐      ┌──────────┐    │  │  │
│  │  │  │Image │  │ Title/Info   │      │  Score   │    │  │  │
│  │  │  │60x60 │  │ VStack       │      │  Circle  │    │  │  │
│  │  │  │      │  │ (spacing: 4) │      │  60x60   │    │  │  │
│  │  │  └──────┘  └──────────────┘      └──────────┘    │  │  │
│  │  │                                                     │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                           │  │
│  │  Padding:                                                │  │
│  │  • Vertical: 8pt (top & bottom)                          │  │
│  │  • Horizontal: 12pt (left & right)                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  X Button Overlay (VStack > HStack)                      │  │
│  │                                                           │  │
│  │                    ┌──────────┐                          │  │
│  │                    │    X     │                          │  │
│  │                    │  Button  │                          │  │
│  │                    │  44x44   │                          │  │
│  │                    │          │                          │  │
│  │                    │ Padding: │                          │  │
│  │                    │ top: -4  │                          │  │
│  │                    │ right:-4 │                          │  │
│  │                    └──────────┘                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Padding Breakdown

### Card Content (Button)
```
┌─────────────────────────────────────────────────────────────┐
│  Card Edge                                                  │
│                                                             │
│  ↑ 8pt vertical padding                                    │
│                                                             │
│  ← 12pt →  ┌──────┐ 12pt gap  ┌──────────┐  12pt gap  ┌──────────┐  ← 12pt →
│            │Image │            │  Title   │             │  Score   │
│            │60x60 │            │  Info    │             │  Circle  │
│            └──────┘            └──────────┘             │  60x60   │
│                                                          └──────────┘
│                                                             │
│  ↓ 8pt vertical padding                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### X Button Positioning
```
┌─────────────────────────────────────────────────────────────┐
│  Card Edge                                                   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                                                      │   │
│  │                                      ┌───────────┐ │   │
│  │                                      │     X     │ │   │
│  │                                      │  Button   │ │   │
│  │                                      │  44x44    │ │   │
│  │                                      │           │ │   │
│  │                                      │  -4pt top │ │   │
│  │                                      │  -4pt rt  │ │   │
│  │                                      └───────────┘ │   │
│  │                                                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Element Spacing Summary

### Horizontal Layout (Left to Right)
1. **Card Left Edge** → 12pt padding
2. **Image** (60x60)
3. **12pt spacing** (HStack spacing)
4. **Title/Info VStack**
   - Text elements have 4pt spacing between them
5. **Spacer()** (pushes score circle to right)
6. **Score Circle** (60x60)
7. **12pt padding** → **Card Right Edge**

### Vertical Layout (Top to Bottom)
1. **Card Top Edge** → 8pt padding
2. **Content Row** (Image + Title + Score)
3. **8pt padding** → **Card Bottom Edge**

### X Button Overlay
- **Position**: Top-right corner
- **Frame**: 44x44 points (tap area)
- **Padding from card edge**: 
  - Top: -4pt (overlaps card edge by 4pt)
  - Right: -4pt (overlaps card edge by 4pt)
- **Z-Index**: 1 (above card button)

## Measurements

| Element | Size | Padding/Spacing |
|---------|------|-----------------|
| Card | Full width | Vertical: 8pt, Horizontal: 12pt |
| Image | 60x60 | None (within HStack) |
| HStack spacing | - | 12pt between elements |
| Title VStack spacing | - | 4pt between text lines |
| Score Circle | 60x60 | None (within HStack) |
| X Button | 44x44 | Top: -4pt, Right: -4pt |

## Visual Representation

```
Card Width: Screen width - 40pt (20pt padding on each side from parent)
Card Height: ~76pt (8pt top + ~60pt content + 8pt bottom)

┌──────────────────────────────────────────────────────────────┐
│ Card (rounded corners: 12pt, stroke: 1pt, shadow)          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ 8pt                                                    │ │
│  │  ┌──────┐  12pt  ┌──────────┐  Spacer  ┌──────────┐ │ │
│  │  │Image │  gap   │  Title   │          │  Score   │ │ │
│  │  │60x60 │        │  Info    │          │  Circle  │ │ │
│  │  └──────┘        └──────────┘          │  60x60   │ │ │
│  │                                          └──────────┘ │ │
│  │ 8pt                                                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│                                    ┌──────┐                 │
│                                    │  X   │ (-4pt from top) │
│                                    │ 44x44│ (-4pt from rt)  │
│                                    └──────┘                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```




