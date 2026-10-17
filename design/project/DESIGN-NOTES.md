# Dentory project notes
- Roles: Admin and Staff only (Inventory Manager merged into Admin). Deviations from PRD v1.0 to carry into the next PRD:
  - Staff CAN adjust quantities (Adjust on product detail and Count stock), not only perform counts.
  - Staff CAN add expiry and edit batches (date, lot, qty).
  - Staff cannot: receive deliveries, mark disposed, mark ordered / receive from To buy, edit or delete products, edit procedure templates, clinic settings, billing, export, invite.
  - No Prepared state for procedures: Start deducts immediately; history entries can be edited or cancelled with a reason.
  - Multi-use products (bottles, syringes, kits) are tracked as unopened + open bottles (who, when), no level estimates. Procedure screen section "Opened a new one?" with Take new.
  - No Quick count feature; counting lives in Inventory (Count stock).
  - To buy is a shopping list, not ordering. 3-month trial, $99/clinic/month after, 50% lifetime promo for some clinics.
