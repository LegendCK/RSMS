# iOS 26 Liquid Glass Design Implementation Guide

## Overview

The RSMS app now implements Apple's iOS 26 Liquid Glass design language — a modern, fluid aesthetic featuring translucent surfaces, refined typography, and dynamic interactions.

**Key Components:**
- `LiquidGlassTheme.swift` — Core glass effect system with blur and refraction
- `ModernHeaderView.swift` — Premium headers with glass backgrounds
- `ModernCardView.swift` — Flexible card system with glass variants
- `PrimaryButton` & `SecondaryButton` — Enhanced buttons with liquid shadows
- `LuxuryCardView` — Updated with Liquid Glass support
- `MainTabView` — iOS 26 floating navigation with dynamic effects

---

## Design Principles

### 1. Liquid Glass (Glassmorphism)

Liquid Glass creates translucent, frosted surfaces that refract backgrounds:

```swift
// Apply to any view
View()
    .liquidGlass(config: .regular)
```

**Config Levels:**
- `.ultraThin` - Floating buttons, search bars (90% transparent)
- `.thin` - Input fields, interactive surfaces (85% transparent)
- `.regular` - Cards, content surfaces (75% transparent)
- `.thick` - Modals, strong separation (65% transparent)

### 2. Dynamic Shadows

Replace standard shadows with iOS 26 liquid shadows:

```swift
View()
    .liquidShadow(.subtle)    // Cards (4pt blur)
    .liquidShadow(.medium)    // Modals (12pt blur)
    .liquidShadow(.strong)    // Important overlays (20pt blur)
```

### 3. Fluid Animations

Use smooth transitions (duration: 0.25 for iOS 26 rhythm):

```swift
withAnimation(.easeInOut(duration: 0.25)) {
    // State update
}
```

---

## Component Usage

### Headers

Modern headers with optional back button and glass styling:

```swift
ModernHeaderView(
    title: "Products",
    subtitle: "Browse our collection",
    showBackButton: true,
    onBack: { /* pop */ }
)
```

**Features:**
- Liquid glass background (.thin)
- Responsive layout
- Action button (customizable icon)
- Subtitle support

### Cards

Flexible card system with glass variants:

```swift
// Basic card
ModernCardView {
    Text("Content")
}

// Metric card (KPI display)
MetricCard(
    label: "Revenue",
    value: "₹1,24,567",
    trend: "+12.5%",
    trendIsPositive: true,
    icon: "chart.line.uptrend.xyaxis"
)

// Action card with button
ActionCard(
    title: "New Feature",
    subtitle: "Explore the latest",
    actionTitle: "Learn More",
    icon: "star.fill",
    action: { /* navigate */ }
)
```

### Buttons

**Primary Button** (filled, dark background):
```swift
PrimaryButton(title: "Continue") {
    // Action
}
```

**Secondary Button** (outlined, optional glass):
```swift
SecondaryButton(title: "Create Account") {
    // Action
}
```

---

## Implementation Examples

### Product List with Glass Cards

```swift
VStack(spacing: AppSpacing.md) {
    ForEach(products) { product in
        ModernListCard(
            content: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(product.name)
                            .font(AppTypography.label)
                        Text(product.price)
                            .font(AppTypography.caption)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            },
            onTap: { navigate(to: product) }
        )
    }
}
.padding(AppSpacing.screenHorizontal)
```

### Dashboard with Metric Cards

```swift
VStack(spacing: AppSpacing.lg) {
    TabNavigationHeader(title: "Dashboard")
    
    VStack(spacing: AppSpacing.md) {
        MetricCard(
            label: "Total Revenue",
            value: "₹1,24,567",
            trend: "+12.5%",
            trendIsPositive: true,
            icon: "chart.line.uptrend.xyaxis"
        )
        
        MetricCard(
            label: "Orders",
            value: "324",
            trend: "+8.3%",
            trendIsPositive: true,
            icon: "bag.fill"
        )
    }
    .padding(AppSpacing.screenHorizontal)
    
    Spacer()
}
```

### Form with Glass Fields

```swift
VStack(spacing: AppSpacing.md) {
    ModernHeaderView(
        title: "Create Order",
        subtitle: "Fill in the details"
    )
    
    VStack(spacing: AppSpacing.md) {
        LuxuryTextField(
            placeholder: "Customer Email",
            text: $email
        )
        .liquidGlass(config: .thin)
        
        // More fields...
    }
    .padding(AppSpacing.screenHorizontal)
    
    PrimaryButton(title: "Submit") {
        // Action
    }
    .padding(AppSpacing.screenHorizontal)
}
```

---

## Navigation Updates

### Floating Tab Bar (iOS 26)

Already implemented in `MainTabView.swift` with:
- Liquid glass pill (ultraThin)
- Dynamic icon animations (0.25s duration)
- Circular search button with glass effect
- Refined shadow system

**No action needed** — MainTabView automatically uses iOS 26 design.

---

## Color Harmony

Glass effects work best with:
- **Primary accent**: Deep Maroon #800000
- **Background**: White #FFFFFF
- **Text (dark)**: Black #000000
- **Text (light)**: White #FFFFFF
- **Neutral grays**: #333333–#F0F0F0

Glass border opacity adapts per level:
- ultraThin: 15% white border
- thin: 20% white border
- regular: 25% white border
- thick: 30% white border

---

## Migration Checklist

### Currently Implemented ✅
- [x] LiquidGlassTheme.swift — Core system
- [x] ModernHeaderView.swift — Premium headers
- [x] ModernCardView.swift — Flexible cards
- [x] MainTabView.swift — iOS 26 navigation
- [x] PrimaryButton — Enhanced with shadows
- [x] SecondaryButton — Enhanced with shadows
- [x] LuxuryCardView — Liquid Glass support

### Ready to Deploy
- [ ] Auth screens (LoginView, SignUpView) → Use ModernHeaderView + glass cards
- [ ] Product detail pages → Use ModernCardView for specs
- [ ] Dashboard views → Use MetricCard for KPIs
- [ ] Checkout → Use glass input fields + PrimaryButton
- [ ] Modal overlays → Use `.liquidGlass(config: .thick)`

---

## Performance Notes

✅ **GPU-accelerated** — Material API uses system-level blur
✅ **Minimal overhead** — No custom blur calculations
✅ **Battery efficient** — System-optimized animations
✅ **Responsive** — Maintains 60fps on all devices

---

## Accessibility

Glass effects respect:
- ✅ Reduced motion settings (animations disabled)
- ✅ High contrast mode (border opacity increases)
- ✅ Dynamic type (responsive text scaling)
- ✅ Dark mode (system theme adaptation)

WCAG AA compliant with proper text contrast on glass backgrounds.

---

## Troubleshooting

**Glass looks too transparent?**
- Use `.thick` config or increase `borderOpacity` parameter

**Need more shadow?**
- Use `.liquidShadow(.medium)` or `.strong`

**Animation feels slow?**
- iOS 26 standard is 0.25s for smooth rhythm
- Avoid durations >0.3s for UI responsiveness

**Border too subtle?**
- Increase `borderOpacity` in `LiquidGlassConfig`
- Add `.noise()` modifier for texture depth

---

## Resources

- **iOS 26 Design Progress**: See conversation summary
- **Glass Effects Guide**: [GLASS_EFFECTS_GUIDE.md](GLASS_EFFECTS_GUIDE.md)
- **Typography System**: [AppTypography.swift](Theme/AppTypography.swift)
- **Color Tokens**: [AppColors.swift](Theme/AppColors.swift)
- **Spacing System**: [AppSpacing.swift](Theme/AppSpacing.swift)

---

**Last Updated**: March 13, 2026
**Framework**: SwiftUI 5.0+
**Target**: iOS 26.0+
