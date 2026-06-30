# RLS Matrix

This is the intended access model for current and near-term RLS policies.

| Scope | Roles | Access |
|---|---|---|
| Platform | `platform_owner`, `platform_admin` | Cross-tenant administration, tenant setup, plans, roles, support tools, audit logs according to permission. |
| Platform support | `platform_support` | Support and diagnostic access without ownership-only actions. |
| Platform sales | `platform_sales` | Tenant prospect/onboarding visibility without operational customer data where possible. |
| Tenant owner/admin | `tenant_owner`, `tenant_admin` | Full tenant management for one tenant, including customers, content, tickets, staff, and configuration. |
| Tenant manager | `tenant_manager` | Operational tenant management, CSR visibility, content/customer workflows, and CSR invites. No billing or platform onboarding. |
| Tenant CSR | `tenant_csr` | Customer-service queues, ticket detail, customer updates, ticket notes, and customer/location lookup needed for support. |
| Community contact | `community_admin` | Community-scoped content and contacts for assigned community/HOA context. |
| Customer | `customer_user` | Assigned service locations, relevant city/community content, own ticket submissions, and customer-visible ticket status/history. |

Legacy compatibility roles may still appear in data:

- `tenant_dispatch`: do not expose unless dispatch/routing returns as a product requirement.
- `hoa_manager`, `hoa_board`, `hoa_resident`: map toward `community_admin` or `customer_user`.
