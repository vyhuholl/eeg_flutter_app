# EEG Flutter App - Style Guide

## Overview
This style guide defines the visual design system for the EEG Flutter application, ensuring consistency across all screens and components. The design emphasizes medical-grade professionalism with high contrast for clinical environments.

## Color Palette

### Primary Colors
- **Primary Blue**: `#0A84FF` (RGB: 10, 132, 255)
  - Used for: Primary actions, enabled buttons, active states
  - Accessibility: AAA contrast on black background
- **Black Background**: `Colors.black` (#000000)
  - Used for: Primary background, medical-grade appearance
- **White Text**: `Colors.white` (#FFFFFF)
  - Used for: Primary text on dark backgrounds

### Status Colors
- **Success Green**: `#34C759` (RGB: 52, 199, 89)
  - Used for: Success states, valid connections, checkmarks
- **Error Red**: `#FF3B30` (RGB: 255, 59, 48)
  - Used for: Error states, invalid connections, alerts
- **Warning Orange**: `#FF9500` (RGB: 255, 149, 0)
  - Used for: Warning states, intermediate conditions
- **Disabled Grey**: `#8E8E93` (RGB: 142, 142, 147)
  - Used for: Disabled buttons, inactive states

### Neutral Colors
- **Light Grey**: `#F2F2F7` (RGB: 242, 242, 247)
  - Used for: Secondary text on light backgrounds
- **Medium Grey**: `#C7C7CC` (RGB: 199, 199, 204)
  - Used for: Borders, dividers
- **Dark Grey**: `#48484A` (RGB: 72, 72, 74)
  - Used for: Secondary backgrounds

## Typography

### Font Families
- **Primary**: System default (San Francisco on iOS, Roboto on Android)
- **Fallback**: Inter, Helvetica Neue, Arial, sans-serif

### Font Sizes & Weights
- **Heading Large**: 24px, FontWeight.w600
  - Used for: Screen titles, primary headings
- **Heading Medium**: 20px, FontWeight.w500
  - Used for: Section headers, secondary headings
- **Body Large**: 16px, FontWeight.w400
  - Used for: Primary body text, instructions
- **Body Medium**: 14px, FontWeight.w400
  - Used for: Secondary text, descriptions
- **Caption**: 12px, FontWeight.w400
  - Used for: Labels, small descriptive text

### Text Styling
- **Line Height**: 1.5x font size for body text
- **Letter Spacing**: 0px (default)
- **Text Alignment**: Center for primary content, left for secondary content

## Spacing System

### Base Unit: 8px
All spacing should be multiples of 8px for consistency.

### Standard Spacing Scale
- **xs**: 4px (0.5 * base)
- **sm**: 8px (1 * base)
- **md**: 16px (2 * base)
- **lg**: 24px (3 * base)
- **xl**: 32px (4 * base)
- **2xl**: 40px (5 * base)
- **3xl**: 48px (6 * base)

### Component Spacing
- **Button Padding**: 32px horizontal, 16px vertical
- **Screen Padding**: 20px horizontal margins
- **Content Spacing**: 30-40px between major sections
- **Text Spacing**: 8px between related text elements

## Component Styles

### Buttons

#### Primary Button (Enabled)
```dart
ElevatedButton.styleFrom(
  backgroundColor: Color(0xFF0A84FF),
  foregroundColor: Colors.white,
  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
)
```

#### Primary Button (Disabled)
```dart
ElevatedButton.styleFrom(
  backgroundColor: Color(0xFF8E8E93),
  foregroundColor: Colors.white,
  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
)
```

#### Button Text Style
- Font Size: 16px
- Font Weight: FontWeight.w500
- Color: White

### Icons

#### Standard Icon Sizes
- **Large Icons**: 120x120px (main action icons)
- **Medium Icons**: 64x64px (status indicators)
- **Small Icons**: 24x24px (inline icons)
- **Micro Icons**: 16x16px (decorative icons)

#### Icon Colors
- **Primary**: White (#FFFFFF)
- **Success**: Success Green (#34C759)
- **Error**: Error Red (#FF3B30)
- **Warning**: Warning Orange (#FF9500)

### Cards & Containers

#### Standard Card
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFF48484A),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ],
  ),
  padding: EdgeInsets.all(24),
)
```

### Status Indicators

#### Success Indicator
- **Icon**: Checkmark (✓)
- **Color**: Success Green (#34C759)
- **Size**: 64x64px
- **Animation**: Scale in with ease-out timing

#### Error Indicator
- **Icon**: Cross (✗)
- **Color**: Error Red (#FF3B30)
- **Size**: 64x64px
- **Animation**: Shake animation for attention

#### Loading Indicator
- **Type**: CircularProgressIndicator
- **Color**: Primary Blue (#0A84FF)
- **Size**: 32x32px (standard), 16x16px (inline)

## Layout Guidelines

### Screen Structure
```
┌─────────────────────────────────────┐
│  StatusBar (System)                 │
├─────────────────────────────────────┤
│  AppBar (if needed)                 │
├─────────────────────────────────────┤
│                                     │
│  Main Content Area                  │
│  - Centered vertically             │
│  - 20px horizontal margins          │
│  - Proper spacing between elements  │
│                                     │
├─────────────────────────────────────┤
│  Bottom Actions (if needed)         │
└─────────────────────────────────────┘
```

### Content Hierarchy
1. **Primary Action Area**: Central focus with large icons/indicators
2. **Status Text**: Clear messaging about current state
3. **Secondary Actions**: Continue/navigation buttons
4. **Help Text**: Additional guidance when needed

## Animation Guidelines

### Timing Functions
- **Standard**: `Curves.easeInOut` (300ms)
- **Quick**: `Curves.easeOut` (200ms)
- **Attention**: `Curves.elasticOut` (500ms)

### Common Animations
- **Button Press**: Scale down to 0.95, then back to 1.0
- **Status Change**: Fade out old state, fade in new state
- **Loading**: Continuous rotation or pulsing
- **Success**: Scale in with bounce effect
- **Error**: Horizontal shake (3-4 cycles)

## Accessibility Guidelines

### Color Contrast
- **Primary Text on Black**: AAA (21:1 ratio)
- **Blue on Black**: AAA (4.5:1 ratio)
- **Status Colors on Black**: AA minimum (3:1 ratio)

### Touch Targets
- **Minimum Size**: 44x44px for all interactive elements
- **Recommended**: 48x48px for primary actions
- **Spacing**: Minimum 8px between adjacent touch targets

### Text Sizing
- **Minimum**: 14px for body text
- **Recommended**: 16px for primary content
- **Headers**: 20px+ for clear hierarchy

## Usage Examples

### Validation Screen Status Messages

#### Success State
```dart
Column(
  children: [
    Icon(
      Icons.check_circle,
      size: 64,
      color: Color(0xFF34C759),
    ),
    SizedBox(height: 16),
    Text(
      'Электроды подключены корректно',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    ),
  ],
)
```

#### Error State
```dart
Column(
  children: [
    Icon(
      Icons.cancel,
      size: 64,
      color: Color(0xFFFF3B30),
    ),
    SizedBox(height: 16),
    Text(
      'Проблемы с контактом электродов...',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    ),
  ],
)
```

## Responsive Design

### Breakpoints
- **Mobile**: < 768px width
- **Tablet**: 768px - 1024px width
- **Desktop**: > 1024px width

### Scaling Guidelines
- **Mobile**: Standard sizing as defined
- **Tablet**: 1.2x scaling for touch targets and text
- **Desktop**: 1.4x scaling with max-width constraints

## Medical Device Considerations

### Visual Hierarchy
- **Critical Information**: High contrast, large text, central placement
- **Status Indicators**: Immediately recognizable, consistent positioning
- **Error Messages**: Clear, actionable, non-technical language
- **Progress Feedback**: Continuous, non-distracting, informative

### Professional Appearance
- **Clean Layout**: Minimal distractions, focused content
- **High Contrast**: Optimal visibility in various lighting conditions
- **Consistent Branding**: Medical-grade appearance throughout
- **Reliable Feedback**: Clear success/failure states

---

## Implementation Notes

### Flutter Integration
- Use `Theme.of(context)` for accessing defined colors
- Implement custom `TextTheme` for consistent typography
- Create reusable widgets for common patterns
- Use `MediaQuery` for responsive design adaptations

### Maintenance
- Update this guide when introducing new UI patterns
- Validate all changes against accessibility guidelines
- Test color combinations for sufficient contrast
- Review with users for usability feedback

---

**Version**: 1.0  
**Last Updated**: Current Session  
**Next Review**: After validation screen implementation 