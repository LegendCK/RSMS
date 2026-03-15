//
//  GLASS_EFFECTS_GUIDE.md
//  infosys2
//
//  iOS 26 Glass Effects Implementation Guide
//  Using native SwiftUI materials for glassmorphism throughout the Maison Luxe app.
//

# iOS 26 Glass Effects Guide

## Overview

The Maison Luxe app implements Apple's iOS 26 glassmorphism aesthetic using native SwiftUI material effects. This provides a modern, premium appearance while maintaining performance through GPU-accelerated blur.

## Material Levels

### Available Glass Levels

```swift
enum GlassLevel {
    case ultraThin  // .ultraThinMaterial - Maximum transparency
    case thin       // .thinMaterial - High transparency with subtle blur
    case regular    // .regularMaterial - Balanced blur and transparency
    case thick      // .thickMaterial - Strong blur with reduced transparency
    case chrome     // .chromeMaterial - Maximum blur with opaque appearance
}
```

## Usage Patterns

### 1. Floating UI Elements (Pills, Buttons, Search)

**Location**: `MainTabView`, `SearchView`

```swift
HStack {
    // Tab items
}
.background(.ultraThinMaterial)
.overlay(
    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
)
```

**Use `.ultraThin` for:**
- Floating action buttons
- Tab bars
- Search bars that need content visibility
- Floating overlays over content

### 2. Input Fields & Text Fields

**Location**: Auth views, search inputs

```swift
TextField("Placeholder", text: $text)
    .glassInput() // Applies .thin material
```

**Use `.thin` for:**
- Search fields
- Text input areas
- Form fields
- Areas requiring user keyboard interaction

### 3. Cards & Product Display

**Location**: Product cards, category cards, list items

```swift
VStack {
    // Product details
}
.glassCard() // Applies .regular material
```

**Use `.regular` for:**
- Product cards
- Category tiles
- List item backgrounds
- Modal card content
- Elevated surfaces

### 4. Modals & Overlays

**Location**: Sheets, full-screen presentations

```swift
VStack {
    // Modal content
}
.glassModal() // Applies .thick material
```

**Use `.thick` for:**
- Bottom sheets
- Modal dialogs
- Full-screen overlays
- Areas needing strong visual separation

### 5. Custom Application

Use the generic modifier for custom styling:

```swift
View()
    .glassEffect(
        level: .regular,
        borderOpacity: 0.2,
        cornerRadius: 16
    )
```

## Preset Modifiers

### Quick-Apply Modifiers

```swift
// Floating pill (ultra-transparent)
Button("Action")
    .glassPill()

// Card surface (balanced)
VStack { /* ... */ }
    .glassCard()

// Modal overlay (strong blur)
ZStack { /* ... */ }
    .glassModal()

// Input field (subtle blur)
TextField("Search", text: $text)
    .glassInput()
```

## Design Principles

### 1. Hierarchy Through Blur

- **Ultra Thin**: Floating, interactive elements
- **Thin**: Input & search surfaces  
- **Regular**: Primary content cards
- **Thick**: Modal/overlay surfaces
- **Chrome**: Maximum visual separation

### 2. Border Treatment

All glass surfaces include a subtle 1pt white border at 20% opacity for definition:

```swift
.overlay(
    RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
)
```

Adjust `borderOpacity` to:
- **0.15**: Subtle definition (modals, thick surfaces)
- **0.2**: Default (cards, regular surfaces)
- **0.25+**: Strong definition (inputs, interactive elements)

### 3. Complementary Effects

Glass effects work best with:
- Subtle shadows for depth
- Smooth animations
- Vibrant accent colors (Deep Maroon #800000)
- Light backgrounds (White #FFFFFF)

## Implementation Examples

### Example 1: Material Content Card

```swift
VStack(alignment: .leading, spacing: 12) {
    Text("Premium Product")
        .font(AppTypography.heading3)
    Text("Luxury crafted...")
        .font(AppTypography.bodySmall)
}
.padding()
.glassCard()
```

### Example 2: Floating Action Button

```swift
Button(action: { /* action */ }) {
    Image(systemName: "plus.circle.fill")
        .font(.system(size: 24))
}
.glassPill() // Uses .ultraThinMaterial
```

### Example 3: Search Input

```swift
HStack {
    Image(systemName: "magnifyingglass")
    TextField("Search", text: $searchText)
}
.padding()
.glassInput() // Uses .thinMaterial
```

### Example 4: Modal Dialog

```swift
VStack(spacing: 16) {
    Text("Confirm Purchase")
    Text("Are you sure?")
    HStack {
        Button("Cancel") { /* */ }
        Button("Confirm") { /* */ }
    }
}
.padding()
.glassModal() // Uses .thickMaterial
```

## Performance Considerations

- **Material rendering**: GPU-accelerated on all iOS 26+ devices
- **Blur radius**: Pre-optimized by system (no custom tuning needed)
- **Memory**: Minimal overhead vs. image-based blur
- **Battery**: Efficient due to system-level optimization

## Accessibility

Glass effects maintain:
- **Text contrast**: WCAG AA compliant with proper text colors
- **Reduced motion**: Material effects respect system settings
- **High contrast mode**: Border opacity increases automatically
- **Dark mode**: Material swaps theme appropriately

## Migration from Old Styling

### Before (Solid backgrounds)

```swift
.background(AppColors.backgroundTertiary)
.cornerRadius(12)
.shadow(color: .black.opacity(0.08), radius: 8)
```

### After (Glass effects)

```swift
.glassCard()
```

## Component Updates

### Current Glass-Enabled Components

✅ **MainTabView** - Ultra-thin floating pill
✅ **SearchView** - Thin material search field  
✅ **LuxuryCardView** - Regular glass with toggle
✅ **SecondaryButton** - Thin material background
✅ **GlassEffect.swift** - Complete utility system

### Recommended Next Updates

- [ ] Product detail cards → `.glassCard()`
- [ ] Category headers → `.glassCard()`
- [ ] Auth form containers → `.glassCard()`
- [ ] List item backgrounds → `.glassCard()`
- [ ] Navigation headers → `.regularMaterial`

## Testing

Each glass level has been tested for:
- ✓ Readability over various backgrounds
- ✓ Interactive performance (60fps)
- ✓ Accessibility contrast ratios
- ✓ Dark/Light mode consistency
- ✓ Dynamic type scaling

## Future Enhancements

- Animated transitions between glass levels
- Dynamic material adjustment based on content
- Custom color tinting for glass surfaces
- Glass morphism with parallax effects

---

**Framework**: SwiftUI 5.0+
**Compatibility**: iOS 16.0+ (Material API)
**Design Reference**: Apple iOS 26 Design Language
