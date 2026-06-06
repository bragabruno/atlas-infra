# Terraform Module Dependency Graph

Module composition and dependency order for `atlas-infra`. Environments (`envs/dev`, `envs/prod`) instantiate all modules; state is stored in Azure Blob Storage.

```mermaid
flowchart TD
    STATE["State Backend\nAzure Blob Storage\n(lease locking)"]

    subgraph ENVS["envs/"]
        DEV["envs/dev"]
        PROD["envs/prod"]
    end

    subgraph MODULES["infra/terraform/modules/"]
        NET["network\n(VNet, subnets, NSGs)"]
        AKS["aks\n(cluster, node pools,\nOIDC issuer, Workload Identity)"]
        IDN["identity\n(managed identities,\nfederated credentials,\nrole assignments)"]
        SEC["secrets\n(Key Vault,\nCSI driver,\nSecretProviderClass)"]
        DATA["data\n(PostgreSQL Flexible Server,\nRedis)"]
        STOR["storage\n(Blob containers,\nACR)"]
        KAFKA["kafka\n(Event Hubs / Strimzi)"]
        OBS["observability\n(OTel Collector,\nMLflow)"]
    end

    DEV -->|"compose"| NET
    PROD -->|"compose"| NET

    NET --> AKS

    AKS --> IDN
    AKS --> SEC
    AKS --> DATA
    AKS --> STOR
    AKS --> KAFKA
    AKS --> OBS

    IDN -.->|"provides identities to"| SEC
    IDN -.->|"provides identities to"| DATA
    IDN -.->|"provides identities to"| STOR
    IDN -.->|"provides identities to"| KAFKA
    IDN -.->|"provides identities to"| OBS

    DEV <-->|"remote state"| STATE
    PROD <-->|"remote state"| STATE
```
