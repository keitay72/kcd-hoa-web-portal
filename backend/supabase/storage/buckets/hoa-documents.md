# hoa-documents bucket

Legacy bucket name for customer portal documents.

Current path format: `{community_or_context_id}/{document_id}/{filename}`

Current behavior:

- Community/HOA documents are stored here.
- City-scoped residential documents may also use this bucket while the schema is transitional.
- Customers should receive signed access only for documents visible to their tenant, city/community context, customer account, or service location.
- Tenant staff and authorized community contacts can write documents according to role.

Future direction:

- Rename or replace the bucket only when data cleanup and migration are planned.
- Avoid exposing `hoa` terminology in the UI.
