# Identity, Secrets & Network Security Model

How Atlas enforces zero-secrets-in-code (NFR2): Workload Identity federation, Key Vault CSI mounts, namespace network policies, and OIDC-based CI authentication.

```mermaid
flowchart TD
    subgraph CI["CI Pipeline"]
        GH["GitHub Actions\nWorkflow"]
        FED_CI["Federated Credential\n(OIDC — no long-lived keys)"]
        GH -->|"OIDC token"| FED_CI
        FED_CI -->|"exchange → short-lived\nAzure AD token"| AAD_CI["Azure AD"]
        AAD_CI -->|"ARM token"| TF["terraform apply"]
    end

    subgraph POD["Pod (workload namespace)"]
        SA["Kubernetes\nServiceAccount\n(annotated w/ MI client ID)"]
        APP["Application Container\n(no secrets in image)"]
        CSI_VOL["Mounted Volume\n/mnt/secrets\n(in-memory tmpfs)"]
        SA --> APP
        CSI_VOL --> APP
    end

    subgraph OIDC_FLOW["Workload Identity Federation"]
        OIDC_ISS["AKS OIDC Issuer\n(per cluster)"]
        FED_CRED["Federated Credential\n(K8s SA ↔ Managed Identity)"]
        MI["User-Assigned\nManaged Identity\n(per service)"]
        OIDC_ISS -->|"SA token projection"| FED_CRED
        FED_CRED --> MI
    end

    subgraph KV_ACCESS["Key Vault Access"]
        KV["Azure Key Vault\n(Key Vault Secrets User RBAC)"]
        CSI["Secrets Store\nCSI Driver"]
        SPC["SecretProviderClass\n(Key Vault refs only —\nno plaintext values)"]
        MI -->|"RBAC: least-privilege"| KV
        CSI -->|"uses MI token"| KV
        SPC --> CSI
        CSI --> CSI_VOL
    end

    subgraph NETPOL["Network Policies"]
        NS_GW["Namespace: atlas-gateway"]
        NS_AGENTS["Namespace: atlas-agents"]
        NS_MCP["Namespace: atlas-mcp"]
        NS_DATA["Namespace: atlas-data"]
        NS_GW -->|"allow"| NS_AGENTS
        NS_GW -->|"allow"| NS_MCP
        NS_AGENTS -->|"allow"| NS_DATA
        NS_MCP -->|"allow"| NS_DATA
        NS_AGENTS -.-|"deny (default)"| NS_MCP
        NS_GW -.-|"deny (default)"| NS_DATA
    end

    SA -->|"projected OIDC token"| OIDC_ISS
    SPC -.->|"mounted into"| POD

    INGRESS["Ingress Controller\n(TLS termination)"] -->|"HTTPS"| NS_GW
    INTERNET["Internet"] -->|"HTTPS 443"| INGRESS

    style CI fill:#f0f4ff,stroke:#6b7aff
    style OIDC_FLOW fill:#f0fff4,stroke:#38a169
    style KV_ACCESS fill:#fffbf0,stroke:#d97706
    style NETPOL fill:#fff0f0,stroke:#e53e3e
```
