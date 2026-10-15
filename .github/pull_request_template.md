Closes #

## What changed

## Screenshots
| Frame | iPhone 16 | iPad Pro 11" |
|---|---|---|
|  |  |  |

Notes (anywhere the frame was followed over the PRD):

## Checklist
- [ ] Code sits in the right feature folder; no cross-feature imports.
- [ ] View has no business logic; view model has no `SwiftUI` import; repository returns domain types.
- [ ] Stock changes only through MS-106 RPCs with an idempotency key.
- [ ] Only design-system tokens and components in feature code.
- [ ] Appendix B ids on every interactive element.
- [ ] Unit tests for the view model and domain rules; UI test updated when a flow changed; SQL tests for database changes.
- [ ] Builds clean with zero warnings in Swift 6 mode; SwiftLint clean.
- [ ] Nothing in the skill's "do not" list (section 5) was introduced.
