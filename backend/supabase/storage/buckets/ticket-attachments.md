# ticket-attachments bucket

Stores customer service issue photos and staff ticket attachments.

Current path format: `{community_or_context_id}/{ticket_id}/{filename}`

Current behavior:

- Customers can upload photos while submitting a service issue.
- Tenant staff and CSRs can view attachments for tickets in their tenant scope.
- Customers can view attachments connected to their own assigned service locations and tickets.

The first path segment is legacy from the HOA-first implementation. New code should treat it as a customer/community/city context until storage paths are renamed.
