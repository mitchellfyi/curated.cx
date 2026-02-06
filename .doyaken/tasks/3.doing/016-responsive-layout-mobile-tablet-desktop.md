# Task: Responsive UI/Layout for Mobile, Tablet & Desktop

## Metadata

| Field       | Value                                                  |
| ----------- | ------------------------------------------------------ |
| ID          | `016-responsive-layout-mobile-tablet-desktop`          |
| Status      | `todo`                                                 |
| Priority    | `002` High                                             |
| Created     | `2026-02-06 12:00`                                     |
| Started     |                                                        |
| Completed   |                                                        |
| Blocked By  |                                                        |
| Blocks      |                                                        |
| Assigned To |                                                        |
| Assigned At |                                                        |

---

## Context

The app uses Tailwind CSS v4.4 with a mobile-first approach (`md:` breakpoints). Viewport meta tag is set. The navigation has separate mobile/desktop menus with a Stimulus-controlled mobile toggle. However, the overall layout needs a comprehensive pass to ensure both the public-facing content browsing experience and the admin management interface work well across all device sizes.

Key areas:
- Public content browsing (items, listings, notes) should be optimized for scrolling/discovery on mobile
- Admin interface should be usable on tablets and phones (collapsible sidebar, responsive tables)
- Current admin uses `grid-cols-1 md:grid-cols-5` for stats cards but tables and forms may not be fully responsive

---

## Acceptance Criteria

### Public Content Browsing
- [ ] Content item cards are touch-friendly and well-spaced on mobile
- [ ] Content list/feed scrolls smoothly with good information density
- [ ] Listing cards display properly at all breakpoints (1 col mobile, 2 col tablet, 3-4 col desktop)
- [ ] Notes display cleanly on mobile with proper text wrapping
- [ ] Images are responsive and don't overflow containers
- [ ] Navigation is easy to use on mobile (hamburger menu, clear touch targets)
- [ ] Search is accessible and usable on mobile
- [ ] Pagination/infinite scroll works on touch devices
- [ ] Content detail pages are readable on mobile (proper typography, spacing)

### Admin Interface
- [ ] Admin sidebar collapses to hamburger/drawer on mobile and tablet
- [ ] Admin sidebar is dismissible on tablet (slide-in overlay)
- [ ] Stats cards stack properly (1 col mobile, 2 col tablet, full row desktop)
- [ ] Data tables are horizontally scrollable on mobile (not cut off)
- [ ] Admin forms are single-column on mobile, multi-column on desktop where appropriate
- [ ] Action buttons (publish, approve, etc.) are accessible and touch-friendly
- [ ] Modal/dialog components work on mobile
- [ ] Dropdown menus don't overflow viewport on mobile
- [ ] Admin dashboard cards are scannable on mobile

### Cross-Cutting
- [ ] Typography scales appropriately (body, headings, labels)
- [ ] Touch targets are minimum 44x44px on mobile
- [ ] No horizontal scroll on any page at any breakpoint
- [ ] Proper spacing/padding at all breakpoints
- [ ] Loading states work on all screen sizes
- [ ] Flash messages/alerts are visible and dismissible on mobile

### Testing
- [ ] Manual testing at key breakpoints: 375px (phone), 768px (tablet), 1024px (laptop), 1440px (desktop)
- [ ] Test with actual mobile browser (Safari iOS, Chrome Android) or browser DevTools
- [ ] Quality gates pass
- [ ] Changes committed with task reference

---

## Notes

- Reference: `app/views/layouts/application.html.erb` for main layout structure
- Reference: `app/views/shared/_navigation.html.erb` for nav (desktop: `hidden md:flex`, mobile: `md:hidden`)
- Reference: `app/views/admin/shared/_sidebar.html.erb` for admin nav
- Reference: `tailwind.config.js` for current Tailwind config
- Tailwind breakpoints: `sm` 640px, `md` 768px, `lg` 1024px, `xl` 1280px, `2xl` 1536px
- Consider Stimulus controllers for admin sidebar toggle on mobile
- Prioritize the content browsing experience - that's what end users see most
