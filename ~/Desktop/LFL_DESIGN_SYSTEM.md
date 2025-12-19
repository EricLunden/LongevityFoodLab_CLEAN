# Longevity Food Lab - Design System & Brand Image Book

**Document Version:** 1.0  
**Date:** December 15, 2025  
**App:** Longevity Food Lab (iOS)

---

## Table of Contents
1. [Color Palette](#color-palette)
2. [Typography](#typography)
3. [Icons & Symbols](#icons--symbols)
4. [Layout & Spacing](#layout--spacing)
5. [Components](#components)
6. [Shadows & Effects](#shadows--effects)
7. [Score-Based Visual System](#score-based-visual-system)
8. [Dark Mode](#dark-mode)

---

## Color Palette

### Primary Brand Colors

#### Main Green (Primary Action)
- **RGB:** `rgb(107, 142, 127)` / `Color(red: 0.42, green: 0.557, blue: 0.498)`
- **Usage:** Primary buttons, active states, score badges (80-100)
- **Hex Equivalent:** `#6B8E7F`

#### Teal Accent
- **RGB:** `rgb(155, 211, 213)` / `Color(red: 0.608, green: 0.827, blue: 0.835)`
- **Usage:** Borders, highlights, secondary accents
- **Hex Equivalent:** `#9BD3D5`

#### Light Teal (Secondary Score)
- **RGB:** `rgb(128, 180, 160)` / `Color(red: 0.502, green: 0.706, blue: 0.627)`
- **Usage:** Score badges (60-79), secondary elements
- **Hex Equivalent:** `#80B4A0`

### Button Gradients

#### Primary Action Button (Green Gradient)
- **Start:** `rgb(29, 139, 31)` / `#1D8B1F` - Deep Green
- **End:** `rgb(159, 169, 13)` / `#9FA90D` - Yellow-Green
- **Direction:** Leading to Trailing (left to right)
- **Usage:** "Add to Meal Tracker", "Add A Meal", primary CTAs

#### Secondary Action Button
- **Solid:** `rgb(107, 142, 127)` / `#6B8E7F` (Primary Green)
- **Usage:** "Evaluate Another Food", secondary actions

### Score-Based Color System

#### Score Badge Colors (by range)
- **80-100 (Excellent):** `rgb(107, 142, 127)` / `#6B8E7F` - Primary Green
- **60-79 (Good):** `rgb(128, 180, 160)` / `#80B4A0` - Light Teal
- **40-59 (Fair):** `Color.orange` - System Orange
- **0-39 (Poor):** `Color.red` - System Red

#### Score Gradient System (for progress bars/circles)
- **0-40% (Red-Orange):**
  - Start: `rgb(204, 26, 26)` / `Color(red: 0.8, green: 0.1, blue: 0.1)`
  - End: `rgb(230, 102, 26)` / `Color(red: 0.9, green: 0.4, blue: 0.1)`

- **40-60% (Orange-Yellow):**
  - Start: `rgb(230, 128, 26)` / `Color(red: 0.9, green: 0.5, blue: 0.1)`
  - End: `rgb(230, 179, 51)` / `Color(red: 0.9, green: 0.7, blue: 0.2)`

- **60-80% (Yellow-Green):**
  - Start: `rgb(204, 179, 51)` / `Color(red: 0.8, green: 0.7, blue: 0.2)`
  - End: `rgb(102, 179, 102)` / `Color(red: 0.4, green: 0.7, blue: 0.4)`

- **80-100% (Green):**
  - Start: `rgb(77, 153, 77)` / `Color(red: 0.3, green: 0.6, blue: 0.3)`
  - End: `rgb(51, 128, 51)` / `Color(red: 0.2, green: 0.5, blue: 0.2)`

### Macro Nutrient Colors

#### Calories (Purple Gradient)
- **Start:** `Color.purple`
- **End:** `rgb(153, 51, 204)` / `Color(red: 0.6, green: 0.2, blue: 0.8)`

#### Protein (Blue Gradient)
- **Start:** `rgb(0, 122, 255)` / `Color(red: 0.0, green: 0.478, blue: 1.0)`
- **End:** `rgb(0, 204, 204)` / `Color(red: 0.0, green: 0.8, blue: 0.8)`

#### Carbs (Orange-Yellow Gradient)
- **Start:** `rgb(231, 133, 12)` / `Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0)`
- **End:** `rgb(217, 233, 33)` / `Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)`

#### Fat (Yellow-Blue Gradient)
- **Start:** `rgb(255, 215, 0)` / `Color(red: 1.0, green: 0.843, blue: 0.0)`
- **End:** `rgb(173, 216, 230)` / `Color(red: 0.678, green: 0.847, blue: 0.902)`

#### Fiber (Green Gradient)
- **Start:** `Color.green`
- **End:** `rgb(51, 179, 102)` / `Color(red: 0.2, green: 0.7, blue: 0.4)`

#### Sodium (Purple Gradient)
- **Start:** `rgb(128, 77, 179)` / `Color(red: 0.5, green: 0.3, blue: 0.7)`
- **End:** `rgb(179, 128, 230)` / `Color(red: 0.7, green: 0.5, blue: 0.9)`

### Micronutrient Icon Colors

#### Calcium
- **Icon:** `leaf.fill`
- **Gradient:** Green to `rgb(51, 179, 102)`

#### Iron
- **Icon:** `bolt.fill`
- **Gradient:** Orange-Yellow (`rgb(231, 133, 12)` to `rgb(217, 233, 33)`)

#### Magnesium
- **Icon:** `waveform.path`
- **Gradient:** Purple (`Color.purple` to `rgb(153, 51, 204)`)

#### Phosphorus
- **Icon:** `figure.stand`
- **Gradient:** Gray (`Color.gray` to `rgb(179, 179, 179)`)

#### Potassium
- **Icon:** `brain.head.profile`
- **Gradient:** Blue (`Color.blue` to `rgb(0, 122, 255)`)

#### Sodium
- **Icon:** `drop.fill`
- **Gradient:** Red (`Color.red` to `rgb(204, 51, 51)`)

#### Zinc
- **Icon:** `waveform`
- **Gradient:** Teal (`rgb(65, 164, 167)` to `rgb(0, 204, 204)`)

#### Vitamin C
- **Icon:** `shield.fill`
- **Gradient:** Primary Green (`rgb(107, 142, 127)` to `rgb(77, 179, 153)`)

#### Folate
- **Icon:** `heart.circle.fill`
- **Gradient:** Green (`Color.green` to `rgb(51, 179, 102)`)

#### Vitamin B12
- **Icon:** `bolt.fill`
- **Gradient:** Orange-Yellow (`rgb(231, 133, 12)` to `rgb(217, 233, 33)`)

#### Vitamin D
- **Icon:** `brain.head.profile`
- **Gradient:** Blue (`Color.blue` to `rgb(0, 122, 255)`)

#### Copper
- **Icon:** `circle.hexagongrid.fill`
- **Gradient:** Orange (`rgb(204, 102, 0)` to `rgb(230, 153, 51)`)

#### Manganese
- **Icon:** `sparkles`
- **Gradient:** Purple (`Color.purple` to `rgb(153, 51, 204)`)

#### Selenium
- **Icon:** `bolt.heart.fill`
- **Gradient:** Orange-Red (`rgb(231, 133, 12)` to `Color.red`)

### Accent Colors

#### Blue-Purple Gradient (Scan Cards)
- **Start:** `rgb(64, 56, 213)` / `#4038D5` - Blue-Purple
- **End:** `rgb(12, 97, 255)` / `#0C61FF` - Bright Blue
- **Usage:** Scan result cards, supplement cards

#### System Colors Used
- **Orange:** `Color.orange` - Warnings, medium scores
- **Red:** `Color.red` - Errors, low scores, negative indicators
- **Green:** `Color.green` - Success, positive indicators
- **Blue:** `Color.blue` - Information, links
- **Yellow:** `Color.yellow` - Cautions
- **Gray:** `Color.gray` - Secondary text, disabled states

### Background Colors

#### Light Mode
- **Primary Background:** `Color(UIColor.systemBackground)` - White
- **Secondary Background:** `Color(UIColor.secondarySystemBackground)` - Light Gray
- **Card Background:** `Color(UIColor.systemBackground)` - White

#### Dark Mode
- **Primary Background:** `Color.black` - Pure Black
- **Secondary Background:** `Color(UIColor.secondarySystemBackground)` - Dark Gray
- **Card Background:** `Color.black` - Pure Black

---

## Typography

### Font System
- **Base:** San Francisco (SF Pro) - iOS System Font
- **All text uses:** `.font(.system(...))` or semantic font styles

### Font Sizes & Weights

#### Headlines
- **Large Title:** `.font(.largeTitle)` - ~34pt, Bold
- **Title:** `.font(.title)` - ~28pt, Semibold
- **Title 2:** `.font(.title2)` - ~22pt, Semibold
- **Title 3:** `.font(.title3)` - ~20pt, Bold
- **Headline:** `.font(.headline)` - ~17pt, Semibold

#### Body Text
- **Body:** `.font(.body)` - ~17pt, Regular
- **Body Semibold:** `.font(.body)` + `.fontWeight(.semibold)` - ~17pt, Semibold

#### Subheadings
- **Subheadline:** `.font(.subheadline)` - ~15pt, Regular/Bold
- **Subheadline Bold:** `.font(.subheadline)` + `.fontWeight(.bold)` - ~15pt, Bold

#### Small Text
- **Caption:** `.font(.caption)` - ~12pt, Regular/Medium
- **Caption 2:** `.font(.caption2)` - ~11pt, Regular

#### Custom Sizes
- **Score Display (Large):** `.font(.system(size: 46, weight: .bold))` - 46pt, Bold
- **Score Label:** `.font(.system(size: 11, weight: .bold))` - 11pt, Bold
- **Section Icon:** `.font(.system(size: 18, weight: .medium))` - 18pt, Medium
- **Grid Card Title:** `.font(.system(size: 11, weight: .medium))` - 11pt, Medium
- **Button Text:** `.font(.system(size: 14, weight: .medium))` - 14pt, Medium

### Font Weights Used
- **Regular:** Default weight
- **Medium:** `.fontWeight(.medium)` - 500
- **Semibold:** `.fontWeight(.semibold)` - 600
- **Bold:** `.fontWeight(.bold)` - 700

### Text Colors
- **Primary:** `.foregroundColor(.primary)` - Adapts to light/dark mode
- **Secondary:** `.foregroundColor(.secondary)` - Lighter gray
- **White:** `.foregroundColor(.white)` - For buttons/overlays
- **Custom:** `.foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))` - Brand green

---

## Icons & Symbols

### SF Symbols Used

#### Navigation & Actions
- `line.horizontal.3` - Hamburger menu
- `scope` - Search icon
- `chevron.up` / `chevron.down` - Expand/collapse
- `checkmark` - Success, selected
- `checkmark.circle.fill` - Success indicator
- `exclamationmark.triangle.fill` - Warning

#### Content Categories
- `book.fill` - Recipes
- `cart.fill` - Groceries
- `heart.fill` - Favorites
- `fork.knife` - Meals
- `pills.fill` - Supplements
- `flask.fill` - Ingredients
- `chart.pie.fill` - Macros
- `lightbulb.fill` - Tips/Best Practices

#### Micronutrients (see Micronutrient Icon Colors section)
- `leaf.fill` - Calcium
- `bolt.fill` - Iron, B12
- `waveform.path` - Magnesium
- `figure.stand` - Phosphorus
- `brain.head.profile` - Potassium, Vitamin D
- `drop.fill` - Sodium
- `waveform` - Zinc
- `shield.fill` - Vitamin C
- `heart.circle.fill` - Folate
- `circle.hexagongrid.fill` - Copper
- `sparkles` - Manganese
- `bolt.heart.fill` - Selenium

#### Other
- `photo` - Image placeholder
- `link` - External link
- `list.bullet` - List view
- `square.grid.3x3` - Grid view
- `plus.circle.fill` - Add action

### Emojis Used
- 🍽️ - Meal Tracker
- 🔍 - Search/Evaluate
- 💊 - Supplements
- ✓ - Checkmark (in text)
- ⚠️ - Warning
- 🟢 - High priority (green circle)
- 🟡 - Medium priority (yellow circle)
- ⚪ - Low priority (white circle)

---

## Layout & Spacing

### Standard Padding Values

#### Screen-Level Padding
- **Horizontal:** `20pt` - Standard side padding
- **Vertical:** `16pt` - Standard top/bottom padding

#### Card Padding
- **Standard Card:** `20pt` all sides
- **Compact Card:** `16pt` all sides
- **List Card:** 
  - Horizontal: `12pt`
  - Vertical: `8pt`

#### Button Padding
- **Primary Button:** 
  - Horizontal: `24pt`
  - Vertical: `12pt`
- **Secondary Button:**
  - Horizontal: `20pt`
  - Vertical: `15pt`
- **Icon Button:** `8pt` all sides

#### Section Padding
- **Section Header:** `20pt` horizontal, `16pt` vertical
- **Content Section:** `20pt` all sides
- **Nested Content:** `16pt` all sides

### Spacing Values

#### VStack/HStack Spacing
- **Tight:** `4pt` - Between related text lines
- **Standard:** `8pt` - Between card elements
- **Medium:** `12pt` - Between major elements
- **Large:** `16pt` - Between sections
- **Extra Large:** `20pt` - Between major sections
- **Section:** `24pt` - Between top-level sections

### Corner Radius

#### Cards & Containers
- **Small:** `8pt` - Buttons, small cards
- **Medium:** `12pt` - Standard cards, list items
- **Large:** `16pt` - Large cards, modals
- **Extra Large:** `20pt` - Full-screen modals, scan results
- **Circular:** `30pt` - Score badges (60x60)

### Border Widths
- **Thin:** `0.5pt` - Light mode borders
- **Standard:** `1pt` - Standard borders
- **Thick:** `2pt` - Prominent borders (scan cards)

---

## Components

### Cards

#### Standard Card
- **Background:** `Color(UIColor.systemBackground)` (light) / `Color.black` (dark)
- **Corner Radius:** `12pt`
- **Padding:** `20pt` all sides
- **Border:** `RoundedRectangle` stroke
  - Color: `Color(red: 0.608, green: 0.827, blue: 0.835)`
  - Opacity: `0.6` (light) / `1.0` (dark)
  - Width: `0.5pt` (light) / `1.0pt` (dark)
- **Shadow:** 
  - Color: `.black.opacity(0.1)`
  - Radius: `10pt`
  - Offset: `x: 0, y: 5`

#### List Card (Grid/Row View)
- **Corner Radius:** `12pt`
- **Padding:** 
  - Horizontal: `12pt`
  - Vertical: `8pt`
- **Image Size:** `60x60pt`
- **HStack Spacing:** `12pt`
- **VStack Spacing:** `4pt` (between text lines)
- **Score Circle:** `60x60pt`, circular (`30pt` radius)

#### Scan Result Card
- **Width:** `360pt`
- **Height:** `640pt` (content) / `390pt` (loading)
- **Corner Radius:** `20pt`
- **Border:** `2pt` stroke, teal color
- **Shadow:** 
  - Color: `.black.opacity(0.3)`
  - Radius: `20pt`
  - Offset: `x: 0, y: 10`

### Buttons

#### Primary Action Button (Gradient)
- **Background:** LinearGradient (Green to Yellow-Green)
- **Text Color:** White
- **Font:** `.subheadline` + `.bold` or `.headline` + `.semibold`
- **Padding:** Horizontal `24pt`, Vertical `12pt`
- **Corner Radius:** `8pt` or `12pt`
- **Frame:** `.frame(maxWidth: .infinity)` - Full width

#### Secondary Action Button
- **Background:** Solid Primary Green `rgb(107, 142, 127)`
- **Text Color:** White
- **Font:** `.headline` + `.semibold`
- **Padding:** Horizontal `20pt`, Vertical `15pt`
- **Corner Radius:** `12pt`
- **Frame:** `.frame(maxWidth: .infinity)` - Full width

#### Icon Button
- **Size:** `44x44pt` (tap target)
- **Padding:** `8pt` all sides
- **Style:** `PlainButtonStyle()`

### Score Badges

#### Circular Score Badge
- **Size:** `60x60pt`
- **Shape:** Circle (`30pt` radius)
- **Background:** Score-based color (see Score-Based Color System)
- **Text:** 
  - Score: `.font(.title3)` + `.bold`, White
  - Label: `.font(.caption2)`, White with opacity `0.8`
- **Layout:** VStack with `2pt` spacing

#### Large Score Display
- **Score Number:** `.font(.system(size: 46, weight: .bold))`, White
- **Label:** `.font(.system(size: 11, weight: .bold))`, White
- **Background:** Gradient based on score (see Score Gradient System)

### Progress Bars

#### Macro Progress Bar
- **Height:** Standard system height
- **Background:** Light gray/transparent
- **Fill:** Gradient (see Macro Nutrient Colors)
- **Direction:** Leading to Trailing (left to right)
- **Corner Radius:** Rounded ends

### Expandable Sections

#### Section Header
- **Icon:** SF Symbol, `.font(.system(size: 18, weight: .medium))`
- **Title:** `.font(.headline)` + `.fontWeight(.semibold)`
- **Chevron:** `chevron.up` / `chevron.down`
- **Padding:** Horizontal `20pt`, Vertical `16pt`
- **Background:** `Color(UIColor.secondarySystemBackground)`
- **Corner Radius:** `12pt`
- **Tap Target:** Full header area

### Grid Layouts

#### 2-Column Grid
- **Columns:** `GridItem(.flexible(), spacing: 10)`
- **Spacing:** `10pt` between items
- **Card Size:** Flexible, maintains aspect ratio

#### 3-Column Grid (if used)
- **Columns:** `GridItem(.flexible(), spacing: 10)`
- **Spacing:** `10pt` between items

---

## Shadows & Effects

### Card Shadows

#### Standard Card Shadow
- **Color:** `.black.opacity(0.1)`
- **Radius:** `10pt`
- **Offset:** `x: 0, y: 5`
- **Usage:** Standard cards, content sections

#### Prominent Shadow (Scan Cards)
- **Color:** `.black.opacity(0.3)`
- **Radius:** `20pt`
- **Offset:** `x: 0, y: 10`
- **Usage:** Modal cards, scan results

#### Light Shadow (Search Bar)
- **Color:** `.black.opacity(0.15)` (light) / `.white.opacity(0.6)` (dark)
- **Radius:** `16pt`
- **Offset:** `x: 0, y: 4`
- **Usage:** Elevated elements, search bars

### Blur Effects
- **Background Blur:** `2pt` radius - Used on scan result backgrounds
- **Usage:** To make foreground cards stand out

### Opacity Values
- **Disabled:** `0.5` - Reduced opacity for disabled states
- **Secondary Text:** `.secondary` - System secondary color
- **Border Opacity:** `0.6` (light mode) / `1.0` (dark mode)

---

## Score-Based Visual System

### Score Ranges & Colors

#### 80-100 (Excellent)
- **Color:** Primary Green `rgb(107, 142, 127)`
- **Label:** "Exceptional" (90-100), "Excellent" (80-89)
- **Visual:** Green badge, green gradient

#### 60-79 (Good)
- **Color:** Light Teal `rgb(128, 180, 160)`
- **Label:** "Good"
- **Visual:** Teal badge, yellow-green gradient

#### 40-59 (Fair)
- **Color:** System Orange
- **Label:** "Fair"
- **Visual:** Orange badge, orange-yellow gradient

#### 0-39 (Poor)
- **Color:** System Red
- **Label:** "Needs Improvement"
- **Visual:** Red badge, red-orange gradient

### Score Gradient Application
- **Progress Bars:** Full gradient based on score percentage
- **Circular Progress:** Stroke gradient on circle
- **Card Backgrounds:** Gradient overlay on score cards
- **Direction:** Top-leading to bottom-trailing (diagonal)

---

## Dark Mode

### Background Colors
- **Primary:** `Color.black` - Pure black (not system background)
- **Secondary:** `Color(UIColor.secondarySystemBackground)` - Dark gray
- **Cards:** `Color.black` - Pure black

### Border Adjustments
- **Opacity:** `1.0` (full opacity in dark mode vs `0.6` in light)
- **Width:** `1.0pt` (thicker in dark mode vs `0.5pt` in light)
- **Color:** Same teal color, higher contrast

### Text Colors
- **Primary:** `.primary` - Adapts to white in dark mode
- **Secondary:** `.secondary` - Adapts to lighter gray in dark mode
- **White Text:** Remains white on colored backgrounds

### Shadow Adjustments
- **Search Bar:** `.white.opacity(0.6)` shadow in dark mode (vs `.black.opacity(0.15)` in light)
- **Cards:** Same shadow values, may appear more prominent

### Visual Hierarchy
- **Borders:** More prominent in dark mode (thicker, full opacity)
- **Shadows:** May need adjustment for visibility
- **Contrast:** Higher contrast needed for readability

---

## Component Examples

### Primary Button
```swift
Button(action: {}) {
    HStack(spacing: 8) {
        Text("🍽️")
        Text("Add to Meal Tracker")
            .font(.subheadline)
            .fontWeight(.bold)
    }
    .foregroundColor(.white)
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .background(
        LinearGradient(
            colors: [
                Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),
                Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    )
    .cornerRadius(8)
}
```

### Standard Card
```swift
VStack(alignment: .leading, spacing: 16) {
    // Content
}
.padding(20)
.background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
.cornerRadius(12)
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(
            Color(red: 0.608, green: 0.827, blue: 0.835)
                .opacity(colorScheme == .dark ? 1.0 : 0.6),
            lineWidth: colorScheme == .dark ? 1.0 : 0.5
        )
)
.shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
```

### Score Badge
```swift
VStack(spacing: 2) {
    Text("\(score)")
        .font(.title3)
        .fontWeight(.bold)
        .foregroundColor(.white)
    Text("Score")
        .font(.caption2)
        .foregroundColor(.white.opacity(0.8))
}
.frame(width: 60, height: 60)
.background(scoreColor(score))
.cornerRadius(30)
```

---

## Design Principles

1. **Consistency:** All similar components use the same styling
2. **Hierarchy:** Clear visual hierarchy through size, weight, and color
3. **Accessibility:** Sufficient contrast, readable font sizes, adequate tap targets (44x44pt minimum)
4. **Dark Mode:** Full support with adjusted colors and borders
5. **Score-Based:** Visual system adapts to score values for immediate recognition
6. **Gradients:** Used for primary actions and score visualization
7. **Spacing:** Consistent padding and spacing throughout
8. **Borders:** Teal accent color for card borders, adapts to dark mode

---

## Notes

- All measurements are in points (pt), iOS's standard unit
- Colors are defined in RGB (0.0-1.0 range) and converted to hex where applicable
- SF Symbols are used for icons, with emojis for specific actions (meal tracker, search)
- The design system supports both light and dark modes with appropriate adjustments
- Score-based colors create an intuitive visual language (red = poor, green = excellent)
- Gradients are used strategically for primary actions and visual interest

---

**End of Design System Documentation**

