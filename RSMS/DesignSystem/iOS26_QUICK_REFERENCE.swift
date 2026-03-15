/*
 QUICK REFERENCE: iOS 26 Liquid Glass in 30 Seconds

 1. BASIC GLASS EFFECT
    View()
        .liquidGlass(config: .regular)

 2. WITH SHADOW
    View()
        .liquidGlass(config: .regular)
        .liquidShadow(LiquidShadow.subtle)

 3. MODERN CARD
    ModernCardView {
        Text("Content")
    }

 4. METRIC CARD (KPI)
    MetricCard(
        label: "Revenue",
        value: "₹1,24,567",
        trend: "+12.5%",
        trendIsPositive: true,
        icon: "chart.line.uptrend.xyaxis"
    )

 5. MODERN HEADER
    ModernHeaderView(
        title: "Welcome",
        subtitle: "March 13, 2026"
    )

 6. PRIMARY BUTTON (iOS 26)
    PrimaryButton(title: "Continue") {
        // Action
    }

 7. SECONDARY BUTTON (with glass)
    SecondaryButton(title: "Learn More") {
        // Action
    }

 8. FLOATING THINGS (Ultra-thin glass)
    View()
        .liquidGlass(config: .ultraThin)
        // Used in: MainTabView, search buttons

 9. INPUTS (Thin glass)
    View()
        .liquidGlass(config: .thin)
        // Used in: Text fields, search inputs

 10. CARDS (Regular glass)
    View()
        .liquidGlass(config: .regular)
        // Used in: Product cards, list items, metric cards

 11. MODALS (Thick glass)
    View()
        .liquidGlass(config: .thick)
        // Used in: Dialogs, bottom sheets, overlays

 SHADOW SYSTEM
    .liquidShadow(LiquidShadow.subtle)   // Cards (4pt blur, light)
    .liquidShadow(LiquidShadow.medium)   // Modals (12pt blur, medium)
    .liquidShadow(LiquidShadow.strong)   // Important (20pt blur, heavy)

 ANIMATION TIMING (iOS 26 Standard)
    withAnimation(.easeInOut(duration: 0.25)) {
        // State update — smooth & responsive
    }

 COLOR COMBINATION
    Every glass surface works with:
    - Background: White #FFFFFF
    - Text: Black #000000
    - Accent: Deep Maroon #800000
    - Borders: White @ 15-30% opacity (built-in)
 */
