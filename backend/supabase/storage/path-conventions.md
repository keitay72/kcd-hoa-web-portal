# Storage Path Conventions

- Documents: `hoa-documents/{community_or_context_id}/{document_id}/{filename}`
- Ticket attachments: `ticket-attachments/{community_or_context_id}/{ticket_id}/{filename}`

The bucket and first path segment names are legacy from the HOA-first implementation. Product-facing language should say documents, communities, cities, service locations, and tickets.

Target direction:

- Customer-visible documents should support tenant, city, community, customer account, and service-location scopes.
- Ticket attachments should support customer-submitted photos and staff-uploaded files.
- Signed access should be issued through Edge Functions so public bucket URLs are not required.
