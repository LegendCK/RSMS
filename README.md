# Retail Store Management System (RSMS)

RSMS is a premium iOS application crafted for luxury boutiques. It delivers an end-to-end platform enabling an exceptional digital shopping experience for customers and robust, real-time management tools for in-store staff, boutique managers, and corporate admins.

## Core Features

### 🛍️ Customer Experience
- **Luxury Shopping Flow**: Liquid Glass aesthetics tailored for a modern, sleek browsing experience. Complete with dynamic promotions, deep category filters (Women, Men, Kids, Lifestyle), and real-time stock sync.
- **Omnichannel Delivery**: Support for Standard Delivery, Ship-from-Boutique, and Buy Online Pick-up In Store (BOPIS).
- **Checkout & Payments**: Frictionless payment integration supporting Apple Pay, major Credit Cards, and Pay-In-Store.

### 👥 Sales Associates & POS
- **Clienteling**: Instantly access comprehensive customer purchase histories, preferences, and profiles.
- **Mobile Point of Sale (POS)**: Place and process walk-in orders on behalf of clients directly via the app, updating remote inventory instantly.
- **Stock Tracking**: Search and locate physical inventory counts across all regional boutiques in real-time.

### 📊 Management & Corporate Dashboards
- **Role-based Analytics**: Dedicated, secure views for Boutique Managers and Corporate Admins tracking live sales, unit metrics, and campaign ROI.
- **Store & Staff Org**: Manage staff invitations, edit boutique operating details, and assign location-specific pricing policies.
- **Compliance & Reporting**: Generate and export rich, formatted PDF/CSV reports covering retail events, tax compliance, and multi-currency transactions.

## Architecture & Tech Stack

- **Frontend Platform**: Native iOS (Swift, SwiftUI 5+), designed universally for iPhone and iPad interactions.
- **Local Persistence**: `SwiftData` provides snappy offline-first caching, ensuring the POS layer works flawlessly under unstable network conditions.
- **Backend & Authentication**: Built on [Supabase](https://supabase.com/), utilizing PostgreSQL for the database layer and Secure Auth for user identity.
- **Edge Architecture**: Deno-based Supabase Edge Functions manage sensitive workloads such as securely bypassing Row Level Security (RLS) for final order processing.

## Getting Started

### Prerequisites
- Xcode 15.0+ and iOS 17.0+ Simulator/Device.
- A configured Supabase project with Database, Auth, and deployed Edge Functions.

### Installation & Setup
1. Clone the repository and open `RSMS.xcodeproj` in Xcode.
2. Provide your backend environment variables in `SupabaseConfig.swift`:
   ```swift
   static let projectURL = URL(string: "YOUR_SUPABASE_URL")!
   static let anonKey = "YOUR_SUPABASE_ANON_KEY"
   ```
3. Build and launch the target scheme.

---
*Elevating the standard of omnichannel retail management.*
