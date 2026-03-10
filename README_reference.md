# MAAT's Kiosk Application

> **Time-box**: Maximum 5 days of work
> **AI tools**: Encouraged

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Technical Specifications](#technical-specifications)
- [Design Guidelines](#design-guidelines)
- [Evaluation Criteria](#evaluation-criteria)
- [Deliverables](#deliverables)

## Overview

Build a **Gym Kiosk application** that allows gym members to check in for today's classes. This project tests your ability to:

- Translate design references into functional UI
- Build intuitive user flows
- Write clean, maintainable code
- Make sensible product decisions within time constraints

You will receive a **Figma file featuring the initial screen**. This is **not a complete design system**, but a reference for visual style, spacing, tone, and overall approach. Your task is to follow this visual language and creatively extend it to additional screens.

## Requirements

### 1. Visual Design

**Reference**: Use the provided Figma file as your style guide

The Figma includes:
- Typography examples
- Button styles
- Layout conventions
- Overall aesthetic direction

**Resources**:
- [MAAT's Kiosk Concept File](https://www.figma.com/design/yZiTpnsOb9E8v0lUHRHNB9/MAAT-Kiosk-Concept?node-id=0-1&m=dev)
- [Geist Font](https://github.com/vercel/geist-font/)

**Your task**:
- Recreate the initial screen faithfully
- Extend the design language to additional screens
- Maintain visual consistency across all UI elements

**Note**: Pixel-perfection is not expected, but **design coherence** is required.

### 2. Core User Flow

Implement the following screens and functionality:

#### **A. Home / Entry Screen**
Based on the Figma style:
- [ ] Display welcome state
- [ ] Show today's classes
- [ ] Provide navigation to class details

#### **B. Class Screen**
Internal overview of the selected class:
- [ ] Display basic class information (name, time, instructor, etc.)
- [ ] Show list of attendees with:
  - Display name
  - Profile picture
  - Status (e.g., confirmed, registered)
  - Registration time (optional)
- [ ] Provide ability to add new check-ins

#### **C. Member Search**
- [ ] Implement search by name (simple client-side filter is sufficient)
- [ ] Display scrollable list of members
- [ ] Show "no results" state when search yields no matches

#### **D. Member Check-In**
After selecting a member:
- [ ] Display member's name
- [ ] Show today's date
- [ ] Present clear call-to-action: **"Check In"** button
- [ ] Handle check-in action

#### **E. Success State**
After successful check-in:
- [ ] Show confirmation screen
- [ ] Auto-reset to home screen after 2–3 seconds
- [ ] Ensure kiosk returns to "ready" state

### 3. Data Layer

Choose the approach that best fits your strengths:

#### **Option A: Local JSON** (Recommended for simplicity)

Create a `members.json` file with structure:

```json
[
  {
    "id": "123",
    "firstName": "Anna",
    "lastName": "Rossi",
    "profilePicture": "https://..."
  },
  {
    "id": "124",
    "firstName": "Marco",
    "lastName": "Lopez",
    "profilePicture": "https://..."
  }
]
```

**Implementation**:
- Load JSON at app startup
- Store check-ins in memory or local storage
- Create similar JSON structure for classes/sessions

#### **Option B: Minimal API** (Optional, if you enjoy backend)

Expose basic endpoints:
- `GET /members` - List all members
- `GET /classes` - List today's classes
- `POST /checkins` - Record a check-in

Any stack is acceptable (Firebase, Supabase, Nest, Go, Rails, etc.)

### 4. Optional Enhancements

This project intentionally leaves room for creativity. Consider adding:

- Smooth animations or transitions
- Kiosk lock mode (prevent access to device functions)
- QR code-based check-in
- Offline-first mode with sync
- Any feature that demonstrates your product thinking

**Remember**: Quality over quantity. A few well-executed features are better than many half-finished ones.

## Technical Specifications

### Platform Choice

Choose any mobile technology:
- **Cross-platform**: Flutter, React Native, Kotlin Multiplatform
- **Native**: SwiftUI (iOS), Jetpack Compose (Android)

### Architecture Recommendations

Consider implementing:
- Clear separation of concerns (UI, business logic, data)
- State management appropriate to your chosen stack
- Reusable components
- Proper error handling

## Design Guidelines

### Key Principles

1. **Kiosk-First UX**
   - Large, tappable targets
   - Clear visual hierarchy
   - Minimal text input requirements
   - Auto-reset flows

2. **Consistency**
   - Follow Figma's visual language
   - Maintain consistent spacing
   - Use the same color palette
   - Keep typography hierarchy

3. **States to Consider**
   - Loading states
   - Empty states (no classes, no members)
   - Error states (failed check-in)
   - Success states

## Evaluation Criteria

Your submission will be evaluated on:

### 🎨 Design (25%)
- Faithfulness to Figma's visual style
- Coherent extension of UI patterns to new screens
- Readable, friendly kiosk interface
- Thoughtful UX decisions

### 💻 Code Quality (25%)
- Clear architecture and project structure
- Separation of concerns
- Thoughtful state management
- Readable and well-organized code
- Appropriate use of platform/framework patterns

### 🎯 User Experience (25%)
- Smooth, intuitive flows
- Clear error and empty states
- Attention to edge cases

### 🧠 Ownership & Trade-offs (25%)
- Clear reasoning for technical choices
- Sensible scope management
- Documentation of trade-offs and decisions
- Awareness of what could be improved with more time

### ⭐ Bonus Points
- Smooth animations and transitions
- Offline-first approach
- Integration tests
- Creative features that enhance the experience

## Deliverables

Please submit:

1. **Repository Link**
   - Public GitHub repo

2. **Running Instructions**
   - Clear setup steps
   - Required dependencies
   - How to run the app

3. **README** (optional)
   - Brief architecture overview
   - Key design decisions
   - Trade-offs you made
   - What you would add/improve with more time
   - Known limitations or bugs

### README Template for Your Submission

```markdown
# Gym Kiosk - [Your Name]

## Architecture

[Brief overview of your architectural choices]

## Tech Stack

- Platform: [Flutter/React Native/etc.]
- State Management: [Your choice]
- Additional libraries: [List key dependencies]

## Design Decisions

[Key decisions you made and why]

## Trade-offs

[What you prioritized and what you deprioritized]

## Future Improvements

[What you would add with more time]

## Running the App

[Step-by-step instructions]
```

## Questions?

If you have questions about requirements or need clarification, please reach out. We want you to succeed!

Good luck and have fun building! 🚀
